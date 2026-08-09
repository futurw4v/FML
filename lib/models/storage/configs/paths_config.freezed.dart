// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paths_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PathsConfig {

/// 配置的版本
 int get version;/// 选择的 .minecraft 文件夹的路径
 String get selectedFolderPath;/// 所有 .minecraft 文件夹
 List<DotMinecraftFolder> get paths;
/// Create a copy of PathsConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PathsConfigCopyWith<PathsConfig> get copyWith => _$PathsConfigCopyWithImpl<PathsConfig>(this as PathsConfig, _$identity);

  /// Serializes this PathsConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PathsConfig&&(identical(other.version, version) || other.version == version)&&(identical(other.selectedFolderPath, selectedFolderPath) || other.selectedFolderPath == selectedFolderPath)&&const DeepCollectionEquality().equals(other.paths, paths));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,selectedFolderPath,const DeepCollectionEquality().hash(paths));

@override
String toString() {
  return 'PathsConfig(version: $version, selectedFolderPath: $selectedFolderPath, paths: $paths)';
}


}

/// @nodoc
abstract mixin class $PathsConfigCopyWith<$Res>  {
  factory $PathsConfigCopyWith(PathsConfig value, $Res Function(PathsConfig) _then) = _$PathsConfigCopyWithImpl;
@useResult
$Res call({
 int version, String selectedFolderPath, List<DotMinecraftFolder> paths
});




}
/// @nodoc
class _$PathsConfigCopyWithImpl<$Res>
    implements $PathsConfigCopyWith<$Res> {
  _$PathsConfigCopyWithImpl(this._self, this._then);

  final PathsConfig _self;
  final $Res Function(PathsConfig) _then;

/// Create a copy of PathsConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? selectedFolderPath = null,Object? paths = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,selectedFolderPath: null == selectedFolderPath ? _self.selectedFolderPath : selectedFolderPath // ignore: cast_nullable_to_non_nullable
as String,paths: null == paths ? _self.paths : paths // ignore: cast_nullable_to_non_nullable
as List<DotMinecraftFolder>,
  ));
}

}


/// Adds pattern-matching-related methods to [PathsConfig].
extension PathsConfigPatterns on PathsConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PathsConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PathsConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PathsConfig value)  $default,){
final _that = this;
switch (_that) {
case _PathsConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PathsConfig value)?  $default,){
final _that = this;
switch (_that) {
case _PathsConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String selectedFolderPath,  List<DotMinecraftFolder> paths)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PathsConfig() when $default != null:
return $default(_that.version,_that.selectedFolderPath,_that.paths);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String selectedFolderPath,  List<DotMinecraftFolder> paths)  $default,) {final _that = this;
switch (_that) {
case _PathsConfig():
return $default(_that.version,_that.selectedFolderPath,_that.paths);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String selectedFolderPath,  List<DotMinecraftFolder> paths)?  $default,) {final _that = this;
switch (_that) {
case _PathsConfig() when $default != null:
return $default(_that.version,_that.selectedFolderPath,_that.paths);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PathsConfig extends PathsConfig {
  const _PathsConfig({this.version = 1, this.selectedFolderPath = '', final  List<DotMinecraftFolder> paths = const []}): _paths = paths,super._();
  factory _PathsConfig.fromJson(Map<String, dynamic> json) => _$PathsConfigFromJson(json);

/// 配置的版本
@override@JsonKey() final  int version;
/// 选择的 .minecraft 文件夹的路径
@override@JsonKey() final  String selectedFolderPath;
/// 所有 .minecraft 文件夹
 final  List<DotMinecraftFolder> _paths;
/// 所有 .minecraft 文件夹
@override@JsonKey() List<DotMinecraftFolder> get paths {
  if (_paths is EqualUnmodifiableListView) return _paths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paths);
}


/// Create a copy of PathsConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PathsConfigCopyWith<_PathsConfig> get copyWith => __$PathsConfigCopyWithImpl<_PathsConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PathsConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PathsConfig&&(identical(other.version, version) || other.version == version)&&(identical(other.selectedFolderPath, selectedFolderPath) || other.selectedFolderPath == selectedFolderPath)&&const DeepCollectionEquality().equals(other._paths, _paths));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,selectedFolderPath,const DeepCollectionEquality().hash(_paths));

@override
String toString() {
  return 'PathsConfig(version: $version, selectedFolderPath: $selectedFolderPath, paths: $paths)';
}


}

/// @nodoc
abstract mixin class _$PathsConfigCopyWith<$Res> implements $PathsConfigCopyWith<$Res> {
  factory _$PathsConfigCopyWith(_PathsConfig value, $Res Function(_PathsConfig) _then) = __$PathsConfigCopyWithImpl;
@override @useResult
$Res call({
 int version, String selectedFolderPath, List<DotMinecraftFolder> paths
});




}
/// @nodoc
class __$PathsConfigCopyWithImpl<$Res>
    implements _$PathsConfigCopyWith<$Res> {
  __$PathsConfigCopyWithImpl(this._self, this._then);

  final _PathsConfig _self;
  final $Res Function(_PathsConfig) _then;

/// Create a copy of PathsConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? selectedFolderPath = null,Object? paths = null,}) {
  return _then(_PathsConfig(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,selectedFolderPath: null == selectedFolderPath ? _self.selectedFolderPath : selectedFolderPath // ignore: cast_nullable_to_non_nullable
as String,paths: null == paths ? _self._paths : paths // ignore: cast_nullable_to_non_nullable
as List<DotMinecraftFolder>,
  ));
}


}

// dart format on
