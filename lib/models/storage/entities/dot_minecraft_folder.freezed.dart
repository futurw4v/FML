// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dot_minecraft_folder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DotMinecraftFolder {

/// UI 上显示的名称
 String get name;/// 本地物理绝对路径
 String get path;/// 所选择的版本，游戏与文件夹同名，故为[selectedVersionFolderName]（所选版本的文件夹名）
 String get selectedVersionFolderName;/// 文件夹内所包含的游戏，此处使用[versions]与物理文件夹同名
 List<MinecraftGame> get versions;
/// Create a copy of DotMinecraftFolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DotMinecraftFolderCopyWith<DotMinecraftFolder> get copyWith => _$DotMinecraftFolderCopyWithImpl<DotMinecraftFolder>(this as DotMinecraftFolder, _$identity);

  /// Serializes this DotMinecraftFolder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DotMinecraftFolder&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.selectedVersionFolderName, selectedVersionFolderName) || other.selectedVersionFolderName == selectedVersionFolderName)&&const DeepCollectionEquality().equals(other.versions, versions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,selectedVersionFolderName,const DeepCollectionEquality().hash(versions));

@override
String toString() {
  return 'DotMinecraftFolder(name: $name, path: $path, selectedVersionFolderName: $selectedVersionFolderName, versions: $versions)';
}


}

/// @nodoc
abstract mixin class $DotMinecraftFolderCopyWith<$Res>  {
  factory $DotMinecraftFolderCopyWith(DotMinecraftFolder value, $Res Function(DotMinecraftFolder) _then) = _$DotMinecraftFolderCopyWithImpl;
@useResult
$Res call({
 String name, String path, String selectedVersionFolderName, List<MinecraftGame> versions
});




}
/// @nodoc
class _$DotMinecraftFolderCopyWithImpl<$Res>
    implements $DotMinecraftFolderCopyWith<$Res> {
  _$DotMinecraftFolderCopyWithImpl(this._self, this._then);

  final DotMinecraftFolder _self;
  final $Res Function(DotMinecraftFolder) _then;

/// Create a copy of DotMinecraftFolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? path = null,Object? selectedVersionFolderName = null,Object? versions = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,selectedVersionFolderName: null == selectedVersionFolderName ? _self.selectedVersionFolderName : selectedVersionFolderName // ignore: cast_nullable_to_non_nullable
as String,versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<MinecraftGame>,
  ));
}

}


/// Adds pattern-matching-related methods to [DotMinecraftFolder].
extension DotMinecraftFolderPatterns on DotMinecraftFolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DotMinecraftFolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DotMinecraftFolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DotMinecraftFolder value)  $default,){
final _that = this;
switch (_that) {
case _DotMinecraftFolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DotMinecraftFolder value)?  $default,){
final _that = this;
switch (_that) {
case _DotMinecraftFolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String path,  String selectedVersionFolderName,  List<MinecraftGame> versions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DotMinecraftFolder() when $default != null:
return $default(_that.name,_that.path,_that.selectedVersionFolderName,_that.versions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String path,  String selectedVersionFolderName,  List<MinecraftGame> versions)  $default,) {final _that = this;
switch (_that) {
case _DotMinecraftFolder():
return $default(_that.name,_that.path,_that.selectedVersionFolderName,_that.versions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String path,  String selectedVersionFolderName,  List<MinecraftGame> versions)?  $default,) {final _that = this;
switch (_that) {
case _DotMinecraftFolder() when $default != null:
return $default(_that.name,_that.path,_that.selectedVersionFolderName,_that.versions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DotMinecraftFolder extends DotMinecraftFolder {
  const _DotMinecraftFolder({this.name = '', this.path = '', this.selectedVersionFolderName = '', final  List<MinecraftGame> versions = const []}): _versions = versions,super._();
  factory _DotMinecraftFolder.fromJson(Map<String, dynamic> json) => _$DotMinecraftFolderFromJson(json);

/// UI 上显示的名称
@override@JsonKey() final  String name;
/// 本地物理绝对路径
@override@JsonKey() final  String path;
/// 所选择的版本，游戏与文件夹同名，故为[selectedVersionFolderName]（所选版本的文件夹名）
@override@JsonKey() final  String selectedVersionFolderName;
/// 文件夹内所包含的游戏，此处使用[versions]与物理文件夹同名
 final  List<MinecraftGame> _versions;
/// 文件夹内所包含的游戏，此处使用[versions]与物理文件夹同名
@override@JsonKey() List<MinecraftGame> get versions {
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_versions);
}


/// Create a copy of DotMinecraftFolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DotMinecraftFolderCopyWith<_DotMinecraftFolder> get copyWith => __$DotMinecraftFolderCopyWithImpl<_DotMinecraftFolder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DotMinecraftFolderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DotMinecraftFolder&&(identical(other.name, name) || other.name == name)&&(identical(other.path, path) || other.path == path)&&(identical(other.selectedVersionFolderName, selectedVersionFolderName) || other.selectedVersionFolderName == selectedVersionFolderName)&&const DeepCollectionEquality().equals(other._versions, _versions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,path,selectedVersionFolderName,const DeepCollectionEquality().hash(_versions));

@override
String toString() {
  return 'DotMinecraftFolder(name: $name, path: $path, selectedVersionFolderName: $selectedVersionFolderName, versions: $versions)';
}


}

/// @nodoc
abstract mixin class _$DotMinecraftFolderCopyWith<$Res> implements $DotMinecraftFolderCopyWith<$Res> {
  factory _$DotMinecraftFolderCopyWith(_DotMinecraftFolder value, $Res Function(_DotMinecraftFolder) _then) = __$DotMinecraftFolderCopyWithImpl;
@override @useResult
$Res call({
 String name, String path, String selectedVersionFolderName, List<MinecraftGame> versions
});




}
/// @nodoc
class __$DotMinecraftFolderCopyWithImpl<$Res>
    implements _$DotMinecraftFolderCopyWith<$Res> {
  __$DotMinecraftFolderCopyWithImpl(this._self, this._then);

  final _DotMinecraftFolder _self;
  final $Res Function(_DotMinecraftFolder) _then;

/// Create a copy of DotMinecraftFolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? path = null,Object? selectedVersionFolderName = null,Object? versions = null,}) {
  return _then(_DotMinecraftFolder(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,selectedVersionFolderName: null == selectedVersionFolderName ? _self.selectedVersionFolderName : selectedVersionFolderName // ignore: cast_nullable_to_non_nullable
as String,versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<MinecraftGame>,
  ));
}


}

// dart format on
