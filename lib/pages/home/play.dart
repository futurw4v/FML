import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fml/function/log.dart';
import 'package:fml/function/launcher/fabric.dart';
import 'package:fml/function/launcher/vanilla.dart';
import 'package:fml/function/launcher/neoforge.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  PlayPageState createState() => PlayPageState();
}

class PlayPageState extends State<PlayPage> {
  String _gameType = '';
  // 启动进度
  bool _preparingLaunch = false;
  bool _gettingGameParams = false;
  bool _gettingFabricParams = false;
  bool _buildingPaths = false;
  bool _buildingFabricLibs = false;
  bool _preparingASM = false;
  bool _buildingDependencies = false;
  bool _checkingFiles = false;
  bool _gettingAccount = false;
  bool _buildingArgs = false;
  bool _launching = false;

  Future<void> _launch() async {
    final prefs = await SharedPreferences.getInstance();
    String? selectedPath = prefs.getString('SelectedPath');
    String? selectedGame = prefs.getString('SelectedGame');
    List<String>? gameConfig = prefs.getStringList('Config_${selectedPath}_$selectedGame');
    String? type = gameConfig != null ? gameConfig[4] : null;
    LogUtil.log(gameConfig.toString(), level: 'INFO');
    LogUtil.log(type.toString(), level: 'INFO');
    setState(() {
      _gameType = type ?? '';
    });
    if (type == 'Vanilla'){
      vanillaLauncher();
    }
    if (type == 'Fabric') {
      await fabricLauncher(
        onProgress: (String message) {
          setState(() {
            // 根据消息更新对应的状态
            switch (message) {
              case '正在准备启动':
                _preparingLaunch = true;
                break;
              case '正在获取游戏参数':
                _gettingGameParams = true;
                break;
              case '正在获取Fabric参数':
                _gettingFabricParams = true;
                break;
              case '正在构建路径':
                _buildingPaths = true;
                break;
              case '正在构建Fabric依赖库路径':
                _buildingFabricLibs = true;
                break;
              case '正在准备ASM组件':
                _preparingASM = true;
                break;
              case '正在构建依赖':
                _buildingDependencies = true;
                break;
              case '正在检查文件完整性':
                _checkingFiles = true;
                break;
              case '正在获取账号信息':
                _gettingAccount = true;
                break;
              case '正在构建启动参数':
                _buildingArgs = true;
                break;
              case '正在启动游戏':
                _launching = true;
                break;
            }
          });
        },
        onError: (String error) {
          setState(() {
          });
        },
      );
    }
    if (type == 'NeoForge') {
      neoforgeLauncher();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('正在启动$_gameType')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('准备启动'),
              subtitle: Text(_preparingLaunch ? '完成' : '准备中...'),
              trailing: _preparingLaunch
                ? const Icon(Icons.check)
                : const CircularProgressIndicator(),
            ),
          ),
          if (_preparingLaunch) ...[
            Card(
              child: ListTile(
                title: const Text('获取游戏参数'),
                subtitle: Text(_gettingGameParams ? '完成' : '获取中...'),
                trailing: _gettingGameParams
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_gettingGameParams) ...[
            Card(
              child: ListTile(
                title: const Text('获取Fabric参数'),
                subtitle: Text(_gettingFabricParams ? '完成' : '获取中...'),
                trailing: _gettingFabricParams
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (
            (_gameType == 'Vanilla' && _gettingGameParams) ||
            (_gameType == 'Fabric' && _gettingFabricParams)
          ) ...[
            Card(
              child: ListTile(
                title: const Text('构建路径'),
                subtitle: Text(_buildingPaths ? '完成' : '构建中...'),
                trailing: _buildingPaths
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_gameType == 'Fabric' && _buildingPaths) ...[
            Card(
              child: ListTile(
                title: const Text('构建Fabric依赖库路径'),
                subtitle: Text(_buildingFabricLibs ? '完成' : '构建中...'),
                trailing: _buildingFabricLibs
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_gameType == 'Fabric' && _buildingFabricLibs) ...[
            Card(
              child: ListTile(
                title: const Text('准备ASM组件'),
                subtitle: Text(_preparingASM ? '完成' : '准备中...'),
                trailing: _preparingASM
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_preparingASM) ...[
            Card(
              child: ListTile(
                title: const Text('构建依赖'),
                subtitle: Text(_buildingDependencies ? '完成' : '构建中...'),
                trailing: _buildingDependencies
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_buildingDependencies) ...[
            Card(
              child: ListTile(
                title: const Text('检查文件完整性'),
                subtitle: Text(_checkingFiles ? '完成' : '检查中...'),
                trailing: _checkingFiles
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_checkingFiles) ...[
            Card(
              child: ListTile(
                title: const Text('获取账号信息'),
                subtitle: Text(_gettingAccount ? '完成' : '获取中...'),
                trailing: _gettingAccount
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_gettingAccount) ...[
            Card(
              child: ListTile(
                title: const Text('构建启动参数'),
                subtitle: Text(_buildingArgs ? '完成' : '构建中...'),
                trailing: _buildingArgs
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
          if (_buildingArgs) ...[
            Card(
              child: ListTile(
                title: const Text('正在启动游戏'),
                subtitle: Text(_launching ? '完成' : '启动中...'),
                trailing: _launching
                  ? const Icon(Icons.check)
                  : const CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _launching
      ? FloatingActionButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Icon(Icons.check),
          )
        : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _launch();
  }
}