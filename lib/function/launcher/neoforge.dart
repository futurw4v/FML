import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:fml/function/log.dart';
import 'package:fml/function/download.dart';

typedef ProgressCallback = void Function(String message);
typedef ErrorCallback = void Function(String error);
typedef PortCallback = void Function(int port);
final StreamController<int> lanPortController = StreamController<int>.broadcast();
int? _lastDetectedPort;
int? getLastDetectedPort() => _lastDetectedPort;

// 清除端口缓存
Future<void> clearPortCache() async {
  _lastDetectedPort = null;
  try {
    lanPortController.add(-1);
  } catch (_) {}
  LogUtil.log('已清除端口缓存', level: 'INFO');
}

// library获取
Future<Set<String>> loadLibraryArtifactPaths(String versionJsonPath, String gamePath) async {
  final file = File(versionJsonPath);
  if (!await file.exists()) return {};
  late final dynamic root;
  try {
    root = jsonDecode(await file.readAsString());
  } catch (e) {
    LogUtil.log('JSON 解析失败: $e', level: 'ERROR');
    return {};
  }
  final libs = root is Map ? root['libraries'] : null;
  if (libs is! List) return {};
  final Set<String> result = {};
  for (final item in libs) {
    if (item is! Map) continue;
    final downloads = item['downloads'];
    if (downloads is! Map) continue;
    final artifact = downloads['artifact'];
    if (artifact is! Map) continue;
    final path = artifact['path'];
    if (path is String && path.isNotEmpty) {
      final fullPath = normalizePath('$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$path');
      result.add(fullPath);
    }
  }
  return result;
}

String normalizePath(String path) {
  return p.normalize(path);
}

// 直接从库名称构建路径 (用于install_profile中没有downloads.artifact.path的情况)
Set<String> buildLibraryPaths(List<Map<String, dynamic>> libraries, String gamePath) {
  final Set<String> result = {};
  for (final lib in libraries) {
    final name = lib['name'];
    if (name is! String) continue;
    // 解析Maven坐标 group:artifact:version[:classifier]
    final parts = name.split(':');
    if (parts.length < 3) continue;
    final group = parts[0].replaceAll('.', '/');
    final artifact = parts[1];
    String version = parts[2];
    String classifier = '';
    // 处理classifier和版本
    if (parts.length > 3) {
      classifier = parts.length > 3 ? '-${parts[3]}' : '';
    }
    // 构建jar路径
    final path = normalizePath('$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$group${Platform.pathSeparator}$artifact${Platform.pathSeparator}$version${Platform.pathSeparator}$artifact-$version$classifier.jar');
    if (File(path).existsSync()) {
      result.add(path);
    }
  }
  return result;
}

// assetIndex获取
Future<String?> getAssetIndex(String versionJsonPath) async {
  final file = File(versionJsonPath);
  if (!await file.exists()) return null;
  dynamic root;
  try {
    root = jsonDecode(await file.readAsString());
  } catch (_) {
    return null;
  }
  if (root is! Map) return null;
  // 优先：顶层 assetIndex.id
  final ai = root['assetIndex'];
  if (ai is Map && ai['id'] is String && (ai['id'] as String).isNotEmpty) {
    return ai['id'] as String;
  }
  // 备选：patches[].assetIndex.id
  final patches = root['patches'];
  if (patches is List) {
    for (final p in patches) {
      if (p is Map) {
        final pai = p['assetIndex'];
        final id = (pai is Map) ? pai['id'] : null;
        if (id is String && id.isNotEmpty) return id;
      }
    }
  }
  // 最后回退：assets 字段（通常等于 id）
  final assets = root['assets'];
  if (assets is String && assets.isNotEmpty) return assets;
  return null;
}

// 从jar路径提取库标识 (group:artifact)
String extractLibraryIdentifier(String jarPath) {
  final pathParts = p.split(jarPath);
  final libIndex = pathParts.indexOf('libraries');
  if (libIndex >= 0 && libIndex + 4 <= pathParts.length) {
    // groupId
    final groupPath = pathParts.sublist(libIndex + 1, pathParts.length - 3).join('.');
    // artifactId
    final artifact = pathParts[pathParts.length - 3];
    // version
    final version = pathParts[pathParts.length - 2];
    return '$groupPath:$artifact:$version';
  }
  // fallback
  return p.basename(jarPath);
}

