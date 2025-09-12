import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/download/download.dart';

class ModPage extends StatefulWidget {
  const ModPage({required this.projectId, this.projectName, super.key});

  final String projectId;
  final String? projectName;

  @override
  ModPageState createState() => ModPageState();
}

class ModPageState extends State<ModPage> {
  final Dio dio = Dio();
  bool isLoading = true;
  String? error;
  List<dynamic> versionsList = [];
  List<dynamic> filteredVersionsList = [];
  Map<String, dynamic>? selectedVersion;
  Set<String> availableLoaders = {};
  String? selectedLoader;
  Set<String> availableGameVersions = {};
  String? selectedGameVersion;
  String savePath = '';

  @override
  void initState() {
    super.initState();
    LogUtil.log('加载模组ID: ${widget.projectId}', level: 'INFO');
    _fetchVersions();
  }

  // 从API获取版本信息
  Future<void> _fetchVersions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await dio.get(
        'https://api.modrinth.com/v2/project/${widget.projectId}/version',
      );

      if (response.statusCode == 200) {
        final versions = response.data as List;
        Set<String> loaders = {};
        Set<String> gameVersions = {};
        for (var version in versions) {
          final versionLoaders = version['loaders'] as List?;
          if (versionLoaders != null) {
            for (var loader in versionLoaders) {
              loaders.add(loader.toString());
            }
          }
          final versionGameVersions = version['game_versions'] as List?;
          if (versionGameVersions != null) {
            for (var gameVersion in versionGameVersions) {
              gameVersions.add(gameVersion.toString());
            }
          }
        }
        setState(() {
          versionsList = versions;
          filteredVersionsList = List.from(versions);
          availableLoaders = loaders;
          availableGameVersions = gameVersions;
          isLoading = false;
          if (filteredVersionsList.isNotEmpty) {
            selectedVersion = filteredVersionsList[0];
            LogUtil.log('获取到${versions.length}个版本，默认选择: ${selectedVersion!['version_number']}', level: 'INFO');
          }
          LogUtil.log('支持的加载器: ${availableLoaders.join(", ")}', level: 'INFO');
          LogUtil.log('支持的游戏版本: ${availableGameVersions.join(", ")}', level: 'INFO');
        });
      } else {
        setState(() {
          error = '获取版本信息失败: ${response.statusCode}';
          isLoading = false;
        });
        LogUtil.log(error!, level: 'ERROR');
      }
    } catch (e) {
      setState(() {
        error = '获取版本信息出错: $e';
        isLoading = false;
      });
      LogUtil.log(error!, level: 'ERROR');
    }
  }

  Future<void> _applyFilters() async {
    setState(() {
      filteredVersionsList = List.from(versionsList);
      if (selectedLoader != null) {
        filteredVersionsList = filteredVersionsList.where((version) {
          final loaders = version['loaders'] as List?;
          return loaders != null && loaders.contains(selectedLoader);
        }).toList();
      }
      if (selectedGameVersion != null) {
        filteredVersionsList = filteredVersionsList.where((version) {
          final gameVersions = version['game_versions'] as List?;
          return gameVersions != null && gameVersions.contains(selectedGameVersion);
        }).toList();
      }
      if (filteredVersionsList.isNotEmpty) {
        selectedVersion = filteredVersionsList[0];
      } else {
        selectedVersion = null;
      }
      LogUtil.log('应用筛选 - 加载器: $selectedLoader, 游戏版本: $selectedGameVersion, 结果数量: ${filteredVersionsList.length}', level: 'INFO');
    });
  }

  // 更新加载器筛选
  Future<void> _updateLoaderFilter(String? loader) async {
    setState(() {
      selectedLoader = loader;
      _applyFilters();
    });
  }

  // 更新游戏版本筛选
  Future<void> _updateGameVersionFilter(String? gameVersion) async {
    setState(() {
      selectedGameVersion = gameVersion;
      _applyFilters();
    });
  }

  // 清除所有筛选条件
  Future<void> _clearFilters() async {
    setState(() {
      selectedLoader = null;
      selectedGameVersion = null;
      filteredVersionsList = List.from(versionsList);
    });
  }

  // 下载
  Future<void> _downloadVersion(Map<String, dynamic> version) async {
    final files = version['files'] as List?;
    if (files == null || files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有找到可下载的文件')),
      );
      return;
    }

    // 获取主文件
    final primaryFile = files.firstWhere(
      (file) => file['primary'] == true,
      orElse: () => files.first
    );
    final downloadUrl = primaryFile['url'];
    final fileName = primaryFile['filename'] ?? 'unknown.jar';
    final fileSize = primaryFile['size'] ?? 0;

    // 显示下载选项对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择下载方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: $fileName'),
            const SizedBox(height: 8),
            Text('大小: ${_formatFileSize(fileSize)}'),
            const SizedBox(height: 8),
            Text('版本: ${version['version_number'] ?? "未知"}'),
            const SizedBox(height: 8),
            Text('游戏版本: ${(version['game_versions'] as List?)?.join(", ") ?? "未知"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadToCurrentVersion(downloadUrl, fileName);
            },
            child: const Text('下载到当前版本'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadToCustomDirectory(downloadUrl, fileName);
            },
            child: const Text('指定目录'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // 下载到当前版本目录
  Future<void> _downloadToCurrentVersion(String url, String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('Path_${prefs.getString('SelectedPath')}');
      final game = prefs.getString('SelectedGame');
      if (game == null || path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择版本')),
        );
        return;
      }
      savePath = '$path${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}mods${Platform.pathSeparator}$fileName';
      if (!await Directory('$path${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}mods').exists()) {
        await Directory('$path${Platform.pathSeparator}versions${Platform.pathSeparator}$game${Platform.pathSeparator}mods').create(recursive: true);
      }
      _showDownloadProgressDialog(url, savePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置下载路径失败: $e')),
      );
    }
  }

  // 下载到自定义目录
  Future<void> _downloadToCustomDirectory(String url, String fileName) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        return;
      }
      final savePath = path.join(selectedDirectory, fileName);
      _showDownloadProgressDialog(url, savePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择下载路径失败: $e')),
      );
    }
  }

  // 显示下载进度对话框
  Future<void> _showDownloadProgressDialog(String url, String savePath) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
    final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier(true);
    final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
    CancelToken? cancelToken;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('正在下载'),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: isDownloadingNotifier,
              builder: (context, isDownloading, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: errorMessageNotifier,
                  builder: (context, errorMessage, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (errorMessage != null)
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (isDownloading)
                          Column(
                            children: [
                              LinearProgressIndicator(value: progress),
                              const SizedBox(height: 8),
                              Text('${(progress * 100).toStringAsFixed(1)}%'),
                              const SizedBox(height: 8),
                              Text('保存到: $savePath', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        if (!isDownloading && errorMessage == null)
                          const Text('下载完成！'),
                      ],
                    );
                  }
                );
              }
            );
          }
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: isDownloadingNotifier,
            builder: (context, isDownloading, _) {
              return isDownloading
                ? TextButton(
                    onPressed: () {
                      cancelToken?.cancel();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('取消'),
                  )
                : TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('关闭'),
                  );
            }
          ),
        ],
      ),
    );
    // 开始下载
    try {
      cancelToken = await DownloadUtils.downloadFile(
        url: url,
        savePath: savePath,
        onProgress: (currentProgress) {
          progressNotifier.value = currentProgress;
        },
        onSuccess: () {
          isDownloadingNotifier.value = false;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载成功: ${path.basename(savePath)}')),
            );
            LogUtil.log('下载完成: $savePath', level: 'INFO');
          }
        },
        onError: (error) {
          errorMessageNotifier.value = '下载失败: $error';
          isDownloadingNotifier.value = false;
          if (context.mounted) {
            LogUtil.log('下载失败: $error', level: 'ERROR');
          }
        },
        onCancel: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('下载已取消')),
            );
            LogUtil.log('下载已取消', level: 'INFO');
          }
        },
      );
    } catch (e) {
      errorMessageNotifier.value = '启动下载失败: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动下载失败: $e')),
        );
        LogUtil.log('启动下载失败: $e', level: 'ERROR');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName ?? '模组下载'),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchVersions,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : versionsList.isEmpty
            ? const Center(child: Text('没有可用版本'))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择版本',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (availableLoaders.isNotEmpty)
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: selectedLoader,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('选择加载器'),
                                ),
                                ...availableLoaders.map((loader) =>
                                  DropdownMenuItem<String?>(
                                    value: loader,
                                    child: Text(loader),
                                  )
                                ),
                              ],
                              onChanged: _updateLoaderFilter,
                            ),
                          ),
                        const SizedBox(width: 12),
                        if (availableGameVersions.isNotEmpty)
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: selectedGameVersion,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('选择版本'),
                                ),
                                ...availableGameVersions.map((version) =>
                                  DropdownMenuItem<String?>(
                                    value: version,
                                    child: Text(version),
                                  )
                                ),
                              ],
                              onChanged: _updateGameVersionFilter,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedLoader != null || selectedGameVersion != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '已筛选 ${filteredVersionsList.length} 个结果',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('清除筛选'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (filteredVersionsList.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('没有找到符合条件的版本'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _clearFilters,
                                child: const Text('清除所有筛选'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredVersionsList.length,
                          itemBuilder: (context, index) {
                            final version = filteredVersionsList[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                title: Text(version['version_number'] ?? '未知版本'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('发布日期: ${version['date_published'] ?? "未知日期"}'),
                                    Text(
                                      '加载器: ${(version['loaders'] as List?)?.join(", ") ?? "未知"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '游戏版本: ${(version['game_versions'] as List?)?.join(", ") ?? "未知"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                onTap: () => _downloadVersion(version),
                                trailing: const Icon(Icons.download),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}