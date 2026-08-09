import 'package:fmcl/models/storage/entities/dot_minecraft_folder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'paths_config.freezed.dart';
part 'paths_config.g.dart';

/// 与 configs/paths.json 对应
@freezed
abstract class PathsConfig with _$PathsConfig {
  const PathsConfig._();

  const factory PathsConfig({
    /// 配置的版本
    @Default(1) int version,

    /// 选择的 .minecraft 文件夹的路径
    @Default('') String selectedFolderPath,

    /// 所有 .minecraft 文件夹
    @Default([]) List<DotMinecraftFolder> paths,
  }) = _PathsConfig;

  /// 通过路径获取 .minecraft 文件夹
  DotMinecraftFolder? getFolderByPath(String targetPath) {
    if (targetPath.isEmpty) return null;
    try {
      return paths.firstWhere((folder) => folder.path == targetPath);
    } catch (_) {
      return null;
    }
  }

  /// 获取所选的 .minecraft 文件夹
  DotMinecraftFolder? get selectedFolder => getFolderByPath(selectedFolderPath);

  factory PathsConfig.fromJson(Map<String, dynamic> json) =>
      _$PathsConfigFromJson(json);
}
