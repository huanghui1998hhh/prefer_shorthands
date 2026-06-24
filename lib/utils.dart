import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

extension InterfaceElementExtension on InterfaceElement {
  ConstructorElement? getConstructorByNameOrNull(String constructorName) =>
      constructors.where((c) => c.name == constructorName).firstOrNull;
}

extension ConstructorElementExtension on ConstructorElement? {
  /// Returns true if this is a factory constructor with a body
  /// (not redirecting and not external), which cannot use dot shorthand.
  ///
  /// Examples:
  /// - `factory Result.success(...) { return Result(...); }` -> true (has body)
  /// - `factory A.b() = B.b;` -> false (redirecting)
  /// - `external const factory String.fromEnvironment(...)` -> false (external)
  bool get isNonRedirectingBodyFactory {
    final self = this;
    if (self == null) return false;
    return self.isFactory &&
        self.redirectedConstructor == null &&
        !self.isExternal;
  }
}

extension DartTypeExtension on DartType {
  DartType unwrapFutureOr() => switch (this) {
    InterfaceType(typeArguments: [final type])
        when isDartAsyncFuture || isDartAsyncFutureOr =>
      type,
    _ => this,
  };
}

extension RecordLiteralFieldExtension on RecordLiteralField {
  Expression get expressionValue {
    if (this case RecordLiteralNamedField(:final fieldExpression)) {
      return fieldExpression;
    }
    if (this is Expression) {
      return this as Expression;
    }

    throw StateError('Unexpected record literal field: $runtimeType');
  }

  bool get isNamedRecordField => this is RecordLiteralNamedField;

  String? get namedRecordFieldName => switch (this) {
    RecordLiteralNamedField(:final name) => name.lexeme,
    _ => null,
  };
}

extension ExpressionExtension on Expression {
  String? get constructorNameIfInstanceCreation => switch (this) {
    InstanceCreationExpression(
      constructorName: ConstructorName(name: final name),
    ) =>
      name?.name,
    _ => null,
  };

  bool get isDotShorthand => switch (this) {
    DotShorthandConstructorInvocation() ||
    DotShorthandPropertyAccess() ||
    DotShorthandInvocation() => true,
    _ => false,
  };

  (InterfaceElement, DartType)? getShorthandPrefixElement() => switch (this) {
    InstanceCreationExpression(
      constructorName: ConstructorName(:final name, :final element),
      staticType: InterfaceType(
        element: final typeElement,
        :final extensionTypeErasure,
      ),
    )
        when name?.name != null &&
            name?.name != 'new' &&
            !element.isNonRedirectingBodyFactory =>
      (typeElement, extensionTypeErasure),
    PropertyAccess(target: SimpleIdentifier(element: InterfaceElement e)) => (
      e,
      e.thisType,
    ),
    PrefixedIdentifier(prefix: SimpleIdentifier(element: InterfaceElement e)) =>
      (e, e.thisType),
    MethodInvocation(target: SimpleIdentifier(element: InterfaceElement e)) => (
      e,
      e.thisType,
    ),
    _ => null,
  };

  bool get hasExplicitTypeContext {
    final varDecl = thisOrAncestorOfType<VariableDeclaration>();
    if (varDecl != null) {
      final varList = varDecl.thisOrAncestorOfType<VariableDeclarationList>();
      if (varList?.type != null) {
        return true;
      }
    }

    return false;
  }
}

extension TypedLiteralExtension on TypedLiteral {
  DartType? getIterableGenericType(IterableType iterableType) {
    // 1. Check explicit type arguments on the literal itself
    // e.g., `<String>[]` or `<Direction, String>{}`
    if (typeArguments case TypeArgumentList(
      :final arguments,
    ) when arguments.isNotEmpty) {
      return switch (iterableType) {
        IterableType.mapValue when arguments.length == 2 => arguments[1].type,
        IterableType.mapKey when arguments.length == 2 => arguments[0].type,
        IterableType.list ||
        IterableType.set when arguments.length == 1 => arguments[0].type,
        _ => null,
      };
    }

    // 2. Try to get type from context (parameter, return type, etc.)
    final contextType = _getContextType();
    if (contextType != null) {
      return _extractTypeArgument(contextType, iterableType);
    }

    return null;
  }

