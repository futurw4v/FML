// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'minecraft_game.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MinecraftGame {

/// UI显示的名称
 String get label;/// 版本JSON内的原生ID
 String get id;/// 真实的文件夹名字
 String get folderName; MinecraftVersionType get type; ModLoaderType get modLoaderType; String get assetsIndexId;// 留空为全局默认
 String get javaExecutablePath; String get mainClass;
/// Create a copy of MinecraftGame
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MinecraftGameCopyWith<MinecraftGame> get copyWith => _$MinecraftGameCopyWithImpl<MinecraftGame>(this as MinecraftGame, _$identity);

  /// Serializes this MinecraftGame to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MinecraftGame&&(identical(other.label, label) || other.label == label)&&(identical(other.id, id) || other.id == id)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.type, type) || other.type == type)&&(identical(other.modLoaderType, modLoaderType) || other.modLoaderType == modLoaderType)&&(identical(other.assetsIndexId, assetsIndexId) || other.assetsIndexId == assetsIndexId)&&(identical(other.javaExecutablePath, javaExecutablePath) || other.javaExecutablePath == javaExecutablePath)&&(identical(other.mainClass, mainClass) || other.mainClass == mainClass));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,id,folderName,type,modLoaderType,assetsIndexId,javaExecutablePath,mainClass);

@override
String toString() {
  return 'MinecraftGame(label: $label, id: $id, folderName: $folderName, type: $type, modLoaderType: $modLoaderType, assetsIndexId: $assetsIndexId, javaExecutablePath: $javaExecutablePath, mainClass: $mainClass)';
}


}

/// @nodoc
abstract mixin class $MinecraftGameCopyWith<$Res>  {
  factory $MinecraftGameCopyWith(MinecraftGame value, $Res Function(MinecraftGame) _then) = _$MinecraftGameCopyWithImpl;
@useResult
$Res call({
 String label, String id, String folderName, MinecraftVersionType type, ModLoaderType modLoaderType, String assetsIndexId, String javaExecutablePath, String mainClass
});




}
/// @nodoc
class _$MinecraftGameCopyWithImpl<$Res>
    implements $MinecraftGameCopyWith<$Res> {
  _$MinecraftGameCopyWithImpl(this._self, this._then);

  final MinecraftGame _self;
  final $Res Function(MinecraftGame) _then;

/// Create a copy of MinecraftGame
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? id = null,Object? folderName = null,Object? type = null,Object? modLoaderType = null,Object? assetsIndexId = null,Object? javaExecutablePath = null,Object? mainClass = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MinecraftVersionType,modLoaderType: null == modLoaderType ? _self.modLoaderType : modLoaderType // ignore: cast_nullable_to_non_nullable
as ModLoaderType,assetsIndexId: null == assetsIndexId ? _self.assetsIndexId : assetsIndexId // ignore: cast_nullable_to_non_nullable
as String,javaExecutablePath: null == javaExecutablePath ? _self.javaExecutablePath : javaExecutablePath // ignore: cast_nullable_to_non_nullable
as String,mainClass: null == mainClass ? _self.mainClass : mainClass // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MinecraftGame].
extension MinecraftGamePatterns on MinecraftGame {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MinecraftGame value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MinecraftGame() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MinecraftGame value)  $default,){
final _that = this;
switch (_that) {
case _MinecraftGame():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MinecraftGame value)?  $default,){
final _that = this;
switch (_that) {
case _MinecraftGame() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  String id,  String folderName,  MinecraftVersionType type,  ModLoaderType modLoaderType,  String assetsIndexId,  String javaExecutablePath,  String mainClass)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MinecraftGame() when $default != null:
return $default(_that.label,_that.id,_that.folderName,_that.type,_that.modLoaderType,_that.assetsIndexId,_that.javaExecutablePath,_that.mainClass);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  String id,  String folderName,  MinecraftVersionType type,  ModLoaderType modLoaderType,  String assetsIndexId,  String javaExecutablePath,  String mainClass)  $default,) {final _that = this;
switch (_that) {
case _MinecraftGame():
return $default(_that.label,_that.id,_that.folderName,_that.type,_that.modLoaderType,_that.assetsIndexId,_that.javaExecutablePath,_that.mainClass);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  String id,  String folderName,  MinecraftVersionType type,  ModLoaderType modLoaderType,  String assetsIndexId,  String javaExecutablePath,  String mainClass)?  $default,) {final _that = this;
switch (_that) {
case _MinecraftGame() when $default != null:
return $default(_that.label,_that.id,_that.folderName,_that.type,_that.modLoaderType,_that.assetsIndexId,_that.javaExecutablePath,_that.mainClass);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MinecraftGame implements MinecraftGame {
  const _MinecraftGame({required this.label, required this.id, required this.folderName, required this.type, required this.modLoaderType, required this.assetsIndexId, this.javaExecutablePath = '', this.mainClass = 'net.minecraft.client.main.Main'});
  factory _MinecraftGame.fromJson(Map<String, dynamic> json) => _$MinecraftGameFromJson(json);

/// UI显示的名称
@override final  String label;
/// 版本JSON内的原生ID
@override final  String id;
/// 真实的文件夹名字
@override final  String folderName;
@override final  MinecraftVersionType type;
@override final  ModLoaderType modLoaderType;
@override final  String assetsIndexId;
// 留空为全局默认
@override@JsonKey() final  String javaExecutablePath;
@override@JsonKey() final  String mainClass;

/// Create a copy of MinecraftGame
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MinecraftGameCopyWith<_MinecraftGame> get copyWith => __$MinecraftGameCopyWithImpl<_MinecraftGame>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MinecraftGameToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MinecraftGame&&(identical(other.label, label) || other.label == label)&&(identical(other.id, id) || other.id == id)&&(identical(other.folderName, folderName) || other.folderName == folderName)&&(identical(other.type, type) || other.type == type)&&(identical(other.modLoaderType, modLoaderType) || other.modLoaderType == modLoaderType)&&(identical(other.assetsIndexId, assetsIndexId) || other.assetsIndexId == assetsIndexId)&&(identical(other.javaExecutablePath, javaExecutablePath) || other.javaExecutablePath == javaExecutablePath)&&(identical(other.mainClass, mainClass) || other.mainClass == mainClass));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,id,folderName,type,modLoaderType,assetsIndexId,javaExecutablePath,mainClass);

@override
String toString() {
  return 'MinecraftGame(label: $label, id: $id, folderName: $folderName, type: $type, modLoaderType: $modLoaderType, assetsIndexId: $assetsIndexId, javaExecutablePath: $javaExecutablePath, mainClass: $mainClass)';
}


}

