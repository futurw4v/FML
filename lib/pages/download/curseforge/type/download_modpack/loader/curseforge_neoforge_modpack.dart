import 'package:flutter/material.dart';
import 'package:fml/function/download.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:system_info2/system_info2.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/extract_natives.dart';

class CurseforgeNeoForgeModpackPage extends StatefulWidget {
  const CurseforgeNeoForgeModpackPage({
    super.key,
    required this.name,
    required this.url,
    required this.apiKey,
  });

  final String name;
  final String url;
  final String apiKey;

  @override
  CurseforgeNeoForgeModpackPageState createState() => CurseforgeNeoForgeModpackPageState();
}

class CurseforgeNeoForgeModpackPageState extends State<CurseforgeNeoForgeModpackPage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final Dio dio = Dio();

  bool _downloadZip = false;
  bool _unzipPack = false;
  bool _parseManifest = false;
  bool _downloadModsStatus = false;
  bool _downloadMinecraftJson = false;
  bool _parseGameJsonStatus = false;
  bool _downloadAssetJson = false;
  bool _parseAssetJson = false;
  bool _downloadClient = false;
  bool _downloadLibrary = false;
  bool _downloadAsset = false;
  bool _extractedLwjglNativesPath = false;
  bool _extractedLwjglNatives = false;
  bool _downloadNeoForge = false;
  bool _extractNeoForgeInstallerStatus = false;
  bool _parseNeoForgeInstallerJsonStatus = false;
  bool _downloadNeoForgeLibrary = false;
  bool _neoForgeInstalled = false;
  bool _copyOverrides = false;
  bool _writeConfig = false;
  double _progress = 0.0;
  int _mem = 1;
  String _name = '';
  String _neoforgeVersion = '';
  String _minecraftVersion = '';
  String _appVersion = "unknown";
  String _overridesFolder = 'overrides';
  String _installerJson = '';
  String _neoForgeURL = '';
  int _totalMods = 0;
  int _downloadedMods = 0;
  List<Map<String, dynamic>> _modFiles = [];
  String? assetIndexURL;
  String? clientURL;
  String? assetIndexId;
  final List<String> _assetHash = [];
  List<String> librariesPath = [];
  List<String> librariesURL = [];
  List<String> lwjglNativeNames = [];
  List<String> lwjglNativePaths = [];
  List<Map<String, String>> _failedLibraries = [];
  List<Map<String, String>> _failedAssets = [];
  List<String> neoForgeLibrariesPath = [];
  List<String> neoForgeLibrariesURL = [];
  List<Map<String, String>> _failedMods = [];
  bool _isRetrying = false;
  final int _maxRetries = 3;
  int _currentRetryCount = 0;

  // BMCLAPI 镜像
  String replaceWithMirror(String url) {
    return url
      .replaceAll('piston-meta.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('piston-data.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('launcher.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('launchermeta.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('libraries.minecraft.net', 'bmclapi2.bangbang93.com/maven')
      .replaceAll('resources.download.minecraft.net', 'bmclapi2.bangbang93.com/assets')
      .replaceAll('https://maven.neoforged.net/releases/net/neoforged/forge', 'https://bmclapi2.bangbang93.com/maven/net/neoforged/forge')
      .replaceAll('https://maven.neoforged.net/releases/net/neoforged/neoforge', 'https://bmclapi2.bangbang93.com/maven/net/neoforged/neoforge');
  }

  // 初始化通知
  Future<void> _initNotifications() async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Open');
      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
            appName: 'FML',
            appUserModelId: 'lxdklp.fml',
            guid: '11451419-0721-0721-0721-114514191981',
          );
      const InitializationSettings initializationSettings = InitializationSettings(
        macOS: initializationSettingsDarwin,
        linux: initializationSettingsLinux,
        windows: initializationSettingsWindows,
      );
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }
  }

  // 弹出通知
  Future<void> _showNotification(String title, String body) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails();
      const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        macOS: darwinDetails,
        linux: linuxDetails,
      );
      await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics,
      );
    }
  }

  // 读取App版本
  Future<void> _loadAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString('version') ?? "1.0.0";
    setState(() {
      _appVersion = version;
    });
  }

  // 文件夹创建
  Future<void> _createGameDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    final directory = Directory('$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      await LogUtil.log('创建目录: $gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}', level: 'INFO');
    }
  }

  // 解压 ZIP 文件
  Future<void> _unzipPackFile(String versionPath) async {
    try {
      final zipFile = File('$versionPath${Platform.pathSeparator}${widget.name}.zip');
      final extractPath = '$versionPath${Platform.pathSeparator}curseforge';
      if (!await zipFile.exists()) {
        throw Exception('整合包文件不存在: ${zipFile.path}');
      }
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final directory = Directory(extractPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('$extractPath${Platform.pathSeparator}$filename');
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }
      await LogUtil.log('CurseForge整合包解压完成到: $extractPath', level: 'INFO');
      setState(() {
        _unzipPack = true;
      });
    } catch (e) {
      await LogUtil.log('解压整合包失败: $e', level: 'ERROR');
      await _showNotification('解压失败', '无法解压整合包文件: $e');
      throw Exception('解压整合包失败: $e');
    }
  }

  // 解析 manifest.json
  Future<void> _parseManifestContent(String versionPath) async {
    try {
      final extractPath = '$versionPath${Platform.pathSeparator}curseforge';
      final manifestFile = File('$extractPath${Platform.pathSeparator}manifest.json');
      if (!await manifestFile.exists()) {
        throw Exception('找不到manifest.json文件');
      }
      final Map<String, dynamic> manifest = jsonDecode(await manifestFile.readAsString());
      _overridesFolder = manifest['overrides'] ?? 'overrides';
      if (manifest.containsKey('minecraft')) {
        final minecraft = manifest['minecraft'];
        _minecraftVersion = minecraft['version'] ?? '';
        await LogUtil.log('检测到Minecraft版本: $_minecraftVersion', level: 'INFO');
        final modLoaders = minecraft['modLoaders'] as List?;
        if (modLoaders != null) {
          for (var loader in modLoaders) {
            final id = loader['id']?.toString() ?? '';
            if (id.startsWith('neoforge-')) {
              _neoforgeVersion = id.replaceFirst('neoforge-', '');
              await LogUtil.log('检测到NeoForge版本: $_neoforgeVersion', level: 'INFO');
              // 构建NeoForge安装器下载URL
              _neoForgeURL = 'https://bmclapi2.bangbang93.com/maven/net/neoforged/neoforge/$_neoforgeVersion/neoforge-$_neoforgeVersion-installer.jar';
              await LogUtil.log('NeoForge安装器URL: $_neoForgeURL', level: 'INFO');
              break;
            }
          }
        }
      }
      if (manifest.containsKey('files') && manifest['files'] is List) {
        final List<dynamic> filesList = manifest['files'];
        _totalMods = filesList.length;
        _modFiles.clear();
        for (var fileInfo in filesList) {
          final projectId = fileInfo['projectID'];
          final fileId = fileInfo['fileID'];
          final required = fileInfo['required'] ?? true;
          if (projectId != null && fileId != null) {
            _modFiles.add({
              'projectId': projectId,
              'fileId': fileId,
              'required': required,
            });
          }
        }
        await LogUtil.log('解析了 ${_modFiles.length} 个模组文件', level: 'INFO');
      }
      setState(() {
        _parseManifest = true;
      });
    } catch (e) {
      await LogUtil.log('解析manifest.json失败: $e', level: 'ERROR');
      await _showNotification('解析失败', '无法解析manifest.json: $e');
      throw Exception('解析manifest.json失败: $e');
    }
  }

  // 从 CurseForge API 获取模组下载链接
  Future<String?> _getModDownloadUrl(int projectId, int fileId) async {
    try {
      final response = await dio.get(
        'https://api.curseforge.com/v1/mods/$projectId/files/$fileId/download-url',
        options: Options(
          headers: {
            'x-api-key': widget.apiKey,
            'User-Agent': 'lxdklp/FML/$_appVersion (fml.lxdklp.top)',
          },
        )
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      }
    } catch (e) {
      await LogUtil.log('获取模组下载链接失败 (projectId: $projectId, fileId: $fileId): $e', level: 'ERROR');
    }
    return null;
  }

  // 获取模组文件信息
  Future<Map<String, dynamic>?> _getModFileInfo(int projectId, int fileId) async {
    try {
      final response = await dio.get(
        'https://api.curseforge.com/v1/mods/$projectId/files/$fileId',
        options:  Options(
          headers: {
            'x-api-key': widget.apiKey,
            'User-Agent': 'lxdklp/FML/$_appVersion (fml.lxdklp.top)',
          },
        )
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      }
    } catch (e) {
      await LogUtil.log('获取模组文件信息失败 (projectId: $projectId, fileId: $fileId): $e', level: 'ERROR');
    }
    return null;
  }

  // 下载模组文件
  Future<void> _downloadMods(String versionPath) async {
    try {
      setState(() {
        _downloadModsStatus = false;
        _downloadedMods = 0;
        _progress = 0.0;
      });
      await LogUtil.log('开始下载 $_totalMods 个模组文件', level: 'INFO');
      final modsDir = Directory('$versionPath${Platform.pathSeparator}mods');
      if (!await modsDir.exists()) {
        await modsDir.create(recursive: true);
      }
      _failedMods.clear();
      for (int i = 0; i < _modFiles.length; i++) {
        final modInfo = _modFiles[i];
        final projectId = modInfo['projectId'] as int;
        final fileId = modInfo['fileId'] as int;
        final fileInfo = await _getModFileInfo(projectId, fileId);
        final fileName = fileInfo?['fileName'] ?? 'mod_${projectId}_$fileId.jar';
        String? downloadUrl = await _getModDownloadUrl(projectId, fileId);
        if (downloadUrl == null || downloadUrl.isEmpty) {
          downloadUrl = 'https://edge.forgecdn.net/files/${fileId ~/ 1000}/${fileId % 1000}/$fileName';
          await LogUtil.log('使用备用下载链接: $downloadUrl', level: 'INFO');
        }
        final targetPath = '$versionPath${Platform.pathSeparator}mods${Platform.pathSeparator}$fileName';
        await LogUtil.log('正在下载 (${i + 1}/$_totalMods): $fileName', level: 'INFO');
        try {
          bool success = false;
          await DownloadUtils.downloadFile(
            url: downloadUrl,
            savePath: targetPath,
            onProgress: (progress) {
              setState(() {
                _progress = (i + progress) / _totalMods;
              });
            },
            onSuccess: () {
              success = true;
            },
            onError: (error) async {
              await LogUtil.log('下载失败: $fileName - $error', level: 'ERROR');
              _failedMods.add({'url': downloadUrl!, 'path': targetPath, 'name': fileName});
            }
          );
          if (!success) {
            _failedMods.add({'url': downloadUrl, 'path': targetPath, 'name': fileName});
          }
        } catch (e) {
          await LogUtil.log('下载异常: $fileName - $e', level: 'ERROR');
          _failedMods.add({'url': downloadUrl, 'path': targetPath, 'name': fileName});
        }
        _downloadedMods++;
        setState(() {
          _progress = _downloadedMods / _totalMods;
        });
      }
      if (_failedMods.isNotEmpty) {
        await LogUtil.log('重试下载 ${_failedMods.length} 个失败的模组', level: 'INFO');
        await _retryFailedMods();
      }
      setState(() {
        _downloadModsStatus = true;
      });
      await LogUtil.log('所有模组文件处理完成', level: 'INFO');
    } catch (e) {
      await LogUtil.log('下载模组失败: $e', level: 'ERROR');
      await _showNotification('模组下载失败', '无法完成模组下载: $e');
      throw Exception('下载模组失败: $e');
    }
  }

  // 重试失败的模组下载
  Future<void> _retryFailedMods() async {
    List<Map<String, String>> currentFailed = List.from(_failedMods);
    _failedMods.clear();
    for (var mod in currentFailed) {
      bool success = false;
      int retryCount = 0;
      while (!success && retryCount < 5) {
        retryCount++;
        await LogUtil.log('重试下载 ${mod['name']} (第 $retryCount 次)', level: 'INFO');
        try {
          await DownloadUtils.downloadFile(
            url: mod['url']!,
            savePath: mod['path']!,
            onProgress: (_) {},
            onSuccess: () {
              success = true;
            },
            onError: (error) async {
              await LogUtil.log('重试失败: ${mod['name']} - $error', level: 'ERROR');
            }
          );
          if (success) break;
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          await LogUtil.log('重试异常: ${mod['name']} - $e', level: 'ERROR');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (!success) {
        await LogUtil.log('模组下载最终失败: ${mod['name']}', level: 'ERROR');
      }
    }
  }

  // 获取游戏 Json
  Future<void> _saveMinecraftJson(String versionPath) async {
    try {
      final options = Options(
        headers: {
          'User-Agent': 'FML/$_appVersion',
        },
        responseType: ResponseType.plain,
      );
      LogUtil.log('开始请求版本清单', level: 'INFO');
      final response = await dio.get(
        'https://bmclapi2.bangbang93.com/mc/game/version_manifest.json',
        options: options,
      );
      if (response.statusCode == 200) {
        LogUtil.log('成功获取版本清单', level: 'INFO');
        dynamic parsedData;
        if (response.data is String) {
          parsedData = jsonDecode(response.data);
        } else {
          parsedData = response.data;
        }
        if (parsedData != null && parsedData.containsKey('versions')) {
          final versions = parsedData['versions'];
          for (var version in versions) {
            if (version['id'] == _minecraftVersion) {
              final versionUrl = version['url'];
              final gameJsonURL = replaceWithMirror(versionUrl);
              LogUtil.log('找到版本 $_minecraftVersion 的URL: $versionUrl BMCLAPI: $gameJsonURL', level: 'INFO');
              try {
                await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.json', gameJsonURL);
                setState(() {
                  _downloadMinecraftJson = true;
                });
              } catch (e) {
                await _showNotification('下载失败', '版本Json下载失败\n$e');
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      LogUtil.log('请求出错: $e', level: 'ERROR');
    }
  }

  // 游戏 Json 解析
  Future<void> _parseGameJson(String jsonFilePath) async {
    try {
      final file = File(jsonFilePath);
      if (!file.existsSync()) {
        throw Exception('JSON文件不存在: $jsonFilePath');
      }
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      if (jsonData['assetIndex'] != null) {
        if (jsonData['assetIndex']['url'] != null) {
          assetIndexURL = replaceWithMirror(jsonData['assetIndex']['url']);
        }
        if (jsonData['assetIndex']['id'] != null) {
          assetIndexId = jsonData['assetIndex']['id'];
        }
      }
      if (jsonData['downloads'] != null &&
          jsonData['downloads']['client'] != null &&
          jsonData['downloads']['client']['url'] != null) {
        clientURL = replaceWithMirror(jsonData['downloads']['client']['url']);
      }
      if (jsonData['libraries'] != null && jsonData['libraries'] is List) {
        for (var lib in jsonData['libraries']) {
          if (lib['downloads'] != null && lib['downloads']['artifact'] != null) {
            final artifact = lib['downloads']['artifact'];
            if (artifact['path'] != null) {
              librariesPath.add(artifact['path']);
            }
            if (artifact['url'] != null) {
              librariesURL.add(replaceWithMirror(artifact['url']));
            }
          }
        }
        await LogUtil.log('找到 ${librariesPath.length} 个库文件路径', level: 'INFO');
      }
      setState(() {
        _parseGameJsonStatus = true;
      });
    } catch (e) {
      await _showNotification('解析JSON失败', e.toString());
      await LogUtil.log('解析JSON失败: $e', level: 'ERROR');
    }
  }

  // 解析Asset JSON
  Future<void> _parseAssetIndex(String assetIndexPath) async {
    try {
      final file = File(assetIndexPath);
      if (!file.existsSync()) {
        throw Exception('资产索引文件不存在: $assetIndexPath');
      }
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      _assetHash.clear();
      if (jsonData['objects'] == null) {
        throw Exception('资产索引JSON中缺少objects字段');
      }
      final objects = jsonData['objects'] as Map<String, dynamic>;
      objects.forEach((assetPath, info) {
        if (info['hash'] != null) {
          _assetHash.add(info['hash']);
        }
      });
      await LogUtil.log('已解析 ${_assetHash.length} 个资产哈希值', level: 'INFO');
      setState(() {
        _parseAssetJson = true;
      });
    } catch (e) {
      await _showNotification('解析资产索引失败', e.toString());
      await LogUtil.log('解析资产索引失败: $e', level: 'ERROR');
    }
  }

  // 下载库
  Future<void> _downloadLibraries({int concurrentDownloads = 20}) async {
    if (librariesURL.isEmpty || librariesPath.isEmpty) {
      await LogUtil.log('库文件列表为空，无法下载库文件', level: 'ERROR');
      return;
    }
    if (!_isRetrying) {
      _failedLibraries.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    List<Map<String, String>> downloadTasks = [];
    if (_isRetrying && _failedLibraries.isNotEmpty) {
      downloadTasks = _failedLibraries;
    } else {
      for (int i = 0; i < librariesURL.length; i++) {
        final url = librariesURL[i];
        final relativePath = librariesPath[i];
        final fullPath = '$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$relativePath';
        final file = File(fullPath);
        if (!file.existsSync()) {
          downloadTasks.add({'url': url, 'path': fullPath});
        }
      }
    }
    final totalLibraries = downloadTasks.length;
    if (totalLibraries == 0) {
      await LogUtil.log('所有库文件已存在，无需下载', level: 'INFO');
      setState(() {
        _downloadLibrary = true;
      });
      return;
    }
    int completedLibraries = 0;
    List<Map<String, String>> newFailedList = [];
    void updateProgress() {
      setState(() {
        _progress = completedLibraries / totalLibraries;
      });
    }
    await LogUtil.log('开始下载 $totalLibraries 个库文件，并发数: $concurrentDownloads', level: 'INFO');
    for (int i = 0; i < downloadTasks.length; i += concurrentDownloads) {
      int end = i + concurrentDownloads;
      if (end > downloadTasks.length) end = downloadTasks.length;
      List<Future<void>> batch = [];
      for (int j = i; j < end; j++) {
        final task = downloadTasks[j];
        batch.add(() async {
          try {
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () {
                completedLibraries++;
                updateProgress();
              },
              onError: (error) async {
                completedLibraries++;
                newFailedList.add(task);
              }
            );
          } catch (e) {
            completedLibraries++;
            newFailedList.add(task);
          }
        }());
      }
      await Future.wait(batch);
      updateProgress();
    }
    _failedLibraries = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      setState(() {
        _isRetrying = true;
      });
      await _downloadLibraries(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await _singleThreadRetryDownload(newFailedList, "库文件", (progress) {
        setState(() {
          _progress = progress;
        });
      });
    }
    setState(() {
      _isRetrying = false;
      _currentRetryCount = 0;
      _downloadLibrary = true;
    });
  }

  // 下载资源
  Future<void> _downloadAssets({int concurrentDownloads = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    if (!_isRetrying) {
      _failedAssets.clear();
    }
    List<Map<String, String>> downloadTasks = [];
    if (_isRetrying && _failedAssets.isNotEmpty) {
      downloadTasks = _failedAssets;
    } else {
      for (int i = 0; i < _assetHash.length; i++) {
        final hash = _assetHash[i];
        final hashPrefix = hash.substring(0, 2);
        final assetDir = '$gamePath${Platform.pathSeparator}assets${Platform.pathSeparator}objects${Platform.pathSeparator}$hashPrefix';
        final assetPath = '$assetDir${Platform.pathSeparator}$hash';
        final directory = Directory(assetDir);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        final file = File(assetPath);
        if (!file.existsSync()) {
          final url = 'https://bmclapi2.bangbang93.com/assets/$hashPrefix/$hash';
          downloadTasks.add({'url': url, 'path': assetPath});
        }
      }
    }
    final totalAssets = downloadTasks.length;
    if (totalAssets == 0) {
      await LogUtil.log('所有资源文件已存在，无需下载', level: 'INFO');
      setState(() {
        _downloadAsset = true;
      });
      return;
    }
    int completedAssets = 0;
    List<Map<String, String>> newFailedList = [];
    void updateProgress() {
      setState(() {
        _progress = completedAssets / totalAssets;
      });
    }
    await LogUtil.log('开始下载 $totalAssets 个资源文件，并发数: $concurrentDownloads', level: 'INFO');
    for (int i = 0; i < downloadTasks.length; i += concurrentDownloads) {
      int end = i + concurrentDownloads;
      if (end > downloadTasks.length) end = downloadTasks.length;
      List<Future<void>> batch = [];
      for (int j = i; j < end; j++) {
        final task = downloadTasks[j];
        batch.add(() async {
          try {
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () {
                completedAssets++;
                updateProgress();
              },
              onError: (error) async {
                completedAssets++;
                newFailedList.add(task);
              }
            );
          } catch (e) {
            completedAssets++;
            newFailedList.add(task);
          }
        }());
      }
      await Future.wait(batch);
      updateProgress();
    }
    _failedAssets = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      setState(() {
        _isRetrying = true;
      });
      await _downloadAssets(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await _singleThreadRetryDownload(newFailedList, "资源文件", (progress) {
        setState(() {
          _progress = progress;
        });
      });
    }
    setState(() {
      _isRetrying = false;
      _currentRetryCount = 0;
      _downloadAsset = true;
    });
  }

  // 提取LWJGL本地库文件的名称和路径
  Future<void> extractLwjglNativeLibrariesPath(String jsonFilePath, String gamePath) async {
    final namesList = <String>[];
    final pathsList = <String>[];
    final file = File(jsonFilePath);
    if (!await file.exists()) {
      await LogUtil.log('版本JSON文件不存在: $jsonFilePath', level: 'ERROR');
      setState(() {
        lwjglNativeNames = namesList;
        lwjglNativePaths = pathsList;
        _extractedLwjglNativesPath = true;
      });
      return;
    }
    late final dynamic root;
    try {
      root = jsonDecode(await file.readAsString());
    } catch (e) {
      await LogUtil.log('JSON 解析失败: $e', level: 'ERROR');
      setState(() {
        lwjglNativeNames = namesList;
        lwjglNativePaths = pathsList;
        _extractedLwjglNativesPath = true;
      });
      return;
    }
    final libs = root is Map ? root['libraries'] : null;
    if (libs is! List) {
      await LogUtil.log('JSON中没有libraries字段或格式错误', level: 'ERROR');
      setState(() {
        lwjglNativeNames = namesList;
        lwjglNativePaths = pathsList;
        _extractedLwjglNativesPath = true;
      });
      return;
    }
    for (final item in libs) {
      if (item is! Map) continue;
      final downloads = item['downloads'];
      if (downloads is! Map) continue;
      final artifact = downloads['artifact'];
      if (artifact is! Map) continue;
      final path = artifact['path'];
      if (path is! String || path.isEmpty) continue;
      final fileName = path.split('/').last;
      // 检查是否为所需的LWJGL库
      if ((fileName.startsWith('lwjgl-') && fileName.contains('-natives-')) ||
          (fileName.startsWith('lwjgl-freetype-') && fileName.contains('-natives-')) ||
          (fileName.startsWith('lwjgl-glfw-') && fileName.contains('-natives-')) ||
          (fileName.startsWith('lwjgl-jemalloc-') && fileName.contains('-natives-')) ||
          (fileName.startsWith('lwjgl-openal-') && fileName.contains('-natives-')) ||
          (fileName.startsWith('lwjgl-stb-') && fileName.contains('-natives-')) ||
          fileName.startsWith('lwjgl-tinyfd')) {
        namesList.add(fileName);
        String nativePath = path.replaceAll('/', Platform.pathSeparator);
        final fullPath = ('$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$nativePath');
        pathsList.add(fullPath);
        await LogUtil.log('找到LWJGL库: $fileName, 路径: $fullPath', level: 'INFO');
      }
    }
    await LogUtil.log('总共找到${namesList.length}个LWJGL本地库', level: 'INFO');
    setState(() {
      lwjglNativeNames = namesList;
      lwjglNativePaths = pathsList;
      _extractedLwjglNativesPath = true;
    });
  }

  // 提取LWJGL Natives
  Future<void> _extractLwjglNatives() async {
    if (lwjglNativePaths.isEmpty || lwjglNativeNames.isEmpty) {
      await LogUtil.log('没有找到LWJGL本地库，跳过提取', level: 'WARNING');
      setState(() {
        _extractedLwjglNatives = true;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    final nativesDir = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}natives';
    final nativesDirObj = Directory(nativesDir);
    if (!await nativesDirObj.exists()) {
      await nativesDirObj.create(recursive: true);
      await LogUtil.log('创建natives目录: $nativesDir', level: 'INFO');
    }
    await LogUtil.log('开始提取LWJGL本地库到: $nativesDir', level: 'INFO');
    int successCount = 0;
    List<String> extractedFiles = [];
    for (int i = 0; i < lwjglNativePaths.length; i++) {
      final fullPath = lwjglNativePaths[i];
      final fileName = lwjglNativeNames[i];
      try {
        final jarDir = fullPath.substring(0, fullPath.lastIndexOf(Platform.pathSeparator));
        await LogUtil.log('提取: $fileName 从 $jarDir 到 $nativesDir', level: 'INFO');
        final extracted = await extractNatives(jarDir, fileName, nativesDir);
        if (extracted.isNotEmpty) {
          successCount++;
          extractedFiles.addAll(extracted);
          await LogUtil.log('成功从 $fileName 提取了 ${extracted.length} 个文件');
        }
      } catch (e) {
        await LogUtil.log('提取 $fileName 时出错: $e', level: 'ERROR');
      }
    }
    await LogUtil.log('完成LWJGL本地库提取, 共处理 ${lwjglNativePaths.length} 个文件, 成功: $successCount', level: 'INFO');
    await LogUtil.log('提取的文件: ${extractedFiles.join(', ')}', level: 'INFO');
    setState(() {
      _extractedLwjglNatives = true;
    });
  }

  // 下载NeoForge安装器
  Future<void> _downloadNeoForgeInstaller(String versionPath) async {
    try {
      if (_neoForgeURL.isEmpty) {
        throw Exception('NeoForge安装器URL为空');
      }
      final installerPath = '$versionPath${Platform.pathSeparator}neoforge-installer.jar';
      await LogUtil.log('开始下载NeoForge安装器: $_neoForgeURL', level: 'INFO');
      await _downloadFile(installerPath, _neoForgeURL);
      setState(() {
        _downloadNeoForge = true;
      });
      await LogUtil.log('NeoForge安装器下载完成', level: 'INFO');
    } catch (e) {
      await _showNotification('下载NeoForge安装器失败', e.toString());
      await LogUtil.log('下载NeoForge安装器失败: $e', level: 'ERROR');
      throw Exception('下载NeoForge安装器失败: $e');
    }
  }

  // 提取NeoForge安装器
  Future<void> _extractNeoForgeInstaller() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedGamePath = prefs.getString('SelectedPath') ?? '';
      final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
      final neoForgePath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}neoforge-installer.jar';
      final bytes = await File(neoForgePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name == 'install_profile.json') {
          final content = file.content as List<int>;
          _installerJson = utf8.decode(content);
          final jsonFile = File('$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}install_profile.json');
          await jsonFile.writeAsBytes(content);
          break;
        }
      }
      if (_installerJson.isEmpty) {
        throw Exception('无法从安装器中提取install_profile.json');
      }
    } catch (e) {
      throw Exception('提取NeoForge安装器失败: $e');
    }
    setState(() {
      _extractNeoForgeInstallerStatus = true;
    });
  }

  // 解析NeoForge安装器JSON
  Future<void> _parseNeoForgeInstallerJson() async {
    neoForgeLibrariesURL.clear();
    neoForgeLibrariesPath.clear();
    if (_installerJson.isEmpty) return;
    try {
      final json = jsonDecode(_installerJson);
      if (json['libraries'] != null && json['libraries'] is List) {
        await LogUtil.log('找到NeoForge libraries,开始解析...', level: 'INFO');
        for (var lib in json['libraries']) {
          if (lib['downloads'] != null && lib['downloads']['artifact'] != null) {
            final artifact = lib['downloads']['artifact'];
            if (artifact['path'] != null) {
              neoForgeLibrariesPath.add(artifact['path']);
            }
            if (artifact['url'] != null) {
              String url = artifact['url'];
              url = url.replaceAll(
                'https://maven.neoforged.net/releases/net',
                'https://bmclapi2.bangbang93.com/maven/net'
              );
              neoForgeLibrariesURL.add(url);
            }
          } else if (lib['name'] != null) {
            final String mavenCoords = lib['name'];
            try {
              final parts = mavenCoords.split(':');
              if (parts.length >= 3) {
                final group = parts[0].replaceAll('.', '/');
                final artifact = parts[1];
                final version = parts[2];
                final path = '$group/$artifact/$version/$artifact-$version.jar';
                neoForgeLibrariesPath.add(path);
                final url = 'https://bmclapi2.bangbang93.com/maven/$path';
                neoForgeLibrariesURL.add(url);
              }
            } catch (e) {
              await LogUtil.log('解析Maven坐标失败: $mavenCoords, 错误: $e', level: 'ERROR');
            }
          }
        }
        librariesPath.addAll(neoForgeLibrariesPath);
        librariesURL.addAll(neoForgeLibrariesURL);
        await LogUtil.log('成功解析NeoForge libraries: ${neoForgeLibrariesURL.length}个', level: 'INFO');
      } else {
        await LogUtil.log('未找到NeoForge libraries或格式不正确', level: 'ERROR');
      }
    } catch (e) {
      await LogUtil.log('解析NeoForge安装器JSON失败: $e', level: 'ERROR');
    }
    setState(() {
      _parseNeoForgeInstallerJsonStatus = true;
    });
  }

  // 下载NeoForge库
  Future<void> _downloadNeoForgeLibraries({int concurrentDownloads = 20}) async {
    if (neoForgeLibrariesURL.isEmpty || neoForgeLibrariesPath.isEmpty) {
      await LogUtil.log('NeoForge库文件列表为空', level: 'ERROR');
      await _showNotification('下载失败', 'NeoForge库文件列表为空');
      setState(() {
        _downloadNeoForgeLibrary = false;
        _currentRetryCount = 0;
        _downloadNeoForgeLibrary = true;
      });
      return;
    }
    if (!_isRetrying) {
      _failedLibraries.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    List<Map<String, String>> downloadTasks = [];
    if (_isRetrying && _failedLibraries.isNotEmpty) {
      await LogUtil.log('正在重试下载 ${_failedLibraries.length} 个失败的NeoForge库文件', level: 'INFO');
      downloadTasks = _failedLibraries;
    } else {
      final libraryDir = Directory('$gamePath${Platform.pathSeparator}libraries');
      if (!await libraryDir.exists()) {
        await libraryDir.create(recursive: true);
      }
      for (int i = 0; i < neoForgeLibrariesURL.length; i++) {
        final url = neoForgeLibrariesURL[i];
        final relativePath = neoForgeLibrariesPath[i];
        final fullPath = '$gamePath${Platform.pathSeparator}libraries${Platform.pathSeparator}$relativePath';
        final file = File(fullPath);
        if (!file.existsSync()) {
          downloadTasks.add({'url': url, 'path': fullPath});
        }
      }
    }
    final totalLibraries = downloadTasks.length;
    if (totalLibraries == 0) {
      await LogUtil.log('所有NeoForge库文件已存在,无需下载', level: 'INFO');
      setState(() {
        _downloadNeoForgeLibrary = true;
      });
      return;
    }
    await LogUtil.log('开始下载 $totalLibraries 个NeoForge库文件,并发数: $concurrentDownloads', level: 'INFO');
    int completedLibraries = 0;
    List<Map<String, String>> newFailedList = [];
    void updateProgress() {
      setState(() {
        _progress = completedLibraries / totalLibraries;
      });
    }
    for (int i = 0; i < downloadTasks.length; i += concurrentDownloads) {
      int end = i + concurrentDownloads;
      if (end > downloadTasks.length) end = downloadTasks.length;
      List<Future<void>> batch = [];
      for (int j = i; j < end; j++) {
        final task = downloadTasks[j];
        batch.add(() async {
          try {
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () {
                completedLibraries++;
                updateProgress();
              },
              onError: (error) async {
                completedLibraries++;
                newFailedList.add(task);
                await LogUtil.log('下载NeoForge库文件失败: $error, URL: ${task['url']}', level: 'ERROR');
              }
            );
          } catch (e) {
            completedLibraries++;
            newFailedList.add(task);
            await LogUtil.log('下载NeoForge库文件异常: $e, URL: ${task['url']}', level: 'ERROR');
          }
        }());
      }
      await Future.wait(batch);
      updateProgress();
      await LogUtil.log('已完成: $completedLibraries/$totalLibraries, 失败: ${newFailedList.length}', level: 'INFO');
    }
    _failedLibraries = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      await LogUtil.log('准备重试下载 ${newFailedList.length} 个失败的NeoForge库文件 (第 $_currentRetryCount 次重试)', level: 'INFO');
      setState(() {
        _isRetrying = true;
      });
      await _downloadNeoForgeLibraries(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await LogUtil.log('已达最大并发重试次数,开始单线程重试 ${newFailedList.length} 个NeoForge库文件', level: 'WARNING');
      await _singleThreadRetryDownload(newFailedList, "NeoForge库文件", (progress) {
        setState(() {
          _progress = progress;
        });
      });
    }
    setState(() {
      _isRetrying = false;
      _currentRetryCount = 0;
      _downloadNeoForgeLibrary = true;
    });
  }

  // 执行NeoForge安装器
  Future<void> _executeNeoForgeInstaller() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    final installerPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}neoforge-installer.jar';
    final neoForgeJson = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}neoforge-$_neoforgeVersion${Platform.pathSeparator}neoforge-$_neoforgeVersion.json';
    await LogUtil.log('开始执行NeoForge安装器: $installerPath', level: 'INFO');
    final result = await Process.run('java', [
      '-jar', installerPath,
      '--installClient', gamePath
    ]);
    if (result.stderr.toString().isNotEmpty) {
      for (var line in result.stderr.toString().split('\n')) {
        if (line.trim().isNotEmpty) {
          await LogUtil.log('[NEOFORGE INSTALLER] $line', level: 'ERROR');
        }
      }
    }
    final code = result.exitCode;
    await LogUtil.log('NeoForge安装器退出码: $code', level: 'INFO');
    if (code != 0) {
      throw Exception('NeoForge安装器执行失败,退出码: $code');
    }
    await LogUtil.log('NeoForge安装器执行成功', level: 'INFO');
    await LogUtil.log('移动$neoForgeJson 配置文件到: $gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}NeoForge.json', level: 'INFO');
    await _moveFile(neoForgeJson, '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}NeoForge.json');
    setState(() {
      _neoForgeInstalled = true;
    });
  }

  // 移动文件
  Future<void> _moveFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('源文件不存在: $sourcePath');
      }
      final destinationDir = Directory(destinationPath.substring(0, destinationPath.lastIndexOf(Platform.pathSeparator)));
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }
      await sourceFile.rename(destinationPath);
      await LogUtil.log('文件已成功移动到: $destinationPath', level: 'INFO');
    } catch (e) {
      await LogUtil.log('移动文件时发生错误: $e', level: 'ERROR');
      await _showNotification('移动文件时发生错误', e.toString());
    }
  }

  // 单线程重试
  Future<void> _singleThreadRetryDownload(List<Map<String, String>> failedList, String fileType,
      Function(double) updateProgressCallback) async {
    int total = failedList.length;
    int completed = 0;
    List<Map<String, String>> currentFailedList = List.from(failedList);
    while (currentFailedList.isNotEmpty) {
      List<Map<String, String>> nextRetryList = [];
      for (var task in currentFailedList) {
        bool success = false;
        while (!success) {
          try {
            bool downloadComplete = false;
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () {
                downloadComplete = true;
              },
              onError: (error) {}
            );
            if (downloadComplete) {
              success = true;
              completed++;
              updateProgressCallback(completed / total);
            } else {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      currentFailedList = nextRetryList;
    }
  }

  // 文件下载
  Future<void> _downloadFile(String path, String url) async {
    bool success = false;
    try {
      await DownloadUtils.downloadFile(
        url: url,
        savePath: path,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
        onSuccess: () {
          success = true;
        },
        onError: (error) async {
          await LogUtil.log('下载失败: $error, URL: $url', level: 'ERROR');
        }
      );
      final file = File(path);
      if (await file.exists()) {
        success = true;
      }
      if (!success) {
        throw Exception('下载失败: $url');
      }
    } catch (e) {
      throw Exception('下载出错: $e');
    }
  }

  // 复制 overrides 内容
  Future<void> _copyOverridesContent(String versionPath) async {
    try {
      final overridesDir = Directory('$versionPath${Platform.pathSeparator}curseforge${Platform.pathSeparator}$_overridesFolder');
      if (!await overridesDir.exists()) {
        await LogUtil.log('overrides 文件夹不存在($_overridesFolder),跳过复制', level: 'INFO');
        setState(() {
          _copyOverrides = true;
        });
        return;
      }
      await LogUtil.log('开始复制 overrides 文件夹内容到版本文件夹', level: 'INFO');
      int copiedFiles = 0;
      int copiedDirs = 0;
      Future<void> copyDirectory(Directory source, Directory destination) async {
        if (!await destination.exists()) {
          await destination.create(recursive: true);
          copiedDirs++;
        }
        await for (final entity in source.list(recursive: false, followLinks: false)) {
          final String relativePath = entity.path.substring(source.path.length);
          final String destinationPath = '${destination.path}$relativePath';
          if (entity is File) {
            await entity.copy(destinationPath);
            copiedFiles++;
          } else if (entity is Directory) {
            await copyDirectory(entity, Directory(destinationPath));
          }
        }
      }
      await copyDirectory(overridesDir, Directory(versionPath));
      await LogUtil.log('overrides 内容复制完成,共复制 $copiedFiles 个文件和 $copiedDirs 个目录', level: 'INFO');
      setState(() {
        _copyOverrides = true;
      });
    } catch (e) {
      await LogUtil.log('复制 overrides 内容失败: $e', level: 'ERROR');
      throw Exception('复制 overrides 内容失败: $e');
    }
  }

  // 获取系统内存
  Future<void> _getMemory() async {
    int bytes = SysInfo.getTotalPhysicalMemory();
    if (bytes > (1024 * 1024 * 1024 * 1024) && bytes % 16384 == 0) {
      bytes = bytes ~/ 16384;
    }
    final physicalMemory = bytes ~/ (1024 * 1024 * 1024);
    setState(() {
      _mem = physicalMemory;
    });
  }

  // 游戏配置文件创建
  Future<void> _writeGameConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('SelectedPath') ?? '';
    List<String> gameList = prefs.getStringList('Game_$_name') ?? [];
    List<String> defaultConfig = [
      '${_mem ~/ 2}',
      '0',
      '854',
      '480',
      'NeoForge',
      ''
    ];
    final key = 'Config_${_name}_${widget.name}';
    await prefs.setStringList(key, defaultConfig);
    gameList.add(widget.name);
    await prefs.setStringList('Game_$_name', gameList);
    await LogUtil.log('已将 ${widget.name} 添加到游戏列表', level: 'INFO');
    setState(() {
      _writeConfig = true;
    });
  }

  // 下载逻辑
  Future<void> _startDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    final versionPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}';
    try {
      await LogUtil.log('正在下载 CurseForge 整合包 ${widget.name}', level: 'INFO');
      await _showNotification('开始下载', '正在下载 ${widget.name}');
      await _createGameDirectories();
      // 下载整合包
      try {
        await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.zip', widget.url);
        setState(() {
          _downloadZip = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载整合包失败: $e')),
        );
        return;
      }
      // 解压整合包
      await _unzipPackFile(versionPath);
      // 解析 manifest.json
      await _parseManifestContent(versionPath);
      // 下载模组文件
      await _downloadMods(versionPath);
      // 保存 Minecraft Json
      await _saveMinecraftJson(versionPath);
      // 解析游戏 Json
      await _parseGameJson('$versionPath${Platform.pathSeparator}${widget.name}.json');
      // 下载资产索引文件
      if (assetIndexURL != null) {
        final assetIndexPath = '$gamePath${Platform.pathSeparator}assets${Platform.pathSeparator}indexes${Platform.pathSeparator}$assetIndexId.json';
        try {
          await _downloadFile(assetIndexPath, assetIndexURL!);
          setState(() {
            _downloadAssetJson = true;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载资产索引失败: $e')),
          );
          return;
        }
        // 解析资产索引
        await _parseAssetIndex(assetIndexPath);
        // 下载客户端
        try {
          await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.jar', clientURL!);
          setState(() {
            _downloadClient = true;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载客户端失败: $e')),
          );
          return;
        }
        // 下载库文件
        await _downloadLibraries(concurrentDownloads: 30);
        // 下载资源文件
        await _downloadAssets(concurrentDownloads: 30);
        // 提取 LWJGL 本地库路径
        await extractLwjglNativeLibrariesPath('$versionPath${Platform.pathSeparator}${widget.name}.json', gamePath);
        // 提取 LWJGL Natives
        await _extractLwjglNatives();
        // 下载NeoForge安装器
        await _downloadNeoForgeInstaller(versionPath);
        // 提取NeoForge安装器
        await _extractNeoForgeInstaller();
        // 解析NeoForge安装器JSON
        await _parseNeoForgeInstallerJson();
        // 下载NeoForge库文件
        await _downloadNeoForgeLibraries(concurrentDownloads: 30);
        // 执行NeoForge安装器
        await _executeNeoForgeInstaller();
        // 复制 overrides 文件
        await _copyOverridesContent(versionPath);
        // 写入游戏配置
        await _writeGameConfig();
        // 完成通知
        await _showNotification('安装完成', '${widget.name} 安装完成');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadAppVersion();
    _getMemory();
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('下载整合包 ${widget.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('正在下载整合包'),
              subtitle: Text(_downloadZip ? '下载完成' : '下载中...'),
              trailing: _downloadZip
                ? const Icon(Icons.check)
                : const CircularProgressIndicator(),
            ),
          ),
          if (_downloadZip) ...[
            Card(
              child: ListTile(
                title: const Text('正在解压整合包'),
                subtitle: Text(_unzipPack ? '解压完成' : '解压中...'),
                trailing: _unzipPack
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_unzipPack) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析manifest.json'),
                subtitle: Text(_parseManifest ? '解析完成' : '解析中...'),
                trailing: _parseManifest
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_parseManifest) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载模组文件'),
                    subtitle: Text(_downloadModsStatus
                      ? '下载完成'
                      : '下载中... $_downloadedMods/$_totalMods (${(_progress * 100).toStringAsFixed(1)}%)'),
                    trailing: _downloadModsStatus
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadModsStatus)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadModsStatus) ...[
            Card(
              child: ListTile(
                title: const Text('正在获取游戏Json'),
                subtitle: Text(_downloadMinecraftJson ? '获取完成' : '获取中...'),
                trailing: _downloadMinecraftJson
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_downloadMinecraftJson) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析游戏Json'),
                subtitle: Text(_parseGameJsonStatus ? '解析完成' : '解析中...'),
                trailing: _parseGameJsonStatus
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_parseGameJsonStatus) ...[
            Card(
              child: ListTile(
                title: const Text('正在获取资源Json'),
                subtitle: Text(_downloadAssetJson ? '获取完成' : '获取中...'),
                trailing: _downloadAssetJson
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_downloadAssetJson) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析资源Json'),
                subtitle: Text(_parseAssetJson ? '解析完成' : '解析中...'),
                trailing: _parseAssetJson
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_parseAssetJson) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载客户端'),
                    subtitle: Text(_downloadClient
                      ? '下载完成'
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%'),
                    trailing: _downloadClient
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadClient)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadClient) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载游戏库'),
                    subtitle: Text(_downloadLibrary
                      ? '下载完成'
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%'),
                    trailing: _downloadLibrary
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadLibrary)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadLibrary) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载游戏资源'),
                    subtitle: Text(_downloadAsset
                      ? '下载完成'
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%'),
                    trailing: _downloadAsset
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadAsset)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadAsset) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取LWJGL路径'),
                subtitle: Text(_extractedLwjglNativesPath ? '提取完成' : '提取中...'),
                trailing: _extractedLwjglNativesPath
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_extractedLwjglNativesPath) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取LWJGL'),
                subtitle: Text(_extractedLwjglNatives ? '提取完成' : '提取中...'),
                trailing: _extractedLwjglNatives
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_extractedLwjglNatives) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载NeoForge安装器'),
                    subtitle: Text(_downloadNeoForge
                      ? '下载完成'
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%'),
                    trailing: _downloadNeoForge
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadNeoForge)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadNeoForge) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取NeoForge安装器'),
                subtitle: Text(_extractNeoForgeInstallerStatus ? '提取完成' : '提取中...'),
                trailing: _extractNeoForgeInstallerStatus
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_extractNeoForgeInstallerStatus) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析NeoForge安装配置'),
                subtitle: Text(_parseNeoForgeInstallerJsonStatus ? '解析完成' : '解析中...'),
                trailing: _parseNeoForgeInstallerJsonStatus
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_parseNeoForgeInstallerJsonStatus) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载NeoForge库'),
                    subtitle: Text(_downloadNeoForgeLibrary
                      ? '下载完成'
                      : '下载中... ${(_progress * 100).toStringAsFixed(1)}%'),
                    trailing: _downloadNeoForgeLibrary
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator(),
                  ),
                  if (!_downloadNeoForgeLibrary)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              ),
            ),
          ],
          if (_downloadNeoForgeLibrary) ...[
            Card(
              child: ListTile(
                title: const Text('正在安装NeoForge'),
                subtitle: Text(_neoForgeInstalled ? '安装完成' : '安装中...'),
                trailing: _neoForgeInstalled
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_neoForgeInstalled) ...[
            Card(
              child: ListTile(
                title: const Text('正在复制整合包文件'),
                subtitle: Text(_copyOverrides ? '复制完成' : '复制中...'),
                trailing: _copyOverrides
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_copyOverrides) ...[
            Card(
              child: ListTile(
                title: const Text('正在写入配置文件'),
                subtitle: Text(_writeConfig ? '写入完成' : '写入中...'),
                trailing: _writeConfig
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _writeConfig
        ? FloatingActionButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Icon(Icons.check),
          )
        : null,
    );
  }
}
