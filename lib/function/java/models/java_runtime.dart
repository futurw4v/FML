import 'java_info.dart';

class JavaRuntime {
  final JavaInfo info;
  final String executable;
  final bool isJdk;

  JavaRuntime({
    required this.info,
    required this.executable,
    required this.isJdk,
  });

  @override
  String toString() => '${isJdk ? 'JDK' : 'JRE'} ${info.version} @ $executable';
}
