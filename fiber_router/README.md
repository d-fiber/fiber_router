# fiber_router

Typed navigation layer built on [`go_router`](https://pub.dev/packages/go_router) - declarative view, node, and shell routes with fade transitions and code-generated `BuildContext` extensions.

Designed to work with [`fiber_router_gen`](https://pub.dev/packages/fiber_router_gen), the companion code generator that produces typed navigation helpers from your router definition.

---

## Features

- **Declarative route tree** via `PoppinRouteNode.view()`, `.node()`, `.shell()`, and `.deeplink()`
- **Shell routes** - persistent UI wrapper (e.g. auth layout) while inner routes change
- **Typed navigation** - `context.go<MyView, MyParams>()` instead of string paths
- **Fade & system transitions** out of the box
- **`@FiberRouterGen()` annotation** - marks the router variable for code generation
- **`NavigatorFadeTransition`** - fade `PageRoute` for local `Navigator` push

---

## Installation

```yaml
dependencies:
  fiber_router: ^1.0.0
```

---

## Usage

### 1. Define your router

```dart
import 'package:fiber_router/fiber_router.dart';

@FiberRouterGen()
final router = PoppinRouter.create(
  initialLocation: const HomeView(),
  refreshListenable: myAuthNotifier,
  redirect: (context, state) {
    if (!myAuthNotifier.isSignedIn) return const SignInView();
    return null;
  },
  nodes: [
    // Simple view route
    PoppinRouteNode.view<HomeView, Null>(
      transition: RouteTransition.fade,
      builder: (_, __) => const HomeView(),
    ),

    // Named group with sub-routes
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

    // Shell route - layout persists, inner content changes
    PoppinRouteNode.shell(
      builder: (context, child) => AuthShell(child: child),
      routes: [
        PoppinRouteNode.view<SignInView, Null>(
          transition: RouteTransition.fade,
          builder: (context, _) => SignInView(
            onRequiresOtp: (token) => context.go<OtpView, OtpParams>(OtpParams(token: token)),
          ),
        ),
        PoppinRouteNode.view<OtpView, OtpParams>(
          transition: RouteTransition.fade,
          builder: (_, params) => OtpView(token: params?.token ?? ''),
        ),
      ],
    ),

    // Deeplink route - parameters from query string
    PoppinRouteNode.deeplink<InviteView, InviteParams>(
      fromQuery: InviteParams.fromMap,
      builder: (_, params) => InviteView(params: params),
    ),
  ],
);
```

### 2. Navigate

```dart
// Navigate to a route (replaces current)
context.go<HomeView, Null>(replace: true);

// Navigate with parameters
context.go<OtpView, OtpParams>(OtpParams(token: token));

// Check current route
if (state.isOn<DashboardView>()) { ... }
```

### 3. Shell route

A shell route renders a persistent wrapper widget while swapping its inner `child` as routes change. Useful for layouts that must stay on screen (e.g. auth shell with background image).

```dart
class AuthShell extends StatelessWidget {
  final Widget child;
  const AuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(child: child), // SignInView or OtpView renders here
          const AuthBackground(),
        ],
      ),
    );
  }
}
```

### 4. Code generation

Annotate your router variable with `@FiberRouterGen()` and run the generator:

```bash
dart run fiber_router_gen lib/src/router/router.dart
```

This produces a typed `router.g.dart` with `BuildContext` extensions:

```dart
// Generated
context.router.dashboard.go();
context.router.dashboard.settings.go();
```

### 5. Local navigator fade transition

For push navigation inside a local `Navigator`:

```dart
navigatorKey.currentState?.push(
  NavigatorFadeTransition(OtpView(token: pendingToken)),
);
```

---

## Route types

| Factory                            | Description                                         |
| ---------------------------------- | --------------------------------------------------- |
| `PoppinRouteNode.view<T, P>()`     | Single screen route                                 |
| `PoppinRouteNode.node()`           | Named group with optional main route and sub-routes |
| `PoppinRouteNode.shell()`          | Shell wrapper - layout persists across inner routes |
| `PoppinRouteNode.deeplink<T, P>()` | Route with query-string parameter deserialization   |

## Transitions

| Value                    | Behavior                                                  |
| ------------------------ | --------------------------------------------------------- |
| `RouteTransition.fade`   | Cross-fade                                                |
| `RouteTransition.system` | Platform default (Cupertino slide on iOS, fade on others) |

---

## Related packages

- [`fiber_router_gen`](https://pub.dev/packages/fiber_router_gen) - code generator for typed navigation extensions