// 加载NeoForge配置文件
Future<Map<String, dynamic>?> loadNeoForgeConfig(String gamePath, String game) async {
  final neoForgeJsonPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}NeoForge.json';
  final file = File(neoForgeJsonPath);
  if (!await file.exists()) {
    LogUtil.log('找不到NeoForge配置: $neoForgeJsonPath', level: 'ERROR');
    return null;
  }
  try {
    final jsonContent = await file.readAsString();
    final config = jsonDecode(jsonContent) as Map<String, dynamic>;
    return config;
  } catch (e) {
    LogUtil.log('解析NeoForge.json失败: $e', level: 'ERROR');
    return null;
  }
}

// 替换配置中的变量
String replaceConfigVariables(String input, Map<String, String> variables) {
  String result = input;
  for (final entry in variables.entries) {
    result = result.replaceAll('\${${entry.key}}', entry.value);
  }
  return result;
}

// 检查authlib-injector
Future<bool> checkAuthlibInjector(String gamePath) async {
  File authlibFile = File('$gamePath${Platform.pathSeparator}authlib-injector.jar');
  if (authlibFile.existsSync()) {
    LogUtil.log('authlib-injector 已存在，无需下载', level: 'INFO');
    return true;
  }
  else {
    return false;
  }
}

  // 读取App版本
  Future<String> _loadAppVersion() async {
  final prefs = await SharedPreferences.getInstance();
  final version = prefs.getString('version') ?? "1.0.0";
  return version;
}

// 下载authlib-injector
Future<void> downloadAuthlibInjector(String gamePath) async {
  LogUtil.log('加载authlib-injector版本', level: 'INFO');
  final Dio dio = Dio();
  final String appVersion = await _loadAppVersion();
  final options = Options(
    headers: {
      'User-Agent': 'FML/$appVersion',
    },
  );
  try {
    final response = await dio.get(
      'https://bmclapi2.bangbang93.com/mirrors/authlib-injector/artifact/latest.json',
      options: options,
    );
    if (response.statusCode == 200 && response.data.isNotEmpty) {
      final String? downloadUrl = response.data['download_url'];
      if (downloadUrl != null) {
        // 使用获取到的下载链接
        await DownloadUtils.downloadFile(
          url: downloadUrl,
          savePath: '$gamePath${Platform.pathSeparator}authlib-injector.jar',
          onProgress: (progress) {
            final percent = (progress * 100).toStringAsFixed(2);
            LogUtil.log('正在下载AuthlibInjector: $percent%', level: 'INFO');
          },
          onSuccess: () {
            LogUtil.log('AuthlibInjector 下载完成', level: 'INFO');
          },
          onError: (error) {
            LogUtil.log('AuthlibInjector 下载失败: $error', level: 'ERROR');
          },
          onCancel: () {
            LogUtil.log('AuthlibInjector 下载已取消', level: 'WARNING');
          }
        );
      } else {
        throw '无法获取 authlib-injector 下载链接';
      }
    } else {
      throw '获取 authlib-injector 版本信息失败';
    }
  } catch (e) {
    LogUtil.log('获取 authlib-injector 信息失败: $e', level: 'ERROR');
    rethrow;
  }
}

// 令牌检查
Future<bool> checkToken(String url,String accessToken,String clientToken) async {
  LogUtil.log('检查令牌有效性', level: 'INFO');
  final Dio dio = Dio();
  final String appVersion = await _loadAppVersion();
  final options = Options(
    headers: {
      'User-Agent': 'FML/$appVersion',
      'Content-Type': 'application/json'
    },
  );
  try {
    Map<String, dynamic> data = {
      'accessToken': accessToken,
      'clientToken': clientToken
    };
    final response = await dio.post(
      '$url/authserver/validate',
      data: data,
      options: options,
    );
    if (response.statusCode == 204) {
      LogUtil.log('令牌有效', level: 'INFO');
      return true;
    } else if (response.statusCode == 403) {
      LogUtil.log('令牌无效', level: 'WARNING');
      return false;
    }
    else {
      LogUtil.log('令牌检查失败，状态码: ${response.statusCode}', level: 'WARNING');
      return false;
    }
  }
  catch (e) {
    LogUtil.log('$url/authserver/validate令牌检查失败: $e', level: 'ERROR');
    return false;
  }
}

// 刷新令牌
Future<String> refreshToken(String url,
    String accessToken,
    String clientToken,
    String name,
    String uuid
  ) async {
  LogUtil.log('正在刷新令牌', level: 'INFO');
  final Dio dio = Dio();
  final String appVersion = await _loadAppVersion();
  final options = Options(
    headers: {
      'User-Agent': 'FML/$appVersion',
      'Content-Type': 'application/json'
    },
  );
  try {
    Map<String, dynamic> data = {
      'accessToken': accessToken,
      'clientToken': clientToken,
      "selectedProfile":{
        'name': name,
        'id': uuid
      },
    };
    final response = await dio.post(
      '$url/authserver/refresh',
      data: data,
      options: options,
    );
    if (response.statusCode == 200) {
      LogUtil.log('令牌刷新成功', level: 'INFO');
      return response.data['accessToken'];
    } else {
      LogUtil.log('令牌刷新失败，状态码: ${response.statusCode}', level: 'WARNING');
      return accessToken;
    }
  }
  catch (e) {
    LogUtil.log('令牌刷新失败: $e', level: 'ERROR');
    return accessToken;
  }
}

