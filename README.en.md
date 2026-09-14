# Mere Code Flutter Forks

[中文](README.md)

A public monorepo for maintained Flutter package forks. Each package is based on a specific upstream version and carries only the changes required by our projects.

## Packages

| Package | Fork version | Upstream baseline | Reason |
| --- | --- | --- | --- |
| `svgaplayer_flutter` | `2.2.0+merecode.2` | [`yyued/SVGAPlayer-Flutter@a1c6d55`](https://github.com/yyued/SVGAPlayer-Flutter/commit/a1c6d5580eb5cce267a652a670726403b4091f03) | Uses `http` 1.2.2, supports the current toolchain, and fixes animation duration and embedded-image memory handling. |

Each package retains its original package name for drop-in compatibility. Its `FORK.md` documents the upstream baseline and every fork-specific change.

## Using a package

This is a public GitHub repository. HTTPS dependencies can be fetched without an SSH key or other read credentials:

```yaml
dependencies:
  svgaplayer_flutter:
    git:
      url: https://github.com/mere-code/fcp.git
      ref: svgaplayer_flutter-v2.2.0-merecode.2
      path: packages/svgaplayer_flutter
```

Always pin a package-scoped tag instead of depending directly on the `main` branch.

## Local development

The repository is validated with Flutter 3.24.5.

```bash
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

Package tags follow `<package>-v<upstream-version>-merecode.<revision>`. Versions in `pubspec.yaml` follow `<upstream-version>+merecode.<revision>`.
