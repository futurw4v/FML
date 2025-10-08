import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
// 导入外置登录模块
import 'package:fml/function/account/authlib_injector.dart' as auth_lib;

class NewAccountPage extends StatefulWidget {
  const NewAccountPage({super.key});

  @override
  NewAccountPageState createState() => NewAccountPageState();
}

class NewAccountPageState extends State<NewAccountPage> {
  // 登录模式
  String _loginMode = 'offline';
  String _uuid = '';
  static const String defaultAuthServer = 'https://littleskin.cn/api/yggdrasil';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      if (_loginMode == 'authlibInjector') {
        _nameController.text = _usernameController.text;
      }
    });
  }

  @override
  void dispose() {
    // 释放控制器资源
    _nameController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 密码可见性
  Future<void> _togglePasswordVisibility() async {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // 保存账号
  Future<void> _saveAccountName(String name, String uuid, String loginMode) async {
    String isCustomUUID = '0';
    String customUUID = '';
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList('AccountsList') ?? [];
    if (accounts.contains(name)) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(content: Text('账号 $name 已存在')),
      );
      return;
    }
    if (!accounts.contains(name)) {
      accounts.add(name);
      await prefs.setStringList('AccountsList', accounts);
    }
    if (loginMode == 'online') {
      await prefs.setStringList('Account_$name',
        [uuid, '1', isCustomUUID, customUUID]);
    }
    else {
      await prefs.setStringList('Account_$name',
        [uuid, '0', isCustomUUID, customUUID]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加账号'),
      ),
      body: Center(
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('登录模式', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DropdownButton<String>(
                          value: _loginMode,
                          onChanged: (String? value) {
                            setState(() {
                              _loginMode = value!;
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'offline',
                              child: Text('离线登录'),
                            ),
                            DropdownMenuItem(
                              value: 'online',
                              child: Text('正版登录'),
                            ),
                            DropdownMenuItem(
                              value: 'authlibInjector' ,
                              child: Text('外置登录(authlib-injector)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loginMode == 'online')
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const ListTile(
                  leading: Icon(Icons.account_circle),
                  title: Text('将在Mojang审批完成后推出'),
                ),
              ),
            if (_loginMode == 'offline')
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '离线ID \n',
                    prefixIcon: Icon(Icons.account_circle),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            if (_loginMode == 'authlibInjector')
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: '验证服务器(留空使用littleskin)',
                          hintText: defaultAuthServer,
                          prefixIcon: Icon(Icons.dns),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        ),
                        obscureText: _obscurePassword,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_loginMode == 'offline' && _nameController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('名称不能为空')),
            );
            return;
          }
          // 处理外置登录
          if (_loginMode == 'authlibInjector') {
            // 检查用户名和密码
            if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请填写完整的账号和密码')),
              );
              return;
            }
            final String serverUrl = _serverUrlController.text.isEmpty ?
              defaultAuthServer : _serverUrlController.text;
            await auth_lib.saveAuthLibInjectorAccount(
              context, serverUrl, _usernameController.text, _passwordController.text);
            return;
          }
          // 处理其他登录方式
          String loginModeText = _loginMode == 'online' ? '正版账号' : '离线账号';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('正在添加$loginModeText: ${_nameController.text}')),
          );
          // 离线UUID生成
          if (_loginMode == 'offline') {
            _uuid = md5.convert(utf8.encode('OfflinePlayer:${_nameController.text}')).toString();
          }
          _saveAccountName(_nameController.text, _uuid, _loginMode);
          Navigator.pop(context);
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}