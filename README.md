# yapyap

[English](README_EN.md)

轻量 macOS 菜单栏语音输入工具（~700KB），按住 `fn` 键说话，识别结果实时插入光标所在位置。

纯原生 Swift 实现的[豆包大模型语音识别](https://www.volcengine.com/docs/6561/163043) (Seed ASR) 客户端，无任何第三方依赖。

## 功能

- **按住即录** — 按住 fn 键开始录音，松开即停止，文字实时插入光标位置
- **全局可用** — 在任意应用中使用，包括浏览器、编辑器、终端等
- **实时识别** — 基于豆包 Seed ASR 大模型，支持中英文混合识别，准确率 99%
- **录音指示器** — 录音时屏幕底部显示胶囊形波形动画浮层

## 文本处理

yapyap 提供灵活的文本后处理选项，让识别结果更贴合使用场景：

### 标点展示

| 模式 | 效果 |
|------|------|
| 保持原样 | 直接输出 ASR 原始结果 |
| 空格代替标点 | `你好，世界。` → `你好 世界` |
| 句末不加标点 | `你好，世界。` → `你好，世界` |
| 保留所有标点 | `你好，世界。` → `你好，世界。` |

### 数字、英文展示

| 模式 | 效果 |
|------|------|
| 保持原样 | 直接输出 ASR 原始结果 |
| 前后无空格 | `测试test数据` → `测试test数据` |
| 前后加空格 | `测试test数据` → `测试 test 数据` |

<img src="images/settings.png" width="420" alt="yapyap Settings" />

## 使用方法

1. 在[火山引擎控制台](https://console.volcengine.com/speech/service/10038)获取 App Key 和 Access Key
2. 打开 yapyap Settings，填入 App Key、Access Key，选择 Resource ID
3. 点击「测试连接」确认配置正确
4. 在系统设置 → 键盘中，将「按下 🌐 键时」设为「不执行任何操作」
5. 在任意应用中按住 `fn` 键开始语音输入

> 首次使用需要授予麦克风和辅助功能权限。

## 系统要求

- macOS 14.0+
- Apple Silicon

## 构建

```bash
# 生成 Xcode 项目
xcodegen

# 用 Xcode 打开并构建
open yapyap.xcodeproj
```
