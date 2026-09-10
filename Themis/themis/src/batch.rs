use anyhow::{Context, Result};
use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::Instant;

use crate::compliance::evaluate_compliance_with_quality;
use crate::compliance::types::{ComplianceReport, RiskTier};
use crate::ocr::OcrPipeline;

// ANSI Colors
const GREEN: &str = "\x1b[92m";
const RED: &str = "\x1b[91m";
const YELLOW: &str = "\x1b[93m";
const CYAN: &str = "\x1b[96m";
const MAGENTA: &str = "\x1b[95m";
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

#[derive(Debug, Clone)]
pub struct TargetSku {
    pub name: String,
    pub _path: PathBuf,
    pub panel_images: Vec<PathBuf>,
}

/// Discovers product subdirectories (each containing packaging panels) or flat images
pub fn discover_product_skus(target_dir: &Path) -> Result<Vec<TargetSku>> {
    let extensions = ["jpg", "jpeg", "png", "webp"];
    let mut skus = Vec::new();

    let mut entries: Vec<PathBuf> = std::fs::read_dir(target_dir)?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .collect();
    entries.sort();

    // Check if there are subdirectories (Product SKU directories)
    let subdirs: Vec<PathBuf> = entries.iter().filter(|p| p.is_dir()).cloned().collect();

    if !subdirs.is_empty() {
        for dir in subdirs {
            let mut panel_images = Vec::new();
            if let Ok(dir_entries) = std::fs::read_dir(&dir) {
                for file_res in dir_entries.flatten() {
                    let p = file_res.path();
                    if p.is_file() {
                        if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
                            if extensions.contains(&ext.to_lowercase().as_str()) {
                                panel_images.push(p);
                            }
                        }
                    }
                }
            }
            if !panel_images.is_empty() {
                panel_images.sort();
                let name = dir
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string();
                skus.push(TargetSku {
                    name,
                    _path: dir,
                    panel_images,
                });
            }
        }
    }

    // Fallback: flat list of images in target_dir
    if skus.is_empty() {
        let mut flat_images = Vec::new();
        for p in entries {
            if p.is_file() {
                if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
                    if extensions.contains(&ext.to_lowercase().as_str()) {
                        flat_images.push(p);
                    }
                }
            }
        }
        for img in flat_images {
            let name = img
                .file_stem()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();
            skus.push(TargetSku {
                name,
                _path: img.clone(),
                panel_images: vec![img],
            });
        }
    }

    Ok(skus)
}

/// Prompts user or parses concurrency profile
pub fn resolve_concurrency_workers(profile_arg: Option<&str>, total_cpus: usize) -> (usize, String) {
    let w_full = total_cpus;
    let w_5_6 = (total_cpus * 5 / 6).max(1);
    let w_3_4 = (total_cpus * 3 / 4).max(1);
    let w_1_2 = (total_cpus / 2).max(1);

    if let Some(arg) = profile_arg {
        match arg.to_lowercase().as_str() {
            "full" | "100" => return (w_full, "Full (100%)".to_string()),
            "5/6" | "83" => return (w_5_6, "5/6 (~83%) [Recommended]".to_string()),
            "3/4" | "75" => return (w_3_4, "3/4 (75%)".to_string()),
            "1/2" | "50" => return (w_1_2, "1/2 (50%)".to_string()),
            "single" | "1" => return (1, "Single Worker".to_string()),
            custom if custom.starts_with("custom:") => {
                if let Ok(val) = custom[7..].parse::<usize>() {
                    return (val.max(1), format!("Custom ({val} workers)"));
                }
            }
            _ => {}
        }
    }

    // Interactive prompt
    println!("\n{BOLD}Detected System Hardware: {total_cpus} Logical CPU Cores{RESET}");
    println!("{BOLD}Select Concurrency Profile (CPU Multi-threading):{RESET}");
    println!("  {CYAN}1){RESET} {BOLD}5/6 Threads (~83%){RESET} — {w_5_6} workers {GREEN}[Recommended: Maximum throughput + system headroom]{RESET}");
    println!("  {CYAN}2){RESET} Full Power (100%) — {w_full} workers [All CPU cores saturated]");
    println!("  {CYAN}3){RESET} 3/4 Threads (75%) — {w_3_4} workers [Balanced multi-tasking]");
    println!("  {CYAN}4){RESET} 1/2 Threads (50%) — {w_1_2} workers [Eco mode / Low thermal budget]");
    println!("  {CYAN}5){RESET} Single Worker — 1 worker [Sequential debug]");
    println!("  {CYAN}6){RESET} Custom worker count");

    print!("\nEnter choice [1-6, default: {BOLD}1{RESET}]: ");
    let _ = io::stdout().flush();

    let mut line = String::new();
    let stdin = io::stdin();
    if stdin.lock().read_line(&mut line).is_ok() {
        let trimmed = line.trim();
        match trimmed {
            "2" => (w_full, "Full (100%)".to_string()),
            "3" => (w_3_4, "3/4 (75%)".to_string()),
            "4" => (w_1_2, "1/2 (50%)".to_string()),
            "5" => (1, "Single Worker".to_string()),
            "6" => {
                print!("Enter custom worker count: ");
                let _ = io::stdout().flush();
                let mut custom_line = String::new();
                if stdin.lock().read_line(&mut custom_line).is_ok() {
                    if let Ok(val) = custom_line.trim().parse::<usize>() {
                        return (val.max(1), format!("Custom ({val} workers)"));
                    }
                }
                (w_5_6, "5/6 (~83%)".to_string())
            }
            _ => (w_5_6, "5/6 (~83%) [Recommended]".to_string()),
        }
    } else {
        (w_5_6, "5/6 (~83%) [Recommended]".to_string())
    }
}

