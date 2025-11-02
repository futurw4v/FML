import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogSettingPage extends StatefulWidget {
  const LogSettingPage({super.key});

  @override
  LogSettingPageState createState() => LogSettingPageState();
}

class LogSettingPageState extends State<LogSettingPage> {
  int _logLevel = 0;
  bool _autoClearLog = false;

  // 读取日志配置信息
  Future<void> _readLogConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int logLevel = prefs.getInt('logLevel') ?? 0;
    final bool autoClearLog = prefs.getBool('autoClearLog') ?? false;
    setState(() {
      _logLevel = logLevel;
      _autoClearLog = autoClearLog;
    });
  }

  // 保存日志等级配置
  Future<void> _saveLogLevel() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('logLevel', _logLevel);
  }

  // 保存日志自动清理配置
  Future<void> _saveAutoClearLog() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoClearLog', _autoClearLog);
  }

  @override
  void initState() {
    super.initState();
    _readLogConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('日志等级'),
                      DropdownButton<int>(
                        hint: const Text('日志等级'),
                        isExpanded: true,
                        value: _logLevel,
                        items: [
                          DropdownMenuItem(value: 0, child: const Text('INFO')),
                          DropdownMenuItem(value: 1, child: const Text('WARNING')),
                          DropdownMenuItem(value: 2, child: const Text('ERROR')),
                        ],
                        onChanged: (int? value) {
                          setState(() {
                            _logLevel = value!;
                          });
                          _saveLogLevel();
                        }
                      ),
                    ]
                  )
                )
              )
            ]
          )
      )
    );
  }
}