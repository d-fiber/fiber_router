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

import 'dart:async';
import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'controller.dart';

extension FiberRouterExtension on BuildContext {
  Future<T?> go<T extends Widget, P extends Object?>({P? queryParameters, bool replace = false}) async {
    final name = T.toString().toSnakeCase();

    final query = <String, String>{
      if (queryParameters is FiberParameters) ...queryParameters.toQuery(),
      '_id': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    if (!replace) {
      return pushNamed(name, queryParameters: query, extra: queryParameters);
    } else {
      Router.neglect(this, () => pushReplacementNamed(name, queryParameters: query, extra: queryParameters));
      return null;
    }
  }

  Future<T?> goShell<T extends Widget, P extends Object?>({P? queryParameters, bool replace = true}) async {
    final name = T.toString().toSnakeCase();
    final query = <String, String>{
      if (queryParameters is FiberParameters) ...queryParameters.toQuery(),
      '_id': DateTime.now().microsecondsSinceEpoch.toString(),
    };
    if (replace) {
      Router.neglect(this, () => pushReplacementNamed(name, queryParameters: query, extra: queryParameters));
      return null;
    } else {
      return pushNamed(name, queryParameters: query, extra: queryParameters);
    }
  }

  Future<T?> goShellNamed<T>(String routeName, {bool replace = false}) async {
    final query = <String, String>{'_id': DateTime.now().microsecondsSinceEpoch.toString()};
    if (replace) {
      Router.neglect(this, () => pushReplacementNamed(routeName, queryParameters: query));
      return null;
    } else {
      return pushNamed(routeName, queryParameters: query);
    }
  }
}

abstract interface class FiberParameters {
  Map<String, String> toQuery();
}

enum RouteTransition { system, fade, none }

class FiberRouter {
  const FiberRouter._();

  static GoRouter create({
    required Widget initialLocation,
    List<NavigatorObserver>? observers,
    FutureOr<Widget?> Function(BuildContext, GoRouterState)? redirect,
    required List<FiberRouteNode> nodes,
    Listenable? refreshListenable,
  }) {
    final controllerRouteNames = _collectControllerRouteNames(nodes);
    String pathFor(Widget widget) => '/${_routeNameFor(widget, controllerRouteNames)}';

    return GoRouter(
      initialLocation: pathFor(initialLocation),
      observers: [_fiberRouteObserver, ...?observers],
      refreshListenable: refreshListenable,
      redirect: (context, state) async {
        final result = await redirect?.call(context, state);
        if (result == null) return null;
        return pathFor(result);
      },
      debugLogDiagnostics: false,
      routes: _flatten(nodes, controllerRouteNames: controllerRouteNames),
    );
  }

  static Map<Type, String> _collectControllerRouteNames(List<FiberRouteNode> nodes) {
    final result = <Type, String>{};
    void walk(List<FiberRouteNode> list, List<String> ancestorPath) {
      for (final node in list) {
        if (node is _FiberControllerRouteNode) {
          final path = [...ancestorPath, node.name!.toSnakeCase()];
          result[node.controllerWidgetType] = path.join('_');
          walk(node.routes, path);
        } else if (node is _FiberShellRouteNode || node is _FiberBranchRouteNode) {
          walk(node.routes, [...ancestorPath, node.name!.toSnakeCase()]);
        } else {
          walk(node.routes, ancestorPath);
        }
      }
    }

    walk(nodes, const []);
    return result;
  }

  static String _routeNameFor(Widget widget, Map<Type, String> controllerRouteNames) =>
      controllerRouteNames[widget.runtimeType] ?? widget.runtimeType.toString().toSnakeCase();

