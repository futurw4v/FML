import 'dart:io';

import 'package:fmcl/models/game/minecraft_game.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;

part 'dot_minecraft_folder.freezed.dart';
part 'dot_minecraft_folder.g.dart';

@freezed
abstract class DotMinecraftFolder with _$DotMinecraftFolder {
  const DotMinecraftFolder._();

  const factory DotMinecraftFolder({
    /// UI 上显示的名称
    @Default('') String name,

    /// 本地物理绝对路径
    @Default('') String path,

    @Default('') String selectedVersionFolderName,

    @Default([]) List<MinecraftGame> versions,
  }) = _DotMinecraftFolder;

  Future<void> ensureStructureExists() async {
    if (path.isEmpty) return;

    // .minecraft 目录下的文件夹
    final subFolders = ['assets', 'versions', 'libraries'];

    // 确保自身存在
    final rootDir = Directory(path);
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }

    // 创建所有子文件夹
    for (final sub in subFolders) {
      final dir = Directory(p.join(path, sub));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  factory DotMinecraftFolder.fromJson(Map<String, dynamic> json) =>
      _$DotMinecraftFolderFromJson(json);
}
