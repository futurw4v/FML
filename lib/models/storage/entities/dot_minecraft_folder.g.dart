// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dot_minecraft_folder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DotMinecraftFolder _$DotMinecraftFolderFromJson(Map<String, dynamic> json) =>
    _DotMinecraftFolder(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      selectedVersionFolderName:
          json['selectedVersionFolderName'] as String? ?? '',
      versions:
          (json['versions'] as List<dynamic>?)
              ?.map((e) => MinecraftGame.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DotMinecraftFolderToJson(_DotMinecraftFolder instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'selectedVersionFolderName': instance.selectedVersionFolderName,
      'versions': instance.versions,
    };