/// Run native multi-threaded batch compliance scan
pub async fn run_native_batch_scan(
    target_dir: &Path,
    models_dir: &Path,
    profile_arg: Option<&str>,
    out_json: Option<&Path>,
) -> Result<()> {
    let total_cpus = std::thread::available_parallelism()
        .map(|p| p.get())
        .unwrap_or(4);

    println!("\n{BOLD}{CYAN}{}{RESET}", "=".repeat(85));
    println!("{BOLD}{CYAN}      THEMIS — NATIVE RUST LEGAL METROLOGY BATCH COMPLIANCE ENGINE{RESET}");
    println!("{BOLD}{CYAN}          (Multi-Panel SKU Pooling & LMPC 2011 Regulatory Audit){RESET}");
    println!("{BOLD}{CYAN}{}{RESET}", "=".repeat(85));

    let skus = discover_product_skus(target_dir)
        .with_context(|| format!("Failed to discover targets in {}", target_dir.display()))?;

    if skus.is_empty() {
        println!("{RED}[!] No product folders or packaging images found in {}{RESET}", target_dir.display());
        return Ok(());
    }

    let (workers, profile_name) = resolve_concurrency_workers(profile_arg, total_cpus);

    // Task-level macro-parallelism: single-threaded sessions inside workers so
    // W pipelines saturate W cores instead of oversubscribing (W × threads).
    // Respects an explicit user override.
    if std::env::var("THEMIS_INTRA_THREADS").is_err() {
        // SAFETY: set once at batch startup before worker threads spawn.
        unsafe { std::env::set_var("THEMIS_INTRA_THREADS", "1") };
    }

    println!("\n[✓] Discovered   : {BOLD}{} Complete Products{RESET} in {}", skus.len(), target_dir.display());
    println!("[✓] Concurrency  : {BOLD}{workers} parallel worker threads{RESET} ({profile_name})");
    println!("[✓] OCR Models   : {}", models_dir.display());

    // Pre-allocate exactly `workers` pipelines — load ONNX models once, not per task.
    // This is the key fix: previously each spawned task called OcrPipeline::new() which
    // reloaded the ONNX model from disk, causing massive overhead per product.
    print!("[…] Pre-loading {workers} OCR pipeline(s) into memory...");
    let _ = io::stdout().flush();
    let mut pipeline_pool: Vec<OcrPipeline> = Vec::with_capacity(workers);
    for i in 0..workers {
        match OcrPipeline::new(models_dir) {
            Ok(p) => pipeline_pool.push(p),
            Err(e) => {
                println!("\n{RED}[!] Failed to initialize pipeline #{}: {e}{RESET}", i + 1);
                return Err(e);
            }
        }
    }
    println!(" {GREEN}done{RESET} ({workers} pipeline(s) ready)\n");

    // Channel-based pipeline pool — receiving a pipeline IS the concurrency permit.
    // A task blocks on recv() until a free pipeline is returned by a finishing task.
    let (pipeline_tx, mut pipeline_rx) = tokio::sync::mpsc::channel::<OcrPipeline>(workers);
    for p in pipeline_pool {
        let _ = pipeline_tx.send(p).await;
    }
    let pipeline_tx = Arc::new(pipeline_tx);


    // Header for live progress
    println!("{BOLD}{:<10} | {:<18} | {:<7} | {:<32} | {:<20}{RESET}", "PROGRESS", "RISK TIER", "SCORE", "PRODUCT SKU", "PRIMARY STATUS / REMARKS");
    println!("{}", "-".repeat(100));

    let progress_counter = Arc::new(AtomicUsize::new(0));
    let total_targets = skus.len();
    let start_time = Instant::now();

    let (result_tx, mut result_rx) = tokio::sync::mpsc::channel::<ComplianceReport>(total_targets);

    // Spawn the dispatcher task: pulls pipelines from pool (blocks for backpressure),
    // hands each one to spawn_blocking for CPU work, then returns it to pool.
    let dispatcher = {
        let result_tx = result_tx.clone();
        let pipeline_tx = pipeline_tx.clone();
        let models_path = models_dir.to_path_buf();

        tokio::spawn(async move {
            for sku in skus {
                // Block here until a pipeline is available — this IS the semaphore
                let ocr = match pipeline_rx.recv().await {
                    Some(p) => p,
                    None => break,
                };

                let ptx = pipeline_tx.clone();
                let rtx = result_tx.clone();
                let _models = models_path.clone();

                tokio::spawn(async move {
                    let report_res = tokio::task::spawn_blocking(move || -> Result<(ComplianceReport, OcrPipeline)> {
                        let mut pooled_tokens = Vec::new();
                        let mut panel_names = Vec::new();
                        let mut panel_qualities = Vec::new();
                        let mut max_w = 0u32;
                        let mut max_h = 0u32;

                        for img_path in &sku.panel_images {
                            let fname = img_path
                                .file_name()
                                .unwrap_or_default()
                                .to_string_lossy()
                                .to_string();
                            panel_names.push(fname.clone());

                            if let Ok(rgb) = crate::ocr::load_image_from_path(img_path) {
                                let (w, h) = rgb.dimensions();
                                max_w = max_w.max(w);
                                max_h = max_h.max(h);
                                panel_qualities.push(
                                    crate::compliance::quality::analyze_panel_quality(&fname, &rgb),
                                );
                                if let Ok(tokens) = ocr.process_image_with_source(&rgb, Some(fname)) {
                                    pooled_tokens.extend(tokens);
                                }
                            }
                        }

                        let report = evaluate_compliance_with_quality(
                            &pooled_tokens,
                            max_w,
                            max_h,
                            Some(sku.name),
                            panel_names,
                            panel_qualities,
                        );
                        Ok((report, ocr))
                    })
                    .await;

                    if let Ok(Ok((report, returned_ocr))) = report_res {
                        // Return pipeline to pool
                        let _ = ptx.send(returned_ocr).await;
                        let _ = rtx.send(report).await;
                    }
                });
            }
        })
    };
    drop(result_tx);

    let mut reports = Vec::new();

    while let Some(rep) = result_rx.recv().await {
        let completed = progress_counter.fetch_add(1, Ordering::SeqCst) + 1;
        let pct = (completed as f32 / total_targets as f32) * 100.0;

        let tier_str = rep.risk_tier.label();
        let color = rep.risk_tier.color_code();

        let prod_name = rep.product_name.clone().unwrap_or_default();
        let short_name = if prod_name.len() > 30 {
            format!("{}...", &prod_name[..27])
        } else {
            prod_name
        };

        let remarks = if rep.risk_tier == RiskTier::Compliant {
            "Fully Compliant".to_string()
        } else if let Some(first_missing) = rep.violations.mandatory_missing.first() {
            format!("Missing {:?}", first_missing)
        } else {
            format!("{} issues detected", rep.violations.total_violations)
        };

        println!(
            "[{:>3}/{:<3}] {:>3.0}% | {}{:<18}{} | {:>5.1}% | {:<32} | {}",
            completed, total_targets, pct,
            color, tier_str, RESET,
            rep.compliance_score_pct,
            short_name,
            remarks
        );

        reports.push(rep);
    }

    let _ = dispatcher.await;
    let elapsed = start_time.elapsed().as_secs_f64();
    let throughput = total_targets as f64 / elapsed;

    // Statistical aggregation
    let mut compliant_count = 0;
    let mut low_risk_count = 0;
    let mut moderate_risk_count = 0;
    let mut high_risk_count = 0;
    let mut critical_count = 0;
    let mut total_score = 0.0;
    let mut total_penalties = 0u64;
    let mut missing_freq = HashMap::new();

    for r in &reports {
        match r.risk_tier {
            RiskTier::Compliant => compliant_count += 1,
            RiskTier::LowRiskMinor => low_risk_count += 1,
            RiskTier::ModerateRisk => moderate_risk_count += 1,
            RiskTier::HighRiskMajor => high_risk_count += 1,
            RiskTier::CriticalSevere => critical_count += 1,
        }
        total_score += r.compliance_score_pct;
        for p in &r.violations.statutory_penalties {
            total_penalties += p.compoundable_fine_inr;
        }
        for m in &r.violations.mandatory_missing {
            let key = format!("{:?}", m);
            *missing_freq.entry(key).or_insert(0) += 1;
        }
    }

    let avg_score = if !reports.is_empty() {
        total_score / reports.len() as f32
    } else {
        0.0
    };

    println!("\n{BOLD}{CYAN}{}{RESET}", "=".repeat(85));
    println!("{BOLD}{CYAN}                    LEGAL METROLOGY BATCH AUDIT REPORT{RESET}");
    println!("{BOLD}{CYAN}{}{RESET}", "=".repeat(85));
    println!("Evaluation Mode         : Product-Level SKU Pooling (All Panels Evaluated Together)");
    println!("Total Targets Audited   : {}", total_targets);
    println!("Parallel Worker Threads : {} ({})", workers, profile_name);
    println!("Total Wall-Clock Time   : {:.2} seconds", elapsed);
    println!("Processing Throughput   : {:.1} targets/sec ({:.1} ms wall-latency/product)", throughput, (elapsed / total_targets as f64) * 1000.0);
    println!("Average Compliance Score: {:.1}%", avg_score);
    println!("Total Assessed Penalties: ₹{} INR (under Jan Vishwas Act compounding)", total_penalties);

    println!("\n{BOLD}STATUTORY RISK TIER BREAKDOWN:{RESET}");
    println!("  {GREEN}• COMPLIANT            {RESET}: {:>2} products ({:.1}%)", compliant_count, (compliant_count as f32 / total_targets as f32) * 100.0);
    println!("  {CYAN}• LOW RISK (MINOR)     {RESET}: {:>2} products ({:.1}%)", low_risk_count, (low_risk_count as f32 / total_targets as f32) * 100.0);
    println!("  {YELLOW}• MODERATE RISK        {RESET}: {:>2} products ({:.1}%)", moderate_risk_count, (moderate_risk_count as f32 / total_targets as f32) * 100.0);
    println!("  {MAGENTA}• HIGH RISK (MAJOR)    {RESET}: {:>2} products ({:.1}%)", high_risk_count, (high_risk_count as f32 / total_targets as f32) * 100.0);
    println!("  {RED}• CRITICAL (SEVERE)    {RESET}: {:>2} products ({:.1}%)", critical_count, (critical_count as f32 / total_targets as f32) * 100.0);

    let mut freq_vec: Vec<(String, usize)> = missing_freq.into_iter().collect();
    freq_vec.sort_by(|a, b| b.1.cmp(&a.1));

    println!("\n{BOLD}TOP MISSING MANDATORY DECLARATIONS:{RESET}");
    for (name, cnt) in freq_vec.iter().take(6) {
        let bar_len = (cnt * 25) / total_targets;
        let bar = "█".repeat(bar_len);
        println!("  • {:<22} : {:>3} products {}{RESET}", name, cnt, bar);
    }

    // Save JSON audit file
    let default_out = PathBuf::from("dataset/batch_scan_results.json");
    let save_path = out_json.unwrap_or(&default_out);

    let export_payload = serde_json::json!({
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "evaluation_mode": "native_rust_sku_pooling",
        "concurrency_profile": profile_name,
        "worker_threads": workers,
        "total_targets": total_targets,
        "wall_time_seconds": elapsed,
        "throughput_fps": throughput,
        "summary": {
            "compliant_count": compliant_count,
            "low_risk_count": low_risk_count,
            "moderate_risk_count": moderate_risk_count,
            "high_risk_count": high_risk_count,
            "critical_count": critical_count,
            "average_score_pct": avg_score,
            "total_penalties_inr": total_penalties,
        },
        "results": reports,
    });

    if let Ok(json_str) = serde_json::to_string_pretty(&export_payload) {
        if let Some(parent) = save_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        if std::fs::write(save_path, json_str).is_ok() {
            println!("\n[✓] Full structured audit report saved to: {BOLD}{}{RESET}\n", save_path.display());
        }
    }

    Ok(())
}
