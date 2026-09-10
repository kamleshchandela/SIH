use anyhow::Result;

/// Parse EXIF orientation from raw image byte stream without external dependencies.
/// Returns orientation tag 1..8 (1 = normal / no rotation).
pub fn get_exif_orientation(data: &[u8]) -> u16 {
    if data.len() < 4 || data[0] != 0xFF || data[1] != 0xD8 {
        return 1;
    }
    let mut idx = 2;
    while idx + 4 < data.len() {
        if data[idx] != 0xFF {
            break;
        }
        let marker = data[idx + 1];
        let length = ((data[idx + 2] as usize) << 8) | (data[idx + 3] as usize);
        if marker == 0xE1 && idx + 10 <= data.len() && &data[idx + 4..idx + 10] == b"Exif\0\0" {
            let exif_start = idx + 10;
            if exif_start + 8 > data.len() {
                return 1;
            }
            let is_le = &data[exif_start..exif_start + 2] == b"II";
            let read_u16 = |buf: &[u8], offset: usize| -> Option<u16> {
                if offset + 2 > buf.len() {
                    return None;
                }
                Some(if is_le {
                    u16::from_le_bytes([buf[offset], buf[offset + 1]])
                } else {
                    u16::from_be_bytes([buf[offset], buf[offset + 1]])
                })
            };
            let read_u32 = |buf: &[u8], offset: usize| -> Option<u32> {
                if offset + 4 > buf.len() {
                    return None;
                }
                Some(if is_le {
                    u32::from_le_bytes([buf[offset], buf[offset + 1], buf[offset + 2], buf[offset + 3]])
                } else {
                    u32::from_be_bytes([buf[offset], buf[offset + 1], buf[offset + 2], buf[offset + 3]])
                })
            };
            let first_ifd = match read_u32(&data[exif_start..], 4) {
                Some(o) => o as usize,
                None => return 1,
            };
            let ifd_start = exif_start + first_ifd;
            let num_entries = match read_u16(data, ifd_start) {
                Some(n) => n as usize,
                None => return 1,
            };
            for i in 0..num_entries {
                let entry_start = ifd_start + 2 + i * 12;
                if entry_start + 12 > data.len() {
                    break;
                }
                if let Some(tag) = read_u16(data, entry_start) {
                    if tag == 0x0112 {
                        return read_u16(data, entry_start + 8).unwrap_or(1);
                    }
                }
            }
        }
        idx += 2 + length;
    }
    1
}

/// Apply EXIF orientation rotation to normalize image to standard display coordinates
pub fn apply_exif_orientation(img: image::RgbImage, orientation: u16) -> image::RgbImage {
    match orientation {
        3 => image::imageops::rotate180(&img),
        6 => image::imageops::rotate90(&img),
        8 => image::imageops::rotate270(&img),
        _ => img,
    }
}

/// Load image from in-memory bytes with automatic EXIF orientation normalization
pub fn load_image_from_bytes(data: &[u8]) -> Result<image::RgbImage> {
    let orientation = get_exif_orientation(data);
    let img = image::load_from_memory(data)?.to_rgb8();
    Ok(apply_exif_orientation(img, orientation))
}

/// Load image from filesystem path with automatic EXIF orientation normalization
pub fn load_image_from_path<P: AsRef<std::path::Path>>(path: P) -> Result<image::RgbImage> {
    let data = std::fs::read(path)?;
    load_image_from_bytes(&data)
}
