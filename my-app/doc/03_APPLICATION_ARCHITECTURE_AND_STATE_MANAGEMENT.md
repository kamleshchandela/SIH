# 03 — Application Architecture & State Management

> **Detailed architectural specifications of the mobile application layer, global state machines, authentication lifecycles, and the dynamic host IP auto-discovery system.**

---

## 1. High-Level Mobile Layer Architecture

The mobile application enforces a strict unidirectional data flow and clean separation of concerns:

```
+-------------------------------------------------------------------------------+
|                             PRESENTATION LAYER                                |
|   (app/*.tsx Screens, Expo Router Stack, Tab Navigators, Safe Area Insets)     |
+-------------------------------------------------------------------------------+
                                      |
                                      v (Custom Hook: useAuth())
+-------------------------------------------------------------------------------+
|                           STATE & CONTEXT LAYER                               |
|            src/context/AuthContext.tsx (Global Authentication State)          |
|  - Active User & Role Guard      - Dynamic Host IP Auto-Resolver              |
|  - Token Expiry Machine          - AsyncStorage Persistence Bridge            |
+-------------------------------------------------------------------------------+
                                      |
                                      v (Instantiates ApiClient)
+-------------------------------------------------------------------------------+
|                            SERVICE & API LAYER                                |
|                src/services/api.ts (PARAKH Unified REST Client)                |
|  - 12 REST Endpoints             - Multipart FormData Streamer                |
|  - 401 Session Interceptor       - Native FileSystem Downloader               |
+-------------------------------------------------------------------------------+
                                      |
                                      v (HTTP / HTTPS)
+-------------------------------------------------------------------------------+
|                       PARAKH RUST BACKEND ENGINE (8080)                       |
+-------------------------------------------------------------------------------+
```

---

## 2. Global State Management: Why Context API Over Redux

For an operational field tool, state complexity must remain lean, predictable, and memory-safe.
- **Redux / Redux Toolkit:** Introduces 40+ KB of boilerplate, action creators, reducers, and serialization overhead. It causes unnecessary re-renders when handling high-frequency camera states.
- **React Context API (`AuthContext`):** Native to React, zero external bundle weight, perfectly scoped to global auth credentials, backend connectivity states, and role permissions.

### The Auth State Machine (`src/context/AuthContext.tsx`):
```typescript
interface AuthContextType {
  token: string | null;           // Active JWT bearer token
  username: string | null;        // Authenticated officer handle (e.g. "admin")
  role: AuthRole | null;          // Role enum: "Admin" | "Inspector"
  baseUrl: string;                // Active backend engine address
  isLoading: boolean;             // Initial storage bootstrap state
  api: ApiClient;                 // Pre-configured ApiClient singleton
  login: (u: string, p: string) => Promise<LoginResponse>;
  logout: () => Promise<void>;
  updateBaseUrl: (newUrl: string) => Promise<void>;
}
```

### Authentication Lifecycle & 24-Hour Token Persistence:
1. **Cold Launch:** App boots with `isLoading = true`.
2. **Storage Bootstrap:** Reads 5 persistent keys from `AsyncStorage`:
   - `themis_token`: The JWT string.
   - `themis_user`: Officer handle.
   - `themis_role`: Authorization level (`Admin` or `Inspector`).
   - `themis_base_url`: Target engine URL.
   - `themis_token_expiry`: Epoch timestamp.
3. **Expiry Check:** Evaluates `Date.now() < Number(savedExpiry)`. If expired, silently flushes credentials and redirects to `app/login.tsx`. If valid, hydrates state instantly.
4. **Auto-Logout on HTTP 401:** If any API call returns `401 Unauthorized` (e.g. backend restarted with new JWT secret key), `ApiClient` invokes `onUnauthorized()` which automatically wipes storage and presents the login screen.

---

## 3. The Dynamic Host IP Auto-Discovery System

### The Mobile Hotspot "Subnet Hopping" Paradox
During field operations, officers often connect their testing laptops to their smartphone's mobile hotspot.
Android mobile hotspots dynamically change subnets whenever toggled:
- Session 1: `192.168.1.84` (Home Wi-Fi)
- Session 2: `10.40.218.132` (Mobile Hotspot Initial Subnet)
- Session 3: `10.236.186.132` (Mobile Hotspot Reconnected Subnet)

If the mobile app relies on a hardcoded `.env` file, the app immediately breaks with **"Request timed out"** or **"Engine connection failed"** every time the network reconnects.

### The Solution: Runtime Metro Host Discovery
When Expo Go downloads the JavaScript bundle from the laptop, Expo's native runtime already knows the laptop's exact active IP address via `Constants.expoConfig.hostUri`:

```typescript
// src/context/AuthContext.tsx
import Constants from 'expo-constants';

export function getAutoDetectedBaseUrl(): string {
  // Extract hostUri from Expo Constants (the host that served the JS bundle)
  const hostUri =
    Constants.expoConfig?.hostUri ||
    (Constants as any).manifest?.debuggerHost ||
    (Constants as any).manifest2?.extra?.expoClient?.hostUri;

  if (hostUri) {
    const hostIp = hostUri.split(':')[0]; // Extracts "10.236.186.132"
    if (hostIp && hostIp !== 'localhost' && hostIp !== '127.0.0.1') {
      return `http://${hostIp}:8080`;
    }
  }

  // Graceful fallback to env or current IP
  return process.env.EXPO_PUBLIC_API_BASE_URL || 'http://10.236.186.132:8080';
}
```

### Self-Healing Cache Synchronization
In `loadAuth()`, the app compares the previously stored `savedUrl` in `AsyncStorage` with the newly detected `dynamicUrl`:
- If `savedHost !== detectedHost`, the app **automatically updates `AsyncStorage`** and migrates `baseUrl` to the new live IP on the fly.
- **Zero manual configuration is ever required by the officer.**

---

## 4. UI Layer Architecture & Screen Organization

Expo Router organizes screens into an intuitive stack with bottom tabs:

| Route | File Path | Type | Access Level | Description |
|---|---|---|---|---|
| `/` | `app/(tabs)/index.tsx` | Bottom Tab | Officer | Real-time Engine & AI Core status card, compliance statistics, Jan Vishwas fines. |
| `/scan` | `app/(tabs)/scan.tsx` | Bottom Tab | Officer | Single Panel, Multi-Panel SKU upload strip, Server Path & Directory inputs. |
| `/inspections` | `app/(tabs)/inspections.tsx` | Bottom Tab | Officer | Historical repository list, debounced search, risk tier filter pills, pagination. |
| `/settings` | `app/(tabs)/settings.tsx` | Bottom Tab | Officer | Officer profile, engine address override, regulatory legal acts, logout. |
| `/login` | `app/login.tsx` | Full Modal | Public | Secure JWT credential authentication form. |
| `/result` | `app/result.tsx` | Stack Push | Officer | Comprehensive statutory audit report, progress bar, rule evaluations, OCR text. |
| `/csv-viewer` | `app/csv-viewer.tsx` | Stack Push | Officer | In-app scrollable spreadsheet table with native CSV export and share sheet. |
| `/pdf-viewer` | `app/pdf-viewer.tsx` | Stack Push | Officer | Official statutory show-cause notice layout with Section 36(1) charges and native share. |
| `/evidence` | `app/evidence.tsx` | Stack Push | Officer | Packaging photo asset viewer with pinch-to-zoom and native share. |