  static List<RouteBase> _flatten(
    List<FiberRouteNode> nodes, {
    required Map<Type, String> controllerRouteNames,
    Widget? Function(BuildContext)? activeRedirect,
    List<String> ancestorPath = const [],
  }) {
    final routes = <RouteBase>[];

    for (final node in nodes) {
      if (node is _FiberControllerRouteNode) {
        final path = [...ancestorPath, node.name!.toSnakeCase()];
        final controllerName = path.join('_');
        final firstLeaf = _firstLeafName(node.routes, path);
        routes.add(
          ShellRoute(
            pageBuilder: (context, state, child) => _routeTransition(
              child: node.builder(context, child, state.extra),
              state: state,
              transition: node.transition,
              gesturePopEnabled: node.gesturePopEnabled,
            ),
            routes: [
              if (firstLeaf != null)
                GoRoute(
                  path: '/$controllerName',
                  name: controllerName,
                  redirect: (ctx, state) => '/${firstLeaf.toSnakeCase()}',
                ),
              ..._flatten(
                node.routes,
                controllerRouteNames: controllerRouteNames,
                activeRedirect: activeRedirect,
                ancestorPath: path,
              ),
            ],
          ),
        );
        continue;
      }
      if (node is _FiberShellRouteNode) {
        final path = [...ancestorPath, node.name!.toSnakeCase()];
        routes.add(
          ShellRoute(
            builder: (context, state, child) => node.builder(context, child, state.extra),
            routes: _flatten(node.routes, controllerRouteNames: controllerRouteNames, ancestorPath: path),
          ),
        );
        continue;
      }
      if (node is _FiberBranchRouteNode) {
        final path = [...ancestorPath, node.name!.toSnakeCase()];
        final redirect = node.redirect ?? activeRedirect;
        final main = node.main;
        if (main != null) {
          final viewName = main.name!.toSnakeCase();
          routes.add(
            GoRoute(
              path: "/$viewName",
              name: viewName,
              pageBuilder: main.pageBuilder!,
              redirect: redirect == null
                  ? null
                  : (ctx, _) {
                      final result = redirect(ctx);
                      if (result == null) return null;
                      return '/${_routeNameFor(result, controllerRouteNames)}';
                    },
            ),
          );
        }
        routes.addAll(
          _flatten(
            node.routes,
            controllerRouteNames: controllerRouteNames,
            activeRedirect: redirect,
            ancestorPath: path,
          ),
        );
      } else {
        final name = node.name?.toSnakeCase();
        if (name != null && node.pageBuilder != null) {
          routes.add(
            GoRoute(
              path: "/$name",
              name: name,
              pageBuilder: node.pageBuilder!,
              redirect: activeRedirect == null
                  ? null
                  : (ctx, _) {
                      final result = activeRedirect(ctx);
                      if (result == null) return null;
                      return '/${_routeNameFor(result, controllerRouteNames)}';
                    },
            ),
          );
        }
        routes.addAll(
          _flatten(
            node.routes,
            controllerRouteNames: controllerRouteNames,
            activeRedirect: activeRedirect,
            ancestorPath: ancestorPath,
          ),
        );
      }
    }
    return routes;
  }
}

sealed class FiberRouteNode {
  final String? name;
  final Page<dynamic> Function(BuildContext, GoRouterState)? pageBuilder;
  final List<FiberRouteNode> routes;

  const FiberRouteNode._({this.name, this.pageBuilder, this.routes = const []});

  Type? get controllerWidgetType => null;

  static FiberRouteNode view<T extends Widget, P extends Object?>({
    required String name,
    RouteTransition transition = RouteTransition.system,
    bool gesturePopEnabled = true,
    required Widget Function(BuildContext, P?) builder,
  }) => _FiberViewRouteNode<T, P?>(
    transition: transition,
    gesturePopEnabled: gesturePopEnabled,
    fromQuery: null,
    builder: builder,
  );

  static FiberRouteNode deeplink<T extends Widget, P extends FiberParameters>({
    required String name,
    RouteTransition transition = RouteTransition.system,
    bool gesturePopEnabled = true,
    required P Function(Map<String, String>) fromQuery,
    required Widget Function(BuildContext, P?) builder,
  }) => _FiberViewRouteNode<T, P?>(
    transition: transition,
    gesturePopEnabled: gesturePopEnabled,
    fromQuery: fromQuery,
    builder: builder,
  );

  const factory FiberRouteNode.node({
    required String name,
    FiberRouteNode? main,
    Widget? Function(BuildContext)? redirect,
    required List<FiberRouteNode> routes,
  }) = _FiberBranchRouteNode;

  static FiberRouteNode shell({
    required String name,
    required Widget Function(BuildContext context, Widget child, [Object? extra]) builder,
    required List<FiberRouteNode> routes,
  }) => _FiberShellRouteNode(name: name, builder: builder, routes: routes);

