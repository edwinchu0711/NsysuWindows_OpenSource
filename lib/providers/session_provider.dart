import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import 'storage_provider.dart';

class SessionState {
  final String cookies;
  final String userAgent;

  const SessionState({this.cookies = '', this.userAgent = ''});

  bool get isLoggedIn => cookies.isNotEmpty && cookies != 'OFFLINE';
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SessionNotifier(storage);
});

class SessionNotifier extends StateNotifier<SessionState> {
  final StorageService _storage;

  SessionNotifier(this._storage) : super(const SessionState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final cookies = await _storage.getSession() ?? '';
    final userAgent = SessionService.instance.userAgentNotifier.value;
    state = SessionState(cookies: cookies, userAgent: userAgent);
  }

  void updateSession(String cookies, {String? userAgent}) {
    SessionService.instance.updateSession(cookies, userAgent: userAgent);
    state = SessionState(
      cookies: cookies,
      userAgent: userAgent ?? state.userAgent,
    );
  }
}