// 启动NeoForge
Future<void> neoforgeLauncher({
    ProgressCallback? onProgress,
    ErrorCallback? onError,
    PortCallback? onPortOpen,
  }) async {
  onProgress?.call('正在准备启动');
  final prefs = await SharedPreferences.getInstance();
  // 游戏参数
  final java = prefs.getString('SelectedJavaPath') ?? 'java';
  final selectedPath = prefs.getString('SelectedPath') ?? '';
  final gamePath = prefs.getString('Path_$selectedPath') ?? '';
  final game = prefs.getString('SelectedGame') ?? '';
  final nativesPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}natives';
  final version = prefs.getString('version') ?? '';
  final cfg = prefs.getStringList('Config_${selectedPath}_$game') ?? [];
  final jsonPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}$game.json';
  // 加载NeoForge配置
  final neoForgeConfig = await loadNeoForgeConfig(gamePath, game);
  LogUtil.log('NeoForge配置加载${neoForgeConfig != null ? "成功" : "失败"}', level: 'INFO');
  // 变量映射，用于替换配置中的占位符
  final variables = {
    'library_directory': '$gamePath${Platform.pathSeparator}libraries',
    'classpath_separator': Platform.isWindows ? ';' : ':',
    'version_name': game,
    'natives_directory': nativesPath,
  };
  // 使用Map存储库路径，按库标识去重，确保优先使用NeoForge版本
  final Map<String, String> librariesMap = {};
  // 首先从NeoForge.json加载库
  if (neoForgeConfig != null && neoForgeConfig.containsKey('libraries')) {
    final libraries = neoForgeConfig['libraries'] as List;
    for (final lib in libraries) {
      if (lib is! Map) continue;
      final downloads = lib['downloads'];
      if (downloads is! Map) continue;
      final artifact = downloads['artifact'];
      if (artifact is! Map) continue;
      final path = artifact['path'];
      if (path is String && path.isNotEmpty) {
        final fullPath = normalizePath('$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$path');
        final identifier = extractLibraryIdentifier(fullPath);
        librariesMap[identifier] = fullPath;
      }
    }
    LogUtil.log(librariesMap.toString(), level: 'INFO');
    LogUtil.log('从NeoForge.json加载了 ${librariesMap.length} 个库', level: 'INFO');
  }
  final versionLibs = await loadLibraryArtifactPaths(jsonPath, gamePath);
  for (final lib in versionLibs) {
    final identifier = extractLibraryIdentifier(lib);
    librariesMap.putIfAbsent(identifier, () => lib);
  }
  final libraries = librariesMap.values.toSet();
  final separator = Platform.isWindows ? ';' : ':';
  final gameJar = normalizePath('$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}$game.jar');
  final sortedLibraries = libraries.toList()..sort();
  final classPath = sortedLibraries.join(separator);
  final cp = '$classPath$separator$gameJar';
  String mainClass = neoForgeConfig?['mainClass'] as String? ?? 'net.neoforged.fancymodloader.bootstraplauncher.BootstrapLauncher';
  LogUtil.log('使用mainClass: $mainClass', level: 'INFO');
  LogUtil.log('类路径库数量: ${libraries.length}', level: 'INFO');
  final account = prefs.getString('SelectedAccount') ?? '';
  final accountInfo = prefs.getStringList('Account_$account') ?? [];
  final assetIndex = await getAssetIndex(jsonPath) ?? '';
  // 基础JVM参数
  final jvmArgs = <String>[
    '-Xmx${cfg[0]}G',
    '-XX:+UseG1GC',
    '-Dstderr.encoding=UTF-8',
    '-Dstdout.encoding=UTF-8',
    '-XX:-OmitStackTraceInFastThrow',
    '-Dfml.ignoreInvalidMinecraftCertificates=true',
    '-Dfml.ignorePatchDiscrepancies=true',
    '-Dminecraft.launcher.brand=FML',
    if (Platform.isMacOS) '-XstartOnFirstThread',
    if (accountInfo[0] == '2') '-javaagent:$gamePath${Platform.pathSeparator}authlib-injector.jar=${accountInfo[2]}',
    '-Djava.library.path=$nativesPath',
    '-Djna.tmpdir=$nativesPath',
  ];
  // 添加NeoForge.json中定义的JVM参数
  onProgress?.call('正在获取Neoforge参数');
  if (neoForgeConfig != null &&
      neoForgeConfig.containsKey('arguments') &&
      neoForgeConfig['arguments'] is Map &&
      neoForgeConfig['arguments'].containsKey('jvm')) {
    final jvmArgsList = neoForgeConfig['arguments']['jvm'] as List;
    for (var arg in jvmArgsList) {
      if (arg is String) {
        final processedArg = replaceConfigVariables(arg, variables);
        jvmArgs.add(processedArg);
      }
    }
    LogUtil.log('添加了 ${jvmArgsList.length} 个来自NeoForge.json的JVM参数', level: 'INFO');
  }
  // 账号信息
  String uuid = '';
  String token = '';
  onProgress?.call('正在获取账号信息');
  if (accountInfo[0] == '0') {
    if (accountInfo[2] == '1') {
    uuid = accountInfo[3];
    }
    else {
      uuid = accountInfo[1];
    }
  }
  if (accountInfo[0] == '1') {
    uuid = '';
  }
  if (accountInfo[0] == '2') {
    if (await checkAuthlibInjector(gamePath)) {
      onProgress?.call('AuthlibInjector已存在');
    }
    else {
      onProgress?.call('正在下载AuthlibInjector');
      await downloadAuthlibInjector(gamePath);
    }
    uuid = accountInfo[1];
    onProgress?.call('正在检查令牌');
    if (await checkToken(accountInfo[2], accountInfo[5], accountInfo[6])) {
      token = accountInfo[5];
    } else {
      token = await refreshToken(accountInfo[2],
      accountInfo[5],
      accountInfo[6],
      account,
      uuid);
    }
  }
  jvmArgs.addAll(['-cp', cp]);
  onProgress?.call('正在准备启动参数');
  final gameArgs = <String>[
    '--username', account,
    '--version', game,
    '--gameDir', '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game',
    '--assetsDir', '$gamePath${Platform.pathSeparator}assets',
    '--assetIndex', assetIndex,
    '--uuid', if (accountInfo[2] == '1') accountInfo[3] else accountInfo[0],
    if (accountInfo[0] == '0') '--accessToken', accountInfo[0],
    if (accountInfo[0] == '0') '--clientId', '"\${clientid}"',
    if (accountInfo[0] == '0') '--accessToken', token,
    if (accountInfo[0] == '2') '--clientId', token,
    if (accountInfo[0] == '2') '--userType', 'mojang',
    '--versionType', '"FML $version"',
    '--width', cfg[2],
    '--height', cfg[3],
    if (cfg[1] == '1') '--fullscreen'
  ];
  // 添加NeoForge.json中定义的游戏参数
  if (neoForgeConfig != null &&
      neoForgeConfig.containsKey('arguments') &&
      neoForgeConfig['arguments'] is Map &&
      neoForgeConfig['arguments'].containsKey('game')) {
    final gameArgsList = neoForgeConfig['arguments']['game'] as List;
    for (var arg in gameArgsList) {
      if (arg is String) {
        final processedArg = replaceConfigVariables(arg, variables);
        gameArgs.add(processedArg);
      }
    }
    LogUtil.log('添加了 ${gameArgsList.length} 个来自NeoForge.json的游戏参数', level: 'INFO');
  }
  final args = [...jvmArgs, mainClass, ...gameArgs];
  onProgress?.call('正在启动游戏');
  final proc = await Process.start(
    java,
    args,
    workingDirectory: '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}$game'
  );
  final stdoutController = StreamController<String>();
  proc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    // 端口检测
    if (line.contains('Started serving on')) {
      final portMatch = RegExp(r'Started serving on (\d+)').firstMatch(line);
      if (portMatch != null) {
        final port = int.parse(portMatch.group(1)!);
        LogUtil.log('检测到局域网游戏已开放，端口: $port', level: 'INFO');
        _lastDetectedPort = port;
        try {
          lanPortController.add(port);
        } catch (e) {
          LogUtil.log('端口事件发送失败: $e', level: 'ERROR');
        }
      }
    } else if (line.contains('Stopping server')) {
      LogUtil.log('检测到局域网游戏已关闭', level: 'INFO');
      clearPortCache();
    }
    LogUtil.log('[MINECRAFT] $line', level: 'INFO');
    stdoutController.add(line);
  });
  proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) => LogUtil.log('[MINECRAFT] $line', level: 'ERROR')
  );
  onProgress?.call('游戏启动完成');
  final code = await proc.exitCode;
  LogUtil.log('退出码: $code', level: 'INFO');
}
