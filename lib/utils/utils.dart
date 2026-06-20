import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class Utils {
  static const bool dev = false; // 若為 true 則不執行記錄

  /// 中山大學校務系統專用的密碼加密方式：MD5 後轉為 Base64
  static String base64md5(String text) {
    // 1. 將字串轉為 UTF-8 位元組
    var bytes = utf8.encode(text);
    // 2. 進行 MD5 哈希
    var digest = md5.convert(bytes);
    // 3. 將 MD5 的原始位元組進行 Base64 編碼
    return base64.encode(digest.bytes);
  }

  /// 取得應用程式資料庫目錄（位於使用者 AppData，避免寫入 Program Files）
  static Future<String> getAppDbDirectory() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 記錄應用程式啟動（登入成功時呼叫）
  static Future<void> recordLaunch() async {
    if (dev) {
      debugPrint('ℹ️ recordLaunch: 開發模式已啟動，略過記錄。');
      return;
    }
    try {
      final dio = Dio(BaseOptions(connectTimeout: Duration(seconds: 10)));
      String platformName = 'unknown';
      try {
        platformName = Platform.operatingSystem;
      } catch (_) {
        // 辨識不出來或發生例外時，預設為 'unknown'
      }

      final response = await dio.post(
        'https://quiet-scene-52f9.jawei-hsu2005.workers.dev',
        data: {'platform': platformName}, // 帶入平台資訊
      );

      if (response.statusCode == 200) {
        // debugPrint('記錄成功：${response.data}');
      } else {
        debugPrint('失敗：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('記錄啟動錯誤：$e');
    }
  }
}
