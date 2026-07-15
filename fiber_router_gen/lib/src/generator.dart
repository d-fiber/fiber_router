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

  final classNames = _resolveClassNames(nodes);
  final routeNames = _resolveControllerRouteNames(nodes);

  _writeClass(buf, 'ContextRouter', nodes, classNames: classNames);
  _writeGroupClasses(buf, nodes, classNames, routeNames);

  _writeGoRouterClasses(buf);

  _writeParamsClasses(buf, nodes, paramsMap);

  return buf.toString();
}

Map<RouterNode, String> _resolveControllerRouteNames(List<RouterNode> nodes) {
  final result = <RouterNode, String>{};

  void walk(List<RouterNode> list, List<String> ancestorPath) {
    for (final node in _mergeGroupNodes(list)) {
      switch (node) {
        case RouterControllerNode(:final children):
          final ownName = (node.explicitName ?? node.builderWidgetType).toSnakeCase();
          final path = [...ancestorPath, ownName];
          result[node] = path.join('_');
          walk(children, path);
        case RouterShellNode(:final children):
          final path = [...ancestorPath, node.effectiveGroupName.toSnakeCase()];
          walk(children, path);
        case RouterGroupNode(:final name, :final children):
          final path = [...ancestorPath, name.toSnakeCase()];
          walk(children, path);
        case RouterViewNode():
          break;
      }
    }
  }

  walk(nodes, const []);

  final counts = <String, int>{};
  for (final routeName in result.values) {
    counts[routeName] = (counts[routeName] ?? 0) + 1;
  }
  final collisions = counts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
  if (collisions.isNotEmpty) {
    throw StateError(
      'fiber_router_gen: duplicate controller route name(s) even after ancestor-path qualification: '
      '${collisions.join(', ')}. This means two controllers occupy the exact same position in the tree — '
      'check for a duplicated node in router.dart.',
    );
  }

  return result;
}

Map<RouterNode, String> _resolveClassNames(List<RouterNode> nodes) {
  final shortNames = <RouterNode, String>{};
  final ancestorPaths = <RouterNode, List<String>>{};

  void walk(List<RouterNode> list, List<String> ancestors) {
    for (final node in _mergeGroupNodes(list)) {
      switch (node) {
        case RouterShellNode(:final children):
          final shortName = node.effectiveGroupName;
          shortNames[node] = shortName;
          ancestorPaths[node] = [...ancestors, shortName];
          walk(children, ancestorPaths[node]!);
        case RouterControllerNode(:final children):
          final shortName = node.effectiveGroupName;
          shortNames[node] = shortName;
          ancestorPaths[node] = [...ancestors, shortName];
          walk(children, ancestorPaths[node]!);
        case RouterGroupNode(:final name, :final children):
          shortNames[node] = name;
          ancestorPaths[node] = [...ancestors, name];
          walk(children, ancestorPaths[node]!);
        case RouterViewNode():
          break;
      }
    }
  }

  walk(nodes, const []);

  final shortNameCounts = <String, int>{'ContextRouter': 1};
  for (final shortName in shortNames.values) {
    final cls = _groupClassName(shortName);
    shortNameCounts[cls] = (shortNameCounts[cls] ?? 0) + 1;
  }

  final resolved = <RouterNode, String>{};
  for (final node in shortNames.keys) {
    final shortCls = _groupClassName(shortNames[node]!);
    resolved[node] = (shortNameCounts[shortCls] ?? 0) > 1 ? _qualifiedClassName(ancestorPaths[node]!) : shortCls;
  }

  final finalCounts = <String, int>{};
  for (final cls in resolved.values) {
    finalCounts[cls] = (finalCounts[cls] ?? 0) + 1;
  }
  final collisions = finalCounts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
  if (collisions.isNotEmpty) {
    throw StateError(
      'fiber_router_gen: duplicate generated class name(s) even after qualifying with ancestor names: '
      '${collisions.join(', ')}. Give one of the conflicting shell/controller/node nodes a distinct `name`.',
    );
  }

  return resolved;
}

