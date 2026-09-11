# PARAKH Mobile — Legal Metrology Field Enforcement Client Documentation

> **Production-grade, offline-resilient, cross-platform React Native (Expo SDK 54 / Expo Router v6) mobile client developed for the Ministry of Consumer Affairs, Food & Public Distribution (SIH Problem Statement 26034).**

---

## 📑 Documentation Index

| Chapter | Document | Description |
|---|---|---|
| **01** | [**Problem Statement & Mobile UX Framework**](./01_PROBLEM_STATEMENT_AND_MOBILE_UX_FRAMEWORK.md) | In-depth analysis of SIH 26034 from the mobile field enforcement perspective, officer personas, harsh environment constraints, and zero-dummy-data core principles. |
| **02** | [**Technology Stack & Frontend Evaluation**](./02_FRONTEND_TECHNOLOGY_STACK_EVALUATION.md) | Technical architectural evaluation of **React Native + Expo SDK 54 vs Flutter vs Native Kotlin/Swift vs PWA**, file-based routing, Hermes engine, and React 19 compiler. |
| **03** | [**Application Architecture & State Management**](./03_APPLICATION_ARCHITECTURE_AND_STATE_MANAGEMENT.md) | Complete mobile architectural blueprints, global authentication lifecycle, dynamic host IP auto-detection (`expo-constants` bridge), and device resilience. |
| **04** | [**End-to-End API Integration & Network Resilience**](./04_END_TO_END_API_INTEGRATION_AND_NETWORK_RESILIENCE.md) | Exhaustive specification of all 12 REST API endpoints, multipart binary streaming, token serialization, stateless backend handling, and zero-latency failover. |
| **05** | [**Screen-by-Screen Deep Dive & User Flows**](./05_SCREEN_BY_SCREEN_DEEP_DIVE_AND_USER_FLOWS.md) | Exhaustive documentation of all 9 frontend screens: Login, Dashboard, Scan SKU, Audits History, Settings, Inspection Report, In-App CSV Viewer, In-App PDF Notice, and Evidence Viewer. |
| **06** | [**Design System, Typography & Statutory Aesthetics**](./06_DESIGN_SYSTEM_TYPOGRAPHY_AND_STATUTORY_AESTHETICS.md) | Design philosophy, WCAG 2.1 AA high-contrast typography, statutory color palette, card hierarchy, and official Directorate of Legal Metrology notice layout. |
| **07** | [**File Manifest & Engineering Changelog**](./07_FILE_MANIFEST_AND_ENGINEERING_CHANGELOG.md) | Chronological development history, problem-solving changelog, and clean file tree manifest. |
| **08** | [**Statutory Reports: CSV & PDF Generation**](./08_STATUTORY_REPORTS_CSV_AND_PDF_GENERATION.md) | Technical architecture of on-device RFC 4180 CSV generation, official Directorate Notice PDF compilation, Section 65B evidence, and native sharing. |

---

## 📱 System Overview & Architecture

```
+-------------------------------------------------------------------------------+
|                       PARAKH MOBILE FRONTEND (CLIENT)                         |
|                    React Native (v0.81) | Expo SDK 54 | Expo Router           |
+-------------------------------------------------------------------------------+
                                        |
  +-------------------------------------+------------------------------------+
  |                                     |                                    |
  v                                     v                                    v
[Presentation Layer]          [State & Auth Layer]                 [Network Layer]
- Dashboard Screen (index)    - AuthContext (JWT Provider)         - ApiClient (REST)
- Scan SKU Screen (scan)      - Dynamic Host IP Auto-Discovery     - Multipart Upload
- Audits History (inspections)- Token Storage (AsyncStorage)       - RFC 4180 CSV Gen
- Settings Screen (settings)  - Role Guard (Admin / Inspector)     - In-App Notice Doc
- Inspection Report (result)
- In-App CSV Viewer
- In-App Notice PDF Viewer
- Evidence Asset Viewer
                                        |
                                        v HTTP / REST (12 Endpoints)
+-------------------------------------------------------------------------------+
|                    PARAKH LEGAL METROLOGY BACKEND ENGINE                      |
|                  Rust (Axum) | PP-OCRv4 | ONNX Runtime CPU                    |
+-------------------------------------------------------------------------------+
```

---

## ⚡ Quickstart & Development Guide

### 1. Prerequisites
- **Node.js**: v18.x or v20.x+ installed.
- **Expo Go App**: Installed on physical Android or iOS device (from Google Play Store / Apple App Store).
- **PARAKH Backend Engine**: Running locally on `http://<YOUR_LOCAL_IP>:8080`.

### 2. Install Dependencies
Navigate to the mobile app directory:
```bash
cd "e:\New folder\my-app"
npm install
```

### 3. Start Expo Development Server
```bash
npm run start
```
- Metro bundler will start and display a QR code in the terminal.
- Open the **Expo Go** app on your mobile phone and scan the QR code.

### 4. Automatic Network Connection
The mobile app automatically reads the laptop's live IP address from the Metro bundler connection (`Constants.expoConfig.hostUri`). You **never** need to configure or edit IP addresses manually, even when switching Wi-Fi networks or mobile hotspots.

---

## 🔐 Default Credentials

| Role | Username | Password | Permissions |
|---|---|---|---|
| **Enforcement Director (Admin)** | `admin` | `admin@themis2026` | All endpoints, batch audits, global analytics, legal notice issuance. |
| **Field Inspector** | `inspector` | `inspector@themis2026` | Field SKU scans, rule evaluations, evidence verification, CSV audit exports. |