  static FiberRouteNode controller<T extends Widget>({
    required String name,
    RouteTransition transition = RouteTransition.none,
    bool gesturePopEnabled = false,
    Widget Function(BuildContext context, Widget child, [Object? extra])? builder,
    required List<FiberRouteNode> routes,
  }) => _FiberControllerRouteNode<T>(
    name: name,
    transition: transition,
    gesturePopEnabled: gesturePopEnabled,
    builder: builder ?? (context, child, [extra]) => ControllerView(child: child),
    routes: routes,
  );
}

final class _FiberViewRouteNode<T extends Widget, P extends Object?> extends FiberRouteNode {
  _FiberViewRouteNode({
    RouteTransition transition = RouteTransition.system,
    bool gesturePopEnabled = true,
    required P Function(Map<String, String>)? fromQuery,
    required Widget Function(BuildContext, P?) builder,
  }) : super._(
         name: T.toString(),
         pageBuilder: (context, state) {
           final params = (state.extra as P?) ?? fromQuery?.call(state.uri.queryParameters);

           return _routeTransition(
             child: builder(context, params),
             state: state,
             gesturePopEnabled: gesturePopEnabled,
             transition: transition,
           );
         },
       );
}

final class _FiberShellRouteNode extends FiberRouteNode {
  final Widget Function(BuildContext, Widget, [Object? extra]) builder;
  _FiberShellRouteNode({super.name, required this.builder, required super.routes}) : super._();
}

final class _FiberControllerRouteNode<T extends Widget> extends FiberRouteNode {
  final Widget Function(BuildContext, Widget, [Object? extra]) builder;
  final RouteTransition transition;
  final bool gesturePopEnabled;

  _FiberControllerRouteNode({
    required String name,
    required this.builder,
    required this.transition,
    required this.gesturePopEnabled,
    required super.routes,
  }) : super._(name: name);

  @override
  Type get controllerWidgetType => T;
}

final class _FiberBranchRouteNode extends FiberRouteNode {
  final FiberRouteNode? main;
  final Widget? Function(BuildContext)? redirect;
  const _FiberBranchRouteNode({required super.name, this.main, this.redirect, required super.routes}) : super._();
}

String? _firstLeafName(List<FiberRouteNode> nodes, List<String> ancestorPath) {
  for (final node in nodes) {
    if (node is _FiberViewRouteNode) return node.name;
    if (node is _FiberShellRouteNode) {
      final path = [...ancestorPath, node.name!.toSnakeCase()];
      final found = _firstLeafName(node.routes, path);
      if (found != null) return found;
    }
    if (node is _FiberControllerRouteNode) return [...ancestorPath, node.name!.toSnakeCase()].join('_');
    if (node is _FiberBranchRouteNode) {
      if (node.main?.name != null) return node.main!.name;
      final path = [...ancestorPath, node.name!.toSnakeCase()];
      final found = _firstLeafName(node.routes, path);
      if (found != null) return found;
    }
  }
  return null;
}

extension GoRouterStateExtension on GoRouterState {
  bool isOn<T extends Widget>() => matchedLocation.contains(T.toString().toSnakeCase());
}

extension QueryParametersRequireNotNull<P> on P? {
  P require([String? message]) {
    final value = this;
    if (value == null) {
      throw StateError(message ?? 'Required value is null');
    }
    return value;
  }
}

class _SleepingPage extends StatefulWidget {
  const _SleepingPage({required this.child});
  final Widget child;

  @override
  State<_SleepingPage> createState() => _SleepingPageState();
}

class _SleepingPageState extends State<_SleepingPage> with RouteAware {
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _fiberRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _fiberRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => setState(() => _active = false);

  @override
  void didPopNext() => setState(() => _active = true);

