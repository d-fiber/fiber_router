# Changelog

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
- `PoppinRouter.create()` — wraps `GoRouter` with a declarative node-based API.
- `PoppinRouteNode.view()` — typed view route with optional fade transition.
- `PoppinRouteNode.node()` — named group for organizing related routes.
- `PoppinRouteNode.shell()` — shell route that keeps a persistent UI wrapper while inner routes change.
- `PoppinRouteNode.deeplink()` — deeplink-capable route with query-parameter deserialization.
- `BuildContext.go<T, P>()` — type-safe navigation extension.
- `GoRouterState.isOn<T>()` — check if the current location matches a route type.
- `NavigatorFadeTransition` — fade `PageRoute` for local `Navigator` push.
- `@FiberRouterGen()` — annotation to mark the router variable for code generation with `fiber_router_gen`.
