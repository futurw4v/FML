import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fml/function/log.dart';

Future<int?> getPort() async {
  final completer = Completer<int?>();
  final sockets = <RawDatagramSocket>[];
  final subs = <StreamSubscription>[];

  // 关闭所有资源
  Future<void> closeAll([int? result]) async {
    for (final s in sockets) {
      try {
        s.close();
      } catch (e) {
        LogUtil.log('关闭 socket 失败: $e', level: 'WARNING');
      }
    }
    for (final sub in subs) {
      try {
        sub.cancel();
      } catch (e) {
        LogUtil.log('取消订阅失败: $e', level: 'WARNING');
      }
    }
    if (!completer.isCompleted) completer.complete(result);
  }

  // 绑定并监听指定地址
  Future<void> tryBindAndListen(InternetAddress bindAddr, bool isIpv4) async {
    try {
      final socket = await RawDatagramSocket.bind(bindAddr, 4445);
      sockets.add(socket);
      try {
        if (isIpv4) {
          socket.joinMulticast(InternetAddress('224.0.2.60'));
        } else {
          socket.joinMulticast(InternetAddress('FF75:230::60'));
        }
      } catch (e) {
        LogUtil.log('加入多播组失败 ($bindAddr): $e', level: 'WARNING');
      }
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        String data;
        try {
          data = utf8.decode(dg.data);
        } catch (e) {
          LogUtil.log('解码数据失败: $e', level: 'WARNING');
          return;
        }
        final adBegin = data.indexOf('[AD]');
        final adEnd = data.indexOf('[/AD]');
        if (adBegin == -1 || adEnd == -1 || adEnd <= adBegin + '[AD]'.length) return;
        final portStr = data.substring(adBegin + '[AD]'.length, adEnd).trim();
        final port = int.tryParse(portStr);
        if (port == null) return;
        closeAll(port);
      });
      subs.add(sub);
    } catch (e) {
      LogUtil.log('绑定监听失败 ($bindAddr): $e', level: 'WARNING');
    }
  }

  // 尝试绑定 IPv4/IPv6
  await tryBindAndListen(InternetAddress.anyIPv4, true);
  await tryBindAndListen(InternetAddress.anyIPv6, false);
  return completer.future;
}
