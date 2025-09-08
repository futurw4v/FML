import 'package:flutter/material.dart';
import 'package:fml/function/log.dart';
import 'package:fml/pages/download/modrinth/type/download_modpack/download_modpack.dart';

class DownloadInfo extends StatefulWidget {
  const DownloadInfo(
      this.version, {
        super.key
      });

  final Map<String, dynamic> version;

  @override
  DownloadInfoState createState() => DownloadInfoState();
}

class DownloadInfoState extends State<DownloadInfo> {
  String? _downloadUrl;
  String? _fileName;
  String? _gameName;
  late final TextEditingController _gameNameController;

  @override
  void initState() {
    super.initState();
    _extractFileInfo();
    _gameNameController = TextEditingController();
    _gameNameController.text = _fileName ?? '';
    _gameName = _gameNameController.text;
    LogUtil.log('开始下载模组包版本: ${widget.version['version_number']}', level: 'INFO');
  }

  // 获取信息
  void _extractFileInfo() {
    final files = widget.version['files'] as List?;
    if (files != null && files.isNotEmpty) {
      final primaryFile = files.firstWhere(
        (file) => file['primary'] == true,
        orElse: () => files.first
      );
      setState(() {
        _downloadUrl = primaryFile['url'];
        _fileName = primaryFile['filename'];
      });
      LogUtil.log('获取到下载地址: $_downloadUrl', level: 'INFO');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模组包下载'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模组包名称: $_fileName',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('版本: ${widget.version['version_number'] ?? '未知版本'}'),
                  const SizedBox(height: 8),
                  Text('发布日期: ${widget.version['date_published'] ?? '未知日期'}'),
                  const SizedBox(height: 8),
                  Text('模组加载器: ${widget.version['loaders']?.join(", ") ?? '未知加载器'}'),
                  if (widget.version['changelog'] != null &&
                      widget.version['changelog'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '更新日志:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(widget.version['changelog'].toString()),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Card(
              child: TextField(
                controller: _gameNameController,
                decoration: InputDecoration(
                  labelText: '游戏名称',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() {
                  _gameName = value;
                }),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_gameName == null || _gameName!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请输入游戏名称')),
            );
            return;
          }
          if (_downloadUrl == null || _downloadUrl!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('下载地址获取失败')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DownloadModpackPage(
                gameName: _gameName!,
                downloadUrl: _downloadUrl ?? '',
              ),
            ),
          );
        },
        child: const Icon(Icons.download),
      ),
    );
  }
}