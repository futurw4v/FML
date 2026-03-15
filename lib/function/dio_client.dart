import 'package:dio/dio.dart';
import 'package:fml/function/download.dart';
import 'package:fml/function/log.dart';

import 'package:fml/constants.dart';

///
/// 一个自带默认配置的Dio单例
///
/// 对于下载调用请使用[DownloadUtils]
///
class DioClient {
  // 静态实例保证 DioClient 只有一个实例
  static final DioClient _instance = DioClient._internal();

  // 公开的Dio实例
  late Dio dio;

  factory DioClient() => _instance;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        // 固定超时时长
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    ///
    /// 添加拦截器
    ///

    // UA拦截器
    dio.interceptors.add(_getUserAgentInterceptor());

    // LogUtil日志拦截器（全模式）
    dio.interceptors.add(_getLogInterceptor());
  }

  ///
  /// LogUtil 日志拦截器
  ///
  InterceptorsWrapper _getLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        LogUtil.log('Dio ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        final uri = response.requestOptions.uri;
        final status = response.statusCode;
        LogUtil.log('HTTP请求 [$status] $uri');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        final uri = e.requestOptions.uri;
        final status = e.response?.statusCode;
        final msg = e.message ?? e.type.name;
        LogUtil.log(
          'HTTP请求失败 [$status] $uri - $msg',
          level: 'ERROR',
        );
        return handler.next(e);
      },
    );
  }

  ///
  /// 设置UserAgent
  ///
  InterceptorsWrapper _getUserAgentInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final existingUserAgent = options.headers['User-Agent'];
        if (existingUserAgent == null ||
            (existingUserAgent is String && existingUserAgent.isEmpty)) {
          final userAgent = gAppDefaultUserAgent;
          options.headers['User-Agent'] = userAgent;
        }
        return handler.next(options);
      },
    );
  }
}
