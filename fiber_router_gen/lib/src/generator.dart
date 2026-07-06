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

import 'package:change_case/change_case.dart';

import 'models.dart';

typedef ParamsMap = Map<String, List<ConstructorParam>>;

const _mandatoryImports = ["import 'package:flutter/material.dart';"];

String generateRouterExtension(
  List<RouterNode> nodes, {
  List<String> imports = const [],
  ParamsMap paramsMap = const {},
}) {
  final buf = StringBuffer();

  buf.writeln('// GENERATED CODE — DO NOT MODIFY BY HAND');
  buf.writeln('// Run: dart run fiber_router_gen <router_file.dart>');
  buf.writeln();

  final allImports = [..._mandatoryImports, ...imports.where((i) => !_mandatoryImports.contains(i))];
  for (final imp in allImports) {
    buf.writeln(imp);
  }
  buf.writeln();

  buf.writeln('extension BuildContextRouterExtension on BuildContext {');
  buf.writeln('  ContextRouter get router => ContextRouter(this);');
  buf.writeln('}');
  buf.writeln();

  _writeClass(buf, 'ContextRouter', nodes);
  _writeGroupClasses(buf, nodes);

  _writeGoRouterClasses(buf);

  _writeParamsClasses(buf, nodes, paramsMap);

  return buf.toString();
}

void _writeClass(StringBuffer buf, String className, List<RouterNode> nodes, {RouterViewNode? main, bool isShell = false}) {
  buf.writeln('class $className {');
  buf.writeln('  final BuildContext _context;');
  buf.writeln('  $className(this._context);');
  buf.writeln();

  if (main != null) {
    _writeViewGo(buf, main, indent: '  ');
    buf.writeln("  String get name => '${main.widgetType.toSnakeCase()}';");
    buf.writeln();
  }

  for (final node in _mergeGroupNodes(nodes)) {
    _writeMember(buf, node, isShell: isShell);
  }

  buf.writeln('}');
  buf.writeln();
}

void _writeMember(StringBuffer buf, RouterNode node, {bool isShell = false}) {
  switch (node) {
    case RouterShellNode(:final builderWidgetType):
      final groupName = _shellGroupName(builderWidgetType);
      final cls = _groupClassName(groupName);
      buf.writeln('  $cls get ${groupName.toCamelCase()} => $cls(_context);');
    case RouterGroupNode(:final name):
      final cls = _groupClassName(name);
      buf.writeln('  $cls get ${name.toCamelCase()} => $cls(_context);');
    case RouterViewNode():
      _writeViewGetter(buf, node, indent: '  ', isShell: isShell);
  }
}

void _writeViewGo(StringBuffer buf, RouterViewNode node, {required String indent}) {
  if (node.hasParams) {
    buf.writeln(
      '${indent}void go(${node.paramsType} params, {bool replace = false}) => '
      '_context.go<${node.widgetType}, ${node.paramsType}>(queryParameters: params, replace: replace);',
    );
  } else {
    buf.writeln(
      '${indent}void go({bool replace = false}) => '
      '_context.go<${node.widgetType}, Null>(replace: replace);',
    );
  }
}

void _writeViewGetter(StringBuffer buf, RouterViewNode node, {required String indent, bool isShell = false}) {
  final getterName = _viewGetterName(node.widgetType);
  final routeName = "'${node.widgetType.toSnakeCase()}'";

  if (isShell) {
    if (node.hasParams) {
      buf.writeln(
        '${indent}ShellRouterParams<${node.widgetType}, ${node.paramsType}> get $getterName => '
        'ShellRouterParams<${node.widgetType}, ${node.paramsType}>((params) => _context.goShell<${node.widgetType}, ${node.paramsType}>(queryParameters: params), $routeName);',
      );
    } else {
      buf.writeln(
        '${indent}ShellRouter<${node.widgetType}> get $getterName => '
        'ShellRouter<${node.widgetType}>(() => _context.goShell<${node.widgetType}, Null>(), $routeName);',
      );
    }
  } else {
    if (node.hasParams) {
      buf.writeln(
        '${indent}GoRouterParams<${node.widgetType}, ${node.paramsType}> get $getterName => '
        'GoRouterParams<${node.widgetType}, ${node.paramsType}>((params, r) => _context.go<${node.widgetType}, ${node.paramsType}>(queryParameters: params, replace: r), $routeName);',
      );
    } else {
      buf.writeln(
        '${indent}GoRouter<${node.widgetType}> get $getterName => '
        'GoRouter<${node.widgetType}>((r) => _context.go<${node.widgetType}, Null>(replace: r), $routeName);',
      );
    }
  }
}

void _writeGroupClasses(StringBuffer buf, List<RouterNode> nodes) {
  final merged = _mergeGroupNodes(nodes);
  for (final node in merged) {
    if (node is RouterShellNode) {
      final groupName = _shellGroupName(node.builderWidgetType);
      _writeClass(buf, _groupClassName(groupName), node.children, isShell: true);
      _writeGroupClasses(buf, node.children);
    } else if (node is RouterGroupNode) {
      _writeClass(buf, _groupClassName(node.name), node.children, main: node.main);
      _writeGroupClasses(buf, node.children);
    }
  }
}

