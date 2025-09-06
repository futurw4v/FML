import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fml/pages/download/download_game.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fml/function/log.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  DownloadPageState createState() => DownloadPageState();
}

class DownloadPageState extends State<DownloadPage> {
  final Dio dio = Dio();
  List<dynamic> _versionList = [];
  bool _isLoading = true;
  String? _error;
  String _appVersion = "unknown";
  bool _showSnapshots = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString('version') ?? "1.0.0";
    setState(() {
      _appVersion = version;
    });
    fetchVersionManifest();
  }

  Future<void> fetchVersionManifest() async {
    try {
      final options = Options(
        headers: {
          'User-Agent': 'FML/$_appVersion',
        },
      );

      // FML UA请求BMCLAPI
      final response = await dio.get(
        'https://bmclapi2.bangbang93.com/mc/game/version_manifest.json',
        options: options,
      );
      if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map && data['versions'] is List) {
        setState(() {
          _versionList = data['versions'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '返回数据格式异常,请刷新重试';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _error = '请求失败：状态码 ${response.statusCode}';
        _isLoading = false;
      });
    }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '请求出错: $e';
        _isLoading = false;
      });
    }
  }

  // 打开URL
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return; // 添加 mounted 检查
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    } catch (e) {
      if (!mounted) return; // 添加 mounted 检查
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    }
  }

  // 检查选择目录
  Future<void> _checkSelectedPath(id, url, type) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDir = prefs.getString('SelectedPath');
    if (!mounted) return;
    if (selectedDir == null || selectedDir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择下载目录')),
      );
    } else {
      LogUtil.log('选择了版本: $id - URL: $url', level: 'INFO');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DownloadGamePage(type: type, version: id, url: url),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              fetchVersionManifest();
            },
          )
        ],
      ),
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
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      fetchVersionManifest();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                Card(
                  child: ListTile(
                    title: const Text('下载由 BMCLAPI 提供'),
                    subtitle: const Text('赞助 BMCLAPI 喵~ 赞助 BMCLAPI 谢谢喵~ '),
                    leading: const Icon(Icons.info),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchURL('https://bmclapi.bangbang93.com/'),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    title: const Text('显示快照版本'),
                    value: _showSnapshots,
                    onChanged: (value) {
                      setState(() {
                        _showSnapshots = value;
                      });
                    },
                  ),
                ),
                ..._versionList
                    .where((version) => _showSnapshots || version['type'] != 'snapshot')
                    .map(
                      (version) => Card(
                        child: ListTile(
                          title: Text(version['id']),
                          subtitle: Text('类型: ${version['type']} - 发布时间: ${_formatDate(version['releaseTime'])}'),
                          leading: Icon(
                        version['type'] == 'release' ? Icons.check_circle : Icons.science,
                      ),
                      onTap: () {
                        _checkSelectedPath(version['id'], version['url'], version['type']);
                      },
                    ),
                  ),
                )
              ],
            ),
    );
  }
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }
}