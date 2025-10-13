import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:fml/function/log.dart';

Future<void> saveOffineAccount(BuildContext context,String name) async {
  String uuid = md5.convert(utf8.encode('OfflinePlayer:$name')).toString();
  final prefs = await SharedPreferences.getInstance();
  List<String> accounts = prefs.getStringList('AccountsList') ?? [];
  if (accounts.contains(name)) {
    LogUtil.log('账号 $name 已存在', level: 'ERROR');
    return;
  }
  accounts.add(name);
  await prefs.setStringList('AccountsList', accounts);
  await prefs.setStringList(
    'Account_$name',
    ['0', uuid, '0', ''],
  );
  LogUtil.log('账号 $name 保存成功', level: 'INFO');
  ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加离线账号: $name')),
      );
      Navigator.pop(context);
}