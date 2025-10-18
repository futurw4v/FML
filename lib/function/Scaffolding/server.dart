import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:fml/function/log.dart';

/// 联机协议TCP服务器
class OnlineCenterServer {
  ServerSocket? _server;
  final int port;
  final List<Socket> _clients = [];
  final List<PlayerProfile> _players = [];
  final int minecraftServerPort;
  OnlineCenterServer({required this.port, required this.minecraftServerPort});
  List<PlayerProfile> get players => _players;

  Future<void> start() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      LogUtil.log('TCP服务器启动在端口 $port', level: 'INFO');
      _server!.listen((socket) {
        _handleClient(socket);
      });
      return Future.value();
    } catch (e) {
      LogUtil.log('TCP服务器启动失败: $e', level: 'ERROR');
      return Future.error(e);
    }
  }

  Future<void> stop() async {
    for (var client in _clients) {
      try {
        client.close();
      } catch (e) {
        LogUtil.log('关闭客户端连接失败: $e', level: 'ERROR');
      }
    }
    _clients.clear();
    _server?.close();
    _server = null;
    LogUtil.log('TCP服务器已关闭', level: 'INFO');
  }

  Future<void> _handleClient(Socket socket) async {
    LogUtil.log('新客户端连接: ${socket.remoteAddress.address}:${socket.remotePort}', level: 'INFO');
    _clients.add(socket);
    List<int> buffer = [];
    int? expectedLength;
    socket.listen(
      (data) {
        // 添加新数据到缓冲区
        buffer.addAll(data);
        while (buffer.isNotEmpty) {
          if (expectedLength == null) {
            if (buffer.isEmpty) return;
            final typeLength = buffer[0];
            if (buffer.length < 1 + typeLength + 4) return;
            final requestTypeBytes = buffer.sublist(1, 1 + typeLength);
            utf8.decode(requestTypeBytes);
            final bodyLengthBytes = buffer.sublist(1 + typeLength, 5 + typeLength);
            final bodyLength = _bytesToUint32(bodyLengthBytes);
            expectedLength = 5 + typeLength + bodyLength;
            if (buffer.length < expectedLength!) return;
          }
          if (buffer.length >= expectedLength!) {
            final requestBytes = buffer.sublist(0, expectedLength!);
            buffer = buffer.sublist(expectedLength!);
            _handleRequest(requestBytes, socket);
            expectedLength = null;
          }
        }
      },
      onError: (error) {
        LogUtil.log('客户端连接错误: $error', level: 'ERROR');
        _removeClient(socket);
      },
      onDone: () {
        LogUtil.log('客户端连接关闭: ${socket.remoteAddress.address}:${socket.remotePort}', level: 'INFO');
        _removeClient(socket);
      },
    );
  }

  Future<void> _removeClient(Socket socket) async {
    _clients.remove(socket);
    _players.removeWhere((player) {
      final isMatch = player.socketId == '${socket.remoteAddress.address}:${socket.remotePort}';
      if (isMatch) {
        LogUtil.log('玩家离线: ${player.name}', level: 'INFO');
      }
      return isMatch;
    });
  }

  Future<void> _handleRequest(List<int> requestBytes, Socket socket) async {
    try {
      // 解析请求
      final typeLength = requestBytes[0];
      final requestTypeBytes = requestBytes.sublist(1, 1 + typeLength);
      final requestType = utf8.decode(requestTypeBytes);
      final bodyLengthBytes = requestBytes.sublist(1 + typeLength, 5 + typeLength);
      final bodyLength = _bytesToUint32(bodyLengthBytes);
      final body = bodyLength > 0
          ? requestBytes.sublist(5 + typeLength, 5 + typeLength + bodyLength)
          : <int>[];
      LogUtil.log('收到请求: $requestType, 请求体长度: $bodyLength', level: 'INFO');
      // 根据请求类型分发处理
      switch (requestType) {
        case 'c:ping':
          await _handlePingRequest(body, socket);
          break;
        case 'c:protocols':
          await _handleProtocolsRequest(body, socket);
          break;
        case 'c:server_port':
          await _handleServerPortRequest(body, socket);
          break;
        case 'c:player_ping':
          await _handlePlayerPingRequest(body, socket);
          break;
        case 'c:player_profiles_list':
          await _handlePlayerProfilesListRequest(body, socket);
          break;
        default:
          // 未知协议请求
          await _sendErrorResponse(socket, 255, 'Unknown protocol: $requestType');
          break;
      }
    } catch (e) {
      LogUtil.log('处理请求失败: $e', level: 'ERROR');
      _sendErrorResponse(socket, 255, 'Error processing request: $e');
    }
  }

  // 处理 c:ping 请求
  Future<void> _handlePingRequest(List<int> body, Socket socket) async {
    _sendSuccessResponse(socket, body);
  }

  // 处理 c:protocols 请求
  Future<void> _handleProtocolsRequest(List<int> body, Socket socket) async {
    // 支持的协议列表
    final supportedProtocols = [
      'c:protocols',
      'c:ping',
      'c:server_port',
      'c:player_ping',
      'c:player_profile_list'
    ];
    final responseBody = utf8.encode(supportedProtocols.join('0'));
    _sendSuccessResponse(socket, responseBody);
  }

  // 处理 c:server_port 请求
  Future<void> _handleServerPortRequest(List<int> body, Socket socket) async {
    if (minecraftServerPort <= 0) {
      _sendErrorResponse(socket, 32, '');
      return;
    }
    final portBytes = Uint8List(2);
    portBytes[0] = (minecraftServerPort >> 8) & 0xFF;
    portBytes[1] = minecraftServerPort & 0xFF;
    _sendSuccessResponse(socket, portBytes);
  }

  // 处理 c:player_ping 请求
  Future<void> _handlePlayerPingRequest(List<int> body, Socket socket) async {
    try {
      final jsonString = utf8.decode(body);
      final data = jsonDecode(jsonString);
      final name = data['name'] as String;
      final machineId = data['machine_id'] as String;
      final vendor = data['vendor'] as String;
      final socketId = '${socket.remoteAddress.address}:${socket.remotePort}';
      final existingPlayerIndex = _players.indexWhere((p) => p.machineId == machineId);
      if (existingPlayerIndex >= 0) {
        _players[existingPlayerIndex].lastActivity = DateTime.now();
        _players[existingPlayerIndex].socketId = socketId;
      } else {
        _players.add(PlayerProfile(
          name: name,
          machineId: machineId,
          vendor: vendor,
          kind: 'GUEST',
          socketId: socketId,
        ));
        LogUtil.log('新玩家加入: $name ($vendor)', level: 'INFO');
      }
      _sendSuccessResponse(socket, []);
    } catch (e) {
      LogUtil.log('处理player_ping失败: $e', level: 'ERROR');
      _sendErrorResponse(socket, 255, 'Invalid player_ping format: $e');
    }
  }

  // 处理 c:player_profiles_list 请求
  Future<void> _handlePlayerProfilesListRequest(List<int> body, Socket socket) async {
    // 清理超时玩家（30秒无心跳）
    final now = DateTime.now();
    _players.removeWhere((player) {
      final isTimeout = now.difference(player.lastActivity).inSeconds > 30;
      if (isTimeout) {
        LogUtil.log('玩家超时: ${player.name}', level: 'INFO');
      }
      return isTimeout;
    });
    // 生成包含所有玩家的列表
    final allPlayers = [
      {
        'name': 'Host',
        'machine_id': 'host-machine-id',
        'vendor': 'FML',
        'kind': 'HOST'
      },
      ..._players.map((p) => {
        'name': p.name,
        'machine_id': p.machineId,
        'vendor': p.vendor,
        'kind': p.kind
      })
    ];
    final responseBody = utf8.encode(jsonEncode(allPlayers));
    _sendSuccessResponse(socket, responseBody);
  }

  // 发送成功响应
  Future<void> _sendSuccessResponse(Socket socket, List<int> body) async {
    final response = _buildResponse(0, body);
    _sendResponse(socket, response);
  }

  // 发送错误响应
  Future<void> _sendErrorResponse(Socket socket, int status, String message) async{
    final body = message.isNotEmpty ? utf8.encode(message) : <int>[];
    final response = _buildResponse(status, body);
    _sendResponse(socket, response);
  }
  // 构建响应
  Uint8List _buildResponse(int status, List<int> body) {
    final bodyLength = body.length;
    // 创建响应缓冲区：1字节状态 + 4字节长度 + 正文
    final buffer = Uint8List(5 + bodyLength);
    buffer[0] = status;
    buffer[1] = (bodyLength >> 24) & 0xFF;
    buffer[2] = (bodyLength >> 16) & 0xFF;
    buffer[3] = (bodyLength >> 8) & 0xFF;
    buffer[4] = bodyLength & 0xFF;
    if (bodyLength > 0) {
      buffer.setRange(5, 5 + bodyLength, body);
    }
    return buffer;
  }

  // 发送响应
  Future<void> _sendResponse(Socket socket, List<int> response) async {
    try {
      socket.add(response);
    } catch (e) {
      LogUtil.log('发送响应失败: $e', level: 'ERROR');
    }
  }
  int _bytesToUint32(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  // 生成并添加主机玩家
  Future<void> addHostPlayer(String name) async {
    _players.add(PlayerProfile(
      name: name,
      machineId: 'host-machine-id',
      vendor: 'FML',
      kind: 'HOST',
      socketId: 'local-host',
    ));
    LogUtil.log('添加房主: $name', level: 'INFO');
  }
}

/// 玩家信息
class PlayerProfile {
  final String name;
  final String machineId;
  final String vendor;
  final String kind; // 'HOST' | 'GUEST'
  DateTime lastActivity;
  String socketId;
  PlayerProfile({
    required this.name,
    required this.machineId,
    required this.vendor,
    required this.kind,
    required this.socketId,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();
}