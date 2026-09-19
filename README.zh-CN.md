<div align="center">

# Eureka

**按下快捷键，写一句话，完事。**

一个很小的 macOS 菜单栏工具：随手记下一个想法，连同你当时选中的文字、<br>
所在的网页或一张截图，直接写进 Obsidian 或 Apple 备忘录。

[![Release](https://img.shields.io/github/v/release/Claire1217/Eureka)](https://github.com/Claire1217/Eureka/releases)
[![Build](https://github.com/Claire1217/Eureka/actions/workflows/build.yml/badge.svg)](https://github.com/Claire1217/Eureka/actions/workflows/build.yml)
[![macOS 12+](https://img.shields.io/badge/macOS-12%2B-black)](#安装)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[**下载**](https://github.com/Claire1217/Eureka/releases) · [安装](#安装) · [配置 AI 快问](#配置-ai-快问) · [English](README.md)

</div>

<p align="center">
  <img src="assets/hero.zh-CN.svg" alt="Eureka 演示：选中文字，按 Option+T，写一句话，回车，想法带着来源以彩色卡片的形式出现在 Obsidian 里" width="880">
</p>

想法总是出现在读文章、写代码、开会的时候，而不是打开笔记软件的时候。为了一句话切换应用，
打断的注意力比这句话本身更贵，于是大部分想法就这么丢了。Eureka 把成本降到一个快捷键加一行字，
并且记住这个想法是从哪儿来的，下周再看还能看懂。

## 三种记录方式

### <kbd>⌥</kbd> <kbd>T</kbd> &nbsp;一个想法，带着它的上下文

在任意应用里按下快捷键，输入框出现在光标旁。你当时选中的文字会作为引用附在想法下面，
并标注来源网页（Safari、Chrome、Edge、Brave、Arc）或应用名。什么都没选，那就是一条随手记。
**回车**保存，**Esc** 取消，全程不用离开手头的事。

<table>
<tr>
<td width="50%" valign="top">

### <kbd>⌥</kbd> <kbd>R</kbd> &nbsp;一张截图，加一句话

<img src="assets/feature-screenshot.zh-CN.svg" alt="截图捕获：按 Option+R，框选一块区域，写一句话，回车，截图和评论存成同一张卡片" width="100%">

框选一块区域，写下它为什么重要，回车。截图和评论存进同一张卡片：开会时随手截的那张图表，
一个月后旁边还写着「这个尖峰 = 早上 9 点那条推送」。不想写评论也行，留空直接回车就只存图。

</td>
<td width="50%" valign="top">

### <kbd>/</kbd> &nbsp;就着选中的内容问 AI

<img src="assets/feature-ask.zh-CN.svg" alt="AI 快问：选中文字，按 Option+T，输入斜杠和问题，答案直接显示在面板里" width="100%">

以 `/` 开头，这一行就从笔记变成了提问。选中的文字会作为上下文一起发出去，简短的答案直接显示在
面板里，不用切标签页，也不用复制粘贴。用你自己的 key：DeepSeek、OpenAI，或者通过 Ollama
跑本地模型（[配置方法](#配置-ai-快问)）。

</td>
</tr>
</table>

**还有这些**

- **捕获圆点**：用鼠标选中文字后，旁边出现一个小蓝点，点它就能记录，不用按快捷键。可在设置里关闭。
- **最近记录**：悬浮气泡保留最近 20 条，点一条直接跳到 Obsidian 对应位置。
- **Obsidian 或 Apple 备忘录**：存成 vault 里的纯 Markdown，或备忘录里的每日笔记。
- **都能改**：两个快捷键可自定义，所有设置都可以用命令行脚本化。

## 记下来是什么样

<p align="center">
  <img src="assets/obsidian-demo.png" alt="用 Eureka 记下的一天的想法，在 Obsidian 里显示为彩色卡片" width="760">
</p>

每天一个文件，每个想法一个 callout：

```
你的vault/Eureka/
  2026-06-29/
    Thoughts.md       # 当天所有想法
    attachments/      # 截图
```

```markdown
> [!thought-coral] 11:03
> job title 改成可跳过，首次使用后再问
> > Step 3: “Tell us about yourself” — 42% drop-off 【[mixpanel.com/funnels](https://…)】
```

这是标准的 Obsidian callout，在任何编辑器里都能读。彩色卡片的样式来自一个 CSS 片段，选好 vault 时
Eureka 会自动装进 `.obsidian/snippets/` 并启用（如果 Obsidian 正开着，重开一次即可）。手动安装：
把 [`thought-cards.css`](thought-cards.css) 复制进去，在 设置 → 外观 → CSS 代码片段 里启用。

使用 **Apple 备忘录**时，想法会追加到名为 `Thoughts — YYYY-MM-DD` 的笔记里。通过自动化往备忘录写图片
会导致之前的图片丢失，所以截图会存到 `~/Pictures/Eureka/`，笔记里记录文件路径。

## 安装

需要 macOS 12 或更高版本（Apple Silicon 和 Intel 均可）。

```bash
curl -fsSL https://raw.githubusercontent.com/Claire1217/Eureka/main/install.sh | bash
```

或从 [Releases](https://github.com/Claire1217/Eureka/releases) 下载 `.zip`，解压到 `/Applications`，
然后去掉隔离标记（应用尚未公证）：

```bash
xattr -dr com.apple.quarantine /Applications/Eureka.app
```

**首次启动**

1. **系统设置 → 隐私与安全性 → 辅助功能** → 开启 Eureka。读取选中文字需要这个权限。
2. 选择你的 Obsidian vault（Eureka 会在里面建一个 `Eureka/` 文件夹），或选择 Apple 备忘录。
3. 好了，按 <kbd>⌥</kbd> <kbd>T</kbd> 试试。其余设置都在菜单栏 **E!** → **Settings…** 里。

> 目前的发布包是 ad-hoc 签名，所以每次更新后 macOS 会要求重新授予辅助功能权限：
> 把列表里旧的 Eureka 删掉，再添加新的即可。

## 速查表

| | |
|---|---|
| <kbd>⌥</kbd> <kbd>T</kbd> | 记录想法（有选中文字就一起带上） |
| <kbd>⌥</kbd> <kbd>R</kbd> | 框选截图，然后写评论 |
| <kbd>回车</kbd> | 保存；输入框留空时，只保存选中内容或截图 |
| <kbd>Shift</kbd> <kbd>回车</kbd> | 换行 |
| <kbd>/</kbd> + 问题 | 问 AI，不保存 |
| <kbd>Esc</kbd> | 取消 / 关闭答案 |

## 配置 AI 快问

在 **E!** → **Settings…** 里填入 API key，`/` 提问就能用了。默认是 DeepSeek，因为便宜、快；
任何 OpenAI 兼容的 chat completions 接口也都可以：

| 服务 | `llmApiBase` | `llmModel` |
|---|---|---|
| DeepSeek（默认） | `https://api.deepseek.com/chat/completions` | `deepseek-chat` |
| OpenAI | `https://api.openai.com/v1/chat/completions` | 例如 `gpt-4o-mini` |
| Ollama（本地，数据不出你的 Mac） | `http://localhost:11434/v1/chat/completions` | 例如 `llama3.2` |

```bash
defaults write com.eureka.app llmApiBase "http://localhost:11434/v1/chat/completions"
defaults write com.eureka.app llmModel "llama3.2"
defaults write com.eureka.app llmApiKey "ollama"     # 本地模型填任意非空值即可
killall Eureka; open /Applications/Eureka.app
```

答案刻意保持简短，并且用你提问的语言回答。想改风格：

```bash
defaults write com.eureka.app llmSystemPrompt "用中文简洁回答，技术术语保留英文。"
```

答案只显示、不保存。值得留下的，再记成一条想法就好。

## 隐私

所有内容只写在本地：你的 vault 文件夹，或 Apple 备忘录。Eureka 没有服务器、没有账号、没有统计。
唯一的联网请求是 `/` 提问（你的问题加上选中的文字），发给你自己配置的接口，并且只在你提问时发生。
剪贴板里原有的内容永远不会被保存：当某个应用不暴露选中文字时，Eureka 会发一次 ⌘C 来读取，
随后立刻把你原来的剪贴板还原。

<details>
<summary><strong>用命令行配置所有设置</strong></summary>

设置里的每一项都是一个 `defaults` 键，方便脚本化：

```bash
defaults write com.eureka.app vaultPath "/path/to/vault/Eureka"
defaults write com.eureka.app storageBackend "obsidian"        # 或 "notes"
defaults write com.eureka.app selectionToolbarEnabled -bool NO  # 关闭捕获圆点
defaults write com.eureka.app llmApiKey "sk-your-key"
killall Eureka; open /Applications/Eureka.app
```

</details>

<details>
<summary><strong>从源码构建</strong></summary>

```bash
git clone https://github.com/Claire1217/Eureka.git
cd Eureka && ./deploy.sh
```

需要 Xcode 命令行工具。经常重新构建的话，先跑一次 `./setup_cert.sh`，之后用 `./build.sh`：
固定的签名身份能让辅助功能权限在重新构建后保留。`./release.sh` 会打出 universal 的 `.zip`，
CI 在每次 push 时都会跑一遍。

README 里的动画是脚本生成的：`python3 assets/make_hero.py` 和
`python3 assets/make_features.py`（加 `zh` 参数生成中文版）。

</details>

## 已知限制

- <kbd>⌥</kbd> <kbd>T</kbd> 和 <kbd>⌥</kbd> <kbd>R</kbd> 原本会输入 `†` 和 `®`；需要这两个字符的话，请在设置里换快捷键。
- 部分 Electron 应用不暴露选中文字，Eureka 在这些应用里会退回到 ⌘C 的方式。在「无选区时复制整行」的编辑器（如 VS Code）里，这一行可能被当成上下文带上。
- 来源网址只支持上面列出的浏览器（Firefox 没有脚本接口）。
- 界面目前只有浅色模式。

## 许可

[MIT](LICENSE)
