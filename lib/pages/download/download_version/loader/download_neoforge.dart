import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:system_info2/system_info2.dart';
import 'package:archive/archive.dart';

import 'package:fml/function/download.dart';
import 'package:fml/function/extract_natives.dart';
import 'package:fml/function/log.dart';

class DownloadNeoForgePage extends StatefulWidget {
  const DownloadNeoForgePage({super.key, required this.version, required this.url, required this.name, required this.neoforgeVersion});

  final String version;
  final String url;
  final String name;
  final String neoforgeVersion;

  @override
  DownloadNeoForgePageState createState() => DownloadNeoForgePageState();
}

class DownloadNeoForgePageState extends State<DownloadNeoForgePage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  double _progress = 0.0;
  bool _downloadJson = false;
  bool _parseGameJson = false;
  bool _parseAssetJson = false;
  bool _downloadAssetJson = false;
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
  bool _writeConfig = false;

  int _mem = 1;
  String _name = '';

  String? assetIndexURL;
  String? clientURL;
  String? assetIndexId;
  List<String> librariesPath = [];
  List<String> librariesURL = [];
  List<String> lwjglNativeNames = [];
  List<String> lwjglNativePaths = [];
  List<String> neoForgeLibrariesPath = [];
  List<String> neoForgeLibrariesURL = [];
  final List<String> _assetHash = [];
  List<Map<String, String>> _failedLibraries = [];
  List<Map<String, String>> _failedAssets = [];
  bool _isRetrying = false;
  final int _maxRetries = 3;  // 最大重试次数
  int _currentRetryCount = 0;
  String _installerJson = '';

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

  // 游戏Json解析
  Future<void> parseGameJson(String jsonFilePath) async {
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
        _parseGameJson = true;
      });
    } catch (e) {
      await _showNotification('解析JSON失败', e.toString());
      await LogUtil.log('解析JSON失败: $e', level: 'ERROR');
      setState(() {
        _parseGameJson = false;
      });
    }
  }

  // 解析Assset JSON
  Future<void> parseAssetIndex(String assetIndexPath) async {
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
      await LogUtil.log('解析资产索引失败: $e', level: 'ERROR');
      setState(() {
        _parseAssetJson = false;
      });
    }
  }

  // 下载库
  Future<void> _downloadLibraries({int concurrentDownloads = 20}) async {
    if (librariesURL.isEmpty || librariesPath.isEmpty) {
      await _showNotification('下载失败', '库文件列表为空');
      await LogUtil.log('库文件列表为空', level: 'ERROR');
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
      await LogUtil.log('所有库文件已存在,无需下载', level: 'INFO');
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
    await LogUtil.log('开始下载 $totalLibraries 个库文件,并发数: $concurrentDownloads', level: 'INFO');
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
      await LogUtil.log('已完成: $completedLibraries/$totalLibraries, 失败: ${newFailedList.length}', level: 'INFO');
    }
    _failedLibraries = newFailedList;
    if (newFailedList.isNotEmpty && _currentRetryCount < _maxRetries) {
      _currentRetryCount++;
      await LogUtil.log('准备重试下载 ${newFailedList.length} 个失败的库文件 (第 $_currentRetryCount 次重试)', level: 'INFO');
      setState(() {
        _isRetrying = true;
      });
      await _downloadLibraries(concurrentDownloads: concurrentDownloads);
    } else if (newFailedList.isNotEmpty) {
      await LogUtil.log('已达最大并发重试次数,开始单线程重试 ${newFailedList.length} 个库文件', level: 'WARNING');
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
      await LogUtil.log('所有资源文件已存在,无需下载', level: 'INFO');
      setState(() {
        _downloadAsset = true;
      });
      return;
    }
    await LogUtil.log('需要下载 $totalAssets 个资源文件,并发数: $concurrentDownloads', level: 'INFO');
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
                  await LogUtil.log('已有 ${newFailedList.length} 个资源文件下载失败', level: 'WARNING');
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
      await LogUtil.log('已达最大并发重试次数,开始单线程重试 ${newFailedList.length} 个资源文件', level: 'WARNING');
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
  Future<void> _extractLwjglNativeLibrariesPath(String jsonFilePath, String gamePath) async {
    final namesList = <String>[];
    final pathsList = <String>[];
    final file = File(jsonFilePath);
    if (!await file.exists()) {
      await LogUtil.log('版本JSON文件不存在: $jsonFilePath', level: 'ERROR');
      await _showNotification('下载错误', '版本JSON文件不存在: $jsonFilePath');
      setState(() {
        lwjglNativeNames = namesList;
        lwjglNativePaths = pathsList;
      });
      return;
    }
    late final dynamic root;
    try {
      root = jsonDecode(await file.readAsString());
    } catch (e) {
      await LogUtil.log('JSON 解析失败: $e', level: 'ERROR');
      await _showNotification('下载错误', 'JSON 解析失败: $e');
      setState(() {
        lwjglNativeNames = namesList;
        lwjglNativePaths = pathsList;
      });
      return;
    }
    final libs = root is Map ? root['libraries'] : null;
    if (libs is! List) {
      await LogUtil.log('JSON中没有libraries字段或格式错误', level: 'WARNING');
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
      await LogUtil.log('没有找到LWJGL本地库,跳过提取', level: 'WARNING');
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
        // 调用extractNatives函数提取本地库
        final extracted = await extractNatives(jarDir, fileName, nativesDir);
        if (extracted.isNotEmpty) {
          successCount++;
          extractedFiles.addAll(extracted);
          await LogUtil.log('成功从 $fileName 提取了 ${extracted.length} 个文件', level: 'INFO');
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

  // 提取NeoForge
  Future<void> _extractNeoForgeInstaller() async {
    try {
      // 读取JAR文件
      final prefs = await SharedPreferences.getInstance();
      final selectedGamePath = prefs.getString('SelectedPath') ?? '';
      final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
      final neoForgePath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}${Platform.pathSeparator}neoforge-installer.jar';
      final bytes = await File(neoForgePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      // 提取install_profile.json文件
      for (final file in archive) {
        if (file.name == 'install_profile.json') {
          final content = file.content as List<int>;
          _installerJson = utf8.decode(content);
          // 保存到文件
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
    final neoForgeJson = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}neoforge-${widget.neoforgeVersion}${Platform.pathSeparator}neoforge-${widget.neoforgeVersion}.json';
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
      // 确保源文件存在
      if (!await sourceFile.exists()) {
        throw Exception('源文件不存在: $sourcePath');
      }
      final destinationDir = Directory(destinationPath.substring(0, destinationPath.lastIndexOf(Platform.pathSeparator)));
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }
      // 移动文件
      await sourceFile.rename(destinationPath);
      await LogUtil.log('文件已成功移动到: $destinationPath', level: 'INFO');
    } catch (e) {
      await LogUtil.log('移动文件时发生错误: $e', level: 'ERROR');
      await _showNotification('移动文件时发生错误', e.toString());
    }
  }

  // 单线程重试下载
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
            await LogUtil.log('正在尝试下载$fileType: ${task['url']} (第 $retryCount 次尝试)', level: 'INFO');
            bool downloadComplete = false;
            await DownloadUtils.downloadFile(
              url: task['url']!,
              savePath: task['path']!,
              onProgress: (_) {},
              onSuccess: () async {
                downloadComplete = true;
                await LogUtil.log('$fileType下载成功: ${task['url']}', level: 'INFO');
              },
              onError: (error) async {
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
      await LogUtil.log('下载异常: $e, URL: $url', level: 'ERROR');
      throw Exception('下载出错: $e');
    }
  }

  // 获取系统内存
  void _getMemory(){
    int bytes = SysInfo.getTotalPhysicalMemory();
    // 内存错误修正
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
    // 默认配置
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
    await LogUtil.log('已将 ${widget.name} 添加到游戏列表,当前列表: $gameList', level: 'INFO');
    setState(() {
      _writeConfig = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _getMemory();
    _startDownload();
  }

  // 下载逻辑
  Future<void> _startDownload() async {
    LogUtil.log('开始下载: ${widget.name} NeoForge', level: 'INFO');
    final prefs = await SharedPreferences.getInstance();
    final selectedGamePath = prefs.getString('SelectedPath') ?? '';
    final gamePath = prefs.getString('Path_$selectedGamePath') ?? '';
    final versionPath = '$gamePath${Platform.pathSeparator}versions${Platform.pathSeparator}${widget.name}';
    final gameJsonURL = replaceWithMirror(widget.url);
    final neoForgeURL = 'https://bmclapi2.bangbang93.com/maven/net/neoforged/neoforge/${widget.neoforgeVersion}/neoforge-${widget.neoforgeVersion}-installer.jar';
    try {
      await LogUtil.log('开始下载 ${widget.name} 版本', level: 'INFO');
      await _showNotification('开始下载', '正在下载 ${widget.name} 版本\n你可以将启动器置于后台,安装完成将有通知提醒');
      // 创建文件夹
      await _createGameDirectories();
      // 下载版本json
      try {
        await _downloadFile('$versionPath${Platform.pathSeparator}${widget.name}.json', gameJsonURL);
        setState(() {
          _downloadJson = true;
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
      // 解析游戏Json
      await parseGameJson('$versionPath${Platform.pathSeparator}${widget.name}.json');
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
        // 解析资源索引
        await parseAssetIndex(assetIndexPath);
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
        // 下载资源
        await _downloadAssets(concurrentDownloads: 30);
        // 提取LWJGL本地库路径
        await _extractLwjglNativeLibrariesPath('$versionPath${Platform.pathSeparator}${widget.name}.json', gamePath);
        // 提取LWJGL Natives
        await _extractLwjglNatives();
        // 下载NeoForge安装器
        LogUtil.log('开始下载: $versionPath,$neoForgeURL', level: 'INFO');
        try {
          await _downloadFile('$versionPath${Platform.pathSeparator}neoforge-installer.jar',neoForgeURL);
          setState(() {
            _downloadNeoForge = true;
          });
        } catch (e) {
          setState(() {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载NeoForge失败: $e')),
            );
          });
          return;
        }
        // 提取NeoForge安装器
        await _extractNeoForgeInstaller();
        // 解析NeoForge安装器JSON
        await _parseNeoForgeInstallerJson();
        // 下载NeoForge库文件
        await _downloadNeoForgeLibraries();
        // 执行NeoForge安装器
        await _executeNeoForgeInstaller();
        // 写入游戏配置文件
        await _writeGameConfig();
        // 完成通知
        await _showNotification('完成下载', '点击查看详细');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('正在下载${widget.version} + NeoForge ${widget.neoforgeVersion}'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('正在下载游戏Json'),
              subtitle: Text(_downloadJson ? '下载完成' : '下载中...'),
              trailing: _downloadJson
                ? const Icon(Icons.check)
                : const CircularProgressIndicator(),
            ),
          ),if (_downloadJson) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析游戏Json'),
                subtitle: Text(_parseGameJson ? '解析完成' : '解析中...'),
                trailing: _parseGameJson
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),if (_parseAssetJson) ...[
              Card(
                child: ListTile(
                  title: const Text('正在下载资源Json'),
                  subtitle: Text(_downloadAssetJson ? '下载完成' : '下载中...'),
                  trailing: _downloadAssetJson
                    ? const Icon(Icons.check)
                    : const CircularProgressIndicator(),
                ),
              ),
            ]
          ],if (_downloadAssetJson) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析资源Json'),
                subtitle: Text(_parseAssetJson ? '解析完成' : '解析中...'),
                trailing: _parseAssetJson
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
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
          ],
          if (_downloadClient) ...[
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
            )
          ],if (_extractedLwjglNativesPath) ...[
            Card(
              child: ListTile(
                title: const Text('正在提取LWJGL'),
                subtitle: Text(_extractedLwjglNatives ? '提取完成' : '提取中...'),
                trailing: _extractedLwjglNatives
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )],if (_extractedLwjglNatives) ...[
            Card(
              child: ListTile(
                title: const Text('正在下载NeoForge'),
                subtitle: Text(_downloadNeoForge ? '下载完成' : '下载中...'),
                trailing: _downloadNeoForge
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
          ],if (_downloadNeoForge) ...[
            Card(
              child: ListTile(
                title: const Text('正在解压NeoForge安装列表'),
                subtitle: Text(_extractNeoForgeInstallerStatus ? '解压完成' : '解压中...'),
                trailing: _extractNeoForgeInstallerStatus
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
          ],if (_extractNeoForgeInstallerStatus) ...[
            Card(
              child: ListTile(
                title: const Text('正在解析NeoForge Json'),
                subtitle: Text(_parseNeoForgeInstallerJsonStatus ? '解析完成' : '解析中...'),
                trailing: _parseNeoForgeInstallerJsonStatus
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
          ],if (_parseNeoForgeInstallerJsonStatus) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('正在下载NeoForge库文件'),
                    subtitle: Text(_downloadNeoForgeLibrary ? '下载完成' : '下载中... 已下载${(_progress * 100).toStringAsFixed(2)}%'),
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
            )
          ],if (_downloadNeoForgeLibrary) ...[
            Card(
              child: ListTile(
                title: const Text('正在安装NeoForge'),
                subtitle: Text(_neoForgeInstalled ? '安装完成' : '安装中...'),
                trailing: _neoForgeInstalled
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
          ],if (_neoForgeInstalled) ...[
            Card(
              child: ListTile(
                title: const Text('正在写入配置文件'),
                subtitle: Text(_neoForgeInstalled ? '写入完成' : '写入中...'),
                trailing: _neoForgeInstalled
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            )
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