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

import 'models.dart';

List<ConstructorParam> findConstructorParams(String className, Directory libDir) {
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final source = entity.readAsStringSync();
    if (!source.contains('class $className ') && !source.contains('class $className{')) {
      continue;
    }

    final params = _parseConstructorParams(className, source);
    if (params != null) return params;
  }
  return [];
}

List<ConstructorParam>? _parseConstructorParams(String className, String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  for (final decl in result.unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    if (decl.namePart.typeName.lexeme != className) continue;

    final ctors = decl.body.members.whereType<ConstructorDeclaration>();
    if (ctors.isEmpty) return [];

    final ctor = ctors.firstWhere((c) => c.name == null, orElse: () => ctors.first);

    return _extractParams(ctor);
  }
  return null;
}

List<ConstructorParam> _extractParams(ConstructorDeclaration ctor) {
  final params = <ConstructorParam>[];

  for (final param in ctor.parameters.parameters) {
    if (param is SuperFormalParameter) continue;

    final name = param.name?.lexeme;
    if (name == null || name == 'key') continue;

    final typeSource = param.type?.toSource() ?? 'dynamic';
    final isNullable = typeSource.endsWith('?');

    params.add(ConstructorParam(name: name, type: typeSource, isRequired: param.isRequired, isNullable: isNullable));
  }

  return params;
}