  @override
  Widget build(BuildContext context) => TickerMode(enabled: _active, child: widget.child);
}

Page<T> _routeTransition<T>({
  required Widget child,
  required GoRouterState state,
  RouteTransition transition = RouteTransition.system,
  bool gesturePopEnabled = true,
}) {
  final key = state.pageKey;
  final sleeping = _SleepingPage(child: child);

  if (transition == RouteTransition.none) {
    return NoTransitionPage<T>(key: key, child: sleeping);
  }
  if (transition == RouteTransition.fade) {
    return CustomTransitionPage<T>(
      key: key,
      child: sleeping,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeInCubic)),
          child: child,
        );
      },
    );
  }
  if (Platform.isIOS) {
    return _CupertinoRoutePage<T>(key: key, name: state.name, gesturePopEnabled: gesturePopEnabled, child: sleeping);
  }
  return CustomTransitionPage<T>(
    key: key,
    child: sleeping,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _CupertinoRoutePage<T> extends Page<T> {
  final Widget child;
  final bool gesturePopEnabled;

  const _CupertinoRoutePage({
    required this.child,
    required super.key,
    required this.gesturePopEnabled,
    super.name,
    super.arguments,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return _CupertinoPageRoute<T>(builder: (_) => child, settings: this, gesturePopEnabled: gesturePopEnabled);
  }
}

class _CupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  final bool gesturePopEnabled;

  _CupertinoPageRoute({
    required this.builder,
    this.title,
    super.settings,
    super.requestFocus,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
    this.gesturePopEnabled = true,
  }) {
    assert(opaque);
  }

  final WidgetBuilder builder;

  @override
  final String? title;

  @override
  final bool maintainState;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  bool get popGestureEnabled => gesturePopEnabled && super.popGestureEnabled;
}

final RouteObserver<PageRoute<dynamic>> _fiberRouteObserver = RouteObserver<PageRoute<dynamic>>();

final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero);
final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0 / 3.0, 0.0));

class _CupertinoPageTransition extends StatefulWidget {
  final Widget child;
  final Animation<double> primaryRouteAnimation;
  final Animation<double> secondaryRouteAnimation;
  final bool linearTransition;

  const _CupertinoPageTransition({
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    required this.linearTransition,
  });

  static Widget? delegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final CurvedAnimation animation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.linear,
      reverseCurve: Curves.easeInToLinear,
    );
    final Animation<Offset> delegatedPositionAnimation = animation.drive(_kMiddleLeftTween);
    animation.dispose();

    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: delegatedPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: child,
    );
  }

  @override
  State<_CupertinoPageTransition> createState() => __CupertinoPageTransitionState();
}

class __CupertinoPageTransitionState extends State<_CupertinoPageTransition> {
  late Animation<Offset> _primaryPositionAnimation;
  late Animation<Offset> _secondaryPositionAnimation;
  late Animation<Decoration> _primaryShadowAnimation;
  CurvedAnimation? _primaryPositionCurve;
  CurvedAnimation? _secondaryPositionCurve;
  CurvedAnimation? _primaryShadowCurve;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant _CupertinoPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryRouteAnimation != widget.primaryRouteAnimation ||
        oldWidget.secondaryRouteAnimation != widget.secondaryRouteAnimation ||
        oldWidget.linearTransition != widget.linearTransition) {
      _disposeCurve();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _disposeCurve();
    super.dispose();
  }

  void _disposeCurve() {
    _primaryPositionCurve?.dispose();
    _secondaryPositionCurve?.dispose();
    _primaryShadowCurve?.dispose();
    _primaryPositionCurve = null;
    _secondaryPositionCurve = null;
    _primaryShadowCurve = null;
  }

  void _setupAnimation() {
    if (!widget.linearTransition) {
      _primaryPositionCurve = CurvedAnimation(
        parent: widget.primaryRouteAnimation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      );
      _secondaryPositionCurve = CurvedAnimation(
        parent: widget.secondaryRouteAnimation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      );
      _primaryShadowCurve = CurvedAnimation(parent: widget.primaryRouteAnimation, curve: Curves.linearToEaseOut);
    }
    _primaryPositionAnimation = (_primaryPositionCurve ?? widget.primaryRouteAnimation).drive(_kRightMiddleTween);
    _secondaryPositionAnimation = (_secondaryPositionCurve ?? widget.secondaryRouteAnimation).drive(_kMiddleLeftTween);
    _primaryShadowAnimation = (_primaryShadowCurve ?? widget.primaryRouteAnimation).drive(
      _CupertinoEdgeShadowDecoration.kTween,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: _secondaryPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: SlideTransition(
        position: _primaryPositionAnimation,
        textDirection: textDirection,
        child: DecoratedBoxTransition(decoration: _primaryShadowAnimation, child: widget.child),
      ),
    );
  }
}

