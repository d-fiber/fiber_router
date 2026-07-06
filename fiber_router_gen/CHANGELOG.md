# Changelog

## 1.0.0

- Initial release.
- Parses `@FiberRouterGen()`-annotated `PoppinRouter.create()` declarations.
- Generates typed `BuildContext` extension with `ContextRouter` and nested group classes.
- Supports `PoppinRouteNode.view()`, `.node()`, `.shell()`, and `.deeplink()`.
- Generates `Parameters` classes with `toQuery()` / `fromMap()` for deeplink routes.
- Shell routes are transparent — their children are exposed directly on the parent class.
- Filters imports automatically — only includes what the generated file needs.
