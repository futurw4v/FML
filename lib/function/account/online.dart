import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:fml/function/log.dart';

// 打开URL
Future<void> _launchURL() async {
  try {
    final Uri uri = Uri.parse('https://www.microsoft.com/link');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      LogUtil.log('无法打开链接', level: 'ERROR');
    }
  } catch (e) {
    LogUtil.log('发生错误: $e', level: 'ERROR');
  }
}

// 显示 Code 话框
Future<void> _showCodeDialog(BuildContext context, String code) async {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('验证代码'),
        content: Text('验证代码 $code 已复制到剪贴板,请在稍后显示的浏览器中打开的网页中输入'),
        actions: [
          TextButton(
            onPressed:() => Clipboard.setData(ClipboardData(text: code)),
            child: const Text('再次复制到剪贴板'),
          ),
          TextButton(
            onPressed:() => _launchURL(),
            child: const Text('重新打开网页'),
          )
        ],
      ),
    );
  });
}

// 获取令牌
Future<void> _getToken(context, String userCode, String deviceCode) async {
  String accessToken = '';
  String refreshToken = '';
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  LogUtil.log('获取到 userCode: $userCode, deviceCode: $deviceCode', level: 'INFO');
  await Clipboard.setData(ClipboardData(text: userCode));
  await _showCodeDialog(context, userCode);
  await _launchURL();
  while (true) {
    try {
      final response = await dio.post(
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'FML/$appVersion'
        },
      ),
      data: {
        'client_id': '3847de77-c7ca-4daa-a0b7-50850446d58c',
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': deviceCode
      }
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data =response.data as Map<String, dynamic>;
        String accessToken = data['access_token'] ?? '';
        String refreshToken = data['refresh_token'] ?? '';
        if (userCode.isNotEmpty && deviceCode.isNotEmpty) {
          LogUtil.log('a: $accessToken r: $refreshToken');
          break;
        } else {
          LogUtil.log('无法获取 Token', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求 Token 失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
    }
  } on DioException catch (e) {
    String errorMessage;
    if (e.response != null) {
      try {
        if (e.response!.data is Map) {
          Map<String, dynamic> errorData = e.response!.data as Map<String, dynamic>;
          String errorType = errorData['error'] ?? '未知错误类型';
          String errorDetail = errorData['error_description'] ?? '';
          LogUtil.log('Dio异常: $errorType - $errorDetail', level: 'ERROR');
          if (errorType == 'authorization_pending') {
            LogUtil.log('用户未授权', level: 'INFO');
            continue;
          }
          if (errorType == 'slow_down') {
            continue;
          }
          errorMessage = '$errorType: $errorDetail';
        } else {
          errorMessage = '请求失败: ${e.response?.statusMessage}';
          LogUtil.log('请求异常: 状态码: ${e.response?.statusCode}, 消息: ${e.response?.statusMessage}', level: 'ERROR');
        }
      } catch (_) {
        errorMessage = '解析错误响应失败: ${e.message}';
        LogUtil.log('请求异常: 解析错误响应失败', level: 'ERROR');
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      errorMessage = '连接超时，请检查网络设置';
      LogUtil.log('请求异常: 连接超时', level: 'ERROR');
    } else if (e.type == DioExceptionType.sendTimeout) {
      errorMessage = '发送请求超时，请稍后重试';
      LogUtil.log('请求异常: 发送超时', level: 'ERROR');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      errorMessage = '接收响应超时，请稍后重试';
      LogUtil.log('外请求异常: 接收超时', level: 'ERROR');
    } else {
      errorMessage = '连接服务器失败: ${e.message}';
      LogUtil.log('外请求异常: ${e.message}', level: 'ERROR');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('发生错误: $errorMessage')),
    );
  } catch (e) {
    LogUtil.log('请求Token发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('请求Token发生其他错误: $e')),
    );
  }
  }
}

// 登录
Future<void> getCode(context) async {
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  try {
    final response = await dio.post(
      'https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode',
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'FML/$appVersion'
        },
      ),
      data: {
        'client_id': '3847de77-c7ca-4daa-a0b7-50850446d58c',
        'scope': 'XboxLive.signin offline_access'
      }
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data =response.data as Map<String, dynamic>;
        String userCode = data['user_code'];
        String deviceCode = data['device_code'];
        if (userCode.isNotEmpty && deviceCode.isNotEmpty) {
          _getToken(context, userCode, deviceCode);
        } else {
          LogUtil.log('无法获取Code', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求Code失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
    }
  } on DioException catch (e) {
    String errorMessage;
    if (e.response != null) {
      try {
        if (e.response!.data is Map) {
          Map<String, dynamic> errorData = e.response!.data as Map<String, dynamic>;
          String errorType = errorData['error'] ?? '未知错误类型';
          String errorDetail = errorData['errorMessage'] ?? '';
          LogUtil.log('Dio异常: $errorType - $errorDetail', level: 'ERROR');
          errorMessage = '$errorType: $errorDetail';
        } else {
          errorMessage = '请求失败: ${e.response?.statusMessage}';
          LogUtil.log('请求异常: 状态码: ${e.response?.statusCode}, 消息: ${e.response?.statusMessage}', level: 'ERROR');
        }
      } catch (_) {
        errorMessage = '解析错误响应失败: ${e.message}';
        LogUtil.log('请求异常: 解析错误响应失败', level: 'ERROR');
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      errorMessage = '连接超时，请检查网络设置';
      LogUtil.log('请求异常: 连接超时', level: 'ERROR');
    } else if (e.type == DioExceptionType.sendTimeout) {
      errorMessage = '发送请求超时，请稍后重试';
      LogUtil.log('请求异常: 发送超时', level: 'ERROR');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      errorMessage = '接收响应超时，请稍后重试';
      LogUtil.log('外请求异常: 接收超时', level: 'ERROR');
    } else {
      errorMessage = '连接服务器失败: ${e.message}';
      LogUtil.log('外请求异常: ${e.message}', level: 'ERROR');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('发生错误: $errorMessage')),
    );
  } catch (e) {
    LogUtil.log('请求Code发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('请求Code发生其他错误: $e')),
    );
  }
}
