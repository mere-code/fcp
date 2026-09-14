# Fork 维护说明

## 上游基线

- 上游仓库：https://github.com/yyued/SVGAPlayer-Flutter
- 上游版本：2.2.0
- 基线提交：`a1c6d5580eb5cce267a652a670726403b4091f03`

## Mere Code 版本记录

### 2.2.0+merecode.1

首个 Fork 版本，不包含 `lib/` 功能性修改，保留上游公共 API：

- 将 `http`依赖从 `^0.13.3`调整为 `1.2.2`。
- 提高 Dart SDK 约束，使其兼容该依赖及 Flutter 3.24.5工具链。
- 清理上游源码注释中的一处行尾空格，不影响代码行为。
- 删除 example 中的生成文件及与开发机器相关的构建产物。
- 更新 example 的 Dart、Flutter 和 Android 构建配置，使其可在当前工具链运行。

发布标签：`svgaplayer_flutter-v2.2.0-merecode.1`。

### 2.2.0+merecode.2

基于 `2.2.0+merecode.1` 增加 SVGA 播放时长与图片内存治理：

- `SVGAAnimationController` 默认使用 `AnimationBehavior.preserve`，避免开启系统“移除动画”后压缩 SVGA 播放时长；仍可通过可选参数覆盖。
- 统一解析管线在所有内嵌图片解码成功后，将结果写入 `bitmapCache` 并清空 protobuf `MovieEntity.images` 中的原始图片字节。
- 任一图片解码失败时，使整次解析失败，并回收本次已创建但未交付的 `ui.Image`。
- 保持 sprites、frames、`bitmapCache` 和动态图片替换能力，不依赖已清空的原始图片字节。

预期发布标签：`svgaplayer_flutter-v2.2.0-merecode.2`。

升级 Fork 时，应先将新上游版本与本文件记录的基线进行比较，只保留必要的定制改动；随后更新包版本修订号，并创建对应的包级 Git 标签。
