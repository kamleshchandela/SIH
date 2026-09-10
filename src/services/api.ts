import {
  ComplianceReport,
  HealthResponse,
  InspectionListResponse,
  InspectionStats,
  LoginRequest,
  LoginResponse,
} from '../types/themis';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';

export class ApiClient {
  private baseUrl: string;
  private token: string | null = null;
  private onUnauthorized?: () => void;

  constructor(baseUrl: string, token: string | null = null, onUnauthorized?: () => void) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.token = token;
    this.onUnauthorized = onUnauthorized;
  }

  setToken(token: string | null) {
    this.token = token;
  }

  setBaseUrl(url: string) {
    this.baseUrl = url.replace(/\/+$/, '');
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
    const headers: Record<string, string> = {
      Accept: 'application/json',
      ...((options.headers as Record<string, string>) || {}),
    };

    if (this.token && !headers['Authorization']) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (response.status === 401) {
      if (this.onUnauthorized) {
        this.onUnauthorized();
      }
      throw new Error('Unauthorized or expired session. Please log in again.');
    }

    if (!response.ok) {
      const errorText = await response.text();
      let errorMsg = `HTTP ${response.status}: ${response.statusText}`;
      try {
        const errorJson = JSON.parse(errorText);
        if (typeof errorJson === 'string') errorMsg = errorJson;
        else if (errorJson.message) errorMsg = errorJson.message;
        else if (errorJson.error) errorMsg = errorJson.error;
      } catch {
        if (errorText) errorMsg = errorText;
      }
      throw new Error(errorMsg);
    }

    return response.json();
  }

  // 1. Login
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    return this.request<LoginResponse>('/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
    });
  }

  // 2. Health check
  async getHealth(): Promise<HealthResponse> {
    return this.request<HealthResponse>('/api/v1/health');
  }

  // 3. Scan single image upload (Multipart)
  async scanSingle(imageUri: string, filename = 'panel.jpg'): Promise<ComplianceReport> {
    const formData = new FormData();
    const type = filename.endsWith('.png') ? 'image/png' : 'image/jpeg';
    
    // React Native FormData format
    formData.append('file', {
      uri: imageUri,
      name: filename,
      type,
    } as any);

    return this.request<ComplianceReport>('/api/v1/scan', {
      method: 'POST',
      body: formData,
    });
  }

  // 4. Scan multi-panel SKU upload (Multipart)
  async scanSku(
    productName: string,
    images: Array<{ uri: string; name?: string }>
  ): Promise<ComplianceReport> {
    const formData = new FormData();
    if (productName.trim()) {
      formData.append('product_name', productName.trim());
    }

    images.forEach((img, idx) => {
      const name = img.name || `panel_${idx + 1}.jpg`;
      const type = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
      formData.append('files', {
        uri: img.uri,
        name,
        type,
      } as any);
    });

    return this.request<ComplianceReport>('/api/v1/scan-sku', {
      method: 'POST',
      body: formData,
    });
  }

  // 5. Scan local file path
  async scanPath(filePath: string): Promise<ComplianceReport> {
    return this.request<ComplianceReport>('/api/v1/scan-path', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ file_path: filePath }),
    });
  }

  // 6. Scan product directory or multiple paths
  async scanProductPath(params: {
    product_dir?: string;
    product_name?: string;
    file_paths?: string[];
  }): Promise<ComplianceReport> {
    return this.request<ComplianceReport>('/api/v1/scan-product-path', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    });
  }

  // 7. Get Evidence Asset URL
  getEvidenceUrl(inspectionId: string, panelFilename: string): string {
    let filename = (panelFilename || '').trim();
    if (filename === 'panel.jpg' || filename === 'panel') {
      filename = 'panel_1.jpg';
    }
    return `${this.baseUrl}/api/v1/evidence/${encodeURIComponent(
      inspectionId
    )}/${encodeURIComponent(filename)}`;
  }

  // 8. List past inspections
  async getInspections(query: {
    page?: number;
    limit?: number;
    risk_tier?: string;
    compliant?: boolean;
    search?: string;
  } = {}): Promise<InspectionListResponse> {
    const params = new URLSearchParams();
    if (query.page) params.append('page', query.page.toString());
    if (query.limit) params.append('limit', query.limit.toString());
    if (query.risk_tier && query.risk_tier !== 'All') params.append('risk_tier', query.risk_tier);
    if (query.compliant !== undefined) params.append('compliant', query.compliant.toString());
    if (query.search?.trim()) params.append('search', query.search.trim());

    const qs = params.toString();
    return this.request<InspectionListResponse>(`/api/v1/inspections${qs ? `?${qs}` : ''}`);
  }

  // 9. Get inspection detail
  async getInspectionDetail(id: string): Promise<ComplianceReport> {
    return this.request<ComplianceReport>(`/api/v1/inspections/${encodeURIComponent(id)}`);
  }

  // 10. Export CSV Report
  async exportCsv(id: string): Promise<string> {
    const url = `${this.baseUrl}/api/v1/inspections/${encodeURIComponent(id)}/export/csv`;
    const headers: Record<string, string> = {};
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

    const response = await fetch(url, { headers });
    if (!response.ok) {
      throw new Error(`Failed to export CSV (${response.statusText})`);
    }
    const csvContent = await response.text();

    // Save to local file & share
    const fileUri = `${FileSystem.cacheDirectory}statutory_audit_${id}.csv`;
    await FileSystem.writeAsStringAsync(fileUri, csvContent, {
      encoding: FileSystem.EncodingType.UTF8,
    });

    if (await Sharing.isAvailableAsync()) {
      await Sharing.shareAsync(fileUri, {
        mimeType: 'text/csv',
        dialogTitle: `Export Inspection CSV (${id})`,
        UTI: 'public.comma-separated-values-text',
      });
    }

    return fileUri;
  }

  // 11. Export PDF Show-Cause Notice
  async exportPdf(id: string): Promise<string> {
    const url = `${this.baseUrl}/api/v1/inspections/${encodeURIComponent(id)}/export/pdf`;
    const headers: Record<string, string> = {};
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

    const fileUri = `${FileSystem.cacheDirectory}statutory_notice_${id}.pdf`;
    
    // Download PDF directly
    const downloadRes = await FileSystem.downloadAsync(url, fileUri, { headers });
    if (downloadRes.status !== 200) {
      throw new Error(`Failed to download PDF notice (${downloadRes.status})`);
    }

    if (await Sharing.isAvailableAsync()) {
      await Sharing.shareAsync(downloadRes.uri, {
        mimeType: 'application/pdf',
        dialogTitle: `Statutory Notice PDF (${id})`,
        UTI: 'com.adobe.pdf',
      });
    }

    return downloadRes.uri;
  }

  // 12. Get overall analytics stats
  async getStats(): Promise<InspectionStats> {
    return this.request<InspectionStats>('/api/v1/stats');
  }
}
