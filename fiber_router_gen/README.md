# fiber_router_gen

Code generator for [`fiber_router`](https://pub.dev/packages/fiber_router) - produces typed `BuildContext` navigation extensions from your `PoppinRouter` definition.

---

## Features

- Generates a `ContextRouter` extension on `BuildContext` with typed getters for every route
- Supports `view`, `node`, `shell`, and `deeplink` route nodes
- Shell routes are transparent - their children appear directly on the parent class
- Generates `Parameters` classes with `toQuery()` / `fromMap()` for deeplink routes
- Filters imports automatically - only what the generated file actually needs

---

## Installation

Add as a dev dependency (it's a CLI tool, not a runtime dependency):

```yaml
dev_dependencies:
  fiber_router_gen: ^1.0.0
```

---

## Usage

### 1. Annotate your router

```dart
import 'package:fiber_router/fiber_router.dart';

@FiberRouterGen()
final router = PoppinRouter.create(
  initialLocation: const HomeView(),
  nodes: [
    PoppinRouteNode.view<HomeView, Null>(
      builder: (_, __) => const HomeView(),
    ),
    PoppinRouteNode.node(
      name: 'dashboard',
      main: PoppinRouteNode.view<DashboardView, Null>(
        builder: (_, __) => const DashboardView(),
      ),
      routes: [
        PoppinRouteNode.view<SettingsView, Null>(
          builder: (_, __) => const SettingsView(),
        ),
      ],
    ),
    PoppinRouteNode.shell(
      builder: (context, child) => AuthShell(child: child),
      routes: [
        PoppinRouteNode.view<SignInView, Null>(
          builder: (_, __) => const SignInView(),
        ),
        PoppinRouteNode.view<OtpView, OtpParameters>(
          builder: (_, params) => OtpView(token: params?.token ?? ''),
        ),
      ],
    ),
  ],
);
```

### 2. Run the generator

```bash
dart run fiber_router_gen lib/src/router/router.dart
```

By default the output is written next to the input file as `router.g.dart`. You can specify a custom output path:

```bash
dart run fiber_router_gen lib/src/router/router.dart lib/src/router/router.g.dart
```

### 3. Use the generated code

```dart
// Simple view
context.router.home.go();

// Named group
context.router.dashboard.go();
context.router.dashboard.settings.go();

// Shell children - exposed directly on ContextRouter (no sub-class)
context.router.signIn.go();
context.router.otp.go(OtpParameters(token: token));

// Replace current route
context.router.home.go(replace: true);
```

---

## Generated output

For the router defined above, the generator produces:

```dart
extension BuildContextRouterExtension on BuildContext {
  ContextRouter get router => ContextRouter(this);
}

class ContextRouter {
  void go({bool replace = false}) => ...;  // home
  ContextRouterDashboard get dashboard => ContextRouterDashboard(this);

  // Shell children are inlined here - no AuthShell wrapper class
  GoRouter<SignInView> get signIn => ...;
  GoRouterParams<OtpView, OtpParameters> get otp => ...;
}

class ContextRouterDashboard {
  void go({bool replace = false}) => ...;
  GoRouter<SettingsView> get settings => ...;
}

class OtpParameters {
  final String token;
  const OtpParameters({required this.token});
}
```

---

## Route node behaviour

| Node type         | Generator output                                                  |
| ----------------- | ----------------------------------------------------------------- |
| `view<T, Null>`   | `GoRouter<T>` getter with `.go({replace})`                        |
| `view<T, P>`      | `GoRouterParams<T, P>` getter with `.go(params, {replace})`       |
| `node(name, ...)` | Nested `ContextRouter{Name}` class                                |
| `shell(...)`      | Children inlined directly into the parent class                   |
| `deeplink<T, P>`  | Same as `view<T, P>` + generates `toQuery()` / `fromMap()` on `P` |

---

## Related packages

- [`fiber_router`](https://pub.dev/packages/fiber_router) - the runtime package this generator targets
