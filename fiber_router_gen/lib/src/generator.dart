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

void _writeClass(StringBuffer buf, String className, List<RouterNode> nodes) {
  buf.writeln('class $className {');
  buf.writeln('  final BuildContext _context;');
  buf.writeln('  $className(this._context);');
  buf.writeln();

  for (final node in nodes) {
    _writeMember(buf, node);
  }

  buf.writeln('}');
  buf.writeln();
}

void _writeMember(StringBuffer buf, RouterNode node) {
  switch (node) {
    case RouterGroupNode(:final name):
      final cls = _groupClassName(name);
      buf.writeln('  $cls get $name => $cls(_context);');
    case RouterViewNode():
      _writeViewGetter(buf, node, indent: '  ');
  }
}

void _writeViewGetter(StringBuffer buf, RouterViewNode node, {required String indent}) {
  final getterName = _viewGetterName(node.widgetType);

  if (node.hasParams) {
    buf.writeln(
      '${indent}GoRouterParams<${node.paramsType}> get $getterName => '
      'GoRouterParams<${node.paramsType}>((params, r) => _context.go<${node.widgetType}, ${node.paramsType}>(queryParameters: params, replace: r));',
    );
  } else {
    buf.writeln(
      '${indent}GoRouter get $getterName => '
      'GoRouter((r) => _context.go<${node.widgetType}, Null>(replace: r));',
    );
  }
}

void _writeGroupClasses(StringBuffer buf, List<RouterNode> nodes) {
  for (final node in nodes) {
    if (node is! RouterGroupNode) continue;
    _writeClass(buf, _groupClassName(node.name), node.children);
    _writeGroupClasses(buf, node.children);
  }
}

void _writeGoRouterClasses(StringBuffer buf) {
  buf.writeln('class GoRouter {');
  buf.writeln('  final void Function(bool) _onNavigate;');
  buf.writeln('  GoRouter(this._onNavigate);');
  buf.writeln('  void go({bool replace = false}) => _onNavigate(replace);');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class GoRouterParams<P extends Object?> {');
  buf.writeln('  final void Function(P, bool) _onNavigate;');
  buf.writeln('  GoRouterParams(this._onNavigate);');
  buf.writeln('  void go(P params, {bool replace = false}) => _onNavigate(params, replace);');
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

String _groupClassName(String nodeName) => 'ContextRouter${nodeName[0].toUpperCase()}${nodeName.substring(1)}';

String _viewGetterName(String widgetType) => widgetType[0].toLowerCase() + widgetType.substring(1);

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
    if (node is RouterGroupNode) yield* _allViewNodes(node.children);
  }
}
