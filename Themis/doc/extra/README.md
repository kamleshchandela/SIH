# Extra Technical Documentation & Handoff Guides

This directory contains cross-platform setup guides, environment requirements, and inter-team contracts.

## Documents Index

| Document | Description |
|---|---|
| [**Windows Dependency & Setup Guide**](file:///home/arch/Projects/backbone/doc/extra/WINDOWS_DEPENDENCY_AND_SETUP_GUIDE.md) | Complete guide for Windows 10/11: one-line `winget` installation, MSVC C++ build tools, Rustup, PostgreSQL setup, and PowerShell commands. |
| [**Frontend vs. Backend Division of Responsibilities**](file:///home/arch/Projects/backbone/doc/extra/FRONTEND_VS_BACKEND_RESPONSIBILITIES.md) | Architectural division of labor: what the backend provides (rich JSON, AI vision, rule engine, PostgreSQL), and what the frontend implements (UI, canvas overlays, client-side XLSX via SheetJS, and printable statutory PDF notices). |
| [**Advanced Compliance & Evidence Engine Specification**](file:///home/arch/Projects/backbone/doc/extra/ADVANCED_COMPLIANCE_AND_EVIDENCE_ENGINE.md) | Complete technical documentation for Rule 7 / Schedule II numeral height, Laplacian blur sharpness thresholding, evidence photograph storage & static streaming, role-based JWT auth, and direct PDF/CSV statutory export. |
| [**Incident Postmortem: ARM64 Concurrency Starvation & Swap Thrashing**](file:///home/arch/Projects/backbone/doc/extra/INCIDENT_POSTMORTEM_ARM64_CONCURRENCY_STARVATION_AND_SWAP_THRASHING.md) | Technical postmortem of P1 memory exhaustion: unthrottled concurrent isolate spawning, zRAM saturation, kswapd0 thrashing, and single-flight mutex remediation on Pixel 4a 5G. |
| [**Incident Postmortem: Re-entrant Storage Recursion & Event Loop Starvation**](file:///home/arch/Projects/backbone/doc/extra/INCIDENT_POSTMORTEM_ASYNC_RECURSION_AND_EVENT_LOOP_STARVATION.md) | Technical postmortem of P1 UI freeze and scan stalling: unlatched async storage initialization loop, Dart isolate event queue starvation vs OS swap thrashing comparison, and SAF export integration. |
