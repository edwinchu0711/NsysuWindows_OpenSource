import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  final Completer<void> _initCompleter = Completer<void>();

  /// [初始化並遷移資料]
  Future<void> init() async {
    // 執行遷移 (SharedPreferences -> SecureStorage)
    // 舊版帳密存在 SharedPreferences，需搬移到 SecureStorage
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 遷移帳號
      if (prefs.containsKey('username')) {
        String? oldUser = prefs.getString('username');
        if (oldUser != null) {
          await _secureStorage.write(key: 'username', value: oldUser);
        }
        await prefs.remove('username');
      }
      
      // 遷移密碼
      if (prefs.containsKey('password')) {
        String? oldPass = prefs.getString('password');
        if (oldPass != null) {
          await _secureStorage.write(key: 'password', value: oldPass);
        }
        await prefs.remove('password');
      }
    } catch (e) {
      print("⚠️ StorageService: 遷移失敗: $e");
    }

    if (!_initCompleter.isCompleted) {
      _initCompleter.complete();
    }
    print("🔐 StorageService: 初始化與遷移完成");
  }

  Future<void> _ensureInit() async {
    if (!_initCompleter.isCompleted) {
      await _initCompleter.future;
    }
  }

  // --- 帳密存取 ---
  Future<void> saveCredentials(String username, String password) async {
    await _ensureInit();
    await _secureStorage.write(key: 'username', value: username);
    await _secureStorage.write(key: 'password', value: password);
  }

  Future<Map<String, String?>> getCredentials() async {
    await _ensureInit();
    return {
      'username': await _secureStorage.read(key: 'username'),
      'password': await _secureStorage.read(key: 'password'),
    };
  }
  
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }


  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value != null) {
      print("📂 StorageService: 讀取快取 [$key] (${value.length} 字元)");
    } else {
      print("ℹ️ StorageService: 找不到快取 [$key]");
    }
    return value;
  }

  /// [純文字儲存]
  Future<void> save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString(key, value);
    if (success) {
      print("💾 StorageService: 成功儲存 [$key] (${value.length} 字元)");
    } else {
      print("❌ StorageService: 儲存失敗 [$key]");
    }
  }

  /// [Session Cookie 存取]
  Future<void> saveSession(String cookies) async {
    await save('session_cookies_plain_v1', cookies);
  }

  Future<String?> getSession() async {
    return await read('session_cookies_plain_v1');
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
