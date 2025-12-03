import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:system_info2/system_info2.dart';
import 'package:flutter/foundation.dart';

// 在后台线程中执行的提取
class _ExtractParams {
  final String jarDir;
  final String jarName;
  final String outDir;
  final String os;
  final String kernelArch;
  _ExtractParams({
    required this.jarDir,
    required this.jarName,
    required this.outDir,
    required this.os,
    required this.kernelArch,
  });
}

// 在后台线程中执行提取
List<String> _extractNativesInIsolate(_ExtractParams params) {
  final jarName = params.jarName;
  final jarDir = params.jarDir;
  final outDir = params.outDir;
  final os = params.os;
  final kernelArch = params.kernelArch;
  final lowerName = jarName.toLowerCase();
  bool matches = true;
  final hasPlatformSuffix = lowerName.contains('macos') || lowerName.contains('linux') || lowerName.contains('windows');
  if (hasPlatformSuffix) {
    // macos-arm64
    if (lowerName.contains('macos-arm64')) {
      matches = (os == 'macos' && kernelArch.contains('arm'));
    } else if (lowerName.contains('macos')) {
      // macOS x86
      matches = (os == 'macos' && !kernelArch.contains('arm'));
    } else if (lowerName.contains('linux')) {
      // Linux
      matches = (os == 'linux');
    } else if (lowerName.contains('windows')) {
      // Windows
      if (lowerName.contains('windows-')) {
        matches = false;
      } else {
        matches = (os == 'windows');
      }
    } else {
      matches = false;
    }
  }
  if (!matches) {
    return <String>[];
  }
  final jarPath = p.join(jarDir, jarName);
  final jarFile = File(jarPath);
  if (!jarFile.existsSync()) {
    throw Exception('Jar 文件不存在: $jarPath');
  }
  final bytes = jarFile.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final outDirectory = Directory(outDir);
  if (!outDirectory.existsSync()) {
    outDirectory.createSync(recursive: true);
  }
  final List<String> extracted = [];
  for (final file in archive) {
    if (!file.isFile) continue;
    final name = file.name;
    final lower = name.toLowerCase();
    final isNative =
        name.contains('natives/') || lower.endsWith('.so') || lower.endsWith('.dll') || lower.endsWith('.dylib') || lower.endsWith('.jnilib');
    if (!isNative) continue;
    final outName = name.split('/').last;
    final outPath = '${outDirectory.path}${Platform.pathSeparator}$outName';
    final outFile = File(outPath);
    outFile.writeAsBytesSync(file.content as List<int>);
    extracted.add(outFile.path);
  }
  return extracted;
}

// 提取natives库
Future<List<String>> extractNatives(String jarDir, String jarName, String outDir) async {
  final os = Platform.operatingSystem.toLowerCase();
  final kernelArch = SysInfo.kernelArchitecture.name.toLowerCase();
  final params = _ExtractParams(
    jarDir: jarDir,
    jarName: jarName,
    outDir: outDir,
    os: os,
    kernelArch: kernelArch,
  );
  return await compute(_extractNativesInIsolate, params);
}
