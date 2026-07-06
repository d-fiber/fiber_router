# Changelog

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
- Parses `@FiberRouterGen()`-annotated `PoppinRouter.create()` declarations.
- Generates typed `BuildContext` extension with `ContextRouter` and nested group classes.
- Supports `PoppinRouteNode.view()`, `.node()`, `.shell()`, and `.deeplink()`.
- Generates `Parameters` classes with `toQuery()` / `fromMap()` for deeplink routes.
- Shell routes are transparent — their children are exposed directly on the parent class.
- Filters imports automatically — only includes what the generated file needs.
