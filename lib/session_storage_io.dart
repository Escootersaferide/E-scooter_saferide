import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'session_storage.dart';

const _sessionFileName = 'saferide_auth_session_v1.json';
const _legacySessionFileName = 'scoot_auth_session_v1.json';

SessionStorage createPlatformSessionStorage() => _IoSessionStorage();

class _IoSessionStorage implements SessionStorage {
  AuthSession? _fallback;

  File _legacyFile(File file) => File(
    '${file.parent.path}${Platform.pathSeparator}$_legacySessionFileName',
  );

  Future<File?> _resolveFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_sessionFileName');
    } on Object {
      return null;
    }
  }

  @override
  Future<AuthSession?> load() async {
    final file = await _resolveFile();
    if (file == null) return _fallback;
    try {
      final stored = await file.exists() ? file : _legacyFile(file);
      if (!await stored.exists()) return null;
      final raw = await stored.readAsString();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSession.fromJson(decoded);
    } on Object {
      return _fallback;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    _fallback = session;
    final file = await _resolveFile();
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(session.toJson()), flush: true);
      final legacy = _legacyFile(file);
      if (await legacy.exists()) await legacy.delete();
    } on Object {
      // Fall back to in-memory storage if filesystem writes fail.
    }
  }

  @override
  Future<void> clear() async {
    _fallback = null;
    final file = await _resolveFile();
    if (file == null) return;
    for (final stored in [file, _legacyFile(file)]) {
      try {
        if (await stored.exists()) await stored.delete();
      } on Object {
        // Ignore deletion errors.
      }
    }
  }
}
