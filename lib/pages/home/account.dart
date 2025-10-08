import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fml/pages/home/account/new_account.dart';
import 'package:fml/pages/home/account/account_management.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  AccountPageState createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  List<String> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

// 读取本地账号列表
  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accounts = prefs.getStringList('AccountsList') ?? [];
    });
  }

// 账号信息
  Future<Map<String, dynamic>> _getAccountInfo(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final accountData = prefs.getStringList('Account_$name') ?? [];
    if (accountData.isEmpty) {
      return {'error': '找不到账号数据'};
    }
    final uuid = accountData[0];
    final loginMode = accountData[1]; // '0'离线, '1'正版, '2'外置
    final isCustomUUID = accountData[2];
    final customUUID = accountData[3];
    // 基本信息
    Map<String, dynamic> info = {
      'uuid': uuid,
      'loginMode': loginMode,
      'isCustomUUID': isCustomUUID,
      'customUUID': customUUID,
    };
    // 外置登录
    if (loginMode == '2' && accountData.length >= 8) {
      info['serverUrl'] = accountData[4];
      info['username'] = accountData[5];
      info['accessToken'] = accountData[7];
    }
    return info;
  }

// 跳转添加账号页并在返回后刷新
  Future<void> _addAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewAccountPage()),
    );
    if (mounted) {
      _loadAccounts();
    }
  }

  // 获取登录模式显示文本
  String _getLoginModeText(String loginMode) {
    switch (loginMode) {
      case '0': return '离线登录';
      case '1': return '正版登录';
      case '2': return '外置登录(authlib-injector)';
      default: return '未知类型';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号管理'),
      ),
      body: _accounts.isEmpty
          ? const Center(child: Text('暂无账号'))
          : ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: _getAccountInfo(_accounts[index]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data?.containsKey('error') == true) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.error),
                          title: Text(_accounts[index]),
                          subtitle: Text(snapshot.data?['error'] ?? '加载账号信息失败'),
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    final uuid = data['uuid'] ?? '';
                    final loginMode = data['loginMode'] ?? '';
                    final isCustomUUID = data['isCustomUUID'] ?? '';
                    final customUUID = data['customUUID'] ?? '';
                    String subtitle = '';
                    if (isCustomUUID == '1') {
                      subtitle += '已启用自定义UUID: $customUUID\n';
                    } else {
                      subtitle += 'UUID: $uuid\n';
                    }
                    subtitle += _getLoginModeText(loginMode);
                    if (loginMode == '2') {
                      subtitle += '\n服务器: ${data['serverUrl'] ?? ''}';
                    }
                    // 显示账号信息
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(_accounts[index]),
                        subtitle: Text(subtitle),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('SelectedAccount', _accounts[index]);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换账号: ${_accounts[index]}')),
                          );
                          Navigator.pop(context);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async{
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AccountManagementPage(accountName: _accounts[index]),
                              ),
                            );
                            if (mounted) {
                              _loadAccounts();
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}