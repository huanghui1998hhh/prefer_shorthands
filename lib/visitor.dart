import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:prefer_shorthands/utils.dart';

import 'main.dart';
import 'settings.dart';

class Visitor extends SimpleAstVisitor<void> {
  const Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  Settings get settings => plugin.settings;

  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    AbstractAnalysisRule rule,
  ) {
    registry.addVariableDeclaration(rule, this);
    registry.addPatternVariableDeclaration(rule, this);
    registry.addConstantPattern(rule, this);
    registry.addArgumentList(rule, this);
    registry.addAssignmentExpression(rule, this);
    registry.addMethodDeclaration(rule, this);
    registry.addBinaryExpression(rule, this);
    registry.addConditionalExpression(rule, this);
    registry.addListLiteral(rule, this);
    registry.addSetOrMapLiteral(rule, this);
    registry.addRecordLiteral(rule, this);
    registry.addIfElement(rule, this);
    registry.addForElement(rule, this);
    registry.addMapLiteralEntry(rule, this);
    registry.addFormalParameterDefaultClause(rule, this);
    registry.addReturnStatement(rule, this);
    registry.addExpressionFunctionBody(rule, this);
    registry.addSwitchExpressionCase(rule, this);
  }

  /// [canModifyDeclaredType] is true when the declared type can be modified,
  ///
  /// case `final animal = Animal.dog()` can -> `final Animal animal = .dog();`
  /// Even if `Animal.dog()` returns a `Dog` that is subclass of `Animal`,
  void _checkAndReport({
    required Expression expression,
    required DartType? declaredType,
    bool canModifyDeclaredType = false,
  }) {
    final temp = expression.getShorthandPrefixElement();
    if (temp == null) return;
    final (prefixElement, prefixType) = temp;

    final expressionType = expression.staticType;
    if (expressionType == null) return;
    if (!context.typeSystem.isSubtypeOf(expressionType, prefixType)) {
      return;
    }

    if (declaredType != null) {
      if (prefixType != context.typeSystem.promoteToNonNull(declaredType)) {
        if (context.typeSystem.isSubtypeOf(prefixType, declaredType)) {
          if (!_isRedirectConstructor(
            expression,
            prefixElement,
            declaredType,
          )) {
            return;
          }
        } else {
          if (!canModifyDeclaredType) return;
        }
      }
    }

    final filePath = context.currentUnit?.file.path;
    if (filePath != null &&
        plugin.settings.isExcluded(
          filePath,
          context.package?.root.path ?? '',
        )) {
      return;
    }

    rule.reportAtNode(expression);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final expression = node.initializer;
    if (expression == null) return;
    if (expression.isDotShorthand) return;

    final variableList = node.thisOrAncestorOfType<VariableDeclarationList>();
    final variableListType = variableList?.type;
    final hasExplicitType = variableListType != null;

    if (!hasExplicitType && !settings.convertImplicitDeclaration) {
      return;
    }

    if (expression is RecordLiteral &&
        variableListType is RecordTypeAnnotation) {
      _checkRecordLiteralWithTypeAnnotation(expression, variableListType);
      return;
    }

    _checkAndReport(
      expression: expression,
      declaredType: node.declaredFragment?.element.type,
      canModifyDeclaredType: true,
    );
  }

  void _checkRecordLiteralWithTypeAnnotation(
    RecordLiteral literal,
    RecordTypeAnnotation typeAnnotation,
  ) {
    final positionalFields = typeAnnotation.positionalFields;
    final namedFields = typeAnnotation.namedFields;

    var literalIndex = 0;
    for (
      var i = 0;
      i < positionalFields.length && literalIndex < literal.fields.length;
      i++
    ) {
      final field = positionalFields[i];
      final declaredType = field.type.type;
      if (declaredType == null) continue;

      while (literalIndex < literal.fields.length &&
          literal.fields[literalIndex].isNamedRecordField) {
        literalIndex++;
      }

      if (literalIndex >= literal.fields.length) break;

      final literalField = literal.fields[literalIndex];
      final expression = literalField.expressionValue;

      if (!expression.isDotShorthand) {
        _checkAndReport(expression: expression, declaredType: declaredType);
      }

      literalIndex++;
    }

    if (namedFields != null) {
      for (final field in namedFields.fields) {
        final fieldName = field.name.lexeme;
        final declaredType = field.type.type;
        if (declaredType == null) continue;

        for (final literalField in literal.fields) {
          if (literalField.namedRecordFieldName == fieldName) {
            final expression = literalField.expressionValue;
            if (!expression.isDotShorthand) {
              _checkAndReport(
                expression: expression,
                declaredType: declaredType,
              );
            }
            break;
          }
        }
      }
    }
  }

  @override
  void visitPatternVariableDeclaration(PatternVariableDeclaration node) {
    final literal = node.expression;
    if (literal is! RecordLiteral) return;

    final pattern = switch (node.pattern) {
      final RecordPattern e => e,
      _ => null,
    };
    if (pattern == null) return;

    final patternFieldsLength = pattern.fields.length;
    final literalFieldsLength = literal.fields.length;
    if (patternFieldsLength != literalFieldsLength) return;

    for (var i = 0; i < patternFieldsLength; i++) {
      final patternField = pattern.fields[i];
      final literalField = literal.fields[i];

      final declaredType = switch (patternField.pattern) {
        WildcardPattern(type: final type?) => type.type,
        DeclaredVariablePattern(type: final type?) => type.type,
        _ => null,
      };
      if (declaredType == null) continue;

      final expression = literalField.expressionValue;

      if (!expression.isDotShorthand) {
        _checkAndReport(expression: expression, declaredType: declaredType);
      }
    }
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final expression = node.rightHandSide;
    if (expression.isDotShorthand) return;

    final declaredType = node.writeType;
    if (declaredType == null) return;

    _checkAndReport(expression: expression, declaredType: declaredType);
  }

  @override
  void visitConstantPattern(ConstantPattern node) {
    final expression = node.expression;
    if (expression.isDotShorthand) return;
    if (expression is! PrefixedIdentifier) return;

    final declaredType = switch (node.parent) {
      GuardedPattern(:final pattern) => pattern.matchedValueType,
      LogicalOrPattern(parent: GuardedPattern(:final pattern)) =>
        pattern.matchedValueType,
      _ => null,
    };
    if (declaredType == null) return;

    _checkAndReport(expression: expression, declaredType: declaredType);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final expression = node.rightOperand;
    if (expression.isDotShorthand) return;

    _checkAndReport(
      expression: expression,
      declaredType: switch (node) {
        BinaryExpression(operator: Token(lexeme: '==')) ||
        BinaryExpression(
          operator: Token(lexeme: '!='),
        ) => node.leftOperand.staticType,
        BinaryExpression(operator: Token(lexeme: '??')) =>
          // For ?? operator, try to get context type from parent
          // If in argument position: use parameter type
          // If in return/assignment: use declared type
          // Otherwise fallback to left operand type
          node.correspondingParameter?.type ??
              node.findDeclaredType() ??
              node.leftOperand.staticType,
        _ => node.rightOperand.correspondingParameter?.type,
      },
    );
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    final declaredType =
        node.correspondingParameter?.type ?? node.findDeclaredType();
    if (declaredType == null) return;

    _checkExpression(node.thenExpression, declaredType);
    _checkExpression(node.elseExpression, declaredType);
  }

  void _checkExpression(Expression expression, DartType declaredType) {
    if (!expression.isDotShorthand) {
      _checkAndReport(expression: expression, declaredType: declaredType);
    }
  }

  @override
  void visitArgumentList(ArgumentList node) {
    for (final argument in node.arguments) {
      final expression = argument.argumentExpression;

      if (expression.isDotShorthand) continue;

      final parameter = argument.correspondingParameter;
      final baseType = parameter?.baseElement.type;

      if (baseType is TypeParameterType) {
        if (!expression.hasExplicitTypeContext) continue;
      }

      _checkAndReport(expression: expression, declaredType: parameter?.type);
    }
  }

  @override
  void visitListLiteral(ListLiteral node) {
    _checkCollectionElements(node.elements, IterableType.list, node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    _checkCollectionElements(node.elements, IterableType.set, node);
  }

  void _checkCollectionElements(
    Iterable<CollectionElement> elements,
    IterableType iterableType,
    TypedLiteral literal,
  ) {
    final declaredType = literal.getIterableGenericType(iterableType);
    if (declaredType == null) return;

    for (final element in elements) {
      final expression = switch (element) {
        Expression() => element,
        _ => null,
      };
      if (expression == null) continue;
      if (expression.isDotShorthand) continue;

      _checkAndReport(expression: expression, declaredType: declaredType);
    }
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    final recordType = () {
      final paramType = node.correspondingParameter?.type;
      if (paramType is RecordType) return paramType;

      final declaredType = node.findDeclaredType();
      if (declaredType is RecordType) return declaredType;

      return null;
    }();
    if (recordType == null) return;

    var positionalIndex = 0;
    for (final field in node.fields) {
      final expression = field.expressionValue;

      if (expression.isDotShorthand) {
        if (!field.isNamedRecordField) positionalIndex++;
        continue;
      }

      final fieldName = field.namedRecordFieldName;
      final fieldType = recordType.getFieldTypeByNameOrIndex(
        positionalIndex,
        fieldName,
      );

      if (fieldType != null) {
        _checkAndReport(expression: expression, declaredType: fieldType);
      }

      if (!field.isNamedRecordField) positionalIndex++;
    }
  }

  @override
  void visitFormalParameterDefaultClause(FormalParameterDefaultClause node) {
    final expression = node.value;
    if (expression.isDotShorthand) return;

    final declaredType = switch (node.parent) {
      FormalParameter(type: NamedType(type: final type)) => type,
      _ => null,
    };

    // not same as `variableDeclaration`, function parameter won't do type inference
    if (declaredType == null) return;

    _checkAndReport(expression: expression, declaredType: declaredType);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final expression = node.expression;
    if (expression == null) return;
    _checkExpressionWithReturnType(expression, node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _checkExpressionWithReturnType(node.expression, node);
  }

  void _checkExpressionWithReturnType(Expression expression, AstNode node) {
    if (expression.isDotShorthand) return;

    final returnType = node
        .thisOrAncestorOfType<FunctionDeclaration>()
        ?.returnType
        ?.type;
    if (returnType == null) return;

    // For async functions, unwrap Future<T> to get T
    final declaredType = returnType.unwrapFutureOr();

    _checkAndReport(expression: expression, declaredType: declaredType);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    final expression = node.expression;
    if (expression.isDotShorthand) return;

    final declaredType = node.findDeclaredType();
    if (declaredType == null) return;

    _checkAndReport(expression: expression, declaredType: declaredType);
  }

  @override
  void visitIfElement(IfElement node) {
    final declaredType = node.getCollectionElementType();
    if (declaredType == null) return;

    _checkCollectionElement(node.thenElement, declaredType);
    if (node.elseElement != null) {
      _checkCollectionElement(node.elseElement!, declaredType);
    }
  }

  @override
  void visitForElement(ForElement node) {
    final declaredType = node.getCollectionElementType();
    if (declaredType == null) return;

    _checkCollectionElement(node.body, declaredType);
  }

  void _checkCollectionElement(
    CollectionElement element,
    DartType declaredType,
  ) {
    if (element is Expression && !element.isDotShorthand) {
      _checkAndReport(expression: element, declaredType: declaredType);
    }
  }

  @override
  void visitMapLiteralEntry(MapLiteralEntry node) {
    final mapLiteral = node.thisOrAncestorOfType<SetOrMapLiteral>();
    if (mapLiteral == null || mapLiteral.isSet) return;

    // Check key
    final keyType = mapLiteral.getIterableGenericType(IterableType.mapKey);
    if (keyType != null) {
      _checkExpression(node.key, keyType);
    }

    // Check value
    final valueType = mapLiteral.getIterableGenericType(IterableType.mapValue);
    if (valueType != null) {
      _checkExpression(node.value, valueType);
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isGetter) return;

    final returnType = node.returnType?.type;
    if (returnType == null) return;

    final expression = switch (node.body) {
      ExpressionFunctionBody(:final expression) => expression,
      _ => null,
    };
    if (expression == null) return;

    _checkExpression(expression, returnType);
  }

  /// Check same name constructor is redirected constructor
  ///
  /// resolve case:
  /// ```dart
  /// Padding(
  ///   padding: const EdgeInsets.all(10),
  ///   child: xxx,
  /// );
  /// ```
  /// `padding` need a `EdgeInsetsGeometry`, then `EdgeInsetsGeometry`
  ///  has a redirected constructor to `EdgeInsets`, like
  /// `EdgeInsetsGeometry.all` -> `EdgeInsets.all`.
  bool _isRedirectConstructor(
    Expression expression,
    InterfaceElement prefixElement,
    DartType declaredType,
  ) {
    if (declaredType is! InterfaceType) return false;

    final parameterElement = declaredType.element;

    if (!context.typeSystem.isSubtypeOf(prefixElement.thisType, declaredType)) {
      return false;
    }

    final constructorName = expression.constructorNameIfInstanceCreation;
    if (constructorName == null) return false;

    final parentConstructor = parameterElement.getConstructorByNameOrNull(
      constructorName,
    );
    if (parentConstructor == null) return false;

    if (!parentConstructor.isFactory) return false;

    final redirectedConstructor = parentConstructor.redirectedConstructor;
    if (redirectedConstructor == null) return false;

    return redirectedConstructor.enclosingElement == prefixElement;
  }
}
