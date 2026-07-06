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

import 'package:fiber_router_gen/fiber_router_gen.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  String? inputPath;
  String? outputPath;

  for (var i = 0; i < args.length; i++) {
    if (inputPath == null) {
      inputPath = p.absolute(args[i]);
    } else {
      outputPath ??= p.absolute(args[i]);
    }
  }

  if (inputPath == null) {
    stderr.writeln('Usage: dart run fiber_router_gen <router.dart> [output.dart]');
    exit(1);
  }

  outputPath ??= p.join(p.dirname(inputPath), '${p.basenameWithoutExtension(inputPath)}_gen.dart');

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('File not found: $inputPath');
    exit(1);
  }

  final source = inputFile.readAsStringSync();

  try {
    final nodes = parseRouterFile(source);
    final rawImports = extractImports(source);

    final searchDir = _findLibDir(inputPath) ?? Directory(p.dirname(inputPath));
    final paramsMap = <String, List<ConstructorParam>>{};

    for (final view in _allViewNodes(nodes).where((v) => v.hasParams)) {
      final ctorParams = findConstructorParams(view.widgetType, searchDir);
      if (ctorParams.isNotEmpty) {
        paramsMap[view.widgetType] = ctorParams;
        stdout.writeln('  Found ${ctorParams.length} param(s) for ${view.widgetType}');
      } else {
        stderr.writeln('  Warning: no constructor found for ${view.widgetType}');
      }
    }

    final neededTypes = _allViewNodes(nodes).expand((v) => [v.widgetType, if (v.hasParams) v.paramsType]).toSet();
    final imports = filterImports(rawImports, neededTypes, inputPath);

    final code = generateRouterExtension(nodes, imports: imports, paramsMap: paramsMap);

    File(outputPath).writeAsStringSync(code);
    stdout.writeln('Generated: $outputPath');
  } catch (e, st) {
    stderr.writeln('Error: $e');
    stderr.writeln(st);
    exit(1);
  }
}

Directory? _findLibDir(String filePath) {
  var dir = Directory(p.dirname(filePath));
  while (true) {
    if (p.basename(dir.path) == 'lib') return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
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