/// @nodoc
abstract mixin class _$MinecraftGameCopyWith<$Res> implements $MinecraftGameCopyWith<$Res> {
  factory _$MinecraftGameCopyWith(_MinecraftGame value, $Res Function(_MinecraftGame) _then) = __$MinecraftGameCopyWithImpl;
@override @useResult
$Res call({
 String label, String id, String folderName, MinecraftVersionType type, ModLoaderType modLoaderType, String assetsIndexId, String javaExecutablePath, String mainClass
});




}
/// @nodoc
class __$MinecraftGameCopyWithImpl<$Res>
    implements _$MinecraftGameCopyWith<$Res> {
  __$MinecraftGameCopyWithImpl(this._self, this._then);

  final _MinecraftGame _self;
  final $Res Function(_MinecraftGame) _then;

/// Create a copy of MinecraftGame
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? id = null,Object? folderName = null,Object? type = null,Object? modLoaderType = null,Object? assetsIndexId = null,Object? javaExecutablePath = null,Object? mainClass = null,}) {
  return _then(_MinecraftGame(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,folderName: null == folderName ? _self.folderName : folderName // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MinecraftVersionType,modLoaderType: null == modLoaderType ? _self.modLoaderType : modLoaderType // ignore: cast_nullable_to_non_nullable
as ModLoaderType,assetsIndexId: null == assetsIndexId ? _self.assetsIndexId : assetsIndexId // ignore: cast_nullable_to_non_nullable
as String,javaExecutablePath: null == javaExecutablePath ? _self.javaExecutablePath : javaExecutablePath // ignore: cast_nullable_to_non_nullable
as String,mainClass: null == mainClass ? _self.mainClass : mainClass // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
