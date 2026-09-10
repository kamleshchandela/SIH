pub mod routes;

pub use routes::{
    auth_login, export_inspection_csv, export_inspection_pdf, get_inspection_detail,
    get_inspection_stats, health_check, list_inspections, scan_path, scan_product_path,
    scan_sku_upload, scan_upload, serve_evidence_asset, AppState,
};
