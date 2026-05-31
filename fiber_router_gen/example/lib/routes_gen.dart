// GENERATED CODE — DO NOT MODIFY BY HAND
// Run: dart run fiber_router_gen <router_file.dart>

import 'package:flutter/material.dart';
import 'package:fiber_router_annotation/fiber_router_annotation.dart';
import 'routes_gen.dart';

extension BuildContextRouterExtension on BuildContext {
  ContextRouter get router => ContextRouter(this);
}

class ContextRouter {
  final BuildContext _context;
  ContextRouter(this._context);

  ContextRouterAuth get auth => ContextRouterAuth(_context);
  GoRouter get appControllerView => GoRouter((r) => _context.go<AppControllerView, Null>(replace: r));
  GoRouterParams<NotificationsParameters> get notificationsView => GoRouterParams<NotificationsParameters>((params, r) => _context.go<NotificationsView, NotificationsParameters>(queryParameters: params, replace: r));
  GoRouterParams<Notifications2Parameters> get notificationsView2 => GoRouterParams<Notifications2Parameters>((params, r) => _context.go<NotificationsView2, Notifications2Parameters>(queryParameters: params, replace: r));
}

class ContextRouterAuth {
  final BuildContext _context;
  ContextRouterAuth(this._context);

  GoRouter get authControllerView => GoRouter((r) => _context.go<AuthControllerView, Null>(replace: r));
  GoRouter get signInView => GoRouter((r) => _context.go<SignInView, Null>(replace: r));
  ContextRouterTest get test => ContextRouterTest(_context);
}

class ContextRouterTest {
  final BuildContext _context;
  ContextRouterTest(this._context);

  GoRouter get testControllerView => GoRouter((r) => _context.go<TestControllerView, Null>(replace: r));
}

class GoRouter {
  final void Function(bool) _onNavigate;
  GoRouter(this._onNavigate);
  void go({bool replace = false}) => _onNavigate(replace);
}

class GoRouterParams<P extends Object?> {
  final void Function(P, bool) _onNavigate;
  GoRouterParams(this._onNavigate);
  void go(P params, {bool replace = false}) => _onNavigate(params, replace);
}

class NotificationsParameters {
  final dynamic notificationId;
  final dynamic count;

  const NotificationsParameters({required this.notificationId, required this.count, });

}

class Notifications2Parameters implements PoppinParameters {
  final dynamic notificationId;
  final dynamic count;

  const Notifications2Parameters({required this.notificationId, required this.count, });

  @override
  Map<String, String> toQuery() => {
    'notificationId': notificationId.toString(),
    'count': count.toString(),
  };

  static Notifications2Parameters fromMap(Map<String, String> map) =>
      Notifications2Parameters(
        notificationId: map['notificationId']!,
        count: map['count']!,
      );
}

