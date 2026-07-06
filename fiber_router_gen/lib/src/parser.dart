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

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

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

  throw StateError('No @FiberRouterGen() annotated FiberRouter.create() found in source.');
}

List<String> extractImports(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  return result.unit.directives.whereType<ImportDirective>().map((d) => d.toSource()).toList();
}

List<String> filterImports(List<String> imports, Set<String> neededTypes, String routerFilePath) {
  const alwaysExclude = {'fiber_router_annotation'};
  final packageConfig = _loadPackageConfig(routerFilePath);

  return imports.where((imp) {
    final uriMatch = RegExp(r'''import\s+['"]([^'"]+)['"]''').firstMatch(imp);
    if (uriMatch == null) return false;
    final uri = uriMatch.group(1)!;

    if (alwaysExclude.any((pkg) => uri.contains(pkg))) return false;
    if (uri.startsWith('dart:')) return false;
    if (uri.endsWith('.g.dart')) return false;

    final resolvedPath = _resolveUri(uri, routerFilePath, packageConfig);
    if (resolvedPath == null) return true;

    return _fileContainsAnyType(resolvedPath, neededTypes) ||
        _fileContainsBuildContextExtension(resolvedPath, packageConfig);
  }).toList();
}

// Recursively follows both relative and package: exports to detect `on BuildContext`.
// This correctly includes packages like `ui` (which re-exports fiber_router → navigation.dart)
// while excluding unrelated packages like `services` that have no BuildContext extensions.
bool _fileContainsBuildContextExtension(String filePath, Map<String, String> packageConfig, [Set<String>? visited]) {
  visited ??= {};
  if (!visited.add(filePath)) return false;

  final file = File(filePath);
  if (!file.existsSync()) return false;
  final content = file.readAsStringSync();
  if (content.contains('on BuildContext')) return true;

  for (final m in RegExp(r'''export\s+['"]([^'"]+)['"]''').allMatches(content)) {
    final exportUri = m.group(1)!;
    if (exportUri.startsWith('dart:')) continue;

    final exportPath = exportUri.startsWith('package:')
        ? _resolveUri(exportUri, filePath, packageConfig)
        : p.normalize(p.join(p.dirname(filePath), exportUri));

    if (exportPath != null && _fileContainsBuildContextExtension(exportPath, packageConfig, visited)) return true;
  }

  return false;
}

bool _fileContainsAnyType(String filePath, Set<String> types) {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  final content = file.readAsStringSync();

  if (types.any((t) => content.contains('class $t ') || content.contains('class $t{'))) {
    return true;
  }

  final exportMatches = RegExp(r'''export\s+['"]([^'"]+)['"]''').allMatches(content);
  for (final m in exportMatches) {
    final exportUri = m.group(1)!;
    if (exportUri.startsWith('dart:') || exportUri.startsWith('package:')) continue;
    final exportPath = p.normalize(p.join(p.dirname(filePath), exportUri));
    final exportFile = File(exportPath);
    if (!exportFile.existsSync()) continue;
    final exportContent = exportFile.readAsStringSync();
    if (types.any((t) => exportContent.contains('class $t ') || exportContent.contains('class $t{'))) {
      return true;
    }
  }

  return false;
}

String? _resolveUri(String uri, String routerFilePath, Map<String, String> packageConfig) {
  if (!uri.startsWith('package:')) {
    return p.normalize(p.join(p.dirname(routerFilePath), uri));
  }

  final parts = uri.replaceFirst('package:', '').split('/');
  final pkgName = parts.first;
  final pkgPath = packageConfig[pkgName];
  if (pkgPath == null) return null;

  return p.join(pkgPath, parts.skip(1).join('/'));
}

