class JavaInfo {
  final String version;
  final String? vendor;
  final String path;
  final String os;
  final String arch;

  JavaInfo({
    required this.version,
    this.vendor,
    required this.path,
    required this.os,
    required this.arch,
  });

  @override
  String toString() => '$version (${vendor ?? 'Unknown'}) @ $path';
}
