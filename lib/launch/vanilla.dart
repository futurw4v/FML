import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fmcl/constants.dart';
import 'package:fmcl/java/java_service.dart';
import 'package:fmcl/models/storage/entities/account.dart';
import 'package:fmcl/storage/storage_service.dart';
import 'package:fmcl/utils/log_util.dart';
import 'package:path/path.dart' as p;

typedef ProgressCallback = void Function(String message);
typedef ErrorCallback = void Function(String error);
// library获取
Future<List<String>> loadLibraryArtifactPaths(
  String versionJsonPath,
  String gamePath,
) async {
  final file = File(versionJsonPath);
  if (!await file.exists()) return [];
  late final dynamic root;
  try {
    root = jsonDecode(await file.readAsString());
  } catch (e) {
    LogUtil.log('JSON 解析失败: $e', level: 'ERROR');
    return [];
  }
  final libs = root is Map ? root['libraries'] : null;
  if (libs is! List) return [];
  final List<String> result = [];
  for (final item in libs) {
    if (item is! Map) continue;
    final downloads = item['downloads'];
    if (downloads is! Map) continue;
    final artifact = downloads['artifact'];
    if (artifact is! Map) continue;
    final path = artifact['path'];
    if (path is String && path.isNotEmpty) {
      final fullPath =
          '$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$path';
      result.add(fullPath);
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
  final ai = root['assetIndex'];
  if (ai is Map && ai['id'] is String && (ai['id'] as String).isNotEmpty) {
    return ai['id'] as String;
  }
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
  final assets = root['assets'];
  if (assets is String && assets.isNotEmpty) return assets;
  return null;
}

Future<void> vanillaLauncher({
  ProgressCallback? onProgress,
  ErrorCallback? onError,
}) async {
  onProgress?.call('正在准备启动');

  // 游戏参数
  final currentFolder = StorageService.pathsConfig.selectedFolder;

  if (currentFolder == null) {
    LogUtil.log('未选择游戏文件夹，无法启动', level: 'ERROR');
    return;
  }

  final dotMinecraftFolderPath = currentFolder.path;
  final selectedVersionFolderName = currentFolder.selectedVersionFolderName;
  final selectedGame = currentFolder.getVersionByFolderName(
    selectedVersionFolderName,
  );
  final assetsDirPath = p.join(dotMinecraftFolderPath, 'assets');

  if (selectedVersionFolderName == '' || selectedGame == null) {
    LogUtil.log('未选择游戏版本，无法启动', level: 'ERROR');
    return;
  }

  // 版本根目录
  final versionDir = p.join(
    dotMinecraftFolderPath,
    'versions',
    selectedVersionFolderName,
  );

  final jsonPath = p.join(versionDir, '$selectedVersionFolderName.json');
  final gameJar = p.join(versionDir, '$selectedVersionFolderName.jar');
  final nativesPath = p.join(versionDir, 'natives');

  // 依赖
  final libraries = await loadLibraryArtifactPaths(
    jsonPath,
    dotMinecraftFolderPath,
  );
  final separator = Platform.isWindows ? ';' : ':';
  final classPath = libraries.join(separator);
  final cp = '$classPath$separator$gameJar';

  final assetIndex = await getAssetIndex(jsonPath) ?? '';

  final selectedAccount = StorageService.accountsConfig.selectedAccount;

  if (selectedAccount == null) {
    LogUtil.log('未选择登录账号，无法启动', level: 'ERROR');
    return;
  }
  final java = JavaService.javaSelectedPath;

  // TODO: Java
  // final java = (selectedGame?.javaExecutablePath.isNotEmpty == true)
  //     ? selectedGame!.javaExecutablePath
  //     : (JavaService.javaSelectedPath.isNotEmpty
  //           ? StorageService.settingsConfig.javaSelectedPath
  //           : JavaService.javaSelectedPath);

  // TODO
  // final maxMemory = (selectedGame != null && selectedGame.customMaxMemory > 0)
  //     ? selectedGame.customMaxMemory
  //     : StorageService.settingsConfig.defaultMaxMemory;

  // 账号信息
  String uuid = '';
  String token = '';

  onProgress?.call('正在获取账号信息');

  // TODO: 微软登录与外置登录
  await selectedAccount.when(
    offline: (name, accountUuid, skin) async {
      uuid = accountUuid;
      token = name;
      LogUtil.log('离线账号启动: $name (UUID: $uuid)', level: 'INFO');
    },
    microsoft: (name, uuid, skin, refreshToken) async {},
    external: (name, uuid, skin, authServerUrl) async {},
  );

  // 启动参数
  onProgress?.call('正在准备启动参数');
  final args = <String>[
    '-Xmx4096M', // TODO
    '-XX:+UseG1GC',
    '-XX:-OmitStackTraceInFastThrow',
    '-Dfml.ignoreInvalidMinecraftCertificates=true',
    '-Dfml.ignorePatchDiscrepancies=true',
    '-Dminecraft.launcher.brand=$kAppNameAbb',

    if (Platform.isMacOS) '-XstartOnFirstThread',
    '-Djava.library.path=$nativesPath',
    '-Djna.tmpdir=$nativesPath',

    '-cp',
    cp,

    selectedGame.mainClass,
    '--username',
    selectedAccount.name,

    '--version',
    selectedVersionFolderName,

    '--gameDir',
    versionDir,

    '--assetsDir',
    assetsDirPath,

    '--assetIndex',
    assetIndex,

    '--uuid',
    uuid,

    '--accessToken',
    selectedAccount.name,

    '--clientId',
    '"\${clientid}"',

    '--versionType',
    '"$kAppNameAbb $gAppVersion"',
    '--xuid',
    '"\${auth_xuid}"',

    '--width',
    '800', // TODO

    '--height',
    '600', // TODO
    //'--fullscreen',
  ];

  LogUtil.log('使用的Java: $java', level: 'INFO');
  onProgress?.call('正在启动游戏');

  final out = await Process.start(java, args, workingDirectory: versionDir);

  onProgress?.call('游戏启动完成');

  out.stdout.listen((_) {});
  out.stderr.listen((_) {});

  out.exitCode.then((code) {
    LogUtil.log('游戏进程已退出，退出码: $code', level: 'INFO');
  });
}
