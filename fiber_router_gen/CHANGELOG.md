# Changelog

## 1.5.0

- Every shell/controller/group node gets a short generated class name by default, derived from its own `name` (e.g. `store` instead of `storeController`, `pagination` instead of some builder-derived name). When that short class name collides with another node's elsewhere in the tree (e.g. both `store` and `brand` have a shell named `"pagination"`), every colliding node is instead qualified with its full ancestor path from the root down to itself (e.g. `ContextRouterDashboardStorePagination` / `ContextRouterDashboardBrandPagination`) — this only changes the generated *class* name, never the getter used to reach it, so call sites stay short (`store.pagination...`, `brand.pagination...`). If a collision still can't be resolved this way (e.g. two nodes with the exact same name at the exact same tree position), generation fails with a clear error instead of emitting duplicate classes.
- Every `shell` always gets its own generated class now, regardless of how many shells its parent `controller` has — the generated class structure mirrors the `router.dart` node tree exactly, with no implicit merging. (An earlier draft of this release auto-merged a controller's sole shell child into the controller's own class; that was reverted for consistency — a controller with one shell no longer behaves differently from one with several.)
- `FiberRouteNode.view()` and `.deeplink()` now accept the new, required `name` parameter (see `fiber_router` 1.3.8) to override the generated getter name.
- Controller nodes now expose `Future<R?> go<R>({bool replace})` directly on their own class instead of via a nested `.controller` getter (`context.router.x.go()` instead of `context.router.x.controller.go()`). It's only generated when the controller's first leaf view takes no required parameters — otherwise `go()` would silently redirect there with missing/null params, so it's omitted instead.
- Removed `push()` and the `name` getter from the controller's self-navigation block — only `go()` is generated now.
- Removed the now-unused `ControllerRouter<T>` and `ControllerRouterParams<T, P>` generated helper classes.
- Fix: a blank `name: ""` is now treated the same as an omitted name. Previously it was taken literally and could produce a duplicate, invalid `ContextRouter` class with a broken empty-named getter.
- `bin/fiber_router_gen`: stopped collecting controller builder widget types for import filtering — they're no longer referenced as types in the generated output, and doing so could produce unused-import warnings (e.g. for the dashboard's builder widget).
- Controller nodes now expose `go(params)` (instead of nothing) even when the first leaf view they'd redirect to requires params — it forwards straight to that leaf's own generated getter (e.g. `detail.go(params)` calls `detail.general.go(params)` under the hood), so callers no longer need to know or name the first leaf directly.
- The literal string passed to `_context.goShellNamed(...)` inside a generated controller's `go()`/delegated `go(params)` now matches `fiber_router`'s new ancestor-path-qualified route name (see `fiber_router` 1.3.8) instead of the controller's bare `name` — required to stay in sync now that the real registered route name is qualified.

## 1.4.7

- All router helpers (`GoRouter`, `GoRouterParams`, `ShellRouter`, `ShellRouterParams`, `ControllerRouter`, `ControllerRouterParams`) now expose `Future<R?> go<R>(...)` instead of `void go(...)` — callers can await the result returned by `context.pop(result)` on the pushed route.
- `_onNavigate` function types updated from `void Function(...)` to `Future<dynamic> Function(...)` to propagate the push result through the lambda.
- `ShellRouter<T>` no longer stores `_onNavigate` — `go<R>()` and `push<R>()` both delegate directly to `_context.goShellNamed<R>(name, replace: ...)`. Generated shell getters simplified to `ShellRouter<T>(_context, 'route_name')`.

## 1.4.6

- `ShellRouter<T>` now stores `BuildContext _context` and exposes `Future<R?> push<R>()` — calls `_context.goShellNamed<R>(name, replace: false)`, returning the value passed to `context.pop(result)` by the pushed route.
- Generated shell getters pass `_context` as the first constructor argument: `ShellRouter<T>(_context, (r) => ...)`.

## 1.4.5

- `ShellRouter<T>` now takes `void Function(bool)` and exposes `go({bool replace = true})` — defaults to replace to preserve existing shell behavior. `ShellRouterParams` updated similarly.
- Generated shell getters pass `(r) => _context.goShell<T, P>(replace: r)`.

## 1.4.4

