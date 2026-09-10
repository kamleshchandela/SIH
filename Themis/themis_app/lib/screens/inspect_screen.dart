import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/compliance_report.dart';
import '../services/demo_asset_service.dart';
import '../services/dev_logger.dart';
import '../services/glass_perf_service.dart';
import '../services/themis_api.dart';
import '../theme/sober_theme.dart';
import '../theme/glass_theme.dart';
import '../widgets/bounding_box_canvas.dart';
import '../widgets/clause_tile.dart';
import '../widgets/dashed_border.dart';
import '../widgets/glass/glass_action_grid.dart';
import '../widgets/glass/glass_circular_gauge.dart';
import '../widgets/glass/glass_container.dart';
import '../widgets/glass/glass_wave_chart.dart';
import '../widgets/sober/sober_badge.dart';
import '../widgets/sober/sober_dashboard.dart';
import '../widgets/sober/sober_spacer.dart';
import '../widgets/sober/sober_timeline.dart';
import 'dev_logs_screen.dart';

enum ScanTab { singlePanel, multiSku, serverPath }

class InspectScreen extends StatefulWidget {
  /// Tab-switch hook from the shell (dashboard shortcuts). Null-safe:
  /// plain Inspect usage just ignores it.
  final ValueChanged<int>? onOpenTab;

  const InspectScreen({super.key, this.onOpenTab});

