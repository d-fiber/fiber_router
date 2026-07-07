# Changelog

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
