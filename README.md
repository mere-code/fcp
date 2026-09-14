# Mere Code Flutter Forks

[English](README.en.md)

用于维护 Flutter 定制包的公开 Monorepo。仓库中的包均基于上游版本，仅保留业务所需的必要改动。

## 包列表

| 包名 | 定制版本 | 上游基线 | 定制原因 |
| --- | --- | --- | --- |
| `svgaplayer_flutter` | `2.2.0+merecode.2` | [`yyued/SVGAPlayer-Flutter@a1c6d55`](https://github.com/yyued/SVGAPlayer-Flutter/commit/a1c6d5580eb5cce267a652a670726403b4091f03) | 使用 `http` 1.2.2，兼容当前工具链，并修复动画时长与内嵌图片内存问题。 |

每个包保留原始包名，以便替换现有依赖。包内的 `FORK.md`记录上游基线和全部定制差异。

## 引用包

本仓库为 GitHub 公开仓库。通过 HTTPS 引用时，无需配置 SSH Key 或其他读取凭据：

```yaml
dependencies:
  svgaplayer_flutter:
    git:
      url: https://github.com/mere-code/fcp.git
      ref: svgaplayer_flutter-v2.2.0-merecode.2
      path: packages/svgaplayer_flutter
```

必须固定到包级标签，不要直接依赖 `main`分支。

## 本地开发

仓库使用 Flutter 3.24.5进行验证。

```bash
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

包标签格式为 `<包名>-v<上游版本>-merecode.<修订号>`；`pubspec.yaml`版本格式为 `<上游版本>+merecode.<修订号>`。