List<RouterNode> _mergeGroupNodes(List<RouterNode> nodes) {
  final result = <RouterNode>[];
  final seen = <String, RouterGroupNode>{};
  for (final node in nodes) {
    if (node is RouterGroupNode) {
      if (seen.containsKey(node.name)) {
        final existing = seen[node.name]!;
        final merged = RouterGroupNode(
          name: existing.name,
          main: existing.main ?? node.main,
          children: [...existing.children, ...node.children],
        );
        seen[node.name] = merged;
        final idx = result.indexWhere((n) => n is RouterGroupNode && n.name == node.name);
        result[idx] = merged;
      } else {
        seen[node.name] = node;
        result.add(node);
      }
    } else if (node is RouterShellNode) {
      result.add(node);
    } else {
      result.add(node);
    }
  }
  return result;
}

void _writeGoRouterClasses(StringBuffer buf) {
  buf.writeln('class GoRouter<T> {');
  buf.writeln('  final void Function(bool) _onNavigate;');
  buf.writeln('  final String name;');
  buf.writeln('  GoRouter(this._onNavigate, this.name);');
  buf.writeln('  void go({bool replace = false}) => _onNavigate(replace);');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class GoRouterParams<T, P extends Object?> {');
  buf.writeln('  final void Function(P, bool) _onNavigate;');
  buf.writeln('  final String name;');
  buf.writeln('  GoRouterParams(this._onNavigate, this.name);');
  buf.writeln('  void go(P params, {bool replace = false}) => _onNavigate(params, replace);');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class ShellRouter<T> {');
  buf.writeln('  final void Function() _onNavigate;');
  buf.writeln('  final String name;');
  buf.writeln('  ShellRouter(this._onNavigate, this.name);');
  buf.writeln('  void go() => _onNavigate();');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class ShellRouterParams<T, P extends Object?> {');
  buf.writeln('  final void Function(P) _onNavigate;');
  buf.writeln('  final String name;');
  buf.writeln('  ShellRouterParams(this._onNavigate, this.name);');
  buf.writeln('  void go(P params) => _onNavigate(params);');
  buf.writeln('}');
  buf.writeln();
}

void _writeParamsClasses(StringBuffer buf, List<RouterNode> nodes, ParamsMap paramsMap) {
  for (final node in _allViewNodes(nodes)) {
    if (!node.hasParams) continue;
    final ctorParams = paramsMap[node.widgetType];
    if (ctorParams == null || ctorParams.isEmpty) continue;
    _writeParamsClass(buf, node.paramsType, ctorParams, isDeeplink: node.isDeeplink);
  }
}

void _writeParamsClass(StringBuffer buf, String className, List<ConstructorParam> params, {required bool isDeeplink}) {
  final declaration = isDeeplink ? 'class $className implements PoppinParameters {' : 'class $className {';
  buf.writeln(declaration);

  for (final p in params) {
    buf.writeln('  final ${p.type} ${p.name};');
  }
  buf.writeln();

  buf.write('  const $className({');
  for (final p in params) {
    if (p.isRequired && !p.isNullable) buf.write('required ');
    buf.write('this.${p.name}, ');
  }
  buf.writeln('});');
  buf.writeln();

  if (isDeeplink) {
    buf.writeln('  @override');
    buf.writeln('  Map<String, String> toQuery() => {');
    for (final p in params) {
      buf.writeln("    '${p.name}': ${_toQueryExpr(p)},");
    }
    buf.writeln('  };');
    buf.writeln();

    buf.writeln('  static $className fromMap(Map<String, String> map) =>');
    buf.writeln('      $className(');
    for (final p in params) {
      buf.writeln("        ${p.name}: ${_fromMapExpr(p)},");
    }
    buf.writeln('      );');
  }

  buf.writeln('}');
  buf.writeln();
}

String _groupClassName(String nodeName) => 'ContextRouter${nodeName.toPascalCase()}';

String _shellGroupName(String builderWidgetType) {
  if (builderWidgetType.endsWith('View')) {
    return builderWidgetType.substring(0, builderWidgetType.length - 4);
  }
  return builderWidgetType;
}

String _viewGetterName(String widgetType) {
  final name = widgetType.endsWith('View') ? widgetType.substring(0, widgetType.length - 4) : widgetType;
  return name.toCamelCase();
}

String _toQueryExpr(ConstructorParam p) {
  final baseType = p.type.replaceAll('?', '');
  if (baseType == 'String') return p.isNullable ? "${p.name} ?? ''" : p.name;
  return p.isNullable ? "${p.name}?.toString() ?? ''" : '${p.name}.toString()';
}

String _fromMapExpr(ConstructorParam p) {
  final baseType = p.type.replaceAll('?', '');
  final raw = "map['${p.name}']";
  if (p.isNullable) {
    return switch (baseType) {
      'int' => "$raw != null ? int.parse($raw!) : null",
      'double' => "$raw != null ? double.parse($raw!) : null",
      'bool' => "$raw != null ? $raw == 'true' : null",
      _ => raw,
    };
  }
  return switch (baseType) {
    'int' => "int.parse($raw!)",
    'double' => "double.parse($raw!)",
    'bool' => "$raw == 'true'",
    _ => "$raw!",
  };
}

Iterable<RouterViewNode> _allViewNodes(List<RouterNode> nodes) sync* {
  for (final node in nodes) {
    if (node is RouterViewNode) yield node;
    if (node is RouterShellNode) yield* _allViewNodes(node.children);
    if (node is RouterGroupNode) {
      if (node.main != null) yield node.main!;
      yield* _allViewNodes(node.children);
    }
  }
}
