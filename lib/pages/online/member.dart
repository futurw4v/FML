import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/Scaffolding/client.dart';
import 'package:fml/function/fakeserver.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  static bool _persistIsConnected = false;
  static bool _persistIsEasyTierRunning = false;
  static Process? _persistEasyTierProcess;
  static String? _persistNetworkName;
  static String? _persistNetworkKey;
  static OnlineCenterClient? _persistClient;
  static List<PlayerProfile> _persistPlayers = [];
  static int? _persistMinecraftServerPort;
  static String? _persistIpAddress;
  static FakeServer? _persistFakeServer;

  @override
  MemberPageState createState() => MemberPageState();
}

class MemberPageState extends State<MemberPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidCode = false;
  bool _isConnecting = false;
  bool _isEasyTierRunning = false;
  bool _isConnected = false;
  Process? _easyTierProcess;
  String? _machineId;
  String? _playerName;
  String? _networkName;
  String? _networkKey;
  OnlineCenterClient? _client;
  List<PlayerProfile> _players = [];
  int? _minecraftServerPort;
  String? _ipAddress;
  Timer? _minecraftLaunchTimer;
  FakeServer? _fakeServer;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _initMachineId();
    _codeController.addListener(_validateCode);
    _restoreConnectionState();
  }

  // 从静态变量恢复状态
  Future<void> _restoreConnectionState() async {
    _isConnected = MemberPage._persistIsConnected;
    _isEasyTierRunning = MemberPage._persistIsEasyTierRunning;
    _easyTierProcess = MemberPage._persistEasyTierProcess;
    _networkName = MemberPage._persistNetworkName;
    _networkKey = MemberPage._persistNetworkKey;
    _client = MemberPage._persistClient;
    _players = MemberPage._persistPlayers;
    _minecraftServerPort = MemberPage._persistMinecraftServerPort;
    _ipAddress = MemberPage._persistIpAddress;
    _fakeServer = MemberPage._persistFakeServer;
    if (_isConnected && _client != null) {
      _setupClientListeners();
    }
    LogUtil.log('恢复连接状态: isConnected=$_isConnected, isEasyTierRunning=$_isEasyTierRunning', level: 'INFO');
    if (_networkName != null && _networkKey != null && !_isConnected) {
      final networkParts = _networkName!.substring('scaffolding-mc-'.length).split('-');
      final codePrefix = 'U/${networkParts[0]}-${networkParts[1]}';
      final codeSuffix = _networkKey!;
      _codeController.text = '$codePrefix-$codeSuffix';
    }
  }

  // 启动FakeServer
  Future<void> _startFakeServer() async {
    if (_fakeServer != null && _fakeServer!.isRunning) {
      LogUtil.log('FakeServer已在运行', level: 'INFO');
      return;
    }

    if (_minecraftServerPort == null || _ipAddress == null) {
      LogUtil.log('无法启动FakeServer: 缺少服务器信息', level: 'WARNING');
      return;
    }

    try {
      _fakeServer = FakeServer(
        port: _minecraftServerPort!,
      );
      await _fakeServer!.start();
      MemberPage._persistFakeServer = _fakeServer;
      LogUtil.log('FakeServer已启动', level: 'INFO');
    } catch (e) {
      LogUtil.log('启动FakeServer失败: $e', level: 'ERROR');
      _fakeServer = null;
      MemberPage._persistFakeServer = null;
    }
  }

  // 停止FakeServer
  Future<void> _stopFakeServer() async {
    if (_fakeServer != null) {
      await _fakeServer!.stop();
      _fakeServer = null;
      MemberPage._persistFakeServer = null;
      LogUtil.log('FakeServer已停止', level: 'INFO');
    }
  }

  // 客户端监听器
  Future<void> _setupClientListeners() async {
    _client!.playersStream.listen((players) {
      if (mounted) {
        setState(() {
          _players = players;
          MemberPage._persistPlayers = players;
        });
      }
    });
    _client!.minecraftPortStream.listen((port) {
      if (mounted && port != null && port > 0) {
        setState(() {
          _minecraftServerPort = port;
          MemberPage._persistMinecraftServerPort = port;
        });
        // 收到Minecraft端口后启动FakeServer
        _startFakeServer();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _minecraftLaunchTimer?.cancel();
    super.dispose();
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

  // 初始化机器ID
  Future<void> _initMachineId() async {
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
      LogUtil.log('机器ID: $_machineId', level: 'INFO');
    } catch (e) {
      final tempId = const Uuid().v4();
      setState(() {
        _machineId = tempId;
      });
      LogUtil.log('生成临时机器ID: $_machineId', level: 'ERROR');
    }
  }

  // 验证输入的房间码
  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    final isValidFuture = _isValidRoomCode(code);
    final isValid = await isValidFuture;
    if (isValid != _isValidCode) {
      setState(() {
        _isValidCode = isValid;
      });
      if (isValid) {
        _extractNetworkInfo(code);
      } else {
        setState(() {
          _networkName = null;
          _networkKey = null;
        });
      }
    }
  }

  // 从房间码中提取网络信息
  Future<void> _extractNetworkInfo(String code) async {
    if (!code.startsWith('U/')) return;
    final parts = code.substring(2).split('-');
    if (parts.length != 4) return;
    setState(() {
      _networkName = 'scaffolding-mc-${parts[0]}-${parts[1]}';
      _networkKey = '${parts[2]}-${parts[3]}';
    });
    LogUtil.log('网络名称: $_networkName', level: 'INFO');
    LogUtil.log('网络密钥: $_networkKey', level: 'INFO');
  }

  // 检查房间码是否有效
  Future<bool> _isValidRoomCode(String code) async {
    if (!RegExp(r'^U/[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}$')
        .hasMatch(code)) {
      return false;
    }
    // 有效字符集
    const List<String> validChars = [
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
      'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
      'W', 'X', 'Y', 'Z'
    ];
    final codeContent = code.substring(2).replaceAll('-', '');
    int value = 0;
    for (int i = 0; i < codeContent.length; i++) {
      final charIndex = validChars.indexOf(codeContent[i]);
      if (charIndex == -1) return false;
      int contribution = charIndex;
      for (int j = 0; j < i; j++) {
        contribution = (contribution * 34) % 7;
      }
      value = (value + contribution) % 7;
    }
    return value == 0;
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
      final hostname = 'scaffolding-mc-client-${_machineId!.substring(0, 8)}';
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
      _easyTierProcess!.stdout.transform(utf8.decoder).listen((data) {
        if (data.contains('Connection established') ||
            data.contains('Connection success') ||
            data.contains('connected to') ||
            data.contains('relay connection') ||
            data.contains('dhcp ip changed')) {
          LogUtil.log('检测到EasyTier连接成功信息', level: 'INFO');
          _detectPeers();
        }
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
        }
        MemberPage._persistIsEasyTierRunning = false;
        MemberPage._persistEasyTierProcess = null;
      });
      setState(() {
        _isEasyTierRunning = true;
      });
      MemberPage._persistIsEasyTierRunning = true;
      MemberPage._persistEasyTierProcess = _easyTierProcess;
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
          _easyTierProcess!.kill(ProcessSignal.sigkill);
          return -1;
        }
      );
      if (mounted) {
        setState(() {
          _isEasyTierRunning = false;
          _easyTierProcess = null;
        });
      } else {
        _isEasyTierRunning = false;
        _easyTierProcess = null;
        MemberPage._persistIsEasyTierRunning = false;
        MemberPage._persistEasyTierProcess = null;
      }
      LogUtil.log('EasyTier已停止', level: 'INFO');
    } catch (e) {
      LogUtil.log('停止EasyTier失败: $e', level: 'ERROR');
    }
  }

  // 检测peers并尝试连接到服务器
  Future<void> _detectPeers() async {
    if (!_isEasyTierRunning) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('SelectedPath') ?? '';
      final path = prefs.getString('Path_$name') ?? '';
      final String cliPath = ('$path${Platform.pathSeparator}easytier${Platform.pathSeparator}easytier-cli');
      LogUtil.log('执行easytier-cli peer', level: 'INFO');
      final result = await Process.run(cliPath, ['peer']);
      if (result.exitCode == 0) {
        LogUtil.log('easytier-cli peer命令输出:\n${result.stdout}', level: 'INFO');
        final outputLines = (result.stdout as String).split('\n');
        String? serverIP;
        int? serverPort;
        for (var line in outputLines) {
          if (line.contains('hostname') || line.trim().isEmpty) continue;
          final columns = line.split('|').map((col) => col.trim()).toList();
          columns.removeWhere((col) => col.isEmpty);
          if (columns.length < 3) continue;
          for (int i = 0; i < columns.length; i++) {
            final column = columns[i];
            if (column.startsWith('scaffolding-mc-server-')) {
              final hostname = column;
              final ipWithMask = i > 0 ? columns[i - 1] : null;
              if (ipWithMask != null) {
                if (ipWithMask.contains('/')) {
                  serverIP = ipWithMask.split('/')[0];
                } else {
                  serverIP = ipWithMask;
                }
                final portMatch = RegExp(r'scaffolding-mc-server-(\d+)').firstMatch(hostname);
                if (portMatch != null && portMatch.groupCount >= 1) {
                  serverPort = int.tryParse(portMatch.group(1)!);
                }
                LogUtil.log('在EasyTier网络中发现服务器: $serverIP:$serverPort (主机名: $hostname)', level: 'INFO');
                break;
              }
            }
          }
          if (serverIP != null && serverPort != null) break;
        }
        if (serverIP != null && serverPort != null) {
          LogUtil.log('尝试连接到发现的服务器: $serverIP:$serverPort', level: 'INFO');
          setState(() {
            _ipAddress = serverIP;
            MemberPage._persistIpAddress = serverIP;
          });
          _connectToFoundServer(serverIP, serverPort);
        } else {
          LogUtil.log('未能从EasyTier网络中找到服务器', level: 'WARN');
        }
      } else {
        LogUtil.log('easytier-cli peer命令失败: ${result.stderr}', level: 'ERROR');
      }
    } catch (e) {
      LogUtil.log('执行peers检测时出错: $e', level: 'ERROR');
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

  // 连接到在EasyTier网络中发现的服务器
  Future<void> _connectToFoundServer(String serverIP, int serverPort) async {
    try {
      LogUtil.log('正在连接到EasyTier网络中发现的服务器: $serverIP:$serverPort', level: 'INFO');
      if (mounted) {
        setState(() {
          _isConnecting = true;
        });
      }
      final appVersion = await _loadAppVersion();
      final coreVersion = await _checkCoreVersion();
      _client = OnlineCenterClient(
        serverAddress: serverIP,
        serverPort: serverPort,
        playerName: _playerName ?? 'Guest',
        machineId: _machineId ?? const Uuid().v4(),
        vendor: 'FML $appVersion, EasyTier v$coreVersion',
        useIP: true,
      );
      await _client!.connect();
      _setupClientListeners();
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        MemberPage._persistIsConnected = true;
        MemberPage._persistClient = _client;
        MemberPage._persistNetworkName = _networkName;
        MemberPage._persistNetworkKey = _networkKey;
        LogUtil.log('成功连接到EasyTier网络中发现的服务器', level: 'INFO');
        
        // 如果已经有Minecraft端口信息，立即启动FakeServer
        if (_minecraftServerPort != null) {
          _startFakeServer();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已连接到房间')),
        );
      }
    } catch (e) {
      LogUtil.log('连接到EasyTier网络中发现的服务器失败: $e', level: 'ERROR');
      _client?.disconnect();
      _client = null;
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // 连接到房间
  Future<void> _connectToRoom() async {
    if (!_isValidCode || _networkName == null || _networkKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的房间码')),
      );
      return;
    }
    setState(() {
      _isConnecting = true;
    });
    final easyTierStarted = await _startEasyTier();
    if (!easyTierStarted) {
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('启动EasyTier失败')),
      );
      return;
    }
    _detectPeers();
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 10), (timer) {
      attempts++;
      if (!mounted || _isConnected) {
        timer.cancel();
        return;
      }
      if (attempts < 9) {
        LogUtil.log('第$attempts次尝试检测peers...', level: 'INFO');
        _detectPeers();
      } else {
        timer.cancel();
        if (mounted && !_isConnected) {
          setState(() {
            _isConnecting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('连接超时，请检查房间码是否正确，或者房主是否已创建房间'),
              duration: Duration(seconds: 8),
            ),
          );
          _stopEasyTier();
        }
      }
    });
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _isConnecting && !_isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接需要较长时间，正在建立网络连接...'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }

  // 断开连接
  Future<void> _disconnect() async {
    _minecraftLaunchTimer?.cancel();
    
    // 停止FakeServer
    await _stopFakeServer();
    
    if (_client != null) {
      try {
        await _client?.disconnect();
      } catch (e) {
        LogUtil.log('关闭客户端连接时出错: $e', level: 'ERROR');
      }
      _client = null;
    }
    await _stopEasyTier();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _players = [];
        _minecraftServerPort = null;
        _ipAddress = null;
      });
    }
    MemberPage._persistIsConnected = false;
    MemberPage._persistIsEasyTierRunning = false;
    MemberPage._persistEasyTierProcess = null;
    MemberPage._persistNetworkName = null;
    MemberPage._persistNetworkKey = null;
    MemberPage._persistClient = null;
    MemberPage._persistPlayers = [];
    MemberPage._persistMinecraftServerPort = null;
    MemberPage._persistIpAddress = null;
    MemberPage._persistFakeServer = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已断开连接')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('加入房间'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isConnected ? _buildConnectedView() : _buildConnectForm(),
        ),
        floatingActionButton: _isConnected
            ? FloatingActionButton(
                onPressed: _disconnect,
                tooltip: '断开连接',
                child: const Icon(Icons.logout),
              )
            : FloatingActionButton(
                onPressed: _isConnecting ? null : _connectToRoom,
                tooltip: '连接到房间',
                child: _isConnecting
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.login),
            ),
      ),
    );
  }

  Widget _buildConnectForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入房间邀请码',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '房间码 (格式: U/XXXX-XXXX-XXXX-XXXX)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                  ),
                  maxLength: 21,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z/-]')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('网络名称: $_networkName'),
                Text('网络密钥: $_networkKey'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接到房间',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle),
                    const SizedBox(width: 8),
                    Text('状态: 已连接'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Minecraft服务器地址'),
            subtitle: Text('$_ipAddress:$_minecraftServerPort'),
            leading: const Icon(Icons.dns),
            trailing: const Icon(Icons.copy),
            onTap: () {
              Clipboard.setData(ClipboardData(text: '$_ipAddress:$_minecraftServerPort'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板')),
              );
            },
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '房间内玩家',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_players.isEmpty) const Text('加载玩家列表...'),
                ..._players.map((player) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
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
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}