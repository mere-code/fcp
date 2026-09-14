# Mere Code Flutter Forks

用于维护 Flutter 定制包的私有 Monorepo。仓库中的包均基于上游版本，仅保留业务所需的必要改动。

## 包列表

| 包名 | 定制版本 | 上游基线 | 定制原因 |
| --- | --- | --- | --- |
| `svgaplayer_flutter` | `2.2.0+merecode.1` | [`yyued/SVGAPlayer-Flutter@a1c6d55`](https://github.com/yyued/SVGAPlayer-Flutter/commit/a1c6d5580eb5cce267a652a670726403b4091f03) | 使用 `http` 1.2.2，并兼容当前 Dart/Flutter 工具链。 |

每个包保留原始包名，以便替换现有依赖。包内的 `FORK.md`记录上游基线和全部定制差异。

## 引用包

本仓库为 GitHub 私有仓库，使用方需要具备 `mere-code`账户的 SSH 访问权限。本机配置 SSH 别名后，在项目中添加：

```yaml
dependencies:
  svgaplayer_flutter:
    git:
      url: git@github-mere-code:mere-code/fcp.git
      ref: svgaplayer_flutter-v2.2.0-merecode.1
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
