import 'auth_service.dart';
import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart'
    if (dart.library.io) 'session_storage_io.dart'
    as platform_storage;

abstract interface class SessionStorage {
  Future<AuthSession?> load();
  Future<void> save(AuthSession session);
  Future<void> clear();
}

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this._session]);

  AuthSession? _session;

  @override
  Future<AuthSession?> load() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

SessionStorage createSessionStorage() =>
    platform_storage.createPlatformSessionStorage();
