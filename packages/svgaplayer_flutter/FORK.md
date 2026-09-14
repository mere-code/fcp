# Fork 维护说明

## 上游基线

- 上游仓库：https://github.com/yyued/SVGAPlayer-Flutter
- 上游版本：2.2.0
- 基线提交：`a1c6d5580eb5cce267a652a670726403b4091f03`

## Mere Code 定制内容

版本 `2.2.0+merecode.1`未对 `lib/`进行功能性修改，完整保留上游公共 API。

- 将 `http`依赖从 `^0.13.3`调整为 `1.2.2`。
- 提高 Dart SDK 约束，使其兼容该依赖及 Flutter 3.24.5工具链。
- 清理上游源码注释中的一处行尾空格，不影响代码行为。
- 删除 example 中的生成文件及与开发机器相关的构建产物。
- 更新 example 的 Dart、Flutter 和 Android 构建配置，使其可在当前工具链运行。

升级 Fork 时，应先将新上游版本与本文件记录的基线进行比较，只保留必要的定制改动；随后更新包版本修订号，并创建对应的包级 Git 标签。
