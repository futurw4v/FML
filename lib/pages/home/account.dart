import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fml/function/log.dart';
import 'package:fml/pages/home/account/new_account.dart';
import 'package:fml/pages/home/account/offline_account_management.dart';

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
    // 基本信息
    Map<String, dynamic> info = {
      'loginMode': accountData[0],
      'uuid': accountData[1],
    };
    // 离线登录
    if (accountData[0] == '0') {
      info['isCustomUUID'] = accountData[2];
      info['customUUID'] = accountData[3];
      if (accountData[2] == '1' && accountData[3].isNotEmpty) {
        info['uuid'] = accountData[3];
      }
    }
    // 外置登录
    if (accountData[0] == '2') {
      info['serverUrl'] = accountData[2];
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

  // 删除账号
  Future<void> _deleteAccount(name) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList('AccountsList') ?? [];
    accounts.remove(name);
    await prefs.setStringList('AccountsList', accounts);
    await prefs.remove('Account_$name}');
    if (name == prefs.getString('SelectedAccount')) {
      await prefs.remove('SelectedAccount');
    }
    LogUtil.log('已删除账号: $name', level: 'INFO');
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除账号: $name')),
    );
  }

  // 删除账号提示框
  Future<void> _showDeleteDialog(name) async{
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('确定删除账号 $name ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
            onPressed: () async {
              _deleteAccount(name);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                    final loginMode = data['loginMode'] ?? '3';
                    String subtitle = '';
                    if (loginMode == '0') {
                      subtitle += _getLoginModeText(loginMode);
                      if (data['isCustomUUID'] == '1') {
                        subtitle += '\n已启用自定义UUID: ${data['customUUID']}\n';
                      } else {
                        subtitle += '\nUUID: $uuid';
                      }
                    } else if (loginMode == '1') {
                      subtitle += _getLoginModeText(loginMode);
                      subtitle += '\nUUID: $uuid\n';
                    } else if (loginMode == '2') {
                      subtitle += _getLoginModeText(loginMode);
                      subtitle += '\nUUID: $uuid\n';
                      subtitle += '服务器URL: ${data['serverUrl'] ?? '错误'}';
                    } else {
                      subtitle += _getLoginModeText(loginMode);
                    }
                    // 显示离线账号信息
                    if (loginMode == '0') {
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
                                  builder: (context) => OfflineAccountManagementPage(accountName: _accounts[index]),
                                ),
                              );
                              if (mounted) {
                                _loadAccounts();
                              }
                            },
                          ),
                        ),
                      );
                    }
                    // 显示其它账号信息
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
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            _showDeleteDialog(_accounts[index]);
                          },
                        )
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