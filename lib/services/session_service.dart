import 'package:flutter/material.dart';

class SessionService {
  static final SessionService instance = SessionService._();
  SessionService._();

  final ValueNotifier<String> cookieNotifier = ValueNotifier("OFFLINE");
  final ValueNotifier<String> userAgentNotifier = ValueNotifier("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");

  void updateSession(String cookies, {String? userAgent}) {
    cookieNotifier.value = cookies;
    if (userAgent != null) {
      userAgentNotifier.value = userAgent;
    }
    print("🔑 SessionService: Session 已更新");
  }
}
