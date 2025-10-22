import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:fml/pages/setting/theme.dart';
import 'package:fml/pages/setting/online_setting.dart';
import 'package:fml/pages/setting/about.dart';
import 'package:fml/pages/setting/java.dart';
import 'package:fml/function/log.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  SettingPageState createState() => SettingPageState();
}

class SettingPageState extends State<SettingPage> {
  String _dirPath = '';

  // 文件夹选择器
  Future<void> _selectDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择版本路径');
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择任何路径')));
        return;
      }
      setState(() {
        _dirPath = path;
      });
  }

// 保存日志
Future<void> _saveLog() async {
  await _selectDirectory(); // 等待用户选择目录
  if (_dirPath.isEmpty) {
    return;
  }
  try {
    final directory = Directory(_dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final logs = await LogUtil.getLogs();
    final timestamp = DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').split('.')[0];
    final logFileName = 'fml_$timestamp.log';
    final logFile = File('${directory.path}${Platform.pathSeparator}$logFileName');
    final StringBuffer logContent = StringBuffer();
    logContent.writeln('===== FML 日志 =====');
    logContent.writeln('导出时间: ${DateTime.now()}');
    logContent.writeln('====================\n');
    for (var log in logs) {
      final timestamp = log['timestamp'] as String;
      final level = log['level'] as String;
      final message = log['message'] as String;
      final dateTime = DateTime.parse(timestamp);
      final formattedTime = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      logContent.writeln('[$formattedTime] [$level] $message');
    }
    await logFile.writeAsString(logContent.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('日志已保存至: ${logFile.path}')),
    );
    LogUtil.log('日志已导出到: ${logFile.path}', level: 'INFO');
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('日志保存失败: $e')),
    );
    LogUtil.log('日志导出失败: $e', level: 'ERROR');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: Center(
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 主题设置 \n'),
                leading: Icon(Icons.imagesearch_roller),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ThemePage()),
                  );
                },
              ),
            ),Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 联机设置 \n'),
                leading: Icon(Icons.hub),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OnlineSettingPage()),
                  );
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 系统默认 Java 信息 \n'),
                leading: Icon(Icons.code),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => JavaPage()),
                  );
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 导出APP日志 \n'),
                leading: Icon(Icons.receipt_long),
                onTap: () {
                  _saveLog();
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 关于 \n'),
                leading: Icon(Icons.info),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
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