String _qualifiedClassName(List<String> ancestorPath) =>
    'ContextRouter${ancestorPath.map((n) => n.toPascalCase()).join()}';

void _writeClass(
  StringBuffer buf,
  String className,
  List<RouterNode> nodes, {
  required Map<RouterNode, String> classNames,
  RouterViewNode? main,
  bool isShell = false,
  String? controllerRouteName,
  ({String paramsType, String getterPath})? controllerDelegateGo,
}) {
  buf.writeln('class $className {');
  buf.writeln('  final BuildContext _context;');
  buf.writeln('  $className(this._context);');
  buf.writeln();

  if (main != null) {
    _writeViewGo(buf, main, indent: '  ');
    buf.writeln("  String get name => '${main.widgetType.toSnakeCase()}';");
    buf.writeln();
  }

  if (controllerRouteName != null) {
    _writeControllerGo(buf, controllerRouteName, indent: '  ');
    buf.writeln();
  } else if (controllerDelegateGo != null) {
    buf.writeln(
      '  Future<R?> go<R>(${controllerDelegateGo.paramsType} params, {bool replace = false}) => '
      '${controllerDelegateGo.getterPath}.go(params, replace: replace);',
    );
    buf.writeln();
  }

  for (final node in _mergeGroupNodes(nodes)) {
    _writeMember(buf, node, classNames, isShell: isShell);
  }

  buf.writeln('}');
  buf.writeln();
}

void _writeMember(StringBuffer buf, RouterNode node, Map<RouterNode, String> classNames, {bool isShell = false}) {
  switch (node) {
    case RouterShellNode():
      final cls = classNames[node]!;
      buf.writeln('  $cls get ${node.effectiveGroupName.toCamelCase()} => $cls(_context);');
    case RouterControllerNode():
      final cls = classNames[node]!;
      buf.writeln('  $cls get ${node.effectiveGroupName.toCamelCase()} => $cls(_context);');
    case RouterGroupNode(:final name):
      final cls = classNames[node]!;
      buf.writeln('  $cls get ${name.toCamelCase()} => $cls(_context);');
    case RouterViewNode():
      _writeViewGetter(buf, node, indent: '  ', isShell: isShell);
  }
}

