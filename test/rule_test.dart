// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:prefer_shorthands/main.dart';
import 'package:prefer_shorthands/settings.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'animal.dart';
import 'size.dart';

late final String codeContent;

void main() async {
  Registry.ruleRegistry.registerLintRule(PreferShorthandsRule());

  codeContent = (await File('example/lib/main.dart').readAsLines()).join('\n');

  defineReflectiveSuite(() {
    defineReflectiveTests(PreferShorthandsRuleTest);
  });
}

@reflectiveTest
class PreferShorthandsRuleTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'prefer_shorthands';

  void test_prefer_shorthands() async {
    plugin.settings = Settings(convertImplicitDeclaration: false);
    await assertDiagnostics(codeContent, [
      lint(192, 11),
      lint(340, 7),
      lint(358, 7),
      lint(384, 5),
      lint(394, 11),
      lint(422, 5),
      lint(429, 11),
      lint(479, 5),
      lint(493, 5),
      lint(514, 5),
      lint(557, 7),
      lint(568, 7),
      lint(593, 7),
      lint(635, 10),
      lint(681, 7),
      lint(699, 7),
      lint(710, 7),
      lint(735, 7),
      lint(784, 14),
    ]);
  }

  void test_convert_implicit_declaration() async {
    plugin.settings = Settings(convertImplicitDeclaration: true);
    await assertDiagnostics(codeContent, [
      lint(31, 23),
      lint(83, 10),
      lint(107, 5),
      lint(126, 5),
      lint(145, 7),
      lint(166, 10),
      lint(192, 11),
      lint(340, 7),
      lint(358, 7),
      lint(384, 5),
      lint(394, 11),
      lint(422, 5),
      lint(429, 11),
      lint(455, 30),
      lint(479, 5),
      lint(493, 5),
      lint(514, 5),
      lint(557, 7),
      lint(568, 7),
      lint(593, 7),
      lint(635, 10),
      lint(681, 7),
      lint(699, 7),
      lint(710, 7),
      lint(735, 7),
      lint(784, 14),
    ]);
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/5
  void test_5_generics_implicit() async {
    const code = '''
  final a = List.filled(5, EnumA.a);

  enum EnumA { a, b }
  ''';

    plugin.settings = Settings(convertImplicitDeclaration: false);
    await assertDiagnostics(code, []);
    plugin.settings = Settings(convertImplicitDeclaration: true);
    await assertDiagnostics(code, [lint(12, 23)]);
  }

  void test_5_generics_explicit() async {
    plugin.settings = Settings(convertImplicitDeclaration: true);
    await assertDiagnostics(
      '''
  final List<EnumA> a = List.filled(5, EnumA.a);

  enum EnumA { a, b }
  ''',
      [lint(24, 23), lint(39, 7)],
    );
  }

  void test_binaryExpression() async {
    await assertDiagnostics(
      '''
void main() {
  if (Size(100, 100) == Size.zero) {}
  if (Size(100, 100) > Size.zero) {}
}
$sizeClasses
''',
      [lint(38, 9)],
    );
  }

  void test_parameter_type_relax() async {
    await assertDiagnostics('''
void main() {
  bugDog(Animal.dog());
}

void bugDog(Dog dog) {}
void getaHuskyIfNoAnimal(Animal? animal) => animal ?? Dog.husky();
$animalClasses
''', []);
  }

  void test_list_literal() async {
    plugin.settings = Settings(convertImplicitDeclaration: false);
    await assertDiagnostics(
      '''
final a = <EnumA>[EnumA.a, EnumA.b];
final b = [EnumA.a, EnumA.b];
final List<EnumA> c = [EnumA.a, EnumA.b];

enum EnumA { a, b }
''',
      [lint(18, 7), lint(27, 7), lint(90, 7), lint(99, 7)],
    );
  }

  void test_set_literal() async {
    plugin.settings = Settings(convertImplicitDeclaration: false);
    await assertDiagnostics(
      '''
final a = <EnumA>{EnumA.a, EnumA.b};
final b = {EnumA.a, EnumA.b};
final Set<EnumA> c = {EnumA.a, EnumA.b};

enum EnumA { a, b }
''',
      [lint(18, 7), lint(27, 7), lint(89, 7), lint(98, 7)],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/8
  void test_8() async {
    await assertDiagnostics(
      '''
void f({
  Set<Direction> directions = const {Direction.left, Direction.right},
  String a = const String.fromEnvironment('a'),
  b = const String.fromEnvironment('b'),
}) {}

void d([
  Set<Direction> directions = const {Direction.left, Direction.right},
  String a = const String.fromEnvironment('a'),
  b = const String.fromEnvironment('b'),
]) {}

enum Direction { left, right }
''',
      [
        lint(46, 14),
        lint(62, 15),
        lint(93, 33),
        lint(222, 14),
        lint(238, 15),
        lint(269, 33),
      ],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/11
  void test_11() async {
    await assertDiagnostics(
      '''
final object = <String, Direction>{}..['a'] = Direction.left;
final object2 = <String, dynamic>{}..['a'] = Direction.left;

void main() {
  object['a'] = Direction.left;
  object2['a'] = Direction.left;
}

enum Direction { left, right }
''',
      [lint(46, 14), lint(154, 14)],
    );
  }

  void test_return_expression() async {
    await assertDiagnostics(
      '''
Direction leftDirection() {
  return Direction.left;
}

Direction rightDirection() => Direction.right;

enum Direction { left, right }
''',
      [lint(37, 14), lint(86, 15)],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/9
  void test_9() async {
    await assertDiagnostics(
      '''
Direction getDirection(String directionString) {
  final Direction temp = switch ('') {
    'left' => switch ('') {
      'left' => Direction.left,
      'right' => Direction.right,
      _ => throw ArgumentError(''),
    },
    'right' => Direction.right,
    _ => throw ArgumentError(''),
  };

  return switch (directionString) {
    'left' => switch (directionString) {
      'left' => Direction.left,
      'right' => Direction.right,
      _ => throw ArgumentError(''),
    },
    'right' => Direction.right,
    _ => throw ArgumentError(''),
  };
}

extension on String {
  Direction get direction => switch (this) {
    'left' => switch (this) {
      'left' => Direction.left,
      'right' => Direction.right,
      _ => throw ArgumentError(''),
    },
    'right' => Direction.right,
    _ => throw ArgumentError(''),
  };
}

enum Direction { left, right }
''',
      [
        lint(132, 14),
        lint(165, 15),
        lint(240, 15),
        lint(390, 14),
        lint(423, 15),
        lint(498, 15),
        lint(670, 14),
        lint(703, 15),
        lint(778, 15),
      ],
    );
  }

  void test_subtype_prefix_in_supertype_context() async {
    await assertDiagnostics('''
void main() {
  displayAvatar(() => randomUser ?? User.defaultUser);
  display(randomUser ?? User.defaultUser);
}

void displayAvatar(UserAvatar Function() avatarBuilder) {}
void display(UserAvatar avatar) {}

class User with UserAvatar {
  const User({required this.avatar});

  static const defaultUser = User(avatar: 'default');

  @override
  final String avatar;
}

mixin UserAvatar {
  String get avatar;
}

User? get randomUser => null;
''', []);
  }

  void test_conditional_expression() async {
    await assertDiagnostics(
      '''
void main() {
  final bool condition = getCondition();
  final Direction a = condition ? Direction.left : Direction.right;
  display(condition ? Direction.left : Direction.right);
  Direction getDirection() => condition ? Direction.left : Direction.right;
}

bool getCondition() => true;
void display(Direction dir) {}

enum Direction { left, right }
''',
      [
        lint(89, 14),
        lint(106, 15),
        lint(145, 14),
        lint(162, 15),
        lint(222, 14),
        lint(239, 15),
      ],
    );
  }

  void test_collection_elements() async {
    await assertDiagnostics(
      '''
void main() {
  final List<Direction> directions = [
    Direction.left,
    if (getCondition()) Direction.right,
  ];
  
  final Map<String, Direction> map1 = {
    'left': Direction.left,
    'right': Direction.right,
  };
  
  final Map<Direction, String> map2 = {
    Direction.left: 'left',
    Direction.right: 'right',
  };
  
  final Map<Direction, Direction> map3 = {
    Direction.left: Direction.right,
    Direction.right: Direction.left,
  };
}

bool getCondition() => true;

enum Direction { left, right }
''',
      [
        lint(57, 14),
        lint(97, 15),
        lint(174, 14),
        lint(203, 15),
        lint(272, 14),
        lint(300, 15),
        lint(381, 14),
        lint(397, 15),
        lint(418, 15),
        lint(435, 14),
      ],
    );
  }

  void test_map_control_flow() async {
    await assertDiagnostics(
      '''
void main() {
  // Map with if element - key should trigger warning
  final Map<Direction, String> map1 = {
    if (getCondition()) Direction.left: 'left',
  };
  
  // Map with for element - key should trigger warning
  final Map<Direction, String> map2 = {
    for (var i in [1, 2]) Direction.right: 'value',
  };
  
  // Map with if-else - values should trigger warnings
  final Map<String, Direction> map3 = {
    if (getCondition())
      'left': Direction.left
    else
      'right': Direction.right,
  };
}

bool getCondition() => true;

enum Direction { left, right }
''',
      [
        lint(132, 14), // map1: Direction.left (key)
        lint(285, 15), // map2: Direction.right (key)
        lint(452, 14), // map3 then: Direction.left (value)
        lint(491, 15), // map3 else: Direction.right (value)
      ],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/16
  void test_getter() async {
    await assertDiagnostics(
      '''
enum Direction {left, right}

Direction get direction => Direction.left;

sealed class A {
  Direction get direction;
}

class B extends A {
  @override
  Direction get direction => Direction.left; // should recommend .left
}
''',
      [lint(57, 14), lint(182, 14)],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/15
  void test_collections_as_return_values() async {
    await assertDiagnostics(
      '''
List<Direction> getList() {
  return [Direction.left, Direction.right];
}

List<Direction> getList2() => [Direction.up, Direction.down];

Set<Direction> getSet() {
  return {Direction.left, Direction.right};
}

Map<Direction, String> getMap() {
  return {Direction.left: 'left', Direction.right: 'right'};
}

enum Direction { left, right, up, down }
''',
      [
        lint(38, 14), // getList: Direction.left
        lint(54, 15), // getList: Direction.right
        lint(106, 12), // getList2: Direction.up
        lint(120, 14), // getList2: Direction.down
        lint(174, 14), // getSet: Direction.left
        lint(190, 15), // getSet: Direction.right
        lint(255, 14), // getMap key: Direction.left
        lint(279, 15), // getMap key: Direction.right
      ],
    );
  }

  void test_record_literals() async {
    await assertDiagnostics(
      '''
(Direction, String) getRecord() => (Direction.up, 'up');

void display((Direction, Direction) record) {}

void main() {
  final (Direction, String) record1 = (Direction.left, 'left');
  display((Direction.left, Direction.right));
}

enum Direction { left, right, up, down }
''',
      [
        lint(36, 12), // getRecord: Direction.up
        lint(
          159,
          14,
        ), // record1 with type annotation: Direction.left (now working!)
        lint(195, 14), // display arg: Direction.left
        lint(211, 15), // display arg: Direction.right
      ],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/19
  void test_async_return() async {
    await assertDiagnostics(
      '''
Direction getDirection() {
  return Direction.left;
}

Direction getDirection2() => Direction.right;

Future<Direction> getDirectionAsync() async {
  return Direction.up;
}

Future<Direction> getDirectionAsync2() async => Direction.down;

enum Direction { left, right, up, down }
''',
      [
        lint(36, 14), // getDirection: Direction.left
        lint(84, 15), // getDirection2: Direction.right
        lint(157, 12), // getDirectionAsync: Direction.up (async unwraps Future)
        lint(222, 14), // getDirectionAsync2: Direction.down (async expression)
      ],
    );
  }

  void test_exclusion_g_dart_file_is_skipped() async {
    plugin.settings = Settings(
      convertImplicitDeclaration: false,
      excludePatterns: ['**/*.g.dart'],
    );
    const code = '''
enum Direction { left, right }
Direction dir = Direction.left;
''';
    final file = newFile('$testPackageLibPath/model.g.dart', code);
    await assertDiagnosticsInFile(file.path, []);
  }

  void test_exclusion_regular_file_is_linted() async {
    plugin.settings = Settings(
      convertImplicitDeclaration: false,
      excludePatterns: ['**/*.g.dart'],
    );
    await assertDiagnostics(
      '''
enum Direction { left, right }
Direction dir = Direction.left;
''',
      [lint(47, 14)],
    );
  }

  /// https://github.com/huanghui1998hhh/prefer_shorthands/issues/21
  /// Factory constructors with body should NOT trigger warning
  /// Redirecting factory constructors SHOULD trigger warning
  void test_21_factory_constructors() async {
    await assertDiagnostics(
      '''
final Result a = Result.success('Entity created');
final Result b = Result.failure('Entity created');
final Result c = Result.networkFailure('Entity created');

class Result {
  bool success;
  String? message;
  String? error;
  List<dynamic>? data;
  Object? object;

  Result({
    required this.success,
    this.message,
    this.error,
    this.data,
    this.object,
  });

  factory Result.success(
    String? message, {
    List<dynamic>? data,
    Object? object,
  }) {
    return Result(success: true, message: message, data: data, object: object);
  }

  factory Result.failure(String? error, {List<dynamic>? data, Object? object}) =
      FailureResult;

  factory Result.networkFailure(
    String? error, {
    List<dynamic>? data,
    Object? object,
  }) = FailureResult.networt;
}

class FailureResult extends Result {
  FailureResult(String? error, {super.data, super.object})
    : super(success: false, error: error);

  FailureResult.networt(String? error, {super.data, super.object})
    : super(success: false, error: error);
}
''',
      [
        // Result.success has body -> NO warning
        // Result.failure redirects to FailureResult -> warning
        lint(68, 32),
        // Result.networkFailure redirects to FailureResult.networt -> warning
        lint(119, 39),
      ],
    );
  }
}
