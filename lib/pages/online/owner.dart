import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fml/function/log.dart';
import 'package:fml/function/launcher/fabric.dart';

class OwnerPage extends StatefulWidget {
  final int port;
  const OwnerPage({super.key, required this.port});

  @override
  OwnerPageState createState() => OwnerPageState();
}

class OwnerPageState extends State<OwnerPage> {
  int _port = -1;
  StreamSubscription<int>? _lanPortSub;
  String? _roomCode;
  String? _networkName;
  String? _networkKey;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final cachedPort = getLastDetectedPort();
    if (cachedPort != null && cachedPort > 0) {
      setState(() {
        _port = cachedPort;
      });
      LogUtil.log('使用缓存的端口: $_port', level: 'INFO');
    }
    // 监听端口变化
    _lanPortSub = lanPortController.stream.listen((port) {
      if (!mounted) return;
      setState(() {
        _port = port;
      });
      if (port > 0) {
        LogUtil.log('收到新的端口事件: $_port', level: 'INFO');
      } else if (port == -1) {
        LogUtil.log('局域网游戏已关闭', level: 'INFO');
      }
    });
  }

  @override
  void dispose() {
    _lanPortSub?.cancel();
    super.dispose();
  }

  // 有效字符集（排除I和O）
  static const List<String> _validChars = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
    'W', 'X', 'Y', 'Z'
  ];

Future<void> _generateRoomCode() async {
  setState(() {
    _isGenerating = true;
  });

  final random = Random.secure();
  
  // 先生成前15位字符索引
  final List<int> charIndices = List.generate(15, (_) => random.nextInt(34));
  
  // 计算前15位的值（按小端序）
  // 小端序意味着索引0是最低位，索引15是最高位
  int partialValue = 0;
  
  for (int i = 0; i < 15; i++) {
    // 每一位的贡献是: charIndex * (34^i)
    int contribution = charIndices[i];
    for (int j = 0; j < i; j++) {
      contribution = (contribution * 34) % 7;
    }
    partialValue = (partialValue + contribution) % 7;
  }
  
  // 计算第16位（索引15）需要的值
  int remainder = partialValue % 7;
  int needed = (7 - remainder) % 7;
  
  // 计算第16位的权重: 34^15 mod 7
  int weight = 1;
  for (int i = 0; i < 15; i++) {
    weight = (weight * 34) % 7;
  }
  
  // 找到满足条件的第16位字符索引
  int lastCharIndex = 0;
  for (int i = 0; i < 34; i++) {
    if ((i * weight) % 7 == needed) {
      lastCharIndex = i;
      break;
    }
  }
  
  // 构建最终的16位字符串
  final List<String> chars = charIndices.map((i) => _validChars[i]).toList();
  chars.add(_validChars[lastCharIndex]);
  
  // 格式化为房间码
  final code = 'U/${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8, 12).join()}-${chars.sublist(12, 16).join()}';
  
  // 分割代码生成网络信息
  final parts = code.substring(2).split('-'); // 去掉 "U/" 前缀
  setState(() {
    _roomCode = code;
    _networkName = 'scaffolding-mc-${parts[0]}-${parts[1]}'; // NNNN-NNNN
    _networkKey = '${parts[2]}-${parts[3]}'; // SSSS-SSSS
    _isGenerating = false;
  });
  
  // 验证生成的代码（调试用）
  if (kDebugMode && !_isValidCode(code)) {
    LogUtil.log('生成的代码验证失败: $code', level: 'ERROR');
  } else {
    LogUtil.log('生成房间码: $_roomCode', level: 'INFO');
    LogUtil.log('网络名称: $_networkName', level: 'INFO');
    LogUtil.log('网络密钥: $_networkKey', level: 'INFO');
  }
}

bool _isValidCode(String code) {
  // 验证格式：U/NNNN-NNNN-SSSS-SSSS
  if (!RegExp(r'^U/[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}-[0-9A-HJ-NP-Z]{4}$')
      .hasMatch(code)) {
    return false;
  }

  // 去掉 "U/" 前缀和所有 "-"，得到16位字符串
  final codeContent = code.substring(2).replaceAll('-', '');
  
  // 按小端序计算整型值
  int value = 0;
  
  // 小端序：索引0是最低位
  for (int i = 0; i < codeContent.length; i++) {
    final charIndex = _validChars.indexOf(codeContent[i]);
    if (charIndex == -1) return false; // 无效字符
    
    // 第i位的贡献是: charIndex * (34^i) mod 7
    int contribution = charIndex;
    for (int j = 0; j < i; j++) {
      contribution = (contribution * 34) % 7;
    }
    value = (value + contribution) % 7;
  }
  
  // 检查是否能被7整除
  return value == 0;
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
                          Text('游戏端口: $_port', 
                            style: Theme.of(context).textTheme.titleLarge
                          ),
                          const SizedBox(height: 16),
                          if (_roomCode != null) ...[
                            const Text('房间码:'),
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
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                      text: '网络名称: $_networkName\n网络密钥: $_networkKey'
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('网络信息已复制到剪贴板'))
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: _isGenerating ? null : _generateRoomCode,
                              child: _isGenerating 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('生成房间码'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}