  InterfaceType? _getContextType() {
    // Try correspondingParameter (for arguments)
    // TypedLiteral is always an Expression
    final param = correspondingParameter?.type;
    if (param is InterfaceType) return param;

    // Try findDeclaredType (for return values, assignments, etc.)
    final declaredType = findDeclaredType();
    if (declaredType is InterfaceType) return declaredType;

    // Fallback to parent-based resolution
    return switch (parent) {
      Declaration(
        parent: VariableDeclarationList(
          type: NamedType(:final InterfaceType type),
        ),
      ) =>
        type,
      FormalParameterDefaultClause(
        parent: FormalParameter(type: NamedType(:final InterfaceType type)),
      ) =>
        type,
      _ => null,
    };
  }

  DartType? _extractTypeArgument(
    InterfaceType contextType,
    IterableType iterableType,
  ) {
    // Check if the context type matches the expected collection type
    final isMatchingType = switch (iterableType) {
      IterableType.set => contextType.isDartCoreSet,
      IterableType.list => contextType.isDartCoreList,
      IterableType.mapValue || IterableType.mapKey => contextType.isDartCoreMap,
    };
    if (!isMatchingType) return null;

    // Extract the appropriate type argument
    return switch ((iterableType, contextType.typeArguments)) {
      (IterableType.mapValue, [_, final valueType]) => valueType,
      (IterableType.mapKey, [final keyType, _]) => keyType,
      (IterableType.list || IterableType.set, [final elementType]) =>
        elementType,
      _ => null,
    };
  }
}

enum IterableType { set, list, mapValue, mapKey }

bool matchesGlobPattern(String pattern, String filePath) {
  final path = filePath.replaceAll('\\', '/');
  var regexStr = '';
  var i = 0;
  final p = pattern.replaceAll('\\', '/');
  while (i < p.length) {
    final ch = p[i];
    if (ch == '*' && i + 1 < p.length && p[i + 1] == '*') {
      if (i + 2 < p.length && p[i + 2] == '/') {
        regexStr += '(?:.+/)?';
        i += 3;
      } else {
        regexStr += '.*';
        i += 2;
      }
    } else if (ch == '*') {
      regexStr += '[^/]*';
      i++;
    } else if (RegExp(r'[.+^${}()|[\]]').hasMatch(ch)) {
      regexStr += '\\$ch';
      i++;
    } else {
      regexStr += ch;
      i++;
    }
  }
  return RegExp('^$regexStr\$').hasMatch(path);
}

extension AstNodeExtension on AstNode {
  DartType? findDeclaredType() {
    final varDecl = thisOrAncestorOfType<VariableDeclaration>();
    if (varDecl != null) {
      return switch (varDecl.parent) {
        VariableDeclarationList(type: NamedType(:final type)) => type,
        _ => null,
      };
    }

    final returnType = thisOrAncestorOfType<FunctionDeclaration>()?.returnType;
    if (returnType != null) {
      return returnType.type;
    }

    final getterReturnType =
        thisOrAncestorOfType<MethodDeclaration>()?.returnType;
    if (getterReturnType != null) {
      return getterReturnType.type;
    }

    return null;
  }

  DartType? getCollectionElementType() {
    final listLiteral = thisOrAncestorOfType<ListLiteral>();
    if (listLiteral != null) {
      return listLiteral.getIterableGenericType(IterableType.list);
    }

    final setLiteral = thisOrAncestorOfType<SetOrMapLiteral>();
    if (setLiteral != null && setLiteral.isSet) {
      return setLiteral.getIterableGenericType(IterableType.set);
    }

    return null;
  }
}

extension RecordTypeExtension on RecordType {
  DartType? getFieldTypeByNameOrIndex(int index, String? fieldName) {
    if (fieldName != null) {
      for (final field in namedFields) {
        if (field.name == fieldName) {
          return field.type;
        }
      }
      return null;
    }

    if (index < positionalFields.length) {
      return positionalFields[index].type;
    }

    return null;
  }
}