class _CupertinoEdgeShadowDecoration extends Decoration {
  const _CupertinoEdgeShadowDecoration._([this._colors]);

  static DecorationTween kTween = DecorationTween(
    begin: const _CupertinoEdgeShadowDecoration._(),
    end: const _CupertinoEdgeShadowDecoration._(<Color>[Color(0x04000000), Colors.transparent]),
  );

  final List<Color>? _colors;

  static _CupertinoEdgeShadowDecoration? lerp(
    _CupertinoEdgeShadowDecoration? a,
    _CupertinoEdgeShadowDecoration? b,
    double t,
  ) {
    if (identical(a, b)) return a;

    if (a == null) {
      return b!._colors == null
          ? b
          : _CupertinoEdgeShadowDecoration._(b._colors!.map((color) => Color.lerp(null, color, t)!).toList());
    }
    if (b == null) {
      return a._colors == null
          ? a
          : _CupertinoEdgeShadowDecoration._(a._colors.map((color) => Color.lerp(null, color, 1.0 - t)!).toList());
    }

    assert(b._colors != null || a._colors != null);
    assert(b._colors == null || a._colors == null || a._colors.length == b._colors.length);

    return _CupertinoEdgeShadowDecoration._(<Color>[
      for (int i = 0; i < b._colors!.length; i++) Color.lerp(a._colors?[i], b._colors[i], t)!,
    ]);
  }

  @override
  _CupertinoEdgeShadowDecoration lerpFrom(Decoration? a, double t) {
    if (a is _CupertinoEdgeShadowDecoration) {
      return _CupertinoEdgeShadowDecoration.lerp(a, this, t)!;
    }
    return _CupertinoEdgeShadowDecoration.lerp(null, this, t)!;
  }

  @override
  _CupertinoEdgeShadowDecoration lerpTo(Decoration? b, double t) {
    if (b is _CupertinoEdgeShadowDecoration) {
      return _CupertinoEdgeShadowDecoration.lerp(this, b, t)!;
    }
    return _CupertinoEdgeShadowDecoration.lerp(this, null, t)!;
  }

  @override
  _CupertinoEdgeShadowPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CupertinoEdgeShadowPainter(this, onChanged);
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType && other is _CupertinoEdgeShadowDecoration && other._colors == _colors;
  }

  @override
  int get hashCode => _colors.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Color>('colors', _colors));
  }
}

class _CupertinoEdgeShadowPainter extends BoxPainter {
  _CupertinoEdgeShadowPainter(this._decoration, super.onChanged)
    : assert(_decoration._colors == null || _decoration._colors.length > 1);

  final _CupertinoEdgeShadowDecoration _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final List<Color>? colors = _decoration._colors;
    if (colors == null) return;

    final double shadowWidth = 0.05 * configuration.size!.width;
    final double shadowHeight = configuration.size!.height;

    final double bandWidth = shadowWidth / (colors.length - 1);

    final TextDirection? textDirection = configuration.textDirection;
    assert(textDirection != null);

    final (double shadowDirection, double start) = switch (textDirection!) {
      TextDirection.rtl => (1, offset.dx + configuration.size!.width),
      TextDirection.ltr => (-1, offset.dx),
    };

    int bandColorIndex = 0;

    for (int dx = 0; dx < shadowWidth; dx++) {
      if (dx ~/ bandWidth != bandColorIndex) {
        bandColorIndex += 1;
      }

      final Color interpolatedColor = Color.lerp(
        colors[bandColorIndex],
        colors[bandColorIndex + 1],
        (dx % bandWidth) / bandWidth,
      )!;

      final double x = start + shadowDirection * dx;
      canvas.drawRect(Rect.fromLTWH(x - 1.0, offset.dy, 1.0, shadowHeight), Paint()..color = interpolatedColor);
    }
  }
}

class FiberFadeTransition<T> extends PageRoute<T> {
  final Widget child;

  FiberFadeTransition(this.child);

  @override
  Color get barrierColor => Colors.transparent;

  @override
  bool get opaque => false;

  @override
  String get barrierLabel => "-";

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      FadeTransition(opacity: animation, child: child);
}
