export type AuthRole = 'Admin' | 'Inspector';

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  token_type: string;
  role: AuthRole;
  username: string;
  expires_in_secs: number;
}

export interface HealthResponse {
  status: string;
  service: string;
  inference_device: string;
  active_regulations?: string;
  database_connected: boolean;
  timestamp: string;
}

export type RiskTier = 'LowRisk' | 'ModerateRisk' | 'HighRisk' | 'CriticalRisk';

export type ComplianceField =
  | 'Mrp'
  | 'NetQuantity'
  | 'MonthAndYearOfManufacture'
  | 'ExpiryDate'
  | 'BestBefore'
  | 'ConsumerCare'
  | 'ConsumerCarePhone'
  | 'ConsumerCareEmail'
  | 'Manufacturer'
  | 'Packer'
  | 'Importer'
  | 'CountryOfOrigin'
  | 'CommonGenericName'
  | 'FssaiLicenseNumber';

export type RuleStatus = 'Compliant' | 'Violation' | 'Warning' | 'NotApplicable';

export interface Evaluation {
  field: ComplianceField | string;
  status: RuleStatus;
  remarks: string;
  source_panel?: string | null;
  matched_token?: string | null;
}

export interface StatutoryPenalty {
  section: string;
  offense?: string;
  compoundable_fine_inr: number;
}

export interface Violations {
  mandatory_missing: string[];
  non_standard_units: string[];
  statutory_penalties: StatutoryPenalty[];
}

export interface PanelQuality {
  panel_name: string;
  is_blurry: boolean;
  laplacian_variance?: number;
  assessment: string;
}

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface RawOcrToken {
  text: string;
  confidence: number;
  bbox: BoundingBox;
  source_image?: string | null;
}

export interface ComplianceReport {
  inspection_id: string;
  timestamp: string;
  product_name?: string | null;
  scanned_panels: string[];
  overall_compliant: boolean;
  compliance_score_pct: number;
  risk_tier: RiskTier;
  panel_qualities: PanelQuality[];
  evaluations: Evaluation[];
  violations: Violations;
  raw_ocr_tokens: RawOcrToken[];
}

export interface InspectionSummary {
  inspection_id: string;
  product_name?: string | null;
  scanned_panels: string[];
  overall_compliant: boolean;
  risk_tier: RiskTier;
  compliance_score_pct: number;
  total_violations: number;
  compounding_fine_inr: number;
  created_at: string;
}

export interface InspectionListResponse {
  total: number;
  page: number;
  limit: number;
  total_pages?: number;
  inspections?: InspectionSummary[];
  items?: InspectionSummary[];
}

export interface InspectionStats {
  total_inspections: number;
  compliant_count?: number;
  violation_count?: number;
  total_compliant?: number;
  total_violations?: number;
  compliance_rate_pct?: number;
  total_penalties_inr?: number;
  total_compounding_fines_inr?: number;
  tier_breakdown?: Record<string, number>;
  risk_distribution?: Record<string, number>;
  top_missing_declarations?: Array<{ field: string; count: number }>;
}

export interface ScanProductPathRequest {
  product_dir?: string;
  file_paths?: string[];
  product_name?: string;
}
