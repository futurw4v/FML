import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:fml/function/log.dart';
import 'package:fml/pages/download/modrinth/type/download_modpack/donwnload_info.dart';

class ModpackPage extends StatefulWidget {
  const ModpackPage({required this.projectId, this.projectName, super.key});

  final String projectId;
  final String? projectName;

  @override
  ModpackPageState createState() => ModpackPageState();
}

class ModpackPageState extends State<ModpackPage> {
  final Dio dio = Dio();
  bool isLoading = true;
  String? error;
  List<dynamic> versionsList = [];
  List<dynamic> filteredVersionsList = [];
  Map<String, dynamic>? selectedVersion;
  Set<String> availableLoaders = {'neoforge', 'fabric'};
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
        final allVersions = response.data as List;
        final versions = allVersions.where((version) {
          final versionLoaders = version['loaders'] as List?;
          if (versionLoaders == null) return false;
          return versionLoaders.contains('neoforge') || versionLoaders.contains('fabric');
        }).toList();
        Set<String> gameVersions = {};
        for (var version in versions) {
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
          availableGameVersions = gameVersions;
          isLoading = false;
          if (filteredVersionsList.isNotEmpty) {
            selectedVersion = filteredVersionsList[0];
            LogUtil.log('获取到${versions.length}个版本，默认选择: ${selectedVersion!['version_number']}', level: 'INFO');
          }
          LogUtil.log('支持的加载器: neoforge, fabric', level: 'INFO');
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

  // 应用当前的筛选条件
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
            ? const Center(child: Text('没有可用的 NeoForge 或 Fabric 版本'))
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
                        Expanded(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedLoader,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('全部加载器'),
                              ),
                              const DropdownMenuItem<String?>(
                                value: 'neoforge',
                                child: Text('NeoForge'),
                              ),
                              const DropdownMenuItem<String?>(
                                value: 'fabric',
                                child: Text('Fabric'),
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
                              style: const TextStyle(fontSize: 14),
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
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DownloadInfo(version),
                                    ),
                                  );
                                },
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