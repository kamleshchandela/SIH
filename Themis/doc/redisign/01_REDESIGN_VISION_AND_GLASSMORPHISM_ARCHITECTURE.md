# Chapter 01: Frontend Redesign Vision & Glassmorphic Architecture

> **Themis Mobile-First Client (`themis_app`) — Fluid Glassmorphic UI/UX Redesign**  
> **Status:** Experimental Branch (`feature/frontend-redesign`)  
> **Target Platforms:** Android 11+ (Mobile), Linux / macOS / Windows (Desktop)

---

## 1. Executive Summary & Design Vision

The initial frontend of **Themis** was built as a utilitarian, monochrome desktop control panel suited for command-line operators and bench auditors. While highly functional, it lacked the tactile ergonomics, visual hierarchy, and polished aesthetic expected of a modern statutory inspection tool deployed to field enforcement officers under the Ministry of Consumer Affairs, Food & Public Distribution.

The **v2.0 Redesign** fundamentally transforms the interface into a **soft white-blue-purple glassmorphic ecosystem** inspired by modern fluid 3D UI paradigms (e.g., Apple visionOS, fluid spatial cards, and illuminated ambient mesh shaders).

```
+-------------------------------------------------------------------------+
|                              THEMIS v2.0                                |
|                        [ Fluid Glass Canvas ]                           |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |  Wallpaper Engine: Bundled Presets / Custom SAF File Picker     |   |
|   +-----------------------------------------------------------------+   |
|                                                                         |
|   +--------------------------+   +------------------------------+       |
|   |  Specular Border Cards   |   |   Floating Nav Pill          |       |
|   |  BackdropFilter Blur: 20 |   |   (Inspect, Dossier,         |       |
|   |  Translucent Gradient    |   |    Metrics, Engine)          |       |
|   +--------------------------+   +------------------------------+       |
|                                                                         |
|   +-----------------------------------------------------------------+   |
|   |  Multi-Tier Statutory Severity Chips (Cyan, Amber, Rose, Red)   |   |
|   +-----------------------------------------------------------------+   |
+-------------------------------------------------------------------------+
```

---

## 2. Design Tokens & Visual Language (`GlassTheme`)

All visual styling is strictly unified in [`themis_app/lib/theme/glass_theme.dart`](file:///home/arch/Projects/backbone/themis_app/lib/theme/glass_theme.dart). Ad-hoc color declarations and arbitrary opacities have been purged in favor of an audited design token catalog:

### A. Ambient & Neon Color Palette
| Token | Hex Value | Semantic Usage |
|---|---|---|
| `bgDark` | `#0A0C1B` | Base scaffold backdrop underlayer |
| `bgDeepPurple` | `#1B143F` | Secondary ambient container depth |
| `bgOceanCyan` | `#00C6FF` | Primary action highlights, active selection |
| `bgElectricBlue` | `#0072FF` | Secondary gradients and depth transitions |
| `bgViolet` | `#7F00FF` | Tertiary mesh ribbon lighting |
| `bgSoftLilac` | `#E0C3FC` | Ambient specular glow and highlight accents |
| `bgNeonCyan` | `#00F2FE` | High-visibility status indicators, compliance badges |

### B. Glass Surface Tokens
- **`glassCardGradient`**: `LinearGradient(0x33FFFFFF, 0x14FFFFFF)` — Multi-stop translucent wash providing depth without washing out dark mode.
- **`borderHighlight`**: `Color(0x66FFFFFF)` (40% white) — Directional light reflection along card perimeters.
- **`borderAmbient`**: `Color(0x1FFFFFFF)` (12% white) — Subtle opposite-edge ambient border.

---

## 3. Core Architectural Components

### A. `GlassContainer` ([`lib/widgets/glass/glass_container.dart`](file:///home/arch/Projects/backbone/themis_app/lib/widgets/glass/glass_container.dart))
The structural building block for all cards, panels, and modal dialogs.
- **Blur Isolation**: Wraps content in `ClipRRect(borderRadius: 24)` and `BackdropFilter(sigmaX: 20, sigmaY: 20)` to gently diffuse background textures while ensuring foreground typography is sharp.
- **Specular Edge Painting**: Employs a custom `_GlassBorderPainter` using `Canvas.drawRRect` with an angled linear gradient that simulates a physical beveled glass edge reflecting an overhead light source.
- **Ambient Occlusion**: Dual-layer `BoxShadow` with soft black drop shadow (`Offset(0, 8)`, blur 18) and a faint cyan dispersion glow.

### B. `FluidBackground` ([`lib/widgets/glass/fluid_background.dart`](file:///home/arch/Projects/backbone/themis_app/lib/widgets/glass/fluid_background.dart))
A composite canvas managing backdrops across the entire application stack:
1. **Dynamic Mesh Mode**: An animated 3D gradient mesh driven by a 18-second sinusoidal phase controller (`math.sin(t)`, `math.cos(t)`).
2. **Wallpaper Mode**: Displays ultra-high-definition wallpapers with zero CPU redraw overhead.
3. **Optical Glass Scrim**: A dynamically adjustable scrim overlay (`tintOpacity`: 0.10 to 0.65) that balances wallpaper vibrancy against text contrast.

### C. `GlassBottomBar` ([`lib/widgets/glass/glass_bottom_bar.dart`](file:///home/arch/Projects/backbone/themis_app/lib/widgets/glass/glass_bottom_bar.dart))
A floating capsule navigation bar inspired directly by iOS visionOS and spatial UI paradigms:
- Floats 16px above the display bottom margin with 32px corner radius.
- Contains 4 primary statutory workflows:
  1. **`INSPECT`**: Camera capture, file audit, and single/multi-panel OCR evaluation.
  2. **`DOSSIER`**: Searchable archive of completed inspections, penalty audits, and evidence records.
  3. **`METRICS`**: Interactive telemetry, compliance score distributions, and violation breakdown graphs.
  4. **`ENGINE`**: Hardware profiles, AI vision model selection, and backend host configuration.

---

## 4. Dynamic Wallpaper Engine & State Persistence

The wallpaper system is orchestrated by [`themis_app/lib/services/wallpaper_service.dart`](file:///home/arch/Projects/backbone/themis_app/lib/services/wallpaper_service.dart), implementing a singleton pattern with reactive `ChangeNotifier` state distribution.

### Curated Asset Presets
Twelve high-DPI wallpapers have been optimized and bundled in `assets/wallpapers/`:
- **Default**: `frostedglass.png` (3D frosted glass frost texture).
- **Crystals & Prisms**: `cleancrystal.png`, `circlecrystal.png`, `halfcrystal.png`, `frostedcrystal.png`, `frostedcrystalsunset.png`.
- **Atmospheric**: `frostedblue.png`, `frostedice.png`, `leavesbehindglassdark.png`, `iphone12-wallpaper.png`, `samsungs5_wallpaper.png`, `crystalbehindgassmonochrome.png`.

### Persistence Schema
Wallpaper selections, custom image file paths, and scrim opacity levels are persisted locally in `themis_wallpaper_config.json` via `path_provider`, restoring user preferences seamlessly across cold restarts.
