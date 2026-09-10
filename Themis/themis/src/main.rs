use anyhow::Result;
use axum::{
    extract::DefaultBodyLimit,
    routing::{get, post},
    Router,
};
use clap::Parser;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tracing::info;
use tracing_subscriber::FmtSubscriber;

use themis::api::{
    auth_login, export_inspection_csv, export_inspection_pdf, get_inspection_detail,
    get_inspection_stats, health_check, list_inspections, scan_path, scan_product_path,
    scan_sku_upload, scan_upload, serve_evidence_asset, AppState,
};
use themis::batch;
use themis::compliance;
use themis::db;
use themis::ocr::{self, OcrPipeline};

#[derive(Parser, Debug)]
#[command(
    name = "themis",
    version = "0.1.0",
    about = "Themis — Automated Legal Metrology (Packaged Commodities) Compliance Engine",
    after_help = "CLI USAGE EXAMPLES & NOTES:
  1. Single Packaging Panel Scan:
     themis --scan dataset/real_products/7622201756697_Oreo/panel_raw_3.jpg

  2. Manual Multi-Panel SKU Pooling:
     themis --scan front.jpg panel_raw_1.jpg panel_raw_2.jpg panel_raw_3.jpg

  3. Entire Product Directory SKU Pooling:
     themis --scan-product dataset/real_products/8901058000269_Maggi

  4. Export Report in JSON Format:
     themis --scan-product dataset/real_products/8901058000269_Maggi --json

  5. Native High-Performance Batch Audit (All Products):
     themis --batch dataset/real_products --profile 5/6

  6. Batch Audit with Custom JSON Export Path:
     themis --batch dataset/real_products --profile 5/6 --out-json my_report.json

  7. Run HTTP REST API Server:
     themis --port 8080

NOTES:
  • When executed from the project root, themis automatically locates models in 'themis/models'.
  • To run with debug logs: RUST_LOG=themis=debug themis --scan ...
  • Concurrency profiles for --batch: 5/6 (recommended), full, 3/4, 1/2, single, or custom:<N>."
)]
struct Cli {
    /// Port to listen on
    #[arg(short, long, default_value_t = 8080)]
    port: u16,

    /// Path to directory containing ONNX model files
    #[arg(long, default_value = "./models")]
    models_dir: PathBuf,

    /// Scan one or more packaging images, pooling all declarations across panels
    #[arg(short, long, num_args = 1..)]
    scan: Option<Vec<PathBuf>>,

    /// Scan an entire product directory, pooling all packaging panel images
    #[arg(long)]
    scan_product: Option<PathBuf>,

    /// Run native multi-threaded batch compliance scan across all product SKUs in a directory
    #[arg(short, long)]
    batch: Option<PathBuf>,

    /// Concurrency profile for batch scan (5/6, full, 3/4, 1/2, single, custom:<N>)
    #[arg(long)]
    profile: Option<String>,

    /// Custom output path for batch JSON audit report
    #[arg(long)]
    out_json: Option<PathBuf>,

    /// Output report in JSON format
    #[arg(long)]
    json: bool,

    /// Enforce single-threaded deterministic inference for bit-identical reproducibility
    #[arg(long)]
    deterministic: bool,

    /// Model tier preference ('server-int8', 'server', 'mobile-int8', 'mobile', or 'auto')
    #[arg(long)]
    model_tier: Option<String>,

    /// PostgreSQL connection URL (e.g. postgres://postgres@localhost:5432/themis)
    #[arg(long)]
    database_url: Option<String>,
}

fn resolve_models_path(candidate: &PathBuf) -> PathBuf {
    if candidate.exists() && candidate.join("ppocr_det.onnx").exists() {
        return candidate.clone();
    }
    let alternatives = [
        PathBuf::from("themis/models"),
        PathBuf::from("../themis/models"),
        PathBuf::from("/home/arch/Projects/backbone/themis/models"),
    ];
    for alt in &alternatives {
        if alt.exists() && alt.join("ppocr_det.onnx").exists() {
            return alt.clone();
        }
    }
    candidate.clone()
}

