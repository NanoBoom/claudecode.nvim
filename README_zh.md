# claudecode.nvim (中文)

[![测试](https://github.com/coder/claudecode.nvim/actions/workflows/test.yml/badge.svg)](https://github.com/coder/claudecode.nvim/actions/workflows/test.yml)
![Neovim 版本](https://img.shields.io/badge/Neovim-0.8%2B-green)
![状态](https://img.shields.io/badge/Status-beta-blue)

**第一个为 Claude Code 打造的 Neovim IDE 集成** — 纯 Lua 实现，将 Anthropic 的 AI 编码助手带到你最喜欢的编辑器中。

> 🎯 **简单说：** Anthropic 发布 Claude Code 时只支持 VS Code 和 JetBrains。作者逆向了他们的扩展，开发了这个 Neovim 插件。此插件实现了相同的基于 WebSocket 的 MCP 协议，为 Neovim 用户提供了同等的 AI 编码体验。

## 特点

- 🚀 **纯 Lua, 零依赖** — 完全使用 `vim.loop` 和 Neovim 内置功能构建。
- 🔌 **100% 协议兼容** — 与官方扩展实现相同的 WebSocket MCP 协议。
- ⚡ **抢先发布** — 比 Anthropic 更早发布 Neovim 支持。
- 🛠️ **AI 辅助构建** — 使用 Claude 逆向分析 Claude 自己的协议。

## 安装

使用你喜欢的插件管理器:

```lua
{
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = true,
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "切换 Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "聚焦 Claude" },
    -- 更多快捷键请参考英文原版 README
  },
}
```

就这样。插件会自动配置好一切。

## 需求

- Neovim >= 0.8.0
- 已安装 [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (用于更好的终端支持)

## 快速上手

1.  **启动 Claude**: 运行 `:ClaudeCode` 在分屏中打开 Claude 终端。
2.  **发送上下文**:
    -   在可视模式下选择文本，使用 `<leader>as` 发送给 Claude。
    -   在文件树插件中，对准文件按下 `<leader>as` 将其添加到 Claude 的上下文中。
3.  **开始编码**: Claude 现在可以实时看到你当前的文件和选择，可以打开文件、显示差异、访问诊断信息等。

## 核心命令

- `:ClaudeCode` - 切换 Claude Code 终端窗口。
- `:ClaudeCodeFocus` - 智能聚焦/切换 Claude 终端。
- `:ClaudeCodeSend` - (可视模式下) 发送当前选择给 Claude。
- `:ClaudeCodeDiffAccept` - 接受 diff 变更。
- `:ClaudeCodeDiffDeny` - 拒绝 diff 变更。

---

更多高级配置和技术细节，请**[阅读英文原版 README](./README.md)**。