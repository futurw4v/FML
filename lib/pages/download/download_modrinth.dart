import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fml/function/log.dart';
import 'package:fml/pages/download/modrinth/info.dart';

class DownloadModrinth extends StatefulWidget {
  const DownloadModrinth({super.key});

  @override
  DownloadModrinthState createState() => DownloadModrinthState();
}

class DownloadModrinthState extends State<DownloadModrinth> {
  final Dio dio = Dio();
  List<dynamic> _projectsList = [];
  bool _isLoading = true;
  String? _error;
  String _appVersion = '';
  String _randomCount = '20';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  // 读取App版本
  Future<void> _loadAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString('version') ?? "UnknownVersion";
    setState(() {
      _appVersion = version;
    });
    _fetchProjects();
  }

  // 获取随机项目
  Future<void> _fetchProjects() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final options = Options(
        headers: {
          'User-Agent': 'lxdklp/FML/$_appVersion (fml.lxdklp.top)',
        },
      );
      LogUtil.log('开始请求Modrinth随机项目', level: 'INFO');
      final response = await dio.get(
        'https://api.modrinth.com/v2/projects_random?count=$_randomCount',
        options: options,
      );
      if (response.statusCode == 200) {
        LogUtil.log('成功获取Modrinth项目', level: 'INFO');
        setState(() {
          _projectsList = response.data;
          _isLoading = false;
        });
      } else {
        LogUtil.log('请求失败：状态码 ${response.statusCode}', level: 'ERROR');
        setState(() {
          _error = '请求失败：服务器返回状态码 ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      LogUtil.log('请求出错: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _error = '网络请求失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchProjects,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchProjects,
              child: ListView.builder(
                itemCount: _projectsList.length,
                itemBuilder: (context, index) {
                  final project = _projectsList[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: project['icon_url'] != null
                        ? Image.network(
                            project['icon_url'],
                            width: 50,
                            height: 50,
                            errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.extension, size: 50),
                          )
                        : const Icon(Icons.extension, size: 50),
                      title: Text(
                        project['title'] ?? 'Unknown Title',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project['description'] ?? 'No description available',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              ...?project['categories']?.map<Widget>((category) =>
                                Chip(
                                  label: Text(category),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: const TextStyle(fontSize: 10),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InfoPage(
                            slug: project['slug'] ?? '',
                            projectInfo: project,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchProjects,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}