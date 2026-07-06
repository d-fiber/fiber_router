# Changelog

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