- `ControllerRouter<T>` now takes `void Function(bool)` and exposes `go({bool replace = false})` — matches the `GoRouter` API, allows push or replace navigation. `ControllerRouterParams` updated similarly.
- Generated `controller` getter passes `(r) => _context.goShellNamed(routeName, replace: r)` to `ControllerRouter`. `ShellRouter` is unchanged.

## 1.4.3

- Fix controller builder type fallback: `_parseControllerNode` now defaults to `'ControllerView'` instead of `'Controller'` when no `builder` argument is present, producing `ControllerRouter<ControllerView>` in the generated output.

## 1.4.2

- Fix controller navigation when an explicit `name` is provided: generated `ControllerRouter` now calls `_context.goShellNamed(routeName)` instead of `_context.goShell<T, Null>()`, so the correct registered route name is used rather than the builder widget type snake-cased from `T.toString()`.

## 1.4.1

- Fix missing import for controller builder widget types (e.g. `DashboardView`): `_allControllerBuilderTypes` now collects builder widget types from all `RouterControllerNode` instances and adds them to `neededTypes`, so their import files are emitted in the generated output.

## 1.4.0

- Add `FiberRouterBase<T>` — abstract base class with a single `name` field, shared by all router helper types.
- `GoRouter`, `GoRouterParams`, `ShellRouter`, `ShellRouterParams` now extend `FiberRouterBase<T>` via `super.name`.
- Add `ControllerRouter<T>` and `ControllerRouterParams<T, P>` — generated for `controller` route nodes. `ControllerRouter.go()` navigates to the controller entry point via `goShell`.
- Controller context classes (e.g. `ContextRouterDashboard`) now expose a `ControllerRouter<T> get controller` getter and a `String get name` alongside their children getters.
- Fix import filter: exclude `.g.dart` files (prevents self-import on re-generation), remove `_fileReexportsPackages` heuristic, replace with recursive `_fileContainsBuildContextExtension` that follows both relative and `package:` exports — correctly includes `ui` (re-exports `fiber_router` → `on BuildContext`) while excluding unrelated packages like `services`.
- Fix `_allViewNodes` in the generator binary to traverse `RouterControllerNode` children, ensuring view types inside controllers are included in `neededTypes` and their import files are emitted.

## 1.3.0

- Add support for `FiberRouteNode.controller()` — parsed and generated identically to shell nodes, producing a named `ContextRouter{Name}` class with `isShell: true` children.
- Add optional `name` argument parsing for both `shell` and `controller` — when provided, it overrides the group class name derived from the builder widget type.
- Remove `_shellGroupName` helper — replaced by `effectiveGroupName` getter on `RouterShellNode` and `RouterControllerNode`.

## 1.2.1

- `ShellRouter` and `ShellRouterParams` are now emitted directly in the generated file (alongside `GoRouter` / `GoRouterParams`), rather than being imported from `fiber_router`.

## 1.2.0

- Shell view getters now generate `ShellRouter` / `ShellRouterParams` (from `fiber_router`) instead of `GoRouter` / `GoRouterParams`.
- Shell navigation calls `goShell` (`goNamed`) instead of `go` (`pushNamed`) — navigating within a shell swaps the child without stacking.
- Fix: `_writeGroupClasses` now passes `isShell: true` when writing the class for a `RouterShellNode`, so the correct types are emitted for all shell children.

## 1.1.1

- Fix shell widget type extraction: `AuthView(child: child)` is parsed as a
  `MethodInvocation` without a target — now correctly returns `methodName.name`
  instead of falling back to `'Shell'`.

## 1.1.0

- Shell nodes now generate a named `ContextRouter{Name}` class instead of inlining children into the parent.
  The class name is derived from the builder widget type: `AuthView` → `ContextRouterAuth`, accessible via `context.router.auth`.
- Parser extracts the shell widget type from the builder expression AST (`(ctx, child) => AuthView(...)` → `AuthView`).
- Generator derives the group name by stripping the `View` suffix from the builder type.

## 1.0.0

- Initial release.
- Parses `@FiberRouterGen()`-annotated `FiberRouter.create()` declarations.
- Generates typed `BuildContext` extension with `ContextRouter` and nested group classes.
- Supports `FiberRouteNode.view()`, `.node()`, `.shell()`, and `.deeplink()`.
- Generates `Parameters` classes with `toQuery()` / `fromMap()` for deeplink routes.
- Shell routes are transparent — their children are exposed directly on the parent class.
- Filters imports automatically — only includes what the generated file needs.
