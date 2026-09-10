import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  info,
  warn,
  error,
  success,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = (timestamp.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$h:$m:$s.$ms';
  }

  String toPlainString() {
    final lvl = level.name.toUpperCase().padRight(5);
    return '[$formattedTime] [$lvl] [${tag.padRight(6)}] $message';
  }
}

class DevLogger {
  DevLogger._();
  static final DevLogger instance = DevLogger._();

  static const int maxLogs = 500;

  /// Persistent file log: every entry is appended to
  /// `<docs>/themis_logs/themis_YYYYMMDD.log` automatically — no manual
  /// export needed, survives restarts and `pm clear`-free reinstalls.
  /// Rotation cap 512KB (oldest renamed .prev, one generation).
  static const int maxFileBytes = 512 * 1024;
  static const int maxPendingLines = 200;

  final ValueNotifier<List<LogEntry>> entriesNotifier = ValueNotifier<List<LogEntry>>([]);

  /// Set once per process after the DevLogs screen backfills file history,
  /// so reopening the screen never duplicates persisted lines.
  bool historyBackfilled = false;

  String? _logDirPath;
  bool _fileWriteBusy = false;
  final List<String> _pendingLines = [];
  int _flushCount = 0;

  List<LogEntry> get entries => entriesNotifier.value;

  void log(String tag, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag.toUpperCase(),
      message: message,
    );

    final current = List<LogEntry>.from(entriesNotifier.value);
    current.add(entry);
    if (current.length > maxLogs) {
      current.removeAt(0);
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        entriesNotifier.value = current;
      });
    } else {
      entriesNotifier.value = current;
    }

    _persistLine(entry.toPlainString());
  }

  void info(String tag, String message) => log(tag, message, level: LogLevel.info);
  void warn(String tag, String message) => log(tag, message, level: LogLevel.warn);
  void error(String tag, String message) => log(tag, message, level: LogLevel.error);
  void success(String tag, String message) => log(tag, message, level: LogLevel.success);

  void clear() {
    entriesNotifier.value = [];
    info('SYSTEM', 'Developer log console buffer cleared.');
  }

  /// Fire-and-forget file append. Batches lines through a single-flight
  /// flush (one batched write per burst) and never awaits in the caller, so
  /// logging can never stall the event loop — hard lesson from
  /// INCIDENT_POSTMORTEM_ASYNC_RECURSION_AND_EVENT_LOOP_STARVATION.
  void _persistLine(String line) {
    if (_pendingLines.length < maxPendingLines) {
      _pendingLines.add(line);
    }
    if (_fileWriteBusy) return;
    unawaited(_flushPending());
  }

  Future<void> _flushPending() async {
    if (_fileWriteBusy) return;
    _fileWriteBusy = true;
    try {
      _logDirPath ??= await _resolveLogDir();
      if (_logDirPath != null && _pendingLines.isNotEmpty) {
        final now = DateTime.now();
        final name =
            'themis_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
        final file = File('$_logDirPath/$name');
        final batch = List<String>.from(_pendingLines);
        _pendingLines.clear();
        await file.writeAsString('${batch.join('\n')}\n',
            mode: FileMode.append, flush: false);
        _flushCount++;
        if (_flushCount % 25 == 0 && await file.length() > maxFileBytes) {
          final prev = File('$_logDirPath/$name.prev');
          if (await prev.exists()) await prev.delete();
          await file.rename(prev.path);
        }
      } else if (_pendingLines.length >= maxPendingLines) {
        _pendingLines.clear();
      }
    } catch (_) {
      if (_pendingLines.length >= maxPendingLines) _pendingLines.clear();
    } finally {
      _fileWriteBusy = false;
      if (_pendingLines.isNotEmpty) unawaited(_flushPending());
    }
  }

  Future<String?> _resolveLogDir() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/themis_logs');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  /// Reads persisted history (newest file first, tail-capped) for the log
  /// viewer. Lenient parse — unparseable lines become info entries verbatim.
  Future<List<LogEntry>> loadPersistedHistory({int maxLines = 300}) async {
    try {
      final dirPath = _logDirPath ?? await _resolveLogDir();
      if (dirPath == null) return [];
      final dir = Directory(dirPath);
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      final lines = <String>[];
      for (final f in files) {
        if (lines.length >= maxLines) break;
        try {
          final all = await f.readAsLines();
          final take = maxLines - lines.length;
          lines.addAll(all.length > take
              ? all.sublist(all.length - take)
              : all);
        } catch (_) {}
      }
      return lines.map(_parseLine).toList();
    } catch (_) {
      return [];
    }
  }

  static final RegExp _lineRe =
      RegExp(r'^\[(\d{2}:\d{2}:\d{2}\.\d{2})\] \[(.*?)\] \[(.*?)\] (.*)$');

  LogEntry _parseLine(String line) {
    final m = _lineRe.firstMatch(line);
    if (m == null) {
      return LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          tag: 'FILE',
          message: line);
    }
    final lvl = m.group(2)!.trim().toLowerCase();
    return LogEntry(
      timestamp: _parseTime(m.group(1)!),
      level: lvl.startsWith('error')
          ? LogLevel.error
          : lvl.startsWith('warn')
              ? LogLevel.warn
              : lvl.startsWith('succ')
                  ? LogLevel.success
                  : LogLevel.info,
      tag: m.group(3)!.trim(),
      message: m.group(4)!,
    );
  }

  DateTime _parseTime(String hhmmsscc) {
    try {
      final now = DateTime.now();
      final p = hhmmsscc.split(':');
      return DateTime(now.year, now.month, now.day, int.parse(p[0]),
          int.parse(p[1]), int.parse(p[2].split('.').first));
    } catch (_) {
      return DateTime.now();
    }
  }

  String exportAll() {
    if (entriesNotifier.value.isEmpty) {
      return '// Themis Inspection Diagnostic Log\n// Empty session log.';
    }
    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln('THEMIS LEGAL METROLOGY INSPECTOR // DIAGNOSTIC AUDIT LOGS');
    buffer.writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}');
    buffer.writeln('Active entries: ${entriesNotifier.value.length}');
    buffer.writeln('================================================================\n');

    for (final entry in entriesNotifier.value) {
      buffer.writeln(entry.toPlainString());
    }
    return buffer.toString();
  }
}
