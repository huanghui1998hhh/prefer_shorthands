import 'dart:io';

import 'package:yaml/yaml.dart';

import 'utils.dart';

class Settings {
  static Settings loadFromAnalysisOptions([String? rootPath]) {
    final file = File(
      rootPath == null
          ? 'analysis_options.yaml'
          : '$rootPath${Platform.pathSeparator}analysis_options.yaml',
    );
    if (!file.existsSync()) {
      return const Settings();
    }
    final contents = file.readAsStringSync();
    final yaml = loadYaml(contents);
    if (yaml is! YamlMap) return const Settings();

    final analyzerSection = yaml['analyzer'];
    final excludePatterns = <String>[];
    if (analyzerSection is YamlMap) {
      final exclude = analyzerSection['exclude'];
      if (exclude is YamlList) {
        excludePatterns.addAll(exclude.whereType<String>());
      }
    }

    final preferShorthands = yaml['prefer_shorthands'];
    if (preferShorthands is! YamlMap) {
      return Settings(excludePatterns: excludePatterns);
    }

    return Settings(
      convertImplicitDeclaration: preferShorthands.getKeyAsTypeOrNull<bool>(
        'convert_implicit_declaration',
      ),
      excludePatterns: excludePatterns,
    );
  }

  const Settings({
    bool? convertImplicitDeclaration,
    List<String>? excludePatterns,
  }) : convertImplicitDeclaration = convertImplicitDeclaration ?? false,
       excludePatterns = excludePatterns ?? const [];

  final bool convertImplicitDeclaration;
  final List<String> excludePatterns;

  bool isExcluded(String filePath, String rootPath) {
    var relative = filePath.replaceAll('\\', '/');
    final root = rootPath.replaceAll('\\', '/');
    if (root.isNotEmpty && relative.startsWith(root)) {
      relative = relative.substring(root.length);
      if (relative.startsWith('/')) relative = relative.substring(1);
    }
    return excludePatterns.any((p) => matchesGlobPattern(p, relative));
  }

  @override
  String toString() =>
      'PreferShorthandsSettings(convertImplicitDeclaration: $convertImplicitDeclaration)';
}

extension on YamlMap {
  T? getKeyAsTypeOrNull<T>(String key) => switch (this[key]) {
    T value => value,
    _ => null,
  };
}
