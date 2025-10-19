import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fml/function/log.dart';

// Minecraft局域网游戏广播服务器
class FakeServer {
  final int port;
  final List<RawDatagramSocket> _sockets = [];
  Timer? _broadcastTimer;
  bool _isRunning = false;
  static final InternetAddress _multicastAddressV4 = InternetAddress('224.0.2.60');
  static const int _multicastPort = 4445;
  FakeServer({
    required this.port,
  });

  // 启动广播服务
  Future<void> start() async {
    if (_isRunning) {
      LogUtil.log('FakeServer已在运行中', level: 'WARNING');
      return;
    }
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            try {
              final socket = await RawDatagramSocket.bind(
                address,
                0,
              );
              socket.broadcastEnabled = true;
              socket.multicastLoopback = true;
              socket.multicastHops = 4;
              _sockets.add(socket);
              LogUtil.log('FakeServer绑定到 ${address.address}', level: 'INFO');
            } catch (e) {
              LogUtil.log('绑定到 ${address.address} 失败: $e', level: 'WARNING');
            }
          }
        }
      }
      if (_sockets.isEmpty) {
        throw Exception('无法绑定到任何网络接口');
      }
      _isRunning = true;
      _startBroadcasting();
      LogUtil.log('FakeServer启动成功，广播端口: $port', level: 'INFO');
    } catch (e) {
      LogUtil.log('启动FakeServer失败: $e', level: 'ERROR');
      await stop();
      rethrow;
    }
  }

  // 开始定时广播
  Future<void> _startBroadcasting() async {
    final message = '[MOTD]§6§l双击进入 §r§6FML §l联机大厅[/MOTD][AD]$port[/AD]';
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    _broadcastTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) {
        for (var socket in _sockets) {
          try {
            socket.send(
              messageBytes,
              _multicastAddressV4,
              _multicastPort,
            );
          } catch (e) {
            LogUtil.log('发送广播消息失败: $e', level: 'WARNING');
          }
        }
      },
    );
  }

  // 停止广播服务
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    for (var socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
    _isRunning = false;
    LogUtil.log('FakeServer已停止', level: 'INFO');
  }
  bool get isRunning => _isRunning;
}
