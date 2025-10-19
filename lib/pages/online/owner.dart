import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/launcher/vanilla.dart' as vanilla_launcher;
import 'package:fml/function/launcher/fabric.dart' as fabric_launcher;
import 'package:fml/function/launcher/neoforge.dart' as neoforge_launcher;
import 'package:fml/function/Scaffolding/server.dart';

class OwnerPage extends StatefulWidget {
  final int port;
  const OwnerPage({super.key, required this.port});

  // 静态变量用于在页面重建之间保持状态
  static String? _persistRoomCode;
  static String? _persistNetworkName;
  static String? _persistNetworkKey;
  static OnlineCenterServer? _persistTcpServer;
  static int _persistTcpServerPort = 25565;
  static bool _persistIsServerRunning = false;
  static Process? _easyTierProcess;
  static String? _machineId;

  @override
  OwnerPageState createState() => OwnerPageState();
}

class OwnerPageState extends State<OwnerPage> {
  int _port = -1;
  StreamSubscription<int>? _lanPortSub;
  String? _roomCode;
  String? _networkName;
  String? _networkKey;
  OnlineCenterServer? _tcpServer;
  int _tcpServerPort = 25565;
  bool _isServerRunning = false;
  String _playerName = "房主";
  final Random _random = Random();
  Process? _easyTierProcess;
  String? _machineId;
  bool _isEasyTierRunning = false;
  Timer? _playerListRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _initMachineId();
    _roomCode = OwnerPage._persistRoomCode;
    _networkName = OwnerPage._persistNetworkName;
    _networkKey = OwnerPage._persistNetworkKey;
    _tcpServer = OwnerPage._persistTcpServer;
    _tcpServerPort = OwnerPage._persistTcpServerPort;
    _isServerRunning = OwnerPage._persistIsServerRunning;
    _easyTierProcess = OwnerPage._easyTierProcess;
    _machineId = OwnerPage._machineId;
    _isEasyTierRunning = _easyTierProcess != null;
    
