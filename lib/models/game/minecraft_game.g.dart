// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minecraft_game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MinecraftGame _$MinecraftGameFromJson(Map<String, dynamic> json) =>
    _MinecraftGame(
      id: json['id'] as String,
      folderName: json['folderName'] as String,
      type: $enumDecode(_$MinecraftVersionTypeEnumMap, json['type']),
      modLoaderType: $enumDecode(_$ModLoaderTypeEnumMap, json['modLoaderType']),
      assetsIndexId: json['assetsIndexId'] as String,
      javaExecutablePath: json['javaExecutablePath'] as String? ?? '',
      mainClass:
          json['mainClass'] as String? ?? 'net.minecraft.client.main.Main',
    );

Map<String, dynamic> _$MinecraftGameToJson(_MinecraftGame instance) =>
    <String, dynamic>{
      'id': instance.id,
      'folderName': instance.folderName,
      'type': _$MinecraftVersionTypeEnumMap[instance.type]!,
      'modLoaderType': _$ModLoaderTypeEnumMap[instance.modLoaderType]!,
      'assetsIndexId': instance.assetsIndexId,
      'javaExecutablePath': instance.javaExecutablePath,
      'mainClass': instance.mainClass,
    };

const _$MinecraftVersionTypeEnumMap = {
  MinecraftVersionType.release: 'release',
  MinecraftVersionType.snapshot: 'snapshot',
  MinecraftVersionType.oldBeta: 'oldBeta',
  MinecraftVersionType.oldAlpha: 'oldAlpha',
  MinecraftVersionType.unknown: 'unknown',
};

const _$ModLoaderTypeEnumMap = {
  ModLoaderType.vanilla: 'vanilla',
  ModLoaderType.forge: 'forge',
  ModLoaderType.neoforge: 'neoforge',
  ModLoaderType.fabric: 'fabric',
};
