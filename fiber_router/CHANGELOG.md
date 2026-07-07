# Changelog

## 1.3.4

- Fix controller shell transition: `ShellRoute` for controller nodes now uses `pageBuilder` (returning `_routeTransition` with the node's `transition` and `gesturePopEnabled`) instead of `builder`, so the transition is applied at the shell level rather than only on the inner redirect GoRoute that was never rendered. This fixes the visible animation when switching between controllers (e.g. store → brands) even when `RouteTransition.none` was set.

## 1.3.3

- Add `transition` and `gesturePopEnabled` parameters to `FiberRouteNode.controller()` — controls the page transition and gesture behavior of the controller's entry route. Defaults to `RouteTransition.none` and `gesturePopEnabled: false`.

## 1.3.2

- Fix import

## 1.3.1

- Make `builder` optional on `FiberRouteNode.controller()` — defaults to `(context, child) => ControllerView(child: child)` when omitted.
- Add `BuildContext.goShellNamed(String routeName)` — navigates by explicit route name rather than deriving it from `T.toString()`, fixing controller navigation when an explicit `name` override is provided.

## 1.3.0

- No runtime changes — version bump to stay in sync with `fiber_router_gen 1.4.0`.

## 1.2.0

- Add `FiberRouteNode.controller<T>()` — a hybrid route that acts as both a shell (wraps children with a persistent UI) and a navigable route registered at `/<T snake_case>`. Navigating to the controller automatically redirects to the first available leaf route.
- Add optional `name` parameter to `FiberRouteNode.shell()` and `FiberRouteNode.controller()` — overrides the group class name derived from the builder widget type.

## 1.1.3

- Add `RouteTransition.none` — uses `NoTransitionPage` for an instant child swap with no animation duration. Useful for shell routes where transitions cause layout artefacts.

## 1.1.2

- Fix `goShell`: replace `goNamed` with `pushReplacementNamed` (wrapped in `Router.neglect`) so shell transitions go through the route's `CustomTransitionPage` and apply the correct animation. `goNamed` bypassed the page-level transition, causing a blank frame between views.

## 1.1.1

- Remove `ShellRouter` and `ShellRouterParams` from the library — they are now generated directly in the output file by `fiber_router_gen`, keeping the library free of generated-only artefacts.

## 1.1.0

- Add `ShellRouter<T>` — shell navigation helper without a `replace` parameter (navigation within a shell always swaps the child, never stacks).
- Add `ShellRouterParams<T, P>` — same as `ShellRouter` but with typed parameters.
- Add `BuildContext.goShell<T, P>()` — uses `goNamed` so the shell child is replaced in-place rather than pushed onto the navigator stack.

## 1.0.0

- Initial release.
- `FiberRouter.create()` — wraps `GoRouter` with a declarative node-based API.
- `FiberRouteNode.view()` — typed view route with optional fade transition.
- `FiberRouteNode.node()` — named group for organizing related routes.
- `FiberRouteNode.shell()` — shell route that keeps a persistent UI wrapper while inner routes change.
- `FiberRouteNode.deeplink()` — deeplink-capable route with query-parameter deserialization.
- `BuildContext.go<T, P>()` — type-safe navigation extension.
- `GoRouterState.isOn<T>()` — check if the current location matches a route type.
- `NavigatorFadeTransition` — fade `PageRoute` for local `Navigator` push.
- `@FiberRouterGen()` — annotation to mark the router variable for code generation with `fiber_router_gen`.
