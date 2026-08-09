import 'package:fmcl/models/enums/minecraft_version_type.dart';
import 'package:fmcl/models/enums/mod_loader_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'minecraft_game.freezed.dart';
part 'minecraft_game.g.dart';

@freezed
abstract class MinecraftGame with _$MinecraftGame {
  const factory MinecraftGame({
    /// UI显示的名称
    required String label,

    /// 版本JSON内的原生ID
    required String id,

    /// 真实的文件夹名字
    required String folderName,

    required MinecraftVersionType type,
    required ModLoaderType modLoaderType,
    required String assetsIndexId,

    // 留空为全局默认
    @Default('') String javaExecutablePath,

    @Default('net.minecraft.client.main.Main') String mainClass,
  }) = _MinecraftGame;

  factory MinecraftGame.fromJson(Map<String, dynamic> json) =>
      _$MinecraftGameFromJson(json);
}
