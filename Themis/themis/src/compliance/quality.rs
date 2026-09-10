use serde::{Deserialize, Serialize};

/// Image quality diagnostic metrics for a packaging panel
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PanelImageQuality {
    pub panel_name: String,
    pub width: u32,
    pub height: u32,
    pub laplacian_variance: f32,
    pub is_blurry: bool,
    pub assessment: String,
}

/// Computes the discrete Laplacian variance to assess image sharpness vs camera motion blur
/// L(x, y) = I(x+1, y) + I(x-1, y) + I(x, y+1) + I(x, y-1) - 4*I(x, y)
pub fn analyze_panel_quality(panel_name: &str, img: &image::RgbImage) -> PanelImageQuality {
    let (w, h) = img.dimensions();
    if w < 3 || h < 3 {
        return PanelImageQuality {
            panel_name: panel_name.to_string(),
            width: w,
            height: h,
            laplacian_variance: 0.0,
            is_blurry: true,
            assessment: "Image too small for sharpness analysis".to_string(),
        };
    }

    // Downsample if image is gigantic (> 1200px on any side) for ultra-fast calculation
    let target_w = if w > 1200 { 1200 } else { w };
    let target_h = (h as f32 * (target_w as f32 / w as f32)).round() as u32;

    let resized = if target_w != w {
        image::imageops::resize(img, target_w, target_h, image::imageops::FilterType::Nearest)
    } else {
        img.clone()
    };

    let (rw, rh) = resized.dimensions();
    // Convert to grayscale luminance: Y = 0.299*R + 0.587*G + 0.114*B
    let mut gray = vec![0u8; (rw * rh) as usize];
    for y in 0..rh {
        for x in 0..rw {
            let p = resized.get_pixel(x, y);
            let lum = (0.299 * p[0] as f32 + 0.587 * p[1] as f32 + 0.114 * p[2] as f32).round() as u8;
            gray[(y * rw + x) as usize] = lum;
        }
    }

    let mut sum = 0.0f64;
    let mut sum_sq = 0.0f64;
    let mut count = 0u64;

    for y in 1..(rh - 1) {
        let row_up = ((y - 1) * rw) as usize;
        let row_cur = (y * rw) as usize;
        let row_down = ((y + 1) * rw) as usize;

        for x in 1..(rw - 1) {
            let x_u = x as usize;
            let center = gray[row_cur + x_u] as i32;
            let up = gray[row_up + x_u] as i32;
            let down = gray[row_down + x_u] as i32;
            let left = gray[row_cur + x_u - 1] as i32;
            let right = gray[row_cur + x_u + 1] as i32;

            let lap = (up + down + left + right) - 4 * center;
            let lap_f = lap as f64;
            sum += lap_f;
            sum_sq += lap_f * lap_f;
            count += 1;
        }
    }

    let variance = if count > 0 {
        let mean = sum / count as f64;
        (sum_sq / count as f64) - (mean * mean)
    } else {
        0.0
    };

    let var_f32 = (variance as f32 * 10.0).round() / 10.0;
    let is_blurry = var_f32 < 100.0;

    let assessment = if var_f32 >= 250.0 {
        format!("High sharpness (Laplacian variance: {var_f32}). Crisp packaging edges confirmed.")
    } else if var_f32 >= 100.0 {
        format!("Acceptable sharpness (Laplacian variance: {var_f32}). Legible statutory text.")
    } else if var_f32 >= 50.0 {
        format!("Moderate blur detected (Laplacian variance: {var_f32}). Re-capture recommended if text is smudged.")
    } else {
        format!("Severe blur / out-of-focus capture (Laplacian variance: {var_f32}). Motion-blurred camera artifact.")
    };

    PanelImageQuality {
        panel_name: panel_name.to_string(),
        width: w,
        height: h,
        laplacian_variance: var_f32,
        is_blurry,
        assessment,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{Rgb, RgbImage};

    #[test]
    fn test_laplacian_blur_flat_image() {
        // Flat gray image has zero edge contrast -> variance should be 0.0 -> is_blurry = true
        let flat = RgbImage::from_pixel(100, 100, Rgb([128, 128, 128]));
        let q = analyze_panel_quality("flat.png", &flat);
        assert_eq!(q.laplacian_variance, 0.0);
        assert!(q.is_blurry);
    }

    #[test]
    fn test_laplacian_sharp_checkerboard() {
        // Alternating high-contrast black/white pixels -> very high edge variance
        let mut sharp = RgbImage::new(50, 50);
        for y in 0..50 {
            for x in 0..50 {
                let color = if (x + y) % 2 == 0 { 255 } else { 0 };
                sharp.put_pixel(x, y, Rgb([color, color, color]));
            }
        }
        let q = analyze_panel_quality("sharp.png", &sharp);
        assert!(q.laplacian_variance > 1000.0);
        assert!(!q.is_blurry);
    }
}