Map<String, String> _loadPackageConfig(String filePath) {
  var dir = Directory(p.dirname(filePath));
  while (true) {
    final configFile = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    if (configFile.existsSync()) {
      return _parsePackageConfig(configFile.readAsStringSync());
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return {};
    dir = parent;
  }
}

Map<String, String> _parsePackageConfig(String json) {
  final result = <String, String>{};
  final matches = RegExp(r'"name"\s*:\s*"([^"]+)"[^}]*"rootUri"\s*:\s*"([^"]+)"').allMatches(json);
  for (final m in matches) {
    final name = m.group(1)!;
    var rootUri = m.group(2)!;
    if (rootUri.startsWith('file://')) {
      rootUri = Uri.parse(rootUri).toFilePath();
    }
    result[name] = p.join(rootUri, 'lib');
  }
  return result;
}

RouterNode? _parseNode(Expression expr) {
  if (expr is! MethodInvocation) return null;

  final target = expr.target;
  if (target is! SimpleIdentifier || target.name != 'FiberRouteNode') {
    return null;
  }

  return switch (expr.methodName.name) {
    'node' => _parseGroupNode(expr),
    'shell' => _parseShellNode(expr),
    'controller' => _parseControllerNode(expr),
    'view' => _parseViewNode(expr, isDeeplink: false),
    'deeplink' => _parseViewNode(expr, isDeeplink: true),
    _ => null,
  };
}

RouterControllerNode? _parseControllerNode(MethodInvocation expr) {
  final routesExpr = _namedArg(expr.argumentList, 'routes');
  if (routesExpr == null || routesExpr is! ListLiteral) return null;
  final children = routesExpr.elements.whereType<Expression>().map(_parseNode).nonNulls.toList();

  final nameExpr = _namedArg(expr.argumentList, 'name');
  final explicitName = nameExpr is StringLiteral ? nameExpr.stringValue : null;

  final builderExpr = _namedArg(expr.argumentList, 'builder');
  final builderWidgetType = _extractShellWidgetType(builderExpr) ?? 'Controller';

  return RouterControllerNode(explicitName: explicitName, builderWidgetType: builderWidgetType, children: children);
}

RouterShellNode? _parseShellNode(MethodInvocation expr) {
  final routesExpr = _namedArg(expr.argumentList, 'routes');
  if (routesExpr == null || routesExpr is! ListLiteral) return null;
  final children = routesExpr.elements.whereType<Expression>().map(_parseNode).nonNulls.toList();

  final nameExpr = _namedArg(expr.argumentList, 'name');
  final explicitName = nameExpr is StringLiteral ? nameExpr.stringValue : null;

  final builderExpr = _namedArg(expr.argumentList, 'builder');
  final builderWidgetType = _extractShellWidgetType(builderExpr) ?? 'Shell';

  return RouterShellNode(explicitName: explicitName, builderWidgetType: builderWidgetType, children: children);
}

String? _extractShellWidgetType(Expression? expr) {
  if (expr is! FunctionExpression) return null;
  final body = expr.body;
  if (body is! ExpressionFunctionBody) return null;
  final bodyExpr = body.expression;
  if (bodyExpr is InstanceCreationExpression) {
    return bodyExpr.constructorName.type.name.lexeme;
  }
  if (bodyExpr is MethodInvocation) {
    final target = bodyExpr.target;
    if (target is SimpleIdentifier) return target.name;
    return bodyExpr.methodName.name;
  }
  return null;
}

RouterGroupNode? _parseGroupNode(MethodInvocation expr) {
  final nameExpr = _namedArg(expr.argumentList, 'name');
  final routesExpr = _namedArg(expr.argumentList, 'routes');
  if (nameExpr == null || routesExpr == null) return null;

  final name = nameExpr is StringLiteral ? nameExpr.stringValue : null;
  if (name == null) return null;

  if (routesExpr is! ListLiteral) return null;

  final children = routesExpr.elements.whereType<Expression>().map(_parseNode).nonNulls.toList();

  final mainExpr = _namedArg(expr.argumentList, 'main');
  RouterViewNode? mainNode;
  if (mainExpr != null && mainExpr is MethodInvocation) {
    final parsed = _parseNode(mainExpr);
    if (parsed is RouterViewNode) mainNode = parsed;
  }

  return RouterGroupNode(name: name, main: mainNode, children: children);
}

RouterViewNode? _parseViewNode(MethodInvocation expr, {required bool isDeeplink}) {
  final typeArgs = expr.typeArguments?.arguments;
  if (typeArgs == null || typeArgs.length != 2) return null;

  return RouterViewNode(widgetType: typeArgs[0].toString(), paramsType: typeArgs[1].toString(), isDeeplink: isDeeplink);
}

Expression? _namedArg(ArgumentList argList, String argName) {
  for (final arg in argList.arguments) {
    if (arg is NamedArgument && arg.name.lexeme == argName) {
      return arg.argumentExpression;
    }
  }
  return null;
}
