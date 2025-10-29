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

// 获取代码
Future<List<String>> getCode(context) async {
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
          return [userCode,deviceCode];
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
  return ['',''];
}

// 获取微软账号令牌
Future<List<String>> _getMsToken(context, String userCode, String deviceCode) async {
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
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
          return [accessToken,refreshToken];
        } else {
          LogUtil.log('无法获取微软账号令牌', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求微软账号令牌失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
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
      LogUtil.log('请求微软账号令牌发生其他错误: $e', level: 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请求微软账号令牌发生其他错误: $e')),
      );
    }
  }
}

// 获取 Xbox Live令牌
Future<String> _getXboxLiveToken(context, msToken) async {
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  try {
    final response = await dio.post(
      'https://user.auth.xboxlive.com/user/authenticate',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FML/$appVersion'
        },
      ),
      data: {
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=${msToken[0]}'
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT'
      }
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data =response.data as Map<String, dynamic>;
        String token = data['Token'] ?? '';
        if (token.isNotEmpty) {
          return token;
        } else {
          LogUtil.log('无法获取 Xbox Live 令牌', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求 Xbox Live 令牌失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
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
    LogUtil.log('获取 Xbox Live 令牌发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('获取 Xbox Live 令牌发生其他错误: $e')),
    );
  }
  return '';
}

// 获取 XSTS 令牌
Future<List<String>> _getXSTSToken(context, xblToken) async {
    final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  try {
    final response = await dio.post(
      'https://xsts.auth.xboxlive.com/xsts/authorize',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FML/$appVersion'
        },
      ),
      data: {
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xblToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT'
      }
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data =response.data as Map<String, dynamic>;
        String token = data['Token'] ?? '';
        String userHash = data['DisplayClaims']['xui']['uhs'] ?? '';
        if (token.isNotEmpty && userHash.isNotEmpty) {
          return [token,userHash];
        } else {
          LogUtil.log('无法获取 XSTS 令牌', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求 XSTS 令牌失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
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
    LogUtil.log('获取 XSTS 令牌发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('获取 XSTS 令牌发生其他错误: $e')),
    );
  }
  return ['',''];
}

// 获取 Minecraft 令牌
Future<String> _getMcToken(context, xstsToken) async {
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  try {
    final response = await dio.post(
      'https://api.minecraftservices.com/authentication/login_with_xbox',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FML/$appVersion'
        },
      ),
      data: {
        'identityToken': 'XBL3.0 x=${xstsToken[1]};${xstsToken[0]}'
      }
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data =response.data as Map<String, dynamic>;
        String token = data['access_token'] ?? '';
        if (token.isNotEmpty) {
          return token;
        } else {
          LogUtil.log('无法获取 Minecraft 令牌', level: 'ERROR');
        }
      }
    } else {
      LogUtil.log('请求 Minecraft 令牌失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
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
    LogUtil.log('获取 Minecraft 令牌发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('获取 Minecraft 令牌发生其他错误: $e')),
    );
  }
  return '';
}

// 检查所有权
Future<bool> checkPurchase(BuildContext context, mcToken) async {
  final dio = Dio();
  final prefs = await SharedPreferences.getInstance();
  final appVersion = prefs.getString('version') ?? 'unknown';
  try {
    final response = await dio.get(
      'https://api.minecraftservices.com/entitlements/mcstore',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $mcToken',
          'User-Agent': 'FML/$appVersion'
        },
      )
    );
    if (response.statusCode == 200) {
      if (response.data is Map) {
        Map<String, dynamic> data = response.data as Map<String, dynamic>;
        List<dynamic> items = data['items'] as List<dynamic>;
        bool hasGameMinecraft = items.any((item) {
          return item is Map && item['name'] == 'game_minecraft';
        });
        if (hasGameMinecraft) {
          return true;
        } else {
          LogUtil.log('没有购买游戏', level: 'ERROR');
          return false;
        }
      }
    } else {
      LogUtil.log('检查所有权失败: 状态码: ${response.statusCode}, 响应: ${response.data}', level: 'ERROR');
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
    LogUtil.log('检查所有权发生其他错误: $e', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('检查所有权发生其他错误: $e')),
    );
  }
  return false;
}

// 登录
Future<void> login(
    BuildContext context,
    Future<void> Function(int) onlineCallback
  ) async{
  await onlineCallback(1);
  // 请求代码
  List<String> code = await getCode(context);
  if (code[0].isNotEmpty && code[1].isNotEmpty) {
    // 请求令牌
    List<String> msToken = await _getMsToken(context, code[0], code[1]);
    if (msToken[0].isNotEmpty && msToken[1].isNotEmpty) {
      await onlineCallback(2);
      Navigator.of(context).pop();
      String xblToken = await _getXboxLiveToken(context,msToken);
      if (xblToken.isNotEmpty) {
        debugPrint('Xbox Live 令牌: $xblToken');
        List<String> xstsToken = await _getXSTSToken(context, xblToken);
        if (xstsToken[0].isNotEmpty && xstsToken[1].isNotEmpty) {
          debugPrint('XSTS 令牌: $xstsToken , userHash: ${xstsToken[1]}');
          String mcToken = await _getMcToken(context, xstsToken);
          if (mcToken.isNotEmpty) {
            debugPrint('Minecraft 令牌: $mcToken');
            bool hasMc = await checkPurchase(context, mcToken);
            if (hasMc) {
              await onlineCallback(3);
            } else {
              await onlineCallback(4);
            }
          }
        }
      }
    }
  }
}