void _writeControllerGo(StringBuffer buf, String routeName, {required String indent}) {
  final routeNameLiteral = "'$routeName'";
  buf.writeln(
    '${indent}Future<R?> go<R>({bool replace = false}) => _context.goShellNamed<R>($routeNameLiteral, replace: replace);',
  );
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
  final getterName = _viewGetterName(node);
  final routeName = "'${node.widgetType.toSnakeCase()}'";

  if (isShell) {
    if (node.hasParams) {
      buf.writeln(
        '${indent}ShellRouterParams<${node.widgetType}, ${node.paramsType}> get $getterName => '
        'ShellRouterParams<${node.widgetType}, ${node.paramsType}>((params, r) => _context.goShell<${node.widgetType}, ${node.paramsType}>(queryParameters: params, replace: r), $routeName);',
      );
    } else {
      buf.writeln(
        '${indent}ShellRouter<${node.widgetType}> get $getterName => '
        'ShellRouter<${node.widgetType}>(_context, $routeName);',
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

void _writeGroupClasses(
  StringBuffer buf,
  List<RouterNode> nodes,
  Map<RouterNode, String> classNames,
  Map<RouterNode, String> routeNames,
) {
  final merged = _mergeGroupNodes(nodes);
  for (final node in merged) {
    if (node is RouterShellNode) {
      _writeClass(buf, classNames[node]!, node.children, isShell: true, classNames: classNames);
      _writeGroupClasses(buf, node.children, classNames, routeNames);
    } else if (node is RouterControllerNode) {
      final routeName = routeNames[node]!;
      final firstLeafPath = _firstLeafPath(node.children);
      _writeClass(
        buf,
        classNames[node]!,
        node.children,
        isShell: true,
        controllerRouteName: (firstLeafPath != null && !firstLeafPath.leaf.hasParams) ? routeName : null,
        controllerDelegateGo: (firstLeafPath != null && firstLeafPath.leaf.hasParams)
            ? (paramsType: firstLeafPath.leaf.paramsType, getterPath: firstLeafPath.getterPath.join('.'))
            : null,
        classNames: classNames,
      );
      _writeGroupClasses(buf, node.children, classNames, routeNames);
    } else if (node is RouterGroupNode) {
      _writeClass(buf, classNames[node]!, node.children, main: node.main, classNames: classNames);
      _writeGroupClasses(buf, node.children, classNames, routeNames);
    }
  }
}

({RouterViewNode leaf, List<String> getterPath})? _firstLeafPath(List<RouterNode> nodes) {
  for (final node in nodes) {
    switch (node) {
      case RouterViewNode():
        return (leaf: node, getterPath: [_viewGetterName(node)]);
      case RouterShellNode(:final children):
        final found = _firstLeafPath(children);
        if (found != null) {
          return (leaf: found.leaf, getterPath: [node.effectiveGroupName.toCamelCase(), ...found.getterPath]);
        }
      case RouterControllerNode(:final children):
        final found = _firstLeafPath(children);
        if (found != null) {
          return (leaf: found.leaf, getterPath: [node.effectiveGroupName.toCamelCase(), ...found.getterPath]);
        }
      case RouterGroupNode(:final main, :final children):
        if (main != null) return (leaf: main, getterPath: [_viewGetterName(main)]);
        final found = _firstLeafPath(children);
        if (found != null) {
          return (leaf: found.leaf, getterPath: [node.name.toCamelCase(), ...found.getterPath]);
        }
    }
  }
  return null;
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
    } else {
      result.add(node);
    }
  }
  return result;
}

void _writeGoRouterClasses(StringBuffer buf) {
  buf.writeln('abstract class FiberRouterBase<T> {');
  buf.writeln('  final String name;');
  buf.writeln('  const FiberRouterBase(this.name);');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class GoRouter<T> extends FiberRouterBase<T> {');
  buf.writeln('  final Future<dynamic> Function(bool) _onNavigate;');
  buf.writeln('  GoRouter(this._onNavigate, super.name);');
  buf.writeln('  Future<R?> go<R>({bool replace = false}) async => (await _onNavigate(replace)) as R?;');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class GoRouterParams<T, P extends Object?> extends FiberRouterBase<T> {');
  buf.writeln('  final Future<dynamic> Function(P, bool) _onNavigate;');
  buf.writeln('  GoRouterParams(this._onNavigate, super.name);');
  buf.writeln(
    '  Future<R?> go<R>(P params, {bool replace = false}) async => (await _onNavigate(params, replace)) as R?;',
  );
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class ShellRouter<T> extends FiberRouterBase<T> {');
  buf.writeln('  final BuildContext _context;');
  buf.writeln('  ShellRouter(this._context, super.name);');
  buf.writeln('  Future<R?> go<R>({bool replace = true}) => _context.goShellNamed<R>(name, replace: replace);');
  buf.writeln('  Future<R?> push<R>() => _context.goShellNamed<R>(name, replace: false);');
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class ShellRouterParams<T, P extends Object?> extends FiberRouterBase<T> {');
  buf.writeln('  final Future<dynamic> Function(P, bool) _onNavigate;');
  buf.writeln('  ShellRouterParams(this._onNavigate, super.name);');
  buf.writeln(
    '  Future<R?> go<R>(P params, {bool replace = true}) async => (await _onNavigate(params, replace)) as R?;',
  );
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
  final declaration = isDeeplink ? 'class $className implements FiberParameters {' : 'class $className {';
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

String _viewGetterName(RouterViewNode node) {
  if (node.explicitName != null) return node.explicitName!.toCamelCase();
  final widgetType = node.widgetType;
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
    if (node is RouterControllerNode) yield* _allViewNodes(node.children);
    if (node is RouterGroupNode) {
      if (node.main != null) yield node.main!;
      yield* _allViewNodes(node.children);
    }
  }
}
