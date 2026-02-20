import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fml/constants.dart';
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
  late Future<List<JavaRuntime>> _javaRuntimesFuture;
  late Future<JavaInfo?> _systemDefaultJavaInfo;

  String? _currentJavaPath;

  static final RegExp _vendorVersionRegExp = RegExp(
    r'(?:(OpenJDK|java|IBM|AdoptOpenJDK|Microsoft).*?)?version\s+"([^"]+)"',
    caseSensitive: false,
  );

  static final RegExp _fallbackVersionRegExp = RegExp(r'"([0-9._-]+)"');

  // 每个设置间的间距
  static const _itemsPadding = Padding(
    padding: EdgeInsets.symmetric(vertical: kDefaultPadding / 2),
  );

  @override
  void initState() {
    super.initState();
    _getCurrentJavaPathFromPrefs();
    _refresh();
  }

  ///
  /// 刷新 Java 列表与系统默认 Java
  ///
  Future<void> _refresh() async {
    setState(() {
      _systemDefaultJavaInfo = _getSystemDefaultJavaInfo();
      _javaRuntimesFuture = JavaManager.searchPotentialJavaExecutables();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // 大标题
          Padding(
            padding: const EdgeInsets.only(
              left: kDefaultPadding / 2,
              top: kDefaultPadding,
              bottom: kDefaultPadding,
            ),
            child: Text(
              '设备上的Java列表',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),

          _itemsPadding,

          // 确保FutureBuilder占满剩余空间
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _systemDefaultJavaInfo,
                _javaRuntimesFuture,
              ]),

              builder: (context, snapshot) {
                // 加载中显示CircularProgressIndicator
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 加载失败显示错误信息
                // TODO: 包装一个表示错误的组件
                if (snapshot.hasError) {
                  return Center(child: Text('检测失败：${snapshot.error}'));
                }

                // Index0: _systemDefaultJavaInfo 的结果（JavaInfo?）
                // Index1: _javaRuntimesFuture 的结果（List<JavaRuntime>）
                final results = snapshot.data ?? [];

                // 提取系统默认 Java 信息
                final JavaInfo? systemJava = results.isNotEmpty
                    ? results[0] as JavaInfo?
                    : null;

                // 检测系统默认Java是否存在
                final systemJavaExists = systemJava != null;

                // 提取扫描到的Java运行时列表
                List<JavaRuntime> javaRuntimes = [];
                if (results.length > 1) {
                  javaRuntimes = (results[1] as List).cast<JavaRuntime>();
                }

                final totalItems = systemJavaExists
                    ? javaRuntimes.length + 1
                    : javaRuntimes.length;

                if (totalItems == 0) {
                  return const Center(child: Text('未检测到 Java'));
                }

                return ListView.separated(
                  itemCount: totalItems,

                  separatorBuilder: (_, _) => const Divider(height: 1),

                  itemBuilder: (context, index) {
                    if (systemJavaExists && index == 0) {
                      final info = systemJava;
                      // 当为系统默认时构建Card
                      return Card(
                        // 裁剪掉ListTile超出圆角的部分
                        clipBehavior: Clip.antiAlias,

                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: ListTile(
                          title: Text(info.version),

                          subtitle: Text(
                            info.path.isNotEmpty ? info.path : '路径未知',
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Chip(label: Text('系统默认')),

                              const SizedBox(width: kDefaultPadding / 2),

                              Chip(label: Text(info.vendor ?? 'Unknown')),
                            ],
                          ),

                          onTap: () => _setSystemJava(),
                        ),
                      );
                    }

                    // 构建非系统默认的Java的卡片
                    final realIndex = systemJavaExists ? index - 1 : index;
                    return _buildJavaItem(javaRuntimes[realIndex]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ///
  /// 从SharedPreferences读取选择的Java
  ///
  Future<void> _getCurrentJavaPathFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _currentJavaPath = prefs.getString('java');
    });
  }

  ///
  /// 写入当前 Java
  ///
  Future<void> _setCurrentJavaPathToPrefs(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('java', path);

    setState(() {
      _currentJavaPath = path;
    });
  }

  ///
  /// 设置为系统 Java
  ///
  Future<void> _setSystemJava() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('java');

    setState(() {
      _currentJavaPath = 'java';
    });
  }

  //
  // 获取系统默认 Java 信息
  //
  Future<JavaInfo?> _getSystemDefaultJavaInfo() async {
    try {
      final javaVersionProcess = await Process.run('java', ['-version']);

      if (javaVersionProcess.exitCode != 0) {
        LogUtil.log(
          '获取系统默认 Java 信息失败，退出码：${javaVersionProcess.exitCode}',
          level: 'WARN',
        );
      }

      final versionOutput = (javaVersionProcess.stderr as String).isNotEmpty
          ? javaVersionProcess.stderr as String
          : javaVersionProcess.stdout as String;

      final parsedVersion = _parseVersionOutput(versionOutput);

      if (parsedVersion == null) {
        LogUtil.log('无法解析系统默认 Java 版本信息', level: 'WARN');
        return null;
      }

      String executablePath = '';

      try {
        if (Platform.isWindows) {
          final where = await Process.run('where', ['java']);

          if (where.exitCode == 0) {
            executablePath = (where.stdout as String)
                .toString()
                .split('\n')
                .first
                .trim();
          }
        } else {
          final which = await Process.run('which', ['java']);

          if (which.exitCode == 0) {
            executablePath = (which.stdout as String)
                .toString()
                .split('\n')
                .first
                .trim();
          }
        }
      } catch (e) {
        LogUtil.log('获取系统默认 Java 路径时出错：$e', level: 'WARN');
      }

      return JavaInfo(
        version: parsedVersion['version'] ?? 'unknown',
        vendor: parsedVersion['vendor'],
        path: executablePath,
        os: Platform.operatingSystem,
        arch: Platform.version,
      );
    } catch (e) {
      LogUtil.log('执行 "java -version" 时出错：$e', level: 'WARN');
      return null;
    }
  }

  ///
  /// 解析 "java -version" 输出
  ///
  static Map<String, String?>? _parseVersionOutput(String output) {
    // 分割每行
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) continue;

      final matches = _vendorVersionRegExp.firstMatch(trimmedLine);

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

      final fallbackMatch = _fallbackVersionRegExp.firstMatch(line);

      if (fallbackMatch != null) {
        return {'version': fallbackMatch.group(1) ?? '', 'vendor': null};
      }
    }
    return null;
  }

  ///
  /// 构建 Java 条目
  ///
  Widget _buildJavaItem(JavaRuntime javaRuntime) {
    return Card(
      // 裁剪掉ListTile超出圆角的部分
      clipBehavior: Clip.antiAlias,

      elevation: 0,

      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),

      margin: const EdgeInsets.symmetric(
        horizontal: kDefaultPadding,
        vertical: kDefaultPadding / 2,
      ),

      color: javaRuntime.executable == _currentJavaPath
          ? Theme.of(context).colorScheme.primaryContainer
          : null,

      child: ListTile(
        title: Text(javaRuntime.info.version),

        subtitle: Text(javaRuntime.executable),

        isThreeLine: true,

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(javaRuntime.isJdk ? 'JDK' : 'JRE')),
            SizedBox(width: kDefaultPadding / 2),
            Chip(label: Text(javaRuntime.info.vendor ?? 'Unknown')),
          ],
        ),

        onTap: () => _setCurrentJavaPathToPrefs(javaRuntime.executable),
      ),
    );
  }
}
