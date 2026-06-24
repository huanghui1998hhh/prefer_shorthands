import 'dart:io';

import 'package:prefer_shorthands/settings.dart';
import 'package:prefer_shorthands/utils.dart';
import 'package:test/test.dart';

void main() {
  group('matchesGlobPattern', () {
    test('matches **/*.g.dart in any directory', () {
      expect(matchesGlobPattern('**/*.g.dart', 'lib/models.g.dart'), isTrue);
      expect(
        matchesGlobPattern('**/*.g.dart', 'lib/src/models.g.dart'),
        isTrue,
      );
      expect(matchesGlobPattern('**/*.g.dart', 'models.g.dart'), isTrue);
    });

    test('does not match non-.g.dart files', () {
      expect(matchesGlobPattern('**/*.g.dart', 'lib/models.dart'), isFalse);
      expect(
        matchesGlobPattern('**/*.g.dart', 'lib/models.g.dart.bak'),
        isFalse,
      );
    });

    test('matches directory wildcard pattern', () {
      expect(
        matchesGlobPattern('lib/generated/**', 'lib/generated/foo.dart'),
        isTrue,
      );
      expect(
        matchesGlobPattern('lib/generated/**', 'lib/generated/sub/foo.dart'),
        isTrue,
      );
      expect(
        matchesGlobPattern('lib/generated/**', 'lib/other/foo.dart'),
        isFalse,
      );
    });

    test('single * does not match path separators', () {
      expect(matchesGlobPattern('*.dart', 'foo.dart'), isTrue);
      expect(matchesGlobPattern('*.dart', 'lib/foo.dart'), isFalse);
    });

    test('dots in pattern are matched literally', () {
      expect(
        matchesGlobPattern('**/*.freezed.dart', 'lib/model.freezed.dart'),
        isTrue,
      );
      expect(
        matchesGlobPattern('**/*.freezed.dart', 'lib/modelXfreezedXdart'),
        isFalse,
      );
    });

    test('handles windows-style path separators in file path', () {
      expect(
        matchesGlobPattern('**/*.g.dart', r'lib\src\models.g.dart'),
        isTrue,
      );
    });
  });

  group('Settings.loadFromAnalysisOptions', () {
    late Directory tempDir;

    setUp(
      () => tempDir = Directory.systemTemp.createTempSync(
        'prefer_shorthands_test_',
      ),
    );
    tearDown(() => tempDir.deleteSync(recursive: true));

    void writeOptions(String content) => File(
      '${tempDir.path}/analysis_options.yaml',
    ).writeAsStringSync(content);

    test('reads analyzer.exclude patterns', () {
      writeOptions('''
analyzer:
  exclude:
    - "**/*.g.dart"
    - "lib/generated/**"
''');
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, ['**/*.g.dart', 'lib/generated/**']);
    });

    test('works without prefer_shorthands section', () {
      writeOptions('''
analyzer:
  exclude:
    - "**/*.g.dart"
''');
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, ['**/*.g.dart']);
      expect(settings.convertImplicitDeclaration, isFalse);
    });

    test('combines analyzer.exclude with prefer_shorthands options', () {
      writeOptions('''
analyzer:
  exclude:
    - "**/*.g.dart"

prefer_shorthands:
  convert_implicit_declaration: true
''');
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, ['**/*.g.dart']);
      expect(settings.convertImplicitDeclaration, isTrue);
    });

    test('returns empty patterns when no analyzer.exclude section', () {
      writeOptions('''
prefer_shorthands:
  convert_implicit_declaration: true
''');
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, isEmpty);
    });

    test('returns default settings when file does not exist', () {
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, isEmpty);
      expect(settings.convertImplicitDeclaration, isFalse);
    });

    test('returns default settings when file is empty', () {
      writeOptions('');
      final settings = Settings.loadFromAnalysisOptions(tempDir.path);
      expect(settings.excludePatterns, isEmpty);
    });
  });

  group('Settings.isExcluded', () {
    test('excludes file matching pattern', () {
      final settings = Settings(excludePatterns: ['**/*.g.dart']);
      expect(
        settings.isExcluded('/project/lib/model.g.dart', '/project'),
        isTrue,
      );
    });

    test('does not exclude non-matching file', () {
      final settings = Settings(excludePatterns: ['**/*.g.dart']);
      expect(
        settings.isExcluded('/project/lib/model.dart', '/project'),
        isFalse,
      );
    });

    test('excludes nested file matching pattern', () {
      final settings = Settings(excludePatterns: ['**/*.g.dart']);
      expect(
        settings.isExcluded('/project/lib/src/model.g.dart', '/project'),
        isTrue,
      );
    });

    test('returns false when excludePatterns is empty', () {
      const settings = Settings();
      expect(
        settings.isExcluded('/project/lib/model.g.dart', '/project'),
        isFalse,
      );
    });

    test('works when rootPath is empty', () {
      final settings = Settings(excludePatterns: ['lib/model.g.dart']);
      expect(settings.isExcluded('lib/model.g.dart', ''), isTrue);
    });

    test('supports multiple patterns', () {
      final settings = Settings(
        excludePatterns: ['**/*.g.dart', 'lib/generated/**'],
      );
      expect(settings.isExcluded('/p/lib/foo.g.dart', '/p'), isTrue);
      expect(settings.isExcluded('/p/lib/generated/bar.dart', '/p'), isTrue);
      expect(settings.isExcluded('/p/lib/normal.dart', '/p'), isFalse);
    });
  });
}
