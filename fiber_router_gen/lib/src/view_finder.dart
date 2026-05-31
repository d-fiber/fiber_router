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
