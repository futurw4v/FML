import 'package:flutter/material.dart';
import 'package:fml/function/download/download.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/extract_natives.dart';

class FabricModpackPage extends StatefulWidget {
  const FabricModpackPage({
    super.key,
    required this.name,
    required this.url,
  });

  final String name;
  final String url;

  @override
  FabricModpackPageState createState() => FabricModpackPageState();
}

class FabricModpackPageState extends State<FabricModpackPage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final Dio dio = Dio();

  bool _downloadMrpack = false;
  bool _unzipMrpack = false;
  bool _parseMrpack = false;
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
  bool _saveFabricJsonStatus = false;

  double _progress = 0.0;

  String _fabricVersion = '';
  String _minecraftVersion = '';
  String _appVersion = "unknown";
  List<dynamic> _fabricFullJson = [];
  Map<String, dynamic> _fabricJson = {};

  int _totalMods = 0;
  int _downloadedMods = 0;

  List<String> _modsPath = [];
  List<String> _modsUrl = [];

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

  bool _isRetrying = false;
  final int _maxRetries = 3;  // 最大重试次数
  int _currentRetryCount = 0;

    // BMCLAPI 镜像
  String replaceWithMirror(String url) {
    return url
      .replaceAll('piston-meta.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('piston-data.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('launcher.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('launchermeta.mojang.com', 'bmclapi2.bangbang93.com')
      .replaceAll('libraries.minecraft.net', 'bmclapi2.bangbang93.com/maven')
      .replaceAll('resources.download.minecraft.net', 'bmclapi2.bangbang93.com/assets');
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

  // 解压Mrpack文件
  Future<void> _unzipMrpackFile(String versionPath) async {
    try {
      final mrpackFile = File('$versionPath${Platform.pathSeparator}${widget.name}.mrpack');
      final extractPath = '$versionPath${Platform.pathSeparator}mrpack';
      if (!await mrpackFile.exists()) {
        throw Exception('Mrpack文件不存在: ${mrpackFile.path}');
      }
      final bytes = await mrpackFile.readAsBytes();
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
          await LogUtil.log('解压文件: $filename', level: 'INFO');
        }
      }
      await LogUtil.log('Mrpack解压完成到: $extractPath', level: 'INFO');
      setState(() {
        _unzipMrpack = true;
      });
    } catch (e) {
      await LogUtil.log('解压Mrpack失败: $e', level: 'ERROR');
      await _showNotification('解压失败', '无法解压Mrpack文件: $e');
      throw Exception('解压Mrpack失败: $e');
    }
  }

  // 解析Mrpack内容
  Future<void> _parseMrpackContent(String versionPath) async {
    try {
      final extractPath = '$versionPath${Platform.pathSeparator}mrpack';
      final indexFile = File('$extractPath${Platform.pathSeparator}modrinth.index.json');
      if (!await indexFile.exists()) {
        throw Exception('找不到modrinth.index.json文件');
      }
      final Map<String, dynamic> indexJson = jsonDecode(await indexFile.readAsString());
      if (indexJson.containsKey('dependencies')) {
        final dependencies = indexJson['dependencies'];
        _fabricVersion = dependencies['fabric-loader'] ?? '';
        _minecraftVersion = dependencies['minecraft'] ?? '';
        await LogUtil.log('检测到Fabric加载器版本: $_fabricVersion', level: 'INFO');
        await LogUtil.log('检测到Minecraft版本: $_minecraftVersion', level: 'INFO');
      }
      if (indexJson.containsKey('files') && indexJson['files'] is List) {
        final List<dynamic> filesList = indexJson['files'];
        _totalMods = filesList.length;
        for (var fileInfo in filesList) {
          if (fileInfo['path'] != null) {
            _modsPath.add(fileInfo['path']);
          }
          if (fileInfo['downloads'] != null &&
              fileInfo['downloads'] is List &&
              fileInfo['downloads'].isNotEmpty) {
            _modsUrl.add(fileInfo['downloads'][0]);
          } else {
            _modsUrl.add('');
          }
        }
        await LogUtil.log('解析了 ${_modsPath.length} 个文件路径和下载URL', level: 'INFO');
      }
      setState(() {
        _parseMrpack = true;
      });
    } catch (e) {
      await LogUtil.log('解析Mrpack内容失败: $e', level: 'ERROR');
      await _showNotification('解析失败', '无法解析Mrpack内容: $e');
      throw Exception('解析Mrpack内容失败: $e');
    }
  }

  // 下载和处理模组文件
  Future<void> _downloadMods(String versionPath) async {
    try {
      setState(() {
        _downloadModsStatus = false;
        _downloadedMods = 0;
        _progress = 0.0;
      });
      final extractPath = '$versionPath${Platform.pathSeparator}mrpack';
      await LogUtil.log('开始处理 $_totalMods 个模组文件', level: 'INFO');
      final modsDir = Directory('$versionPath${Platform.pathSeparator}mods');
      if (!await modsDir.exists()) {
        await modsDir.create(recursive: true);
      }
      final resourcepacksDir = Directory('$versionPath${Platform.pathSeparator}resourcepacks');
      if (!await resourcepacksDir.exists()) {
        await resourcepacksDir.create(recursive: true);
      }
      for (int i = 0; i < _modsPath.length; i++) {
        final path = _modsPath[i];
        final url = i < _modsUrl.length ? _modsUrl[i] : '';
        final String fileName = path.split('/').last;
        String targetPath;
        if (path.startsWith('mods/')) {
          targetPath = '$versionPath${Platform.pathSeparator}mods${Platform.pathSeparator}$fileName';
        } else if (path.startsWith('resourcepacks/')) {
          targetPath = '$versionPath${Platform.pathSeparator}resourcepacks${Platform.pathSeparator}$fileName';
        } else {
          final parts = path.split('/');
          if (parts.length > 1) {
            final dirPath = '$versionPath${Platform.pathSeparator}${parts.sublist(0, parts.length - 1).join(Platform.pathSeparator)}';
            final dirObj = Directory(dirPath);
            if (!await dirObj.exists()) {
              await dirObj.create(recursive: true);
            }
            targetPath = '$dirPath${Platform.pathSeparator}$fileName';
          } else {
            targetPath = '$versionPath${Platform.pathSeparator}$fileName';
          }
        }
        final targetFile = File(targetPath);
        if (!await targetFile.parent.exists()) {
          await targetFile.parent.create(recursive: true);
        }
        bool fileHandled = false;
        final String localFilePath = '$extractPath${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}';
        final File localFile = File(localFilePath);
        if (await localFile.exists()) {
          try {
            await localFile.copy(targetPath);
            await LogUtil.log('复制文件 (${_downloadedMods+1}/$_totalMods): $fileName', level: 'INFO');
            fileHandled = true;
          } catch (e) {
            await LogUtil.log('复制文件失败: $fileName - $e', level: 'ERROR');
          }
        }
        if (!fileHandled && url.isNotEmpty) {
          await LogUtil.log('正在下载 (${_downloadedMods+1}/$_totalMods): $fileName', level: 'INFO');
          try {
            await DownloadUtils.downloadFile(
              url: url,
              savePath: targetPath,
              onProgress: (progress) {
                setState(() {
                  _progress = (_downloadedMods + progress) / _totalMods;
                });
              },
              onSuccess: () async {
                await LogUtil.log('下载成功: $fileName', level: 'INFO');
                fileHandled = true;
              },
              onError: (error) async {
                await LogUtil.log('下载失败: $fileName - $error', level: 'ERROR');
              }
            );
            final downloadedFile = File(targetPath);
            if (await downloadedFile.exists()) {
              fileHandled = true;
            }
          } catch (e) {
            await LogUtil.log('下载异常: $fileName - $e', level: 'ERROR');
          }
        }
        if (!fileHandled) {
          await LogUtil.log('无法处理文件: $fileName - 本地不存在且下载URL为空', level: 'ERROR');
        }
        _downloadedMods++;
        setState(() {
          _progress = _downloadedMods / _totalMods;
        });
      }
      setState(() {
        _downloadModsStatus = true;
      });
      await _showNotification('模组下载完成', '已成功下载并安装所有模组');
      await LogUtil.log('所有模组文件处理完成', level: 'INFO');
    } catch (e) {
      await LogUtil.log('下载模组失败: $e', level: 'ERROR');
      await _showNotification('模组下载失败', '无法完成模组下载: $e');
      throw Exception('下载模组失败: $e');
    }
  }

  // 获取游戏Json
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
              setState(() {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('下载版本Json失败: $e')),
                );
              });
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


  // 游戏Json解析
  Future<void> _parseGameJson(String jsonFilePath) async {
    try {
      final file = File(jsonFilePath);
      if (!file.existsSync()) {
        throw Exception('JSON文件不存在: $jsonFilePath');
      }
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      // 提取assetIndex URL和ID
      if (jsonData['assetIndex'] != null) {
        // 解析 URL
        if (jsonData['assetIndex']['url'] != null) {
          assetIndexURL = replaceWithMirror(jsonData['assetIndex']['url']);
        }
        // 解析 ID
        if (jsonData['assetIndex']['id'] != null) {
          assetIndexId = jsonData['assetIndex']['id'];
        }
      }
      // 提取client URL
      if (jsonData['downloads'] != null &&
          jsonData['downloads']['client'] != null &&
          jsonData['downloads']['client']['url'] != null) {
        clientURL = replaceWithMirror(jsonData['downloads']['client']['url']);
      }
      // 提取libraries的path和URL
      if (jsonData['libraries'] != null && jsonData['libraries'] is List) {
        for (var lib in jsonData['libraries']) {
          if (lib['downloads'] != null &&
              lib['downloads']['artifact'] != null) {
            final artifact = lib['downloads']['artifact'];
            if (artifact['path'] != null) {
              librariesPath.add(artifact['path']);
            }
            if (artifact['url'] != null) {
              // 替换URL为BMCLAPI镜像
              librariesURL.add(replaceWithMirror(artifact['url']));
            }
          }
        }
        await LogUtil.log('找到 ${librariesPath.length} 个库文件路径', level: 'INFO');
        await LogUtil.log('找到 ${librariesURL.length} 个库文件URL', level: 'INFO');
      }
      setState(() {
        _parseGameJsonStatus = true;
      });
    } catch (e) {
      await _showNotification('解析JSON失败', e.toString());
      await LogUtil.log('解析JSON失败: $e', level: 'ERROR');
    }
  }

  // 解析Assset JSON
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
      await _showNotification('库文件列表为空', '无法下载库文件');
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
      await LogUtil.log('正在重试下载 ${_failedLibraries.length} 个失败的库文件', level: 'INFO');
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
              onError: (error) async{
                completedLibraries++;
                newFailedList.add(task);
                await LogUtil.log('下载库文件失败: $error, URL: ${task['url']}', level: 'ERROR');
              }
            );
          } catch (e) {
            completedLibraries++;
            newFailedList.add(task);
            await LogUtil.log('下载库文件异常: $e, URL: ${task['url']}', level: 'ERROR');
          }
        }());
      }
      await Future.wait(batch);
      updateProgress();
      await LogUtil.log('已完成: $completedLibraries/$totalLibraries, 失败: ${newFailedList.length}');
    }
    _failedLibraries = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      await LogUtil.log('准备重试下载 ${newFailedList.length} 个失败的库文件 (第 $_currentRetryCount 次重试)');
      setState(() {
        _isRetrying = true;
      });
      await _downloadLibraries(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await LogUtil.log('已达最大并发重试次数，开始单线程无限重试 ${newFailedList.length} 个库文件', level: 'WARNING');
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
    await LogUtil.log('需要下载 $totalAssets 个资源文件，并发数: $concurrentDownloads', level: 'INFO');
    int completedAssets = 0;
    List<Map<String, String>> newFailedList = [];
    void updateProgress() {
      setState(() {
        _progress = completedAssets / totalAssets;
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
                completedAssets++;
                if (completedAssets % 20 == 0 || completedAssets == totalAssets) {
                  updateProgress();
                }
              },
              onError: (error) async {
                completedAssets++;
                newFailedList.add(task);
                if (newFailedList.length % 10 == 0) {
                  await LogUtil.log('已有 ${newFailedList.length} 个资源文件下载失败: $error, URL: ${task['url']}', level: 'ERROR');
                }
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
      await LogUtil.log('已完成: $completedAssets/$totalAssets, 失败: ${newFailedList.length}', level: 'INFO');
    }
    _failedAssets = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      await LogUtil.log('准备重试下载 ${newFailedList.length} 个失败的资源文件 (第 $_currentRetryCount 次重试)', level: 'INFO');
      setState(() {
        _isRetrying = true;
      });
      await _downloadAssets(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await LogUtil.log('已达最大并发重试次数，开始单线程重试 ${newFailedList.length} 个资源文件', level: 'WARNING');
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
      await _showNotification('版本JSON文件不存在', jsonFilePath);
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
      await _showNotification('JSON 解析失败', e.toString());
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
      await _showNotification('JSON中没有libraries字段或格式错误', jsonFilePath);
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
        _extractedLwjglNativesPath = true;
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
        // 调用extractNatives函数提取本地库
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

  // Fabric Json
  Future<void> _saveFabricJson(String versionPath) async {
    LogUtil.log('加载$_minecraftVersion版本列表', level: 'INFO');
    await _loadAppVersion();
    try {
      final options = Options(
        headers: {
          'User-Agent': 'FML/$_appVersion',
        },
      );
      // FML UA请求BMCLAPI Fabric
      final response = await dio.get(
        'https://bmclapi2.bangbang93.com/fabric-meta/v2/versions/loader/$_minecraftVersion',
        options: options,
      );
      if (response.statusCode == 200) {
        _fabricFullJson = response.data;
        LogUtil.log('获取到 ${_fabricFullJson.length} 个Fabric版本记录', level: 'INFO');
      }
    } catch (e) {
      LogUtil.log('请求出错: $e', level: 'ERROR');
    }
    for (var loader in _fabricFullJson) {
      if (loader['loader'] != null &&
          loader['loader']['version'] == _fabricVersion) {
        _fabricJson = loader;
        break;
      }
    }
    LogUtil.log('找到Fabric版本 $_fabricVersion 的Json: ${jsonEncode(_fabricJson)}', level: 'INFO');
    try {
      final String jsonString = jsonEncode(_fabricJson);
      final String dirPath = versionPath;
      final String filePath = '$dirPath${Platform.pathSeparator}fabric.json';
      final Directory directory = Directory(dirPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        await LogUtil.log('已创建目录: $dirPath', level: 'INFO');
      }
      final File file = File(filePath);
      await file.writeAsString(jsonString);
      await LogUtil.log('已成功将fabricLoader保存到: $filePath');
      setState(() {
        _saveFabricJsonStatus = true;
      });
    } catch (e) {
      await _showNotification('保存JSON时出错', e.toString());
      await LogUtil.log('保存JSON时出错: $e', level: 'ERROR');
    }
  }

  // 单线程重新尝试
  Future<void> _singleThreadRetryDownload(List<Map<String, String>> failedList, String fileType,
      Function(double) updateProgressCallback) async {
    int total = failedList.length;
    int completed = 0;
    List<Map<String, String>> currentFailedList = List.from(failedList);
    while (currentFailedList.isNotEmpty) {
      List<Map<String, String>> nextRetryList = [];
      for (var task in currentFailedList) {
        bool success = false;
        int retryCount = 0;
        while (!success) {
          try {
            retryCount++;
            LogUtil.log('正在尝试下载$fileType: ${task['url']} (第 $retryCount 次尝试)', level: 'INFO');
            bool downloadComplete = false;
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () async{
                downloadComplete = true;
                await LogUtil.log('$fileType下载成功: ${task['url']}', level: 'INFO');
              },
              onError: (error) async{
                await LogUtil.log('$fileType下载失败: $error, URL: ${task['url']}', level: 'ERROR');
              }
            );
            if (downloadComplete) {
              success = true;
              completed++;
              updateProgressCallback(completed / total);
              await LogUtil.log('已完成: $completed/$total $fileType', level: 'INFO');
            } else {
              // 短暂延迟后再重试
              await Future.delayed(Duration(milliseconds: 500));
            }
          } catch (e) {
            await LogUtil.log('$fileType下载异常: $e, URL: ${task['url']}', level: 'ERROR');
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }
      currentFailedList = nextRetryList;
    }
    await LogUtil.log('所有$fileType已成功下载', level: 'INFO');
  }

  // 文件下载
  Future<void> _downloadFile(path, url) async {
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
          success = true;  // 正确设置成功标志
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
      await LogUtil.log('下载异常: $e, URL: $url', level: 'ERROR');
      throw Exception('下载出错: $e');
    }
  }

  // 下载逻辑
  Future<void> _startDownload() async {
  final prefs = await SharedPreferences.getInstance();
  final selectedGamePath = prefs.getString('SelectedPath') ?? '';
  final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
  final versionPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}';
  try{
    await LogUtil.log('正在下载整合包 ${widget.name}', level: 'INFO');
    await _showNotification('开始下载', '正在下载 ${widget.name} \n你可以将启动器置于后台,安装完成将有通知提醒');
    // 创建文件夹
    await _createGameDirectories();
    // 下载整合包信息
    try {
      await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.mrpack', widget.url);
      setState(() {
        _downloadMrpack= true;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载整合包信息失败: $e')),
        );
      });
      return;
    }
    // 解压整合包信息
    await _unzipMrpackFile(versionPath);
    // 解析整合包内容
    await _parseMrpackContent(versionPath);
    // 下载模组文件
    //await _downloadMods(versionPath);
    // 保存Minecraft Json
    await _saveMinecraftJson(versionPath);
    // 解析游戏Json
    await _parseGameJson('$versionPath${Platform.pathSeparator}${widget.name}.json');
    // 下载资产索引文件
      if (assetIndexURL != null) {
        final assetIndexDir = '$gamePath${Platform.pathSeparator}assets${Platform.pathSeparator}indexes';
        final assetIndexPath = '$assetIndexDir${Platform.pathSeparator}$assetIndexId.json';
        try {
          await _downloadFile('$gamePath${Platform.pathSeparator}assets${Platform.pathSeparator}indexes${Platform.pathSeparator}$assetIndexId.json', assetIndexURL!);
          setState(() {
            _downloadAssetJson = true;
          });
        } catch (e) {
          setState(() {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载资产索引失败: $e')),
            );
          });
          return;
        }
        // 解析资产索引文件
        await _parseAssetIndex(assetIndexPath);
        // 下载客户端
        try {
          await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.jar', clientURL);
          setState(() {
            _downloadClient = true;
          });
        } catch (e) {
          setState(() {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载客户端失败: $e')),
            );
          });
          return;
        }
              // 下载库文件
        await _downloadLibraries(concurrentDownloads: 30);
        // 下载资源文件
        await _downloadAssets(concurrentDownloads: 30);
        // 提取LWJGL本地库路径
        await extractLwjglNativeLibrariesPath('$versionPath${Platform.pathSeparator}${widget.name}.json',gamePath);
        // 提取LWJGL Natives
        await _extractLwjglNatives();
        // 下载 Fabric
      }
  } catch (e) {
    setState(() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    });
  }
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
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
              title: const Text('正在下载整合包信息'),
              subtitle: Text(_downloadMrpack ? '下载完成' : '下载中...'),
              trailing: _downloadMrpack
                ? const Icon(Icons.check)
                : const CircularProgressIndicator(),
            ),
          ),
          if (_downloadMrpack) ...[
            Card(
              child: ListTile(
                title: const Text('正在解压整合包信息'),
                subtitle: Text(_unzipMrpack ? '解压完成' : '解压中...'),
                trailing: _unzipMrpack
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],if (_unzipMrpack) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析整合包信息'),
                subtitle: Text(_parseMrpack ? '解析完成' : '解析中...'),
                trailing: _parseMrpack
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],if (_unzipMrpack) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析整合包信息'),
                subtitle: Text(_parseMrpack ? '解析完成' : '解析中...'),
                trailing: _parseMrpack
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],if (_parseMrpack) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载模组文件'),
                    subtitle: Text(_downloadModsStatus ? '下载完成' : '下载中... 已下载${(_progress * 100).toStringAsFixed(2)}%'),
                    trailing: _downloadModsStatus
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator()
                  ),
                  if (!_downloadModsStatus)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              )
            ),
          ],if (_downloadModsStatus) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在获取游戏Json'),
                    subtitle: Text(_downloadMinecraftJson ? '获取完成' : '获取中...'),
                    trailing: _downloadMinecraftJson
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator()
                  ),
                ],
              )
            ),
          ],if (_downloadMinecraftJson) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在获取资源Json'),
                    subtitle: Text(_downloadAssetJson ? '获取完成' : '获取中...'),
                    trailing: _downloadAssetJson
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator()
                  ),
                ],
              )
            ),
          ],if (_downloadAssetJson) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在解析资源Json'),
                    subtitle: Text(_parseAssetJson ? '解析完成' : '解析中...'),
                    trailing: _parseAssetJson
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator()
                  ),
                ],
              )
            ),
          ],if (_parseAssetJson) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载客户端'),
                    subtitle: Text(_downloadClient ? '下载完成' : '下载中... 已下载${(_progress * 100).toStringAsFixed(2)}%'),
                    trailing: _downloadClient
                      ? const Icon(Icons.check)
                      : const CircularProgressIndicator()
                  ),
                  if (!_downloadClient)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                ],
              )
            ),
          ],if (_downloadClient) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载游戏库'),
                    subtitle: Text(_downloadLibrary ? '下载完成' : '下载中... 已下载${(_progress * 100).toStringAsFixed(2)}%'),
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
            )
          ],if (_downloadLibrary) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载游戏资源'),
                    subtitle: Text(_downloadAsset ? '下载完成' : '下载中... 已下载${(_progress * 100).toStringAsFixed(2)}%'),
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
            )
          ],if (_downloadAsset) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取LWJGL路径'),
                subtitle: Text(_extractedLwjglNativesPath ? '提取完成' : '提取中...'),
                trailing: _extractedLwjglNativesPath
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )],if (_extractedLwjglNativesPath) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取LWJGL'),
                subtitle: Text(_extractedLwjglNatives ? '提取完成' : '提取中...'),
                trailing: _extractedLwjglNatives
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
          ],
        ],
      )
    );
  }
}