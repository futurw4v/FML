import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fml/function/log.dart';
import 'package:fml/function/java/java_manager.dart';
import 'package:fml/function/java/models/java_info.dart';
import 'package:fml/function/java/models/java_runtime.dart';

class JavaPage extends StatefulWidget {
  const JavaPage({super.key});

  @override
  JavaPageState createState() => JavaPageState();
}

class JavaPageState extends State<JavaPage> {
  late Future<List<JavaRuntime>> _future;
  String? _currentJavaPath;
  late Future<JavaInfo?> _systemDefaultJavaInfo;

  @override
  void initState() {
    super.initState();
    _getCurrentJavaPath();
    _systemDefaultJavaInfo = _getSystemDefaultJavaInfo();
    _refresh();
  }

  // 当前选择 Java
  Future<void> _getCurrentJavaPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentJavaPath = prefs.getString('java');
    });
  }

  // 设置当前 Java
  Future<void> _setCurrentJavaPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('java', path);
    setState(() {
      _currentJavaPath = path;
    });
  }

  // 设置为系统 Java
  Future<void> _setSystemJava() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('java');
    setState(() {
      _currentJavaPath = 'java';
    });
  }

  // 获取系统默认 Java 信息
  Future<JavaInfo?> _getSystemDefaultJavaInfo() async {
    try {
      final result = await Process.run('java', ['-version']);
      if (result.exitCode != 0) {
        LogUtil.log('获取系统默认 Java 信息失败，退出码：${result.exitCode}', level: 'WARN');
      }
      final output = (result.stderr as String).isNotEmpty ? result.stderr as String : result.stdout as String;
      final parsed = _parseVersionOutput(output);
      if (parsed == null) {
        LogUtil.log('无法解析系统默认 Java 版本信息', level: 'WARN');
        return null;
      }
      String path = '';
      try {
        if (Platform.isWindows) {
          final where = await Process.run('where', ['java']);
          if (where.exitCode == 0) {
            path = (where.stdout as String).toString().split('\n').first.trim();
          }
        } else {
          final which = await Process.run('which', ['java']);
          if (which.exitCode == 0) {
            path = (which.stdout as String).toString().split('\n').first.trim();
          }
        }
      } catch (e) {
        LogUtil.log('获取系统默认 Java 路径时出错：$e', level: 'WARN');
      }
      return JavaInfo(
        version: parsed['version'] ?? 'unknown',
        vendor: parsed['vendor'],
        path: path,
        os: Platform.operatingSystem,
        arch: Platform.version,
      );
    } catch (e) {
      LogUtil.log('执行 "java -version" 时出错：$e', level: 'WARN');
      return null;
    }
  }

  // 解析 "java -version" 输出
  static Map<String, String?>? _parseVersionOutput(String out) {
    final lines = out.split('\n');
    for (final l in lines) {
      final s = l.trim();
      if (s.isEmpty) continue;
      final matches = RegExp(r'(?:(OpenJDK|java|IBM|AdoptOpenJDK|Microsoft).*?)?version\s+"([^"]+)"', caseSensitive: false).firstMatch(s);
      if (matches != null) {
        String? vendor;
        if (matches.group(1) == 'java') {
          vendor = 'Oracle';
        } else {
          vendor = matches.group(1);
        }
        final version = matches.group(2);
        return {'version': version ?? '', 'vendor': vendor};
      }
      final alt = RegExp(r'"([0-9._-]+)"').firstMatch(s);
      if (alt != null) return {'version': alt.group(1) ?? '', 'vendor': null};
    }
    return null;
  }

  // 刷新 Java 列表与系统默认 Java
  Future<void> _refresh() async {
    setState(() {
      _systemDefaultJavaInfo = _getSystemDefaultJavaInfo();
      _future = JavaManager.searchPotentialJavaExecutables();
    });
  }

  // 构建 Java 条目
  Widget _buildJavaItem(JavaRuntime javaRuntime) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: javaRuntime.executable == _currentJavaPath ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(javaRuntime.info.version),
        subtitle: Text(javaRuntime.executable),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(javaRuntime.isJdk ? 'JDK' : 'JRE')),
            SizedBox(width: 8),
            Chip(label: Text(javaRuntime.info.vendor ?? 'Unknown')),
          ],
        ),
        onTap: () => _setCurrentJavaPath(javaRuntime.executable)
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备上的 Java 列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_systemDefaultJavaInfo, _future]),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('检测失败：${snap.error}'));
          }
          final data = snap.data ?? [];
          final JavaInfo? sys = data.isNotEmpty ? data[0] as JavaInfo? : null;
          final List<JavaRuntime> list = data.length > 1 ? (data[1] as List).cast<JavaRuntime>() : [];
          final int sysCount = sys != null ? 1 : 0;
          final total = sysCount + list.length;
          if (total == 0) {
            return const Center(child: Text('未检测到 Java'));
          }
          return ListView.separated(
            itemCount: total,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (sysCount == 1 && index == 0) {
                final info = sys!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: _currentJavaPath == 'java' || _currentJavaPath == null ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: ListTile(
                    title: Text(info.version),
                    subtitle: Text(info.path.isNotEmpty ? info.path : '路径未知'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Chip(label: Text('系统默认')),
                        const SizedBox(width: 8),
                        Chip(label: Text(info.vendor ?? 'Unknown')),
                      ],
                    ),
                    onTap: () => _setSystemJava(),
                  ),
                );
              }
              final idx = index - sysCount;
              final jt = list[idx];
              return _buildJavaItem(jt);
            },
          );
        },
      ),
    );
  }
}