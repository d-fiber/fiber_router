// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'models.dart';

List<RouterNode> parseRouterFile(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  for (final decl in result.unit.declarations) {
    if (decl is! TopLevelVariableDeclaration) continue;

    final hasAnnotation = decl.metadata.any((a) => a.name.name == 'FiberRouterGen');
    if (!hasAnnotation) continue;

    final initializer = decl.variables.variables.first.initializer;
    if (initializer is! MethodInvocation) continue;

    final nodesArg = _namedArg(initializer.argumentList, 'nodes');
    if (nodesArg == null) continue;

    final nodesList = nodesArg;
    if (nodesList is! ListLiteral) continue;

    return nodesList.elements.whereType<Expression>().map(_parseNode).nonNulls.toList();
  }

  throw StateError('No @FiberRouterGen() annotated PoppinRouter.create() found in source.');
}

List<String> extractImports(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  return result.unit.directives.whereType<ImportDirective>().map((d) => d.toSource()).toList();
}

RouterNode? _parseNode(Expression expr) {
  if (expr is! MethodInvocation) return null;

  final target = expr.target;
  if (target is! SimpleIdentifier || target.name != 'PoppinRouteNode') {
    return null;
  }

  return switch (expr.methodName.name) {
    'node' => _parseGroupNode(expr),
    'view' => _parseViewNode(expr, isDeeplink: false),
    'deeplink' => _parseViewNode(expr, isDeeplink: true),
    _ => null,
  };
}

RouterGroupNode? _parseGroupNode(MethodInvocation expr) {
  final nameExpr = _namedArg(expr.argumentList, 'name');
  final routesExpr = _namedArg(expr.argumentList, 'routes');
  if (nameExpr == null || routesExpr == null) return null;

  final name = nameExpr is StringLiteral ? nameExpr.stringValue : null;
  if (name == null) return null;

  if (routesExpr is! ListLiteral) return null;

  final children = routesExpr.elements.whereType<Expression>().map(_parseNode).nonNulls.toList();

  return RouterGroupNode(name: name, children: children);
}

RouterViewNode? _parseViewNode(MethodInvocation expr, {required bool isDeeplink}) {
  final typeArgs = expr.typeArguments?.arguments;
  if (typeArgs == null || typeArgs.length != 2) return null;

  return RouterViewNode(
    widgetType: typeArgs[0].toString(),
    paramsType: typeArgs[1].toString(),
    isDeeplink: isDeeplink,
  );
}

Expression? _namedArg(ArgumentList argList, String argName) {
  for (final arg in argList.arguments) {
    if (arg is NamedArgument && arg.name.lexeme == argName) {
      return arg.argumentExpression;
    }
  }
  return null;
}
