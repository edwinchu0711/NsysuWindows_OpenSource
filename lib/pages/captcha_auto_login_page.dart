/*

This file contains code derived from the NSYSU Open Development Community project.

Original Copyright (c) 2024 NSYSU Open Development Community

Licensed under the MIT License.

*/
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/utils.dart';
import '../services/storage_service.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';


bool _obscurePassword = true;

class CaptchaAutoLoginPage extends ConsumerStatefulWidget {
  final bool isRelogin;
  const CaptchaAutoLoginPage({super.key, this.isRelogin = false});

  @override
  ConsumerState<CaptchaAutoLoginPage> createState() => _CaptchaAutoLoginPageState();
}

class _CaptchaAutoLoginPageState extends ConsumerState<CaptchaAutoLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _result = "請輸入帳號密碼";
  bool _isLoading = false;
  bool _isAutoLoggingIn = false;
  static bool _hasAttemptedInitialAutoLogin = false;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    await _loadCredentials();
    
    if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      if (_hasAttemptedInitialAutoLogin) {
        print("ℹ️ CaptchaAutoLoginPage: 已在此工作階段嘗試過自動登入，略過重複執行 (防止 Hot Reload 重複觸發)");
        return;
      }
      _hasAttemptedInitialAutoLogin = true;

      dynamic connectivityResult = await (Connectivity().checkConnectivity());
      bool isNone = (connectivityResult is List) 
          ? connectivityResult.contains(ConnectivityResult.none) 
          : connectivityResult == ConnectivityResult.none;

      if (isNone) {
        _showOfflineDialog();
      } else {
        _startLoginProcess();
      }
    }
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("離線模式預覽"),
        content: Text("目前偵測不到網路連線，無法登入伺服器。\n\n您仍可進入系統查看先前讀取過的快取資料。"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _result = "已取消離線登入";
                _isAutoLoggingIn = false;
                _isLoading = false;
              });
            },
            child: Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enterOfflineMode();
            },
            child: Text("確認進入"),
          ),
        ],
      ),
    );
  }

  void _enterOfflineMode() {
    String userAgent = "Mozilla/5.0 (Offline Mode)";
    if (mounted) {
      ref.read(sessionProvider.notifier).updateSession("OFFLINE", userAgent: userAgent);
      context.go('/home');
    }
  }

  Future<void> _loadCredentials() async {
    final credentials = await StorageService.instance.getCredentials();
    setState(() {
      _usernameController.text = (credentials['username'] ?? "").trim();
      _passwordController.text = (credentials['password'] ?? "").trim();
      if (_usernameController.text.isNotEmpty) {
        _result = widget.isRelogin ? "連線逾時，重新登入中..." : "準備自動登入...";
      }
    });
  }

  Future<void> _saveCredentials() async {
    await StorageService.instance.saveCredentials(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  Future<void> _startLoginProcess() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("請輸入學號和密碼")));
      return;
    }

    dynamic connectivityResult = await (Connectivity().checkConnectivity());
    bool isNone = (connectivityResult is List) 
        ? connectivityResult.contains(ConnectivityResult.none) 
        : connectivityResult == ConnectivityResult.none;

    if (isNone) {
      _showOfflineDialog();
      return;
    }

    setState(() {
      _isAutoLoggingIn = true;
      _isLoading = true;
      _result = "正在進行身分驗證...";
    });

    try {
      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();
      if (username.length < 9 || username.length > 11) {
        _handleLoginError("帳號或密碼錯誤");
        return;
      }
      final dio = Dio(BaseOptions(
        connectTimeout: Duration(seconds: 10),
        followRedirects: false, 
        validateStatus: (status) => status! < 500,
      ));

      final String base64md5Password = Utils.base64md5(password);

      final response = await dio.post(
        'https://selcrs.nsysu.edu.tw/scoreqry/sco_query_prs_sso2.asp',
        data: {
          'SID': username.toUpperCase(),
          'PASSWD': base64md5Password,
          'ACTION': '0',
          'INTYPE': '1',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      
      String bodyText = response.data.toString();
      List<String>? cookies = response.headers['set-cookie'];
      

      bool isFailureMessage = bodyText.contains("錯誤") || bodyText.contains("請重新輸入");
      print("bodyText: $bodyText");
      if (cookies != null && cookies.isNotEmpty && !isFailureMessage) {
        String cookieString = cookies.map((s) => s.split(';').first).join('; ');

        if (response.statusCode == 302 || (response.statusCode == 200)) {
          if (bodyText.contains("請重新輸入")) {
            _handleLoginError("帳號或密碼錯誤");
            return;
          }
          _onLoginSuccess(cookieString);
        } 
        else {
          _handleLoginError("帳號或密碼錯誤");
        }
      } 
      else {
        _handleLoginError("帳號或密碼錯誤");
      }
    } catch (e) {
      setState(() {
        _result = "❌ 連線錯誤";
        _isAutoLoggingIn = false;
        _isLoading = false;
      });
      if (_usernameController.text.isNotEmpty) _showOfflineDialog();
    }
  }

  void _onLoginSuccess(String cookieString) async {
    await _saveCredentials();
    await StorageService.instance.saveSession(cookieString); // 持久化 Session
    
    String userAgent = "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36";

    if (mounted) {
      setState(() {
        _result = "✅ 登入成功！";
        _isLoading = false;
      });

      ref.read(sessionProvider.notifier).updateSession(cookieString, userAgent: userAgent);
      context.go('/home');
    }
  }
  
  void _handleLoginError(String message) {
    setState(() {
      _result = "❌ $message";
      _isAutoLoggingIn = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.pageBackground,
      body: Center(
        child: SingleChildScrollView(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: SizedBox(
                    width: 380,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 80, color: colorScheme.accentBlue),
                        const SizedBox(height: 20),
                        Text(
                          "NSYSU 校務系統",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.primaryText),
                        ),
                        const SizedBox(height: 10),
                        Text(_result, style: TextStyle(color: colorScheme.bodyText)),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: colorScheme.primaryText),
                          decoration: InputDecoration(
                            labelText: "學號",
                            labelStyle: TextStyle(color: colorScheme.subtitleText),
                            prefixIcon: Icon(Icons.person, color: colorScheme.accentBlue),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.isDark ? colorScheme.borderColor : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.accentBlue, width: 2.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: colorScheme.primaryText),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\u4e00-\u9fa5]')),
                          ],
                          decoration: InputDecoration(
                            labelText: "密碼",
                            labelStyle: TextStyle(color: colorScheme.subtitleText),
                            prefixIcon: Icon(Icons.lock, color: colorScheme.accentBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: colorScheme.subtitleText,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.isDark ? colorScheme.borderColor : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.accentBlue, width: 2.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isAutoLoggingIn ? null : _startLoginProcess,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.accentBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isAutoLoggingIn 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("登入系統", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}