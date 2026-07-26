import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A completed participant-side call recording waiting for an admin-only
/// backend upload.
class PendingCallRecording {
  const PendingCallRecording({
    required this.id,
    required this.kind,
    required this.ownerId,
    required this.callId,
    required this.path,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String id;
  final String kind;
  final int ownerId;
  final int callId;
  final String path;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;

  PendingCallRecording copyWith({int? attempts, DateTime? nextAttemptAt}) {
    return PendingCallRecording(
      id: id,
      kind: kind,
      ownerId: ownerId,
      callId: callId,
      path: path,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'ownerId': ownerId,
    'callId': callId,
    'path': path,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toUtc().toIso8601String(),
  };

  factory PendingCallRecording.fromJson(Map<String, dynamic> json) {
    return PendingCallRecording(
      id: json['id'] as String,
      kind: json['kind'] as String,
      ownerId: (json['ownerId'] as num).toInt(),
      callId: (json['callId'] as num).toInt(),
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: json['nextAttemptAt'] == null
          ? null
          : DateTime.parse(json['nextAttemptAt'] as String),
    );
  }
}

/// Durable queue metadata lives in SharedPreferences while audio files live in
/// application support storage. A failed upload therefore survives app restarts
/// and is never exposed through participant UI.
class CallRecordingRetryQueue {
  CallRecordingRetryQueue({
    DateTime Function()? now,
    Future<Directory> Function()? supportDirectory,
    String storageKeyPrefix = _defaultKeyPrefix,
  }) : _now = now ?? DateTime.now,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _storageKeyPrefix = storageKeyPrefix;

  static final CallRecordingRetryQueue instance = CallRecordingRetryQueue();

  static const _defaultKeyPrefix = 'pending_call_recording:';
  static const _baseRetrySeconds = 15;
  static const _maxRetrySeconds = 30 * 60;

  final DateTime Function() _now;
  final Future<Directory> Function() _supportDirectory;
  final String _storageKeyPrefix;

  String _key(String id) => '$_storageKeyPrefix$id';

  /// Moves a completed temporary recording into durable app storage and
  /// persists its upload metadata before the first network attempt.
  Future<PendingCallRecording> persist({
    required String kind,
    required int ownerId,
    required int callId,
    required String sourcePath,
  }) async {
    final createdAt = _now().toUtc();
    final id =
        '${kind}_${ownerId}_${callId}_${createdAt.microsecondsSinceEpoch}';
    final root = await _supportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}pending-call-recordings',
    );
    await directory.create(recursive: true);
    final destination = '${directory.path}${Platform.pathSeparator}$id.m4a';

    final source = File(sourcePath);
    try {
      await source.rename(destination);
    } on FileSystemException {
      await source.copy(destination);
      try {
        await source.delete();
      } on FileSystemException {
        // The durable copy is already complete; failure to remove the temporary
        // duplicate must not prevent the queued upload metadata from being saved.
      }
    }

    final item = PendingCallRecording(
      id: id,
      kind: kind,
      ownerId: ownerId,
      callId: callId,
      path: destination,
      createdAt: createdAt,
    );
    await _write(item);
    return item;
  }

  /// Returns durable items belonging to the currently authenticated account.
  /// The caller uses [PendingCallRecording.nextAttemptAt] for scheduling.
  /// Missing/corrupt metadata and vanished files are cleaned up safely.
  Future<List<PendingCallRecording>> pendingFor({
    required String kind,
    required int ownerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <PendingCallRecording>[];

    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_storageKeyPrefix),
    )) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      PendingCallRecording item;
      try {
        item = PendingCallRecording.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } on Object {
        await prefs.remove(key);
        continue;
      }

      final file = File(item.path);
      if (!await file.exists() || await file.length() < 12) {
        await prefs.remove(key);
        if (await file.exists()) await file.delete();
        continue;
      }
      if (item.kind != kind || item.ownerId != ownerId) continue;
      result.add(item);
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Keeps the file and moves the next attempt forward with capped exponential
  /// backoff: 15s, 30s, 60s ... up to 30 minutes.
  Future<PendingCallRecording> markFailed(PendingCallRecording item) async {
    final attempts = item.attempts + 1;
    final exponent = math.min(attempts - 1, 16);
    final delaySeconds = math.min(
      _baseRetrySeconds * math.pow(2, exponent).toInt(),
      _maxRetrySeconds,
    );
    final updated = item.copyWith(
      attempts: attempts,
      nextAttemptAt: _now().toUtc().add(Duration(seconds: delaySeconds)),
    );
    await _write(updated);
    return updated;
  }

  /// Removes queue metadata and deletes the local audio only after the backend
  /// has accepted it (or when the file is known to be invalid).
  Future<void> complete(PendingCallRecording item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(item.id));
    final file = File(item.path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _write(PendingCallRecording item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(item.id), jsonEncode(item.toJson()));
  }
}
