# yapyap

[English](README_EN.md)

轻量 macOS 菜单栏语音输入工具,按住 `fn` 键说话,识别结果实时插入光标所在位置。

原生 Swift 实现,支持**云端与本地语音识别**、**AI 文本后处理**(在线 API 或本地大模型),一个应用覆盖从"按住说话"到"润色纠错"的完整链路。

## 功能一览

### 🎙️ 语音识别 — 云端 + 本地双模式

**在线识别** — [豆包 Seed ASR](https://www.volcengine.com/docs/6561/163043) 大模型,中英混合识别准确率高,延迟低。

**本地识别** — 基于 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx),完全离线运行,不发送任何数据到服务器:

| 模型 | 大小 | 支持语言 |
|------|------|---------|
| SenseVoice Small | ~155 MB | 中 / 英 / 日 / 韩 / 粤 |
| Whisper Small | ~610 MB | 99 种语言 |
| Whisper Medium | ~1.8 GB | 99 种语言,精度更高 |

在设置中一键下载、切换、删除模型。

<img src="images/settings_asr.png" width="420" alt="语音模型设置" />

### ✨ AI 文本后处理 — 在线 + 本地双模式

ASR 的原始输出往往有错别字、标点不规范、专有名词写错等问题。yapyap 内置**后处理引擎**,识别完成后自动把文本送去 LLM 进行纠错润色,再插入光标。

**在线模式** — 兼容 OpenAI API 协议的任何服务商,一键切换:

- OpenAI
- DeepSeek
- SiliconFlow
- Groq
- Moonshot
- 自定义 Base URL(任意 OpenAI 兼容端点)

**本地模式** — 内置 Qwen3 4B Instruct(~2.1 GB),一键下载后完全离线运行。

**可定制的系统提示词** — 使用推荐的默认 prompt,或换成你自己的风格指令。

**术语表** — 添加常用专有名词(如「Claude Code」「yapyap」),AI 会在后处理时确保这些词的写法正确,修正类似「cloud code → Claude Code」的识别错误。

<img src="images/settings_ai.png" width="420" alt="AI 后处理设置" />

### 📝 格式处理 — 细节控的选项

可选的标点和中英文空格处理,让识别结果贴合不同的写作场景(写代码 / 写文章 / 聊天)。

**标点展示**

| 模式 | 效果 |
|------|------|
| 保持原样 | 直接输出 ASR 原始结果 |
| 空格代替标点 | `你好,世界。` → `你好 世界` |
| 句末不加标点 | `你好,世界。` → `你好,世界` |
| 保留所有标点 | `你好,世界。` → `你好,世界。` |

**数字、英文展示**

| 模式 | 效果 |
|------|------|
| 保持原样 | 直接输出 ASR 原始结果 |
| 前后无空格 | `测试test数据` → `测试test数据` |
| 前后加空格 | `测试test数据` → `测试 test 数据` |

<img src="images/settings_formatting.png" width="420" alt="格式处理设置" />

### 🎛️ 两种触发方式

- **长按模式** — 按住 `fn` 键开始录音,松开即停止。适合快速短句。
- **单击模式** — 快速点一下 `fn` 开始录音,再点一下结束。适合长段落,解放手指。

按住或单击由 yapyap 自动区分(按下 0.3s 内松开视为点击)。

### 🧰 其他

- **全局可用** — 在任意应用中使用,包括浏览器、编辑器、终端等
- **录音浮层** — 屏幕底部显示胶囊形波形动画,直观感受录音状态
- **中英双语 UI** — 设置中一键切换
- **提示音反馈** — 可选的开始/结束提示音,两套主题
- **菜单栏图标可隐藏** — 如果你不想让它出现在菜单栏,可以关掉

<img src="images/settings_general.png" width="420" alt="通用设置" />

## 使用方法

### 云端 ASR(推荐:快速上手)

1. 在[火山引擎控制台](https://console.volcengine.com/speech/service/10038)获取 App Key 和 Access Key
2. 打开 yapyap 设置 → 语音模型 → 在线,填入 App Key、Access Key,选择 Resource ID
3. 点击「测试连接」确认配置正确
4. 在系统设置 → 键盘中,将「按下 🌐 键时」设为「不执行任何操作」
5. 在任意应用中按住 `fn` 键开始语音输入

### 本地 ASR(完全离线)

1. 打开 yapyap 设置 → 语音模型 → 本地模型
2. 选择一个模型并下载(推荐先试 SenseVoice Small,体积小速度快)
3. 下载完成后点击「选择」使其生效
4. 按住 `fn` 键即可离线识别

### 启用 AI 后处理(可选)

1. 打开 yapyap 设置 → 后处理 → 启用 AI 文本纠正
2. 选择「在线」填入 OpenAI 兼容 API,或选择「本地模型」下载 Qwen3
3. (可选)在「术语」中添加常用专有名词
4. 之后每次识别结果都会先经过 LLM 纠错,再插入光标

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

## 许可证

本项目基于 [MIT 协议](LICENSE) 开源。