#[tokio::main]
async fn main() -> Result<()> {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("themis=info,ort=error"));
    // Log to STDERR so STDOUT stays machine-parseable (`--json` piping).
    let subscriber = FmtSubscriber::builder()
        .with_env_filter(filter)
        .with_writer(std::io::stderr)
        .finish();
    let _ = tracing::subscriber::set_global_default(subscriber);

    let cli = Cli::parse();
    if cli.deterministic {
        // Safety: called at start of main before spawning background worker threads
        unsafe {
            std::env::set_var("THEMIS_DETERMINISTIC", "1");
        }
        info!("Deterministic execution mode enabled (THEMIS_DETERMINISTIC=1)");
    }
    let models_dir = resolve_models_path(&cli.models_dir);

    // Handle native batch scanning if --batch is requested
    if let Some(ref batch_dir) = cli.batch {
        batch::run_native_batch_scan(
            batch_dir,
            &models_dir,
            cli.profile.as_deref(),
            cli.out_json.as_deref(),
        )
        .await?;
        return Ok(());
    }

    info!(
        "⚖️  Starting Themis Legal Metrology Compliance Engine (CPU Mode)"
    );

    // Initialize OCR pipeline on CPU
    let ocr = OcrPipeline::new_with_tier(&models_dir, cli.model_tier.as_deref())?;

    // Determine images to scan for CLI mode
    let mut images_to_scan: Vec<PathBuf> = Vec::new();
    let mut product_title: Option<String> = None;

    if let Some(prod_dir) = cli.scan_product {
        if prod_dir.is_file() {
            images_to_scan.push(prod_dir.clone());
            product_title = prod_dir
                .parent()
                .and_then(|p| p.file_name())
                .map(|n| n.to_string_lossy().to_string());
        } else {
            product_title = Some(
                prod_dir
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string(),
            );
            collect_images_recursive(&prod_dir, &mut images_to_scan);

            // Sort with Half-Image / Macro Panel Priority:
            // High-detail crops of statutory declarations (halfimage, macro, panel, detail)
            // take precedence over wide overview fullimage shots.
            images_to_scan.sort_by_key(|p| {
                let s = p.to_string_lossy().to_lowercase();
                if s.contains("half") || s.contains("macro") || s.contains("part") || s.contains("detail") {
                    0 // Priority 1: High-DPI macro panel crops
                } else if s.contains("panel") {
                    1 // Priority 2: Segmented panels
                } else if s.contains("full") || s.contains("wide") || s.contains("front") {
                    3 // Priority 4: Wide packaging shots
                } else {
                    2 // Priority 3: Standard panels
                }
            });
        }

        if images_to_scan.is_empty() {
            eprintln!("\x1b[91m[!] No packaging images found at: {}\x1b[0m", prod_dir.display());
            return Ok(());
        }
    } else if let Some(paths) = cli.scan {
        images_to_scan = paths;
        if images_to_scan.is_empty() {
            eprintln!("\x1b[91m[!] No valid image paths specified for --scan\x1b[0m");
            return Ok(());
        }
    }

    // Execute multi-image pooled product scan
    if !images_to_scan.is_empty() {
        let scanned_panel_names: Vec<String> = images_to_scan
            .iter()
            .map(|p| {
                let fname = p.file_name().unwrap_or_default().to_string_lossy().to_string();
                if let Some(parent) = p.parent().and_then(|pr| pr.file_name()) {
                    let pstr = parent.to_string_lossy();
                    if pstr == "halfimage" || pstr == "fullimage" || pstr.starts_with("panel") {
                        return format!("{}/{}", pstr, fname);
                    }
                }
                fname
            })
            .collect();

        info!(
            panels = images_to_scan.len(),
            "Executing pooled SKU compliance scan across all panels..."
        );

        let start = std::time::Instant::now();
        let mut pooled_tokens = Vec::new();
        let mut panel_qualities = Vec::new();
        let mut max_w = 0;
        let mut max_h = 0;

        for (idx, path) in images_to_scan.iter().enumerate() {
            let panel_tag = scanned_panel_names[idx].clone();
            if let Ok(rgb) = ocr::load_image_from_path(path) {
                let (w, h) = rgb.dimensions();
                max_w = max_w.max(w);
                max_h = max_h.max(h);
                let quality = compliance::quality::analyze_panel_quality(&panel_tag, &rgb);
                panel_qualities.push(quality);
                if let Ok(tokens) = ocr.process_image_with_source(&rgb, Some(panel_tag)) {
                    pooled_tokens.extend(tokens);
                }
            }
        }
        let duration = start.elapsed();

        let report = compliance::evaluate_compliance_with_quality(
            &pooled_tokens,
            max_w,
            max_h,
            product_title,
            scanned_panel_names,
            panel_qualities,
        );

        if cli.json {
            println!("{}", serde_json::to_string_pretty(&report)?);
            return Ok(());
        }

        println!("\n{}", "=".repeat(75));
        println!("       LEGAL METROLOGY COMPLIANCE INSPECTION REPORT (POOLED SKU)");
        println!("{}", "=".repeat(75));
        println!("Inspection ID : {}", report.inspection_id);
        println!("Timestamp     : {}", report.timestamp);
        if let Some(ref name) = report.product_name {
            println!("Product SKU   : {}", name);
        }
        println!("Scanned Panels: {} ({})", report.scanned_panels.len(), report.scanned_panels.join(", "));
        println!("Pooled Tokens : {} text regions across all panels", pooled_tokens.len());
        println!("Inference Time: {:.2?}", duration);
        println!("Overall Status: {}", if report.overall_compliant { "✅ COMPLIANT" } else { "❌ VIOLATION DETECTED" });
        println!("Statutory Risk: {}{}{}", report.risk_tier.color_code(), report.risk_tier.label(), "\x1b[0m");
        println!("Score         : {:.1}%\n", report.compliance_score_pct);

        if !report.panel_qualities.is_empty() {
            println!("PANEL IMAGE QUALITY & LAPLACIAN SHARPNESS:");
            println!("{}", "-".repeat(75));
            for q in &report.panel_qualities {
                let status_icon = if q.is_blurry { "\x1b[91m⚠️ BLURRY\x1b[0m" } else { "\x1b[92m✅ SHARP\x1b[0m" };
                println!("  • {:<18} | {} | {}", q.panel_name, status_icon, q.assessment);
            }
            println!();
        }

        println!("RULE-BY-RULE EVALUATION:");
        println!("{}", "-".repeat(75));
        for eval in &report.evaluations {
            let icon = match eval.status {
                compliance::Status::Compliant => "✅ PASS",
                compliance::Status::Violation => "❌ FAIL",
                compliance::Status::Warning => "⚠️ WARN",
                compliance::Status::NotApplicable => "ℹ️ N/A ",
            };
            let panel_tag = eval
                .source_panel
                .as_ref()
                .map(|p| format!(" [on {p}]"))
                .unwrap_or_default();
            println!("{icon} | {:<22} | {}{}", format!("{:?}", eval.field), eval.remarks, panel_tag);
        }

        if !report.violations.mandatory_missing.is_empty() {
            println!("\nMISSING MANDATORY DECLARATIONS (Rule 6 across all panels):");
            for m in &report.violations.mandatory_missing {
                println!("  • {:?}", m);
            }
        }

        if !report.violations.non_standard_units.is_empty() {
            println!("\nNON-STANDARD UNITS (Rule 13):");
            for u in &report.violations.non_standard_units {
                println!("  • '{u}' is illegal. Must use SI symbols (g, kg, ml, l).");
            }
        }

        if !report.violations.statutory_penalties.is_empty() {
            println!("\nSTATUTORY PENALTIES (Jan Vishwas Act Compounding):");
            for p in &report.violations.statutory_penalties {
                println!("  • {} | ₹{} compounding fine", p.section, p.compoundable_fine_inr);
            }
        }

        println!("\nEXTRACTED OCR TOKENS ({}):", report.raw_ocr_tokens.len());
        for t in &report.raw_ocr_tokens {
            let src = t.source_image.as_deref().unwrap_or("unknown");
            println!("  • [{:<16}] [({:3}, {:3}) {:3}x{:3}] \"{}\"", src, t.bbox.x, t.bbox.y, t.bbox.width, t.bbox.height, t.text);
        }
        println!("{}\n", "=".repeat(75));

        return Ok(());
    }

    // Initialize Database connection if available
    let db_url = cli.database_url.or_else(|| {
        std::env::var("DATABASE_URL").ok()
            .or_else(|| Some("postgres://postgres@localhost:5432/themis".to_string()))
    });

    let db_pool = if let Some(ref url) = db_url {
        info!("Connecting to PostgreSQL database at {}...", url);
        match sqlx::postgres::PgPoolOptions::new()
            .max_connections(10)
            .acquire_timeout(std::time::Duration::from_secs(3))
            .connect(url)
            .await
        {
            Ok(pool) => {
                info!("PostgreSQL connected successfully.");
                if let Err(e) = db::init_db(&pool).await {
                    tracing::warn!("Failed to initialize database schema: {e}");
                }
                Some(pool)
            }
            Err(e) => {
                tracing::warn!("PostgreSQL connection failed ({e}). Running in stateless in-memory mode.");
                None
            }
        }
    } else {
        None
    };

    // Otherwise run Axum HTTP REST server
    let state = Arc::new(AppState {
        ocr,
        db: db_pool,
        recent_inspections: std::sync::RwLock::new(themis::api::routes::load_local_inspections()),
    });

    let app = Router::new()
        .route("/api/v1/health", get(health_check))
        .route("/api/v1/auth/login", post(auth_login))
        .route("/api/v1/scan", post(scan_upload))
        .route("/api/v1/scan-path", post(scan_path))
        .route("/api/v1/scan-sku", post(scan_sku_upload))
        .route("/api/v1/scan-product-path", post(scan_product_path))
        .route("/api/v1/evidence/{id}/{panel}", get(serve_evidence_asset))
        .route("/api/v1/inspections", get(list_inspections))
        .route("/api/v1/inspections/{id}", get(get_inspection_detail))
        .route("/api/v1/inspections/{id}/export/csv", get(export_inspection_csv))
        .route("/api/v1/inspections/{id}/export/pdf", get(export_inspection_pdf))
        .route("/api/v1/stats", get(get_inspection_stats))
        .layer(DefaultBodyLimit::max(100 * 1024 * 1024))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], cli.port));
    info!("🚀 Themis REST API listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// Recursively collect all image paths within a directory tree
fn collect_images_recursive(dir: &std::path::Path, out: &mut Vec<std::path::PathBuf>) {
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() {
                collect_images_recursive(&p, out);
            } else if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
                let ext_lower = ext.to_lowercase();
                if ["jpg", "jpeg", "png", "webp"].contains(&ext_lower.as_str()) {
                    out.push(p);
                }
            }
        }
    }
}

