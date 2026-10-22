# 9451 空闲音频输入隔离测试

## 三个彼此独立的位置

- 已安装可用版：`/Applications/vRemote.app`。本轮不会替换。
- 稳定源码：相邻的 `vRemoter` 工作目录，`feat/google-tv-9451-voice` 分支。
- 本轮测试源码：`vRemoter-audio-isolation` 工作目录，`test/google-tv-9451-audio-updates` 分支，从已验收的 `f714bdb` 创建。

Git 分支保存另一条修改历史，worktree 让该分支拥有单独的文件目录。
两个目录共享 Git 历史，但源码、编译输出、测试配置和日志分开。
聊天只是操作入口，关闭聊天不会使这份代码或记录消失。

## 本轮改动

1. 对虚拟音频设备的**本进程 IOProc**设置输入流不启用，保留输出流持续运行。
   不改变 BLE 生命周期、遥控器待机策略、ATVV、ADPCM 或 Fn 会话控制。
   输入配置失败会记录 OSStatus 并释放该 IOProc，不偷偷使用旧的双向模式。
2. 定制版的官方更新按钮只打开发布说明；安装入口也检查同一策略，
   不直接下载并打开官方安装包。没有定制标记的上游构建保留原行为。
   官方基础版本与 `VRPatchRevision` 分开，避免补丁后缀误触发相同版本更新。
3. Debug 测试包没有独立数据环境变量时拒绝启动；启动脚本与 App 双重防止并行实例。
   会话自测也使用工作区内的数据目录。

没有修改系统蓝牙设置、配对、隐私授权、全局 SDK、默认音频设备、驱动或输入法设置。
独立数据目录不等于另一套系统权限；测试包沿用应用身份，避免另行申请或重置权限。

## 构建与自动检查

```sh
VREMOTER_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  scripts/build-development-app.sh
scripts/run-voice-tests.sh
swiftc -module-cache-path .build/module-cache \
  Sources/vRemote/OutputOnlyIOProc.swift Tests/OutputOnly/main.swift \
  -o .local/isolation/output-only-test
.local/isolation/output-only-test
```

独立音频测试仅启动约一秒静音输出，检查测试进程的 CoreAudio 输入/输出状态，
不读取输入缓冲区，不启用物理麦克风，不触发 Fn 或连接蓝牙。
它不能代替完整 App 的语音和系统指示灯验收。

## 完整 App 验收及恢复

先协调测试时间，再正常退出安装版。不要强制终止正在录音的会话。
从测试目录运行 `scripts/launch-development-app.sh`。
测试数据位于本目录 `.local/runtime`，不会覆盖正式偏好或正式日志。

检查短按切换、长按松开结束、连续录音、实际出字、正常闲置后唤醒、退出释放 Fn。
同时检查空闲时本测试 App 的 CoreAudio 输入状态和控制中心提示。
蓝牙必须继续保持现有连接策略，不通过取电池、复位或重新配对来完成这轮测试。

完成或失败后正常退出测试版，再运行：

```sh
open /Applications/vRemote.app
```

这是恢复原先运行程序，不涉及安装或回滚文件。只有硬件验收通过且用户另行确认，
才讨论替换安装版；安装与备份仍按 `INSTALL-9451.md`。

## 以后如何升级

保留官方更新提醒和发布说明。需要新功能时，在新的升级分支中合并 upstream，
处理冲突、运行回归与上述实测，确认后才替换 App。Git 能帮助定位冲突，
不能保证每次官方升级零冲突，也不能代替实测。
不要用官方 DMG 直接覆盖定制安装版。稳定分支及旧 App 备份继续保留。

## 实际结果

2026-10-22，本机实际执行：

- 独立音频测试：输入流配置返回 `OSStatus=0`；测试进程
  `IsRunningInput=0`、`IsRunningOutput=1`，退出时停止并销毁自己的 IOProc。
- 使用已安装的 26.5 SDK 构建完整 Debug App 成功，签名校验通过。
  默认 27 SDK 首次构建缺少 SwiftUI 宏插件；仅本命令选用 26.5，无全局修改。
- 64 项语音/协议/配置/更新策略回归检查通过。
- 无独立配置启动、正式版运行时启动、启动脚本并行检测三项均拒绝启动，
  没有创建语音控制器或接管遥控器。
- 原安装版进程在上述检查期间持续运行。安装版二进制、Info、驱动、蓝牙配置等
  12 项文件摘要与检查前一致。正式偏好 plist 字节摘要发生变化，原因未归因；
  本轮工具未写该偏好域，读回 Fn 按住、Mac 输入关闭、遥控器输入开启仍符合原设定。
- **尚未验收**：完整测试 App 的实际出字、空闲控制中心提示、闲置唤醒和持续录音。
  独立 IOProc 测试通过不代表这些项目已通过。

原始检查日志和配置摘要仅保存在工作区忽略的 `.local/isolation` 内，不进入 Git。
