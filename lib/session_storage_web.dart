import 'dart:convert';

import 'package:web/web.dart' as web;

import 'auth_service.dart';
import 'session_storage.dart';

const _storageKey = 'scoot_auth_session_v1';

SessionStorage createPlatformSessionStorage() => _WebSessionStorage();

class _WebSessionStorage implements SessionStorage {
  @override
  Future<AuthSession?> load() async {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthSession.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    try {
      web.window.localStorage.setItem(_storageKey, jsonEncode(session.toJson()));
    } on Object {
      // Ignore storage errors (e.g. restricted private browsing mode).
    }
  }

  @override
  Future<void> clear() async {
    try {
      web.window.localStorage.removeItem(_storageKey);
    } on Object {
      // Ignore storage errors.
    }
  }
}