  @override
  State<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends State<InspectScreen> {
  final ThemisApiService _api = ThemisApiService();

  ScanTab _currentTab = ScanTab.singlePanel;

  // Single Panel Tab State
  String? _singlePanelPath;

  // Multi SKU Tab State
  final TextEditingController _productNameController = TextEditingController();
  final List<String> _panelPaths = [];
  int _selectedPanelIndex = 0;

  // Server Path Tab State
  final TextEditingController _serverFilePathController = TextEditingController(
    text: '/home/arch/Projects/backbone/dataset/mine/maggie/IMG20260906201940.jpg',
  );
  final TextEditingController _serverDirPathController = TextEditingController(
    text: '/home/arch/Projects/backbone/dataset/real_products/8901058000269_Maggi',
  );
  final TextEditingController _serverProductTitleController = TextEditingController(
    text: 'Nestle Maggi 2-Minute Noodles',
  );

  bool _isLoading = false;
  ComplianceReport? _report;
  String? _errorMessage;

  /// Sober accent read — only valid inside a ListenableBuilder on
  /// GlassPerfService (all swap sites below are wrapped).
  bool get _sober => GlassPerfService.instance.soberMode;

  @override
  void dispose() {
    _productNameController.dispose();
    _serverFilePathController.dispose();
    _serverDirPathController.dispose();
    _serverProductTitleController.dispose();
    super.dispose();
  }

  // --- Image & Document Pickers ---

  Future<void> _pickSingleImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _singlePanelPath = picked.path;
          _report = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showToast('Failed to select image: $e');
    }
  }

  /// Android Native Storage Access Framework (SAF) document picker
  /// Directly opens system file browser, bypassing flickering/crashing gallery viewers
  Future<void> _pickNativeFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path != null) {
          setState(() {
            _singlePanelPath = path;
            _report = null;
            _errorMessage = null;
          });
          _showToast('Selected: ${files.first.name}');
        }
      }
    } catch (e) {
      _showToast('Native file picker error: $e');
    }
  }

  Future<void> _pickMultiImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _panelPaths.add(picked.path);
          _selectedPanelIndex = _panelPaths.length - 1;
        });
      }
    } catch (e) {
      _showToast('Failed to capture image: $e');
    }
  }

  /// Android Native SAF Multi-File Document Picker
  Future<void> _pickMultiNativeFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isNotEmpty) {
        setState(() {
          for (final file in files) {
            final path = file.path;
            if (path != null && !_panelPaths.contains(path)) {
              _panelPaths.add(path);
            }
          }
          if (_panelPaths.isNotEmpty) {
            _selectedPanelIndex = _panelPaths.length - 1;
          }
        });
        _showToast('Added ${files.length} panel(s)');
      }
    } catch (e) {
      _showToast('Native multi-file picker error: $e');
    }
  }

  Future<void> _loadDemoOats() async {
    try {
      final path = await DemoAssetService.instance.getOatsDemoPath();
      setState(() {
        _singlePanelPath = path;
        _panelPaths.clear();
        _panelPaths.add(path);
        _selectedPanelIndex = 0;
        _productNameController.text = 'Saffola Oats 400g Pouch';
        _report = null;
        _errorMessage = null;
      });
      _showToast('Loaded Saffola Oats demo package');
    } catch (e) {
      _showToast('Failed to load Oats demo: $e');
    }
  }

  Future<void> _loadDemoDishwash() async {
    try {
      final path = await DemoAssetService.instance.getDishwashDemoPath();
      setState(() {
        _singlePanelPath = path;
        _panelPaths.clear();
        _panelPaths.add(path);
        _selectedPanelIndex = 0;
        _productNameController.text = 'SaveMore Active Dishwash 500ml';
        _report = null;
        _errorMessage = null;
      });
      _showToast('Loaded SaveMore Dishwash demo package');
    } catch (e) {
      _showToast('Failed to load Dishwash demo: $e');
    }
  }

  Future<void> _loadDemoMaggi() async {
    try {
      final path = await DemoAssetService.instance.getMaggiDemoPath();
      setState(() {
        _singlePanelPath = path;
        _panelPaths.clear();
        _panelPaths.add(path);
        _selectedPanelIndex = 0;
        _productNameController.text = 'Nestle Maggi 2-Minute Noodles';
        _report = null;
        _errorMessage = null;
      });
      _showToast('Loaded Maggi 2-Minute Noodles sample data');
    } catch (e) {
      _showToast('Failed to load Maggi demo: $e');
    }
  }

  // --- Audit Handlers ---

  Future<void> _runSinglePanelAudit() async {
    if (_singlePanelPath == null || !File(_singlePanelPath!).existsSync()) {
      _showToast('Please capture or choose a packaging panel first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    DevLogger.instance.info('INSPECT', 'Auditing single panel: ${File(_singlePanelPath!).uri.pathSegments.last}...');
    DevLogger.instance.info('TIMER', 'Audit button tapped (single panel, t=+0ms)');

    try {
      final report = await _api.scanSinglePanel(_singlePanelPath!);
      DevLogger.instance.success(
        'INSPECT',
        'Single panel audit complete: ${report.complianceScorePct.toStringAsFixed(1)}% (${report.riskTier})',
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e, st) {
      DevLogger.instance.error('INSPECT', 'Audit failed: $e');
      DevLogger.instance.error('STACK', st.toString().split('\n').take(3).join(' | '));
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runMultiSkuInspection() async {
    if (_panelPaths.isEmpty) {
      _showToast('Please attach at least one packaging panel');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    DevLogger.instance.info('INSPECT', 'Auditing ${_panelPaths.length} pooled panel(s)...');
    DevLogger.instance.info('TIMER', 'Audit button tapped (${_panelPaths.length} pooled panels, t=+0ms)');

    try {
      final report = await _api.scanSku(
        panelImagePaths: _panelPaths,
        productName: _productNameController.text,
      );
      DevLogger.instance.success(
        'INSPECT',
        'Pooled SKU audit complete: ${report.complianceScorePct.toStringAsFixed(1)}% (${report.riskTier})',
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e, st) {
      DevLogger.instance.error('INSPECT', 'Pooled audit failed: $e');
      DevLogger.instance.error('STACK', st.toString().split('\n').take(3).join(' | '));
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runServerFileScan() async {
    final filePath = _serverFilePathController.text.trim();
    if (filePath.isEmpty) {
      _showToast('Please enter a valid server image file path');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    DevLogger.instance.info('INSPECT', 'Scanning server file path: $filePath');

    try {
      final report = await _api.scanPath(filePath);
      DevLogger.instance.success(
        'INSPECT',
        'Server file audit complete: ${report.complianceScorePct.toStringAsFixed(1)}% (${report.riskTier})',
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      DevLogger.instance.error('INSPECT', 'Server file scan failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runServerFolderScan() async {
    final dirPath = _serverDirPathController.text.trim();
    if (dirPath.isEmpty) {
      _showToast('Please enter a valid server directory path');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    DevLogger.instance.info('INSPECT', 'Scanning server directory: $dirPath');

    try {
      final report = await _api.scanProductPath(
        dirPath,
        productName: _serverProductTitleController.text,
      );
      DevLogger.instance.success(
        'INSPECT',
        'Server folder audit complete: ${report.complianceScorePct.toStringAsFixed(1)}% (${report.riskTier})',
      );
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      DevLogger.instance.error('INSPECT', 'Server folder scan failed: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_report == null) return;
    try {
      final bytes = await _api.getPdfBytes(_report!.inspectionId, report: _report);
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Statutory Notice PDF',
        fileName: 'Notice_${_report!.inspectionId}.pdf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        mimeType: 'application/pdf',
      );

      if (uri == null) {
        return; // User canceled the picker
      }

      _showToast('Statutory notice exported: Notice_${_report!.inspectionId}.pdf');
    } catch (e) {
      _showToast('Failed to export notice: $e');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header: sober dashboard (reference screen 1) or glass top
            // bar + bento grid. Listener hot-applies the Engine toggle.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: ListenableBuilder(
                  listenable: GlassPerfService.instance,
                  builder: (context, _) {
                    if (GlassPerfService.instance.soberMode) {
                      return SoberDashboard(
                        onCamera: () {
                          setState(() => _currentTab = ScanTab.singlePanel);
                          _pickSingleImage(ImageSource.camera);
                        },
                        onBrowseFiles: () {
                          setState(() => _currentTab = ScanTab.singlePanel);
                          _pickNativeFile();
                        },
                        onMultiPanel: () {
                          setState(() => _currentTab = ScanTab.multiSku);
                          _pickMultiNativeFiles();
                        },
                        onSample: _loadDemoDishwash,
                        onLoadOats: _loadDemoOats,
                        onLoadDishwash: _loadDemoDishwash,
                        onLoadMaggi: _loadDemoMaggi,
                        onSearchTap: () => widget.onOpenTab?.call(1),
                        onOpenTab: widget.onOpenTab,
                        latestInspectionId: _report?.inspectionId,
                        sessionPanels: [
                          ?_singlePanelPath,
                          ..._panelPaths,
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildGlassHeader(),
                        const SizedBox(height: 16),
                        GlassActionGrid(
                          onCameraTap: () {
                            setState(() => _currentTab = ScanTab.singlePanel);
                            _pickSingleImage(ImageSource.camera);
                          },
                          onBrowseFilesTap: () {
                            setState(() => _currentTab = ScanTab.singlePanel);
                            _pickNativeFile();
                          },
                          onMultiPanelTap: () {
                            setState(() => _currentTab = ScanTab.multiSku);
                            _pickMultiNativeFiles();
                          },
                          onSampleTap: _loadDemoMaggi,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 3-Tab Segmented Control
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _buildSegmentedTabBar(),
              ),
            ),

            // Active Tab Inspection Controls (sober-aware accents inside)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: ListenableBuilder(
                  listenable: GlassPerfService.instance,
                  builder: (context, _) => GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 28,
                    child: _buildActiveTabContent(),
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Center(
                    child: Text(
                      'Multi-threaded ONNX DBNet text detection & Jan Vishwas statutory analysis in progress...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GlassTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ),
              ),

            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 18,
                    borderColor: GlassTheme.criticalCrimson.withValues(alpha: 0.5),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: GlassTheme.criticalCrimson, fontSize: 12),
                    ),
                  ),
                ),
              ),

            // Live Dev Log Console Widget
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildLiveDevLogConsole(),
              ),
            ),

            // High-Resolution Bounding Box Canvas Viewport
            _buildActiveViewport(),

            // Results Section: Adjudication Verdict & Custom Widgets
            if (_report != null) ...[
              // Circular Neumorphic Gauge + Compounding Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: GlassCircularGauge(
                    scorePct: _report!.complianceScorePct,
                    riskTier: _report!.riskTierFormatted,
                  ),
                ),
              ),

              // Compounding Fine & Export Notice Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Sober: saffron fee badge (reference price tag).
                        // Glass: existing frosted liability column. The card
                        // shell itself re-skins via GlassContainer's sober path.
                        ListenableBuilder(
                          listenable: GlassPerfService.instance,
                          builder: (context, _) {
                            if (GlassPerfService.instance.soberMode) {
                              return SoberBadge(
                                amount: '₹${_report!.violations.totalFineInr}',
                                caption: 'Compounding liability • INR',
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COMPOUNDING LIABILITY',
                                  style: TextStyle(
                                    color: GlassTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${_report!.violations.totalFineInr} INR',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(CupertinoIcons.arrow_down_doc, size: 14, color: Colors.black),
                          label: const Text(
                            'Export Notice',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // The Signature Dual-Wave Area Chart Widget (From image copy 2.png Screen 3)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassWaveChart(
                    title: 'COMPLIANCE TRAJECTORY & SHARPNESS',
                    metricValue: '${_report!.complianceScorePct.toStringAsFixed(1)}%',
                    subtitle: '${_report!.evaluations.length} statutory clauses checked',
                    dataPoints: [
                      20.0,
                      45.0,
                      35.0,
                      65.0,
                      50.0,
                      _report!.complianceScorePct,
                      (_report!.complianceScorePct * 0.9).clamp(0.0, 100.0),
                      (_report!.complianceScorePct * 1.05).clamp(0.0, 100.0),
                      _report!.complianceScorePct,
                    ],
                    backWaveData: [
                      15.0,
                      30.0,
                      25.0,
                      50.0,
                      40.0,
                      (_report!.complianceScorePct * 0.75).clamp(0.0, 100.0),
                      55.0,
                      70.0,
                      60.0,
                    ],
                  ),
                ),
              ),

              // Clause Evaluations Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Text(
                    'STATUTORY CLAUSE AUDIT (${_report!.evaluations.length} CLAUSES)',
                    style: const TextStyle(
                      color: GlassTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // Clause Evaluation Tiles: glass list, or sober pin timeline.
              // Wrapped in ListenableBuilder so the Engine sober toggle
              // re-skins already-built rows with no restart. Clause counts
              // are small (~10), so an eager Column is fine here.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListenableBuilder(
                    listenable: GlassPerfService.instance,
                    builder: (context, _) {
                      final sober = GlassPerfService.instance.soberMode;
                      return Column(
                        children: _report!.evaluations
                            .map<Widget>(
                              (eval) => sober
                                  ? SoberClauseRow(evaluation: eval)
                                  : ClauseTile(evaluation: eval),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
              ),

              // Bottom Spacer: taller in sober mode (notched bar + FAB).
              SliverToBoxAdapter(child: SoberBottomSpacer()),
            ],

            // Default Bottom Spacing (sober-aware, see above)
            SliverToBoxAdapter(child: SoberBottomSpacer()),
          ],
        ),
      );
  }

  // --- Glass Header (top bar, sober replaces with SoberDashboard) ---

  Widget _buildGlassHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THEMIS // REGULATORY COGNITION',
              style: TextStyle(
                color: GlassTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Compliance Inspector',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        // Quick Maggi Sample Pill
        GestureDetector(
          onTap: _loadDemoMaggi,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            borderRadius: 20,
            blur: 12,
            enableBlur: true,
            child: const Row(
              children: [
                Icon(CupertinoIcons.sparkles,
                    size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Sample Maggi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Segmented Tab Bar ---

  Widget _buildSegmentedTabBar() {
    // Sober: saffron active pill (reference red). Glass: cyan-blue.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          _buildTabButton('Single Panel', ScanTab.singlePanel),
          _buildTabButton('Full SKU (Multi)', ScanTab.multiSku),
          _buildTabButton('Server Path', ScanTab.serverPath),
        ],
      ),
      ),
    );
  }

  Widget _buildTabButton(String title, ScanTab tab) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      SoberTheme.swap(GlassTheme.bgOceanCyan, _sober),
                      _sober
                          ? SoberTheme.accent
                          : GlassTheme.bgElectricBlue,
                    ],
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: SoberTheme.swap(GlassTheme.bgOceanCyan, _sober)
                          .withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : GlassTheme.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Active Tab Content ---

  Widget _buildActiveTabContent() {
    switch (_currentTab) {
      case ScanTab.singlePanel:
        return _buildSinglePanelTab();
      case ScanTab.multiSku:
        return _buildMultiSkuTab();
      case ScanTab.serverPath:
        return _buildServerPathTab();
    }
  }

  // --- TAB 1: Single Panel ---

  Widget _buildSinglePanelTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Single Packaging Panel Scan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Audit MRP, Net Quantity, Dates, and Manufacturer declarations on an isolated panel.',
          style: TextStyle(
            color: GlassTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // Dropzone / Selected Image Preview
        if (_singlePanelPath == null)
          GestureDetector(
            onTap: _pickNativeFile,
            child: DashedContainer(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: 20,
              strokeWidth: 1.2,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.cloud_upload,
                        size: 38,
                        color: SoberTheme.swap(
                            GlassTheme.bgNeonCyan, _sober)),
                    SizedBox(height: 8),
                    Text(
                      'Tap to browse files or capture panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Android SAF Picker • Supports JPG, PNG, WEBP',
                      style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(_singlePanelPath!), fit: BoxFit.cover),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      File(_singlePanelPath!).uri.pathSegments.last,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _singlePanelPath = null),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Action Buttons Row (Camera, Gallery, Native SAF)
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                'Camera',
                CupertinoIcons.camera,
                () => _pickSingleImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryButton(
                'Browse SAF',
                CupertinoIcons.folder,
                _pickNativeFile,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Primary Action Button
        _buildPrimaryActionButton(
          label: 'Run Legal Metrology Audit',
          icon: CupertinoIcons.viewfinder,
          onPressed: _isLoading ? null : _runSinglePanelAudit,
        ),
      ],
    );
  }

  // --- TAB 2: Full SKU (Multi) ---

  Widget _buildMultiSkuTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Multi-Panel Pooled SKU Audit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pool declarations across Front, Back, Nutritional, and Barcode panels for a complete package evaluation.',
          style: TextStyle(
            color: GlassTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'PRODUCT SKU NAME (OPTIONAL)',
          style: TextStyle(
            color: GlassTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: TextField(
            controller: _productNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g. Amul Butter 100g or Oreo Pack',
              hintStyle: TextStyle(color: GlassTheme.textMuted, fontSize: 13),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'PACKAGING PANELS (${_panelPaths.length})',
          style: const TextStyle(
            color: GlassTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal Panel Carousel
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Dashed Add Panel Button
              GestureDetector(
                onTap: _pickMultiNativeFiles,
                child: DashedContainer(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: 16,
                  strokeWidth: 1.2,
                  child: Container(
                    width: 74,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.plus_circle,
                            color: SoberTheme.swap(
                                GlassTheme.bgNeonCyan, _sober),
                            size: 20),
                        SizedBox(height: 4),
                        Text(
                          '+ Add SAF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Existing Panels
              ..._panelPaths.asMap().entries.map((entry) {
                final idx = entry.key;
                final path = entry.value;
                final isSelected = idx == _selectedPanelIndex;

                return GestureDetector(
                  onTap: () => setState(() => _selectedPanelIndex = idx),
                  child: Container(
                    width: 74,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? SoberTheme.swap(
                                GlassTheme.bgNeonCyan, _sober)
                            : Colors.white.withValues(alpha: 0.2),
                        width: isSelected ? 2.2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(path), fit: BoxFit.cover),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _panelPaths.removeAt(idx);
                                if (_selectedPanelIndex >= _panelPaths.length) {
                                  _selectedPanelIndex = (_panelPaths.length - 1).clamp(0, 999);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.xmark, size: 10, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                'Camera',
                CupertinoIcons.camera,
                () => _pickMultiImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSecondaryButton(
                'Browse SAF',
                CupertinoIcons.folder_badge_plus,
                _pickMultiNativeFiles,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Primary Action Button
        _buildPrimaryActionButton(
          label: 'Run Pooled SKU Scan',
          icon: CupertinoIcons.checkmark_seal,
          onPressed: _isLoading ? null : _runMultiSkuInspection,
        ),
      ],
    );
  }

  // --- TAB 3: Server Path ---

  Widget _buildServerPathTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Server Filesystem Audit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Directly scan image files or product directories stored on the server filesystem.',
          style: TextStyle(
            color: GlassTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),

        // Single File Path Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Option 1: Single File Path',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _serverFilePathController,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '/path/to/dataset/.../panel_raw_1.jpg',
                    hintStyle: TextStyle(color: GlassTheme.textMuted, fontSize: 11.5),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _runServerFileScan,
                  icon: const Icon(CupertinoIcons.doc_text_search, size: 14, color: Colors.white),
                  label: const Text(
                    'Audit File Path',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Entire SKU Folder Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Option 2: Entire SKU Folder',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _serverDirPathController,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '/path/to/real_products/8901058000269_Maggi',
                    hintStyle: TextStyle(color: GlassTheme.textMuted, fontSize: 11.5),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _serverProductTitleController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Optional Product Title',
                    hintStyle: TextStyle(color: GlassTheme.textMuted, fontSize: 12),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _runServerFolderScan,
                  icon: const Icon(CupertinoIcons.folder_badge_person_crop, size: 14, color: Colors.white),
                  label: const Text(
                    'Audit Product Folder',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Buttons ---

  Widget _buildSecondaryButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 18, color: Colors.white),
        label: Text(
          _isLoading ? 'Processing...' : label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ).copyWith(
          backgroundBuilder: (context, states, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: states.contains(WidgetState.disabled)
                    ? null
                    : LinearGradient(
                        colors: [
                          SoberTheme.swap(GlassTheme.bgOceanCyan, _sober),
                          _sober
                              ? SoberTheme.accent
                              : GlassTheme.bgElectricBlue,
                        ],
                      ),
                boxShadow: states.contains(WidgetState.disabled)
                    ? null
                    : [
                        BoxShadow(
                          color: SoberTheme.swap(GlassTheme.bgOceanCyan, _sober)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }

  // --- Active Viewport Canvas ---

  Widget _buildActiveViewport() {
    List<String> activePanels = [];
    if (_report != null) {
      if (_currentTab == ScanTab.multiSku && _panelPaths.isNotEmpty) {
        activePanels = _panelPaths;
      } else if (_currentTab == ScanTab.singlePanel && _singlePanelPath != null) {
        activePanels = [_singlePanelPath!];
      } else if (_currentTab == ScanTab.serverPath) {
        final dir = _serverDirPathController.text.trim();
        final file = _serverFilePathController.text.trim();
        if (dir.isNotEmpty && Directory(dir).existsSync()) {
          final entries = Directory(dir)
              .listSync()
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.endsWith('.jpg') || p.endsWith('.png') || p.endsWith('.jpeg'))
              .toList()..sort();
          activePanels = entries;
        } else if (file.isNotEmpty && File(file).existsSync()) {
          activePanels = [file];
        }
      }
    } else {
      if (_currentTab == ScanTab.singlePanel && _singlePanelPath != null) {
        activePanels = [_singlePanelPath!];
      } else if (_currentTab == ScanTab.multiSku && _panelPaths.isNotEmpty) {
        activePanels = _panelPaths;
      }
    }

    if (activePanels.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final safeIndex = _selectedPanelIndex.clamp(0, activePanels.length - 1);
    final activeImagePath = activePanels[safeIndex];
    final panelFileName = File(activeImagePath).uri.pathSegments.last;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Viewport Header & Multi-Panel In-Canvas Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ListenableBuilder(
                    listenable: GlassPerfService.instance,
                    builder: (context, _) => Row(
                      children: [
                        Icon(CupertinoIcons.viewfinder,
                            size: 15,
                            color: SoberTheme.swap(
                                GlassTheme.bgNeonCyan, _sober)),
                      const SizedBox(width: 6),
                      Text(
                        'EVIDENCE CANVAS ${activePanels.length > 1 ? "(${safeIndex + 1}/${activePanels.length})" : ""}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                        ),
                      ],
                      ),
                    ),
                  if (activePanels.length > 1)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.chevron_left, size: 16, color: Colors.white),
                          onPressed: safeIndex > 0
                              ? () => setState(() => _selectedPanelIndex = safeIndex - 1)
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.white),
                          onPressed: safeIndex < activePanels.length - 1
                              ? () => setState(() => _selectedPanelIndex = safeIndex + 1)
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Bounding Box Hardware Canvas Viewport
              BoundingBoxCanvas(
                imageFile: File(activeImagePath),
                panelIndex: safeIndex,
                tokens: _report?.rawOcrTokens.where((t) {
                      if (t.sourceImage == null) return true;
                      if (activePanels.length == 1) return true;
                      final s = t.sourceImage!;
                      return s == panelFileName ||
                          s == 'panel_${safeIndex + 1}.jpg' ||
                          panelFileName.contains(s) ||
                          s.contains(panelFileName);
                    }).toList() ??
                    [],
                onTokenSelected: (token) {
                  _showToast('"${token.text}" (${(token.confidence * 100).toStringAsFixed(0)}% conf)');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Live Dev Log Console ---

  Widget _buildLiveDevLogConsole() {
    // Sober: saffron telemetry accents + green/blue log badges (reference).
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) => ValueListenableBuilder<List<LogEntry>>(
      valueListenable: DevLogger.instance.entriesNotifier,
      builder: (context, logs, _) {
        final recentLogs = logs.reversed.take(4).toList();

        return GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.chevron_left_slash_chevron_right,
                          size: 13,
                          color: SoberTheme.swap(
                              GlassTheme.bgNeonCyan, _sober)),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE TELEMETRY',
                        style: TextStyle(
                          color: GlassTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DevLogsScreen()),
                      );
                    },
                    child: Text(
                      'View All →',
                      style: TextStyle(
                        color: SoberTheme.swap(
                            GlassTheme.bgNeonCyan, _sober),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recentLogs.isEmpty)
                const Text(
                  'Waiting for inference events...',
                  style: TextStyle(color: GlassTheme.textDim, fontSize: 11, fontStyle: FontStyle.italic),
                )
              else
                Column(
                  children: recentLogs.map((log) {
                    Color badgeColor;
                    switch (log.level) {
                      case LogLevel.error:
                        badgeColor = GlassTheme.criticalCrimson;
                        break;
                      case LogLevel.warn:
                        badgeColor = GlassTheme.moderateRiskAmber;
                        break;
                      case LogLevel.success:
                        badgeColor = SoberTheme.swap(
                            GlassTheme.compliantCyan, _sober);
                        break;
                      default:
                        badgeColor = SoberTheme.swap(
                            GlassTheme.lowRiskBlue, _sober);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.tag,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              log.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
      ),
    );
  }
}
