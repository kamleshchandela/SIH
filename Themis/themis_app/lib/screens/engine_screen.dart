import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/audit_storage_service.dart';
import '../services/themis_api.dart';
import '../theme/theme.dart';
import '../widgets/primitives/themis_primitives.dart';
import 'dev_logs_screen.dart';

/// Engine, System Diagnostics & Officer Profile Screen
///
/// Built strictly for the Sunlight Light Theme for high-visibility field operations.
/// Configures:
/// - Officer credentials and jurisdictional enforcement circle.
/// - Model execution tier (On-Device Compact INT8, High Precision INT8, Remote Server).
/// - Remote daemon endpoint and connection health diagnostics.
/// - Statutory rule coverage and local audit cache maintenance.
class EngineScreen extends StatefulWidget {
  const EngineScreen({super.key});

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen> {
  final ThemisApiService _api = ThemisApiService();
  late final TextEditingController _urlController;

  bool _isChecking = false;
  bool? _isHealthy;
  late EngineModelOption _selectedModelTier;

  @override
  void initState() {
    super.initState();
    _selectedModelTier = _api.modelOption;
    _urlController = TextEditingController(text: _api.baseUrl);
    _testConnection();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onModelTierChanged(EngineModelOption option) {
    setState(() => _selectedModelTier = option);
    _api.setModelOption(option);
  }

  Future<void> _testConnection() async {
    setState(() => _isChecking = true);
    _api.updateBaseUrl(_urlController.text.trim());
    final healthy = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _isHealthy = healthy;
        _isChecking = false;
      });
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: ThemisTheme.sunlightTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemisTheme.radius8)),
      ),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemisTheme.sunlightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemisTheme.radius16)),
        title: const Text(
          'Purge Local Inspection Cache?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ThemisTheme.sunlightTextPrimary,
          ),
        ),
        content: const Text(
          'This will remove all cached audit dossiers stored on this device. Any un-exported statutory notices will be permanently purged.',
          style: TextStyle(fontSize: 13, color: ThemisTheme.sunlightTextSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: ThemisTheme.sunlightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemisTheme.statusViolation,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemisTheme.radius8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuditStorageService.instance.clearAll();
              _showToast('Local inspection cache purged.');
              setState(() {});
            },
            child: const Text('Purge Cache'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localCount = AuditStorageService.instance.allInspections.length;

    return Scaffold(
      backgroundColor: ThemisTheme.sunlightBg,
      appBar: ThemisAppBar(
        title: 'ENGINE & CONFIGURATION',
        subtitle: 'Directorate of Legal Metrology - System Administration',
        roleBadge: 'ADMIN / OFFICER',
        isDark: false,
        isOffline: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: ThemisTheme.space16,
          vertical: ThemisTheme.space16,
        ),
        children: [
          // ===============================================================
          // 1. Officer Profile & Jurisdiction
          // ===============================================================
          _buildCard(
            title: 'OFFICER IDENTITY & JURISDICTION',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ThemisTheme.amberTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThemisTheme.amberPrimary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_crop_circle_fill,
                        size: 28,
                        color: ThemisTheme.amberPrimary,
                      ),
                    ),
                    const SizedBox(width: ThemisTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Inspector Rajesh Sharma',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ThemisTheme.sunlightTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Badge: DLM-MH-4091  •  Senior Enforcement Officer',
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemisTheme.sunlightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ThemisTheme.space12),
                const Divider(height: 1, color: ThemisTheme.sunlightBorder),
                const SizedBox(height: ThemisTheme.space12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Assigned Circle:', style: TextStyle(fontSize: 12, color: ThemisTheme.sunlightTextSecondary)),
                    Text('Circle 4 (Central Enforcement)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemisTheme.sunlightTextPrimary)),
                  ],
                ),
                const SizedBox(height: ThemisTheme.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Statutory Authority:', style: TextStyle(fontSize: 12, color: ThemisTheme.sunlightTextSecondary)),
                    Text('Legal Metrology Act, 2009', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemisTheme.amberHover)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: ThemisTheme.space16),

          // ===============================================================
          // 2. AI Execution Architecture & Model Tier Selector
          // ===============================================================
          _buildCard(
            title: 'AI EXECUTION TIER & COMPLIANCE ENGINE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the inference tier for OCR extraction, multi-panel aggregation, and statutory rule evaluation:',
                  style: TextStyle(fontSize: 12.5, color: ThemisTheme.sunlightTextSecondary, height: 1.4),
                ),
                const SizedBox(height: ThemisTheme.space12),

                _buildModelOption(
                  option: EngineModelOption.mobileCompactInt8,
                  title: 'On-Device Compact INT8 (Recommended)',
                  badge: 'OFFLINE • 180ms',
                  badgeColor: ThemisTheme.statusCompliant,
                  description: 'Zero network latency, 100% offline edge processing. Powered by native Rust FFI bindings for low power consumption.',
                ),
                const SizedBox(height: ThemisTheme.space8),
                _buildModelOption(
                  option: EngineModelOption.mobileAccurateInt8,
                  title: 'On-Device High Precision INT8',
                  badge: 'ACCURATE • 420ms',
                  badgeColor: ThemisTheme.amberPrimary,
                  description: 'Enhanced micro-print font height verification and complex bilingual (Hindi + English) declaration parsing.',
                ),
                const SizedBox(height: ThemisTheme.space8),
                _buildModelOption(
                  option: EngineModelOption.remoteServer,
                  title: 'Remote Daemon / High-Throughput Server',
                  badge: 'SERVER • RAYON',
                  badgeColor: const Color(0xFF38BDF8),
                  description: 'Offloads processing to an external enterprise server with 64 Rayon threadpool workers for mass bulk SKU auditing.',
                ),
              ],
            ),
          ),

          // Conditional Remote Daemon Configuration Card
          if (_selectedModelTier == EngineModelOption.remoteServer) ...[
            const SizedBox(height: ThemisTheme.space16),
            _buildCard(
              title: 'REMOTE DAEMON ENDPOINT',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 13, color: ThemisTheme.sunlightTextPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ThemisTheme.radius8),
                              borderSide: const BorderSide(color: ThemisTheme.sunlightBorder),
                            ),
                            hintText: 'http://192.168.1.100:8080',
                            hintStyle: const TextStyle(fontSize: 13, color: ThemisTheme.sunlightTextMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: ThemisTheme.space8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemisTheme.amberPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemisTheme.radius8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: _isChecking ? null : _testConnection,
                        child: _isChecking
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: ThemisTheme.space12),

                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isHealthy == true
                              ? ThemisTheme.statusCompliant
                              : (_isHealthy == false ? ThemisTheme.statusViolation : ThemisTheme.sunlightTextMuted),
                        ),
                      ),
                      const SizedBox(width: ThemisTheme.space8),
                      Text(
                        _isChecking
                            ? 'Pinging server health probe...'
                            : (_isHealthy == true
                                ? 'Server Online: /health 200 OK'
                                : (_isHealthy == false ? 'Connection Failed: Offline / Unreachable' : 'Untested')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isHealthy == true
                              ? ThemisTheme.statusCompliant
                              : (_isHealthy == false ? ThemisTheme.statusViolation : ThemisTheme.sunlightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ThemisTheme.space12),

                  const Text('Quick Host Presets:', style: TextStyle(fontSize: 11, color: ThemisTheme.sunlightTextMuted)),
                  const SizedBox(height: ThemisTheme.space4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildHostChip('Localhost:8080', 'http://127.0.0.1:8080'),
                      _buildHostChip('Android Emulator', 'http://10.0.2.2:8080'),
                      _buildHostChip('LAN Server', 'http://192.168.1.100:8080'),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: ThemisTheme.space16),

          // ===============================================================
          // 3. Statutory Ruleset & Legal Framework
          // ===============================================================
          _buildCard(
            title: 'STATUTORY FRAMEWORK & RULES',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatutoryItem(
                  rule: 'Rule 6(1)(a) – (g)',
                  title: 'Packaged Commodities Rules, 2011',
                  desc: 'Mandates Commodity Name, MRP, USP, Net Qty, Mfg Date, Packer Info, and Consumer Care on Principal Display Panel.',
                ),
                const SizedBox(height: ThemisTheme.space8),
                _buildStatutoryItem(
                  rule: 'Schedule II',
                  title: 'Minimum Numerals & Letters Height',
                  desc: 'Enforces statutory font height scaling from 1.0mm (≤50g) up to 6.0mm (>4kg) based on net quantity package area.',
                ),
                const SizedBox(height: ThemisTheme.space8),
                _buildStatutoryItem(
                  rule: 'Jan Vishwas 2023',
                  title: 'Compounding & Decriminalization',
                  desc: 'Sec 49 compounding schedule applies standard monetary penalties without court prosecution for first-time non-willful omissions.',
                ),
              ],
            ),
          ),

          const SizedBox(height: ThemisTheme.space16),

          // ===============================================================
          // 4. Local Storage & Diagnostics Maintenance
          // ===============================================================
          _buildCard(
            title: 'DIAGNOSTICS & SYSTEM MAINTENANCE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Local Inspection Dossiers:', style: TextStyle(fontSize: 13, color: ThemisTheme.sunlightTextSecondary)),
                    Text(
                      '$localCount Audits',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThemisTheme.sunlightTextPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: ThemisTheme.space12),

                ThemisButton(
                  label: 'View Developer & Native FFI Logs',
                  leadingIcon: Icons.terminal,
                  variant: ThemisButtonVariant.secondaryOutline,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DevLogsScreen()));
                  },
                ),
                const SizedBox(height: ThemisTheme.space8),
                ThemisButton(
                  label: 'Purge Local Dossier Cache',
                  leadingIcon: CupertinoIcons.trash,
                  variant: ThemisButtonVariant.dangerCrimson,
                  onPressed: _confirmClearCache,
                ),
              ],
            ),
          ),

          const SizedBox(height: ThemisTheme.space24),

          // App build identity footer
          Center(
            child: Column(
              children: const [
                Text(
                  'THEMIS // DIRECTORATE OF LEGAL METROLOGY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: ThemisTheme.sunlightTextMuted),
                ),
                SizedBox(height: 2),
                Text(
                  'v2.4.0-prod (Rust Core Native FFI • On-Device Neural Engine)',
                  style: TextStyle(fontSize: 10, color: ThemisTheme.sunlightTextMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: ThemisTheme.space20),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(ThemisTheme.space16),
      decoration: BoxDecoration(
        color: ThemisTheme.sunlightSurface,
        borderRadius: BorderRadius.circular(ThemisTheme.radius12),
        border: Border.all(color: ThemisTheme.sunlightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: ThemisTheme.sunlightTextSecondary,
            ),
          ),
          const SizedBox(height: ThemisTheme.space12),
          child,
        ],
      ),
    );
  }

  Widget _buildModelOption({
    required EngineModelOption option,
    required String title,
    required String badge,
    required Color badgeColor,
    required String description,
  }) {
    final isSelected = _selectedModelTier == option;

    return InkWell(
      onTap: () => _onModelTierChanged(option),
      borderRadius: BorderRadius.circular(ThemisTheme.radius8),
      child: Container(
        padding: const EdgeInsets.all(ThemisTheme.space12),
        decoration: BoxDecoration(
          color: isSelected ? ThemisTheme.amberTint.withValues(alpha: 0.5) : ThemisTheme.sunlightBg,
          borderRadius: BorderRadius.circular(ThemisTheme.radius8),
          border: Border.all(
            color: isSelected ? ThemisTheme.amberPrimary : ThemisTheme.sunlightBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                  size: 18,
                  color: isSelected ? ThemisTheme.amberPrimary : ThemisTheme.sunlightTextMuted,
                ),
                const SizedBox(width: ThemisTheme.space8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: ThemisTheme.sunlightTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThemisTheme.radius4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThemisTheme.space8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                description,
                style: const TextStyle(fontSize: 11.5, color: ThemisTheme.sunlightTextSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostChip(String label, String url) {
    return InkWell(
      onTap: () {
        setState(() {
          _urlController.text = url;
        });
        _testConnection();
      },
      borderRadius: BorderRadius.circular(ThemisTheme.radius4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ThemisTheme.sunlightBg,
          borderRadius: BorderRadius.circular(ThemisTheme.radius4),
          border: Border.all(color: ThemisTheme.sunlightBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThemisTheme.sunlightTextSecondary),
        ),
      ),
    );
  }

  Widget _buildStatutoryItem({required String rule, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(ThemisTheme.space8),
      decoration: BoxDecoration(
        color: ThemisTheme.sunlightBg,
        borderRadius: BorderRadius.circular(ThemisTheme.radius8),
        border: Border.all(color: ThemisTheme.sunlightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: ThemisTheme.amberTint,
              borderRadius: BorderRadius.circular(ThemisTheme.radius4),
            ),
            child: Text(
              rule,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThemisTheme.amberHover),
            ),
          ),
          const SizedBox(width: ThemisTheme.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemisTheme.sunlightTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: ThemisTheme.sunlightTextSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
