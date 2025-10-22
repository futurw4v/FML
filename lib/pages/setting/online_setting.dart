import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineSettingPage extends StatefulWidget {
  const OnlineSettingPage({super.key});

  @override
  OnlineSettingPageState createState() => OnlineSettingPageState();
}

class OnlineSettingPageState extends State<OnlineSettingPage> {
  bool _useTun = false;
  TextEditingController _extraNodeController = TextEditingController();

  // 获取设置
  Future<void> _getSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool useTun = prefs.getBool('useTun') ?? false;
    String extraNode = prefs.getString('extraNode') ?? '';
    setState(() {
      // 更新状态
      _useTun = useTun;
      _extraNodeController.text = extraNode;
    });
  }

  // 保存设置
  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useTun', _useTun);
    await prefs.setString('extraNode', _extraNodeController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _getSettings();
  }

  @override
  void dispose() {
    _saveSettings();
    _extraNodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          await _saveSettings();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('联机设置'),
        ),
        body: ListView(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile(
                title: const Text('使用TUN模式'),
                subtitle: const Text('不建议,需要sudo权限'),
                value: _useTun,
                onChanged: (bool value) {
                  setState(() {
                    _useTun = value;
                  });
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '额外的节点地址,谨慎填写,无法连接时请删除',
                    hintText: 'tcp://example.com:11010',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  controller: _extraNodeController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}