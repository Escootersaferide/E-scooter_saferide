import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'session_storage.dart';

const _sessionFileName = 'scoot_auth_session_v1.json';

SessionStorage createPlatformSessionStorage() => _IoSessionStorage();

class _IoSessionStorage implements SessionStorage {
  AuthSession? _fallback;

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
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
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
    } on Object {
      // Fall back to in-memory storage if filesystem writes fail.
    }
  }

  @override
  Future<void> clear() async {
    _fallback = null;
    final file = await _resolveFile();
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Ignore deletion errors.
    }
  }
}