    // 启动定时器,每2秒刷新一次玩家列表
    _playerListRefreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isServerRunning && _tcpServer != null && mounted) {
        setState(() {});
      }
    });
    
    final fabricPort = fabric_launcher.getLastDetectedPort();
    final vanillaPort = vanilla_launcher.getLastDetectedPort();
    final neoforgePort = neoforge_launcher.getLastDetectedPort();
    final cachedPort = fabricPort ?? vanillaPort ?? neoforgePort;
    if (cachedPort != null && cachedPort > 0) {
      setState(() {
        _port = cachedPort;
      });
      LogUtil.log('使用缓存的端口: $_port', level: 'INFO');
      if (!_isServerRunning) {
        _startTcpServer();
      } else if (_tcpServer != null && _tcpServer!.minecraftServerPort != cachedPort) {
        _restartTcpServer();
      }
    }
    _lanPortSub = fabric_launcher.lanPortController.stream.listen((port) {
      _handlePortChange(port);
    });
    vanilla_launcher.lanPortController.stream.listen((port) {
      _handlePortChange(port);
    });
    neoforge_launcher.lanPortController.stream.listen((port) {
      _handlePortChange(port);
    });
    if (_roomCode == null) {
      _generateRoomCode();
    }
  }

  // 初始化机器ID
  Future<void> _initMachineId() async {
    if (_machineId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var machineId = prefs.getString('machine_id');
      if (machineId == null) {
        machineId = const Uuid().v4();
        await prefs.setString('machine_id', machineId);
      }
      setState(() {
        _machineId = machineId;
      });
      OwnerPage._machineId = machineId;
      LogUtil.log('机器ID: $_machineId', level: 'INFO');
    } catch (e) {
      final tempId = const Uuid().v4();
      setState(() {
        _machineId = tempId;
      });
      OwnerPage._machineId = tempId;
      LogUtil.log('生成临时机器ID: $_machineId', level: 'INFO');
    }
  }

  // 处理端口变化
  Future<void> _handlePortChange(int port) async {
    if (!mounted) return;
    setState(() {
      _port = port;
    });
    if (port > 0) {
      LogUtil.log('收到新的端口事件: $port', level: 'INFO');
      if (_isServerRunning && _tcpServer != null) {
        _restartTcpServer();
      } else {
        _startTcpServer();
      }
    } else if (port == -1) {
      LogUtil.log('局域网游戏已关闭', level: 'INFO');
      if (_isServerRunning) {
        await _stopTcpServer();
      }
    }
  }

  @override
  void dispose() {
    _lanPortSub?.cancel();
    _playerListRefreshTimer?.cancel();
    super.dispose();
  }

  // 有效字符集
  static const List<String> _validChars = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
    'W', 'X', 'Y', 'Z'
  ];

  Future<void> _generateRoomCode() async {
    final random = Random.secure();
    final List<int> charIndices = List.generate(15, (_) => random.nextInt(34));
    int partialValue = 0;
    for (int i = 0; i < 15; i++) {
      int contribution = charIndices[i];
      for (int j = 0; j < i; j++) {
        contribution = (contribution * 34) % 7;
      }
      partialValue = (partialValue + contribution) % 7;
    }
    int remainder = partialValue % 7;
    int needed = (7 - remainder) % 7;
    int weight = 1;
    for (int i = 0; i < 15; i++) {
      weight = (weight * 34) % 7;
    }
    int lastCharIndex = 0;
    for (int i = 0; i < 34; i++) {
      if ((i * weight) % 7 == needed) {
        lastCharIndex = i;
        break;
      }
    }
    final List<String> chars = charIndices.map((i) => _validChars[i]).toList();
    chars.add(_validChars[lastCharIndex]);
    final code = 'U/${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8, 12).join()}-${chars.sublist(12, 16).join()}';
    final parts = code.substring(2).split('-');
    setState(() {
      _roomCode = code;
      _networkName = 'scaffolding-mc-${parts[0]}-${parts[1]}';
      _networkKey = '${parts[2]}-${parts[3]}';
    });
    OwnerPage._persistRoomCode = _roomCode;
    OwnerPage._persistNetworkName = _networkName;
    OwnerPage._persistNetworkKey = _networkKey;
    if (kDebugMode && !(await _isValidCode(code))) {
      LogUtil.log('生成的代码验证失败: $code', level: 'ERROR');
    } else {
      LogUtil.log('生成房间码: $_roomCode', level: 'INFO');
      LogUtil.log('网络名称: $_networkName', level: 'INFO');
      LogUtil.log('网络密钥: $_networkKey', level: 'INFO');
      if (_port > 0 && !_isServerRunning) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _startTcpServer();
        });
      }
    }
  }

  // 验证房间码
  Future<bool> _isValidCode(String code) async {
    if (!RegExp(r'^U/[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}$')
        .hasMatch(code)) {
      return false;
    }
    final codeContent = code.substring(2).replaceAll('-', '');
    int value = 0;
    for (int i = 0; i < codeContent.length; i++) {
      final charIndex = _validChars.indexOf(codeContent[i]);
      if (charIndex == -1) return false;
      int contribution = charIndex;
      for (int j = 0; j < i; j++) {
        contribution = (contribution * 34) % 7;
      }
      value = (value + contribution) % 7;
    }
    return value == 0;
  }

  // 加载玩家名称
  Future<void> _loadPlayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('SelectedAccount');
      if (name != null && name.isNotEmpty) {
        setState(() {
          _playerName = name;
        });
      } else {
        setState(() {
          _playerName = "匿名玩家";
        });
      }
    } catch (e) {
      LogUtil.log('加载玩家名称失败: $e', level: 'ERROR');
      setState(() {
        _playerName = "FML客户端";
      });
    }
  }

  // 读取App版本
  Future<String> _loadAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString('version') ?? "1.0.0";
    return version;
  }

  // 检测核心版本
  Future<String> _checkCoreVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('SelectedPath') ?? '';
    final path = prefs.getString('Path_$name') ?? '';
    final String core = ('$path${Platform.pathSeparator}easytier${Platform.pathSeparator}easytier-core');
    try {
      final ProcessResult proc = await Process.run(core, ['--version']);
      final String output = proc.stdout.toString().trim();
      if (output.contains('easytier-core ')) {
        final String versionWithHash = output.split('easytier-core ')[1];
        if (versionWithHash.contains('-')) {
          return versionWithHash.split('-')[0];
        }
        return versionWithHash;
      }
      return output;
    } catch (e) {
      LogUtil.log('获取EasyTier核心版本失败: $e', level: 'ERROR');
      return "未知";
    }
  }

  // 生成随机端口并检查可用性
  Future<int> _findAvailablePort() async {
    int maxAttempts = 20;
    int attempts = 0;
    while (attempts < maxAttempts) {
      attempts++;
      int port = 1024 + _random.nextInt(65535 - 1024);
      try {
        final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
        await socket.close();
        LogUtil.log('找到可用的随机端口: $port (尝试次数: $attempts)', level: 'INFO');
        return port;
      } catch (e) {
        LogUtil.log('端口 $port 被占用，尝试另一个随机端口', level: 'INFO');
      }
    }
    throw Exception('尝试$maxAttempts次后仍无法找到可用端口');
  }

  // 启动EasyTier
  Future<bool> _startEasyTier() async {
    if (_isEasyTierRunning || _easyTierProcess != null) {
      LogUtil.log('EasyTier已在运行中', level: 'INFO');
      return true;
    }
    if (_networkName == null || _networkKey == null || _machineId == null) {
      LogUtil.log('缺少启动EasyTier所需的信息', level: 'ERROR');
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('SelectedPath') ?? '';
      final path = prefs.getString('Path_$name') ?? '';
      final String core = ('$path${Platform.pathSeparator}easytier${Platform.pathSeparator}easytier-core');
      final hostname = 'scaffolding-mc-server-$_tcpServerPort';
      LogUtil.log('设置EasyTier主机名: $hostname', level: 'INFO');
      final args = [
        '-d',
        '--network-name', _networkName!,
        '--network-secret', _networkKey!,
        '--machine-id', _machineId!,
        '--hostname', hostname,
        '-p', 'tcp://public.easytier.cn:11010'
      ];
      LogUtil.log('正在启动EasyTier: $core ${args.join(' ')}', level: 'INFO');
      if (Platform.isMacOS || Platform.isLinux) {
        _easyTierProcess = await Process.start('sudo', [core, ...args]);
      } else {
        _easyTierProcess = await Process.start(core, args);
      }
      OwnerPage._easyTierProcess = _easyTierProcess;
      _easyTierProcess!.stdout.transform(utf8.decoder).listen((data) {
        LogUtil.log('EasyTier输出: $data', level: 'INFO');
      });
      _easyTierProcess!.stderr.transform(utf8.decoder).listen((data) {
        LogUtil.log('EasyTier错误: $data', level: 'ERROR');
      });
      _easyTierProcess!.exitCode.then((code) {
        LogUtil.log('EasyTier进程退出,退出码: $code', level: 'INFO');
        if (mounted) {
          setState(() {
            _isEasyTierRunning = false;
            _easyTierProcess = null;
          });
          OwnerPage._easyTierProcess = null;
        }
      });
      setState(() {
        _isEasyTierRunning = true;
      });
      LogUtil.log('EasyTier启动成功', level: 'INFO');
      return true;
    } catch (e) {
      LogUtil.log('启动EasyTier失败: $e', level: 'ERROR');
      return false;
    }
  }

  // 停止EasyTier
  Future<void> _stopEasyTier() async {
    if (!_isEasyTierRunning || _easyTierProcess == null) {
      LogUtil.log('EasyTier未在运行', level: 'INFO');
      return;
    }
    try {
      LogUtil.log('正在停止EasyTier', level: 'INFO');
      _easyTierProcess!.kill(ProcessSignal.sigterm);
      await _easyTierProcess!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // 超时强制结束
          _easyTierProcess!.kill(ProcessSignal.sigkill);
          return -1;
        }
      );
      setState(() {
        _isEasyTierRunning = false;
        _easyTierProcess = null;
      });
      OwnerPage._easyTierProcess = null;
      LogUtil.log('EasyTier已停止', level: 'INFO');
    } catch (e) {
      LogUtil.log('停止EasyTier失败: $e', level: 'ERROR');
    }
  }

  // 启动TCP服务器
  Future<void> _startTcpServer() async {
    if (_isServerRunning) {
      LogUtil.log('TCP服务器已经在运行', level: 'INFO');
      return;
    }
    if (_port <= 0) {
      LogUtil.log('Minecraft服务器尚未启动,无法启动TCP服务器', level: 'WARNING');
      return;
    }
    setState(() {
    });
    try {
      final appVersion = await _loadAppVersion();
      final coreVersion = await _checkCoreVersion();
      _tcpServerPort = await _findAvailablePort();
      _tcpServer = OnlineCenterServer(
        hostName: _playerName,
        hostVendor: 'FML $appVersion, EasyTier v$coreVersion',
        port: _tcpServerPort,
        minecraftServerPort: _port
      );
      await _tcpServer!.start();
      await _tcpServer!.addHostPlayer(_machineId ?? 'unknown-machine-id');
      // 启动EasyTier网络
      final easyTierStarted = await _startEasyTier();
      setState(() {
        _isServerRunning = true;
      });
      OwnerPage._persistTcpServer = _tcpServer;
      OwnerPage._persistTcpServerPort = _tcpServerPort;
      OwnerPage._persistIsServerRunning = _isServerRunning;
      LogUtil.log('TCP服务器启动成功,端口: $_tcpServerPort', level: 'INFO');
      String message = '联机服务器启动成功,端口: $_tcpServerPort';
      if (!easyTierStarted) {
        message += ' (EasyTier启动失败)';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
      );
    } catch (e) {
      LogUtil.log('启动TCP服务器失败: $e', level: 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动联机服务器失败: $e'))
      );
      await _stopEasyTier();
    }
  }

  // 停止TCP服务器
  Future<void> _stopTcpServer() async {
    if (!_isServerRunning) return;
    try {
      await _stopEasyTier();
      await _tcpServer?.stop();
      _tcpServer = null;
      setState(() {
        _isServerRunning = false;
      });
      OwnerPage._persistTcpServer = null;
      OwnerPage._persistIsServerRunning = false;
      LogUtil.log('TCP服务器已停止', level: 'INFO');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('联机服务器已停止'))
      );
      Navigator.pop(context);
    } catch (e) {
      LogUtil.log('停止TCP服务器失败: $e', level: 'ERROR');
    }
  }

  // 重启TCP服务器
  Future<void> _restartTcpServer() async {
    await _stopTcpServer();
    await _startTcpServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建房间'),
      ),
      body: Center(
        child: _port < 0
            ? const Text('正在等待局域网游戏启动...\n请在单人游戏中打开局域网开放')
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_roomCode != null) ...[
                            Text(
                              '邀请码:',
                              style: Theme.of(context).textTheme.titleLarge
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(_roomCode!,
                                    style: Theme.of(context).textTheme.headlineMedium
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _roomCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('房间码已复制到剪贴板'))
                                    );
                                  },
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Scaffolding 协议服务器: ',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            _isServerRunning ? "运行中" : "未运行或正在启动",
                                            style: TextStyle(
                                              color: _isServerRunning ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'EasyTier 网络: ',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            _isEasyTierRunning ? "已连接" : "未连接",
                                            style: TextStyle(
                                              color: _isEasyTierRunning ? Colors.green : Colors.red,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (_isServerRunning)
                                        Text('Scaffolding 协议端口: $_tcpServerPort'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text('EasyTier网络信息:'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('网络名称: $_networkName'),
                                      const SizedBox(height: 4),
                                      Text('网络密钥: $_networkKey'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isServerRunning && _tcpServer != null) ...[
                            const Text('已连接玩家:'),
                            const SizedBox(height: 8),
                            if (_tcpServer!.players.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _tcpServer!.players.map((player) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          player.kind == 'HOST' ? Icons.star : Icons.person,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${player.name} (${player.vendor})'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            else
                              const Text('暂无玩家连接', style: TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _isServerRunning ? FloatingActionButton(
        onPressed:  _stopTcpServer,
        child: const Icon(Icons.stop),
      ) : null,
    );
  }
}