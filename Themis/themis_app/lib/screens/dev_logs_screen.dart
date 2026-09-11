import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dev_logger.dart';
import '../services/glass_perf_service.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';

class DevLogsScreen extends StatefulWidget {
  const DevLogsScreen({super.key});

  @override
  State<DevLogsScreen> createState() => _DevLogsScreenState();
}

class _DevLogsScreenState extends State<DevLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _selectedFilter = 'ALL';

  /// Sober brand swap — this route builds fresh on every push, so a direct
  /// read is always current; no listener needed.
  Color _acc(Color c) =>
      SoberTheme.swap(c, GlassPerfService.instance.soberMode);

  @override
  void initState() {
    super.initState();
    // Permanent log section: backfill persisted file history once per
    // process, prepended ahead of live entries. No manual export needed.
    if (!DevLogger.instance.historyBackfilled) {
      DevLogger.instance.historyBackfilled = true;
      DevLogger.instance.loadPersistedHistory().then((past) {
        if (!mounted || past.isEmpty) return;
        final current = List<LogEntry>.from(DevLogger.instance.entries);
        DevLogger.instance.entriesNotifier.value = [...past, ...current];
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _copyLogs() {
    final text = DevLogger.instance.exportAll();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${DevLogger.instance.entries.length} log traces to clipboard'),
        backgroundColor: const Color(0xFF1E1B4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<LogEntry> _filterEntries(List<LogEntry> entries) {
    if (_selectedFilter == 'ALL') return entries;
    if (_selectedFilter == 'ERRORS') {
      return entries.where((e) => e.level == LogLevel.error || e.level == LogLevel.warn).toList();
    }
    if (_selectedFilter == 'NETWORK') {
      return entries.where((e) => e.tag == 'NET' || e.tag == 'PING' || e.tag == 'HEALTH').toList();
    }
    if (_selectedFilter == 'ENGINE') {
      return entries.where((e) => e.tag == 'ENGINE' || e.tag == 'OCR' || e.tag == 'PCR').toList();
    }
    if (_selectedFilter == 'SCAN') {
      return entries.where((e) => e.tag == 'SCAN' || e.tag == 'FILE' || e.tag == 'AUDIT' || e.tag == 'TIMER').toList();
    }
    return entries;
  }

  Color _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return GlassTheme.criticalCrimson;
      case LogLevel.warn:
        return GlassTheme.moderateRiskAmber;
      case LogLevel.success:
        return GlassTheme.compliantCyan;
      case LogLevel.info:
        return Colors.white;
    }
  }

  Color _getColorForTag(String tag) {
    switch (tag) {
      case 'NET':
      case 'PING':
        return _acc(GlassTheme.bgNeonCyan);
      case 'ENGINE':
      case 'OCR':
        return GlassTheme.bgSoftLilac;
      case 'SCAN':
      case 'AUDIT':
        return GlassTheme.compliantCyan;
      case 'TIMER':
        return _acc(SoberTheme.accent);
      case 'SYSTEM':
      case 'CONFIG':
        return GlassTheme.lowRiskBlue;
      default:
        return GlassTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xCC090A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'PARAKH // DIAGNOSTIC TELEMETRY',
              style: TextStyle(
                color: GlassTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Developer Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Copy Button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _copyLogs,
              icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 14, color: Colors.black),
              label: const Text(
                'Copy',
                style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          // Clear Button
          IconButton(
            tooltip: 'Clear Console',
            icon: const Icon(CupertinoIcons.trash, color: GlassTheme.textSecondary, size: 18),
            onPressed: () {
              DevLogger.instance.clear();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar & Auto-Scroll
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('ALL'),
                          _buildFilterChip('ENGINE'),
                          _buildFilterChip('SCAN'),
                          _buildFilterChip('NETWORK'),
                          _buildFilterChip('ERRORS'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _autoScroll = !_autoScroll),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _autoScroll
                            ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _autoScroll
                              ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoScroll ? CupertinoIcons.arrow_down_to_line_alt : CupertinoIcons.pause,
                            size: 11,
                            color: _autoScroll ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AUTOSCROLL',
                            style: TextStyle(
                              color: _autoScroll ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Log Feed
            Expanded(
              child: ValueListenableBuilder<List<LogEntry>>(
                valueListenable: DevLogger.instance.entriesNotifier,
                builder: (context, allEntries, _) {
                  final filtered = _filterEntries(allEntries);

                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(CupertinoIcons.chevron_left_slash_chevron_right, size: 36, color: GlassTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No log entries matching filter',
                            style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Perform an inspection or ping daemon to capture live traces.',
                            style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final tagColor = _getColorForTag(entry.tag);
                      final textColor = _getColorForLevel(entry.level);

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timestamp
                            Text(
                              entry.formattedTime,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: GlassTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 0.6),
                              ),
                              child: Text(
                                entry.tag,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: tagColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Message
                            Expanded(
                              child: SelectableText(
                                entry.message,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.35,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _acc(GlassTheme.bgNeonCyan) : GlassTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
