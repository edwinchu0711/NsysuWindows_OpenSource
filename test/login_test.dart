import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../lib/utils/utils.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = RealHttpOverrides();

  test('macOS Network SSO Login Status Test', () async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    print('\n========================================');
    print('🚀 開始測試 macOS SSO 登入與連線狀態...');
    print('========================================');

    final String base64md5Password = Utils.base64md5('testpassword');

    try {
      final response = await dio.post(
        'https://selcrs.nsysu.edu.tw/menu4/Studcheck_sso2.asp',
        data: {'stuid': 'B123456789', 'SPassword': base64md5Password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );

      String bodyText = response.data.toString();
      List<String>? cookies = response.headers['set-cookie'];
      bool isFailureMessage =
          bodyText.contains("錯誤") || bodyText.contains("請重新輸入");

      print('📡 伺服器回應狀態碼: ${response.statusCode}');

      if (cookies != null && cookies.isNotEmpty && !isFailureMessage) {
        print('✅ [測試結果]: 登入成功！(成功取得 Session Cookie)');
      } else if (isFailureMessage || response.statusCode == 200 || response.statusCode == 302) {
        print('🔑 [測試結果]: 帳號或密碼錯誤 (伺服器正常回應「請重新輸入」或「帳密錯誤」)');
      } else {
        print('⚠️ [測試結果]: 未知回應 (Status: ${response.statusCode})');
      }

      print('========================================\n');
      expect(response.statusCode, anyOf(equals(200), equals(302)));
    } on DioException catch (e) {
      print('========================================');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        print('⏰ [測試結果]: 連線逾時！超過 10 秒未收到回應 (${e.type})');
      } else {
        print('❌ [測試結果]: 連線發生 DioException: ${e.message}');
      }
      print('========================================\n');
      fail('登入連線失敗: ${e.message}');
    } catch (e) {
      print('========================================');
      print('❌ [測試結果]: 發生非預期例外: $e');
      print('========================================\n');
      fail('登入連線失敗: $e');
    }
  });
}
