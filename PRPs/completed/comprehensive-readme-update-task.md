# TASK PRP: Comprehensive README Update

## Context

### Problem Statement
通过深度代码分析发现，README存在多处与实际实现不一致、缺失关键功能文档的问题：

**过时/不准确内容**:
- 引用旧API `vim.loop`，未说明现已使用`vim.uv`
- 多处使用`terminal_cmd`但代码中是`external_terminal_cmd`

**缺失的命令文档**:
- `:ClaudeCodeStart` - 启动集成
- `:ClaudeCodeStop` - 停止集成
- `:ClaudeCodeRestart` - 重启集成
- `:ClaudeCodeTreeAdd` - 从文件树添加文件
- `:ClaudeCodeDebugState` - 调试状态信息
- `:ClaudeCodeStatus` (仅在troubleshooting提到，未在命令列表中)

**缺失的配置项**:
- `lockfile_check_interval` - 自动重连检查间隔
- `connection_timeout` - 连接超时时间
- `queue_timeout` - 队列超时时间
- `connection_wait_delay` - 连接后等待时间

**缺失的功能说明**:
- Lockfile watcher自动重连机制
- @ mention队列管理系统
- 连接超时和重试策略

### Solution Overview
系统性更新README文档，确保与代码实现完全一致，补充所有缺失的功能和配置说明。

### Design Principles Applied
- **KISS**: 每个任务更新一个独立部分
- **Ockham's Razor**: 只添加必要的文档内容
- **YAGNI**: 只文档化已实现的功能
- **DRY**: 保持文档风格一致
- **SRP**: 每个任务单一职责

### Key Files
- `README.md`: 主文档文件

### Code Analysis Summary

**已实现的用户命令** (11个):
1. ClaudeCodeStart - 启动集成
2. ClaudeCodeStop - 停止集成
3. ClaudeCodeRestart - 重启集成
4. ClaudeCodeStatus - 显示状态
5. ClaudeCodeSend - 发送选中内容/文件
6. ClaudeCodeTreeAdd - 从文件树添加
7. ClaudeCodeAdd - 添加文件(支持行范围)
8. ClaudeCodeDiffAccept - 接受diff
9. ClaudeCodeDiffDeny - 拒绝diff
10. ClaudeCodeDebugState - 调试信息
11. ClaudeCodeSelectModel - 选择模型

**已实现的MCP工具** (11个):
1. open_file
2. get_current_selection
3. get_open_editors
4. open_diff
5. get_latest_selection
6. close_all_diff_tabs
7. get_diagnostics
8. get_workspace_folders
9. check_document_dirty
10. save_document
11. close_tab

**完整配置项列表**:
- port_range
- auto_start
- external_terminal_cmd
- workspace_folders_fn
- log_level
- track_selection
- visual_demotion_delay_ms
- connection_wait_delay
- connection_timeout
- queue_timeout
- lockfile_check_interval
- diff_opts (layout, open_in_new_tab, on_new_file_reject)
- models

---

## Tasks

### TASK 1: 更新vim.loop引用为vim.uv

**File**: `README.md`

**Changes**:

**Location 1** - "What Makes This Special"部分 (line ~17):
```markdown
Old:
- 🚀 **Pure Lua, Zero Dependencies** — Built entirely with `vim.loop` and Neovim built-ins

New:
- 🚀 **Pure Lua, Zero Dependencies** — Built entirely with `vim.uv` (Neovim's libuv bindings) and Neovim built-ins
```

**Location 2** - "Architecture"部分 (line ~229):
```markdown
Old:
- **WebSocket Server** - RFC 6455 compliant implementation using `vim.loop`

New:
- **WebSocket Server** - RFC 6455 compliant implementation using `vim.uv` (Neovim's libuv bindings)
```

**Rationale**:
- vim.uv是Neovim推荐的新API
- vim.loop是向后兼容的别名
- 说明两者关系有助于理解

**Validation**:
- [ ] 所有vim.loop引用已更新
- [ ] 说明清晰准确
- [ ] Markdown格式正确

**If Fail**: 检查是否还有其他vim.loop引用

**Rollback**: 恢复原始内容

---

### TASK 2: 扩展Key Commands部分

**File**: `README.md`

**Location**: `## Key Commands`部分 (line ~192)

**Replace**:
```markdown
## Key Commands

### Core Commands

- `:ClaudeCodeStart` - Start the Claude Code integration (launches server and creates lockfile)
- `:ClaudeCodeStop` - Stop the Claude Code integration (cleanup and shutdown)
- `:ClaudeCodeRestart` - Restart the Claude Code integration
- `:ClaudeCodeStatus` - Show integration status (connection, port, lockfile)

### Terminal Control

- `:ClaudeCode` - Toggle the Claude Code terminal window
- `:ClaudeCodeFocus` - Smart focus/toggle Claude terminal
- `:ClaudeCodeSelectModel` - Select Claude model and open terminal with optional arguments

### Context Management

- `:ClaudeCodeSend` - Send current visual selection to Claude (works in visual mode or from file explorers)
- `:ClaudeCodeTreeAdd` - Add file(s) from file explorer to Claude context (nvim-tree, neo-tree, oil, mini.files, netrw)
- `:ClaudeCodeAdd <file-path> [start-line] [end-line]` - Add specific file to Claude context with optional line range

### Diff Management

- `:ClaudeCodeDiffAccept` - Accept diff changes (equivalent to `:w` in diff buffer)
- `:ClaudeCodeDiffDeny` - Reject diff changes (equivalent to `:q` in diff buffer)

### Debugging

- `:ClaudeCodeDebugState` - Print internal state for debugging (server, connections, timers)
```

**Rationale**:
- 将11个命令按功能分组，更易理解
- 添加简短说明，用户知道每个命令的用途
- 所有已实现的命令都有文档

**Validation**:
- [ ] 所有11个命令都已列出
- [ ] 分组合理清晰
- [ ] 说明简洁准确
- [ ] Markdown格式正确

**If Fail**: 检查命令名称拼写

**Rollback**: 恢复原始Key Commands部分

---

### TASK 3: 在Advanced Configuration添加缺失的配置项

**File**: `README.md`

**Location**: `## Advanced Configuration`部分的opts块 (line ~243)

**Add after existing config items**:
```lua
{
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    -- Server Configuration
    port_range = { min = 10000, max = 65535 },
    auto_start = true,
    log_level = "info", -- "trace", "debug", "info", "warn", "error"
    external_terminal_cmd = nil, -- Command to launch Claude (default: "claude")
                                  -- For local installations: "~/.claude/local/claude"
                                  -- For native binary: use output from 'which claude'

    -- Connection Management
    connection_timeout = 10000, -- Maximum time to wait for Claude Code to connect (milliseconds)
    connection_wait_delay = 600, -- Milliseconds to wait after connection before sending queued @ mentions
    queue_timeout = 5000, -- Maximum time to keep @ mentions in queue (milliseconds)
    lockfile_check_interval = 5000, -- Interval to check lockfile for auto-reconnect (milliseconds, 1-60 seconds)

    -- Selection Tracking
    track_selection = true,
    visual_demotion_delay_ms = 50,

    -- Workspace Configuration
    workspace_folders_fn = nil, -- Optional: custom function to compute workspace folders

    -- Diff Integration
    diff_opts = {
      layout = "vertical", -- "vertical" or "horizontal"
      open_in_new_tab = false, -- Open diff in a new tab (false = use current tab)
      on_new_file_reject = "keep_empty", -- "keep_empty" or "close_window"
    },

    -- Model Selection
    models = {
      { name = "Claude Opus 4.1 (Latest)", value = "opus" },
      { name = "Claude Sonnet 4.5 (Latest)", value = "sonnet" },
      { name = "Opusplan: Claude Opus 4.1 (Latest) + Sonnet 4.5 (Latest)", value = "opusplan" },
      { name = "Claude Haiku 4.5 (Latest)", value = "haiku" },
    },
  },
  keys = {
    -- Your keymaps here
  },
}
```

**Rationale**:
- 按功能分组配置项
- 添加清晰的注释说明
- 包含所有已实现的配置项
- 保持与代码一致的命名

**Validation**:
- [ ] 所有配置项已列出
- [ ] 注释清晰准确
- [ ] 分组合理
- [ ] Lua语法正确

**If Fail**: 检查配置项名称和默认值

**Rollback**: 恢复原始配置块

---

### TASK 4: 更新How It Works部分添加自动重连说明

**File**: `README.md`

**Location**: `## How It Works`部分 (line ~211)

**Add after existing 4 points, before links**:
```markdown
## How It Works

This plugin creates a WebSocket server that Claude Code CLI connects to, implementing the same protocol as the official VS Code extension. When you launch Claude, it automatically detects Neovim and gains full access to your editor.

The protocol uses a WebSocket-based variant of MCP (Model Context Protocol) that:

1. Creates a WebSocket server on a random port
2. Writes a lock file to `~/.claude/ide/[port].lock` (or `$CLAUDE_CONFIG_DIR/ide/[port].lock` if `CLAUDE_CONFIG_DIR` is set) with connection info
3. Sets environment variables that tell Claude where to connect
4. Implements MCP tools that Claude can call

### Auto-Reconnect

The plugin includes a lockfile watcher that monitors the connection every 5 seconds (configurable via `lockfile_check_interval`). If Claude CLI exits or crashes and the lockfile is removed, the plugin automatically restarts the connection within 5-10 seconds, ensuring seamless recovery without manual intervention.

### Connection Management

- **Connection Timeout**: Waits up to 10 seconds (configurable) for Claude to connect after launch
- **Queue Management**: @ mentions are queued if sent before Claude connects, with a 5-second timeout
- **Connection Wait**: After Claude connects, waits 600ms before processing queued mentions to ensure stable connection

📖 **[Read the full reverse-engineering story →](./STORY.md)**
🔧 **[Complete protocol documentation →](./PROTOCOL.md)**
```

**Rationale**:
- 详细说明自动重连机制
- 说明连接管理策略
- 帮助用户理解系统行为

**Validation**:
- [ ] 技术描述准确
- [ ] 数值与代码一致
- [ ] Markdown格式正确

**If Fail**: 检查配置默认值

**Rollback**: 删除添加的部分

---

### TASK 5: 扩展Troubleshooting部分

**File**: `README.md`

**Location**: `## Troubleshooting`部分末尾 (line ~770)

**Add**:
```markdown
- **Claude disconnects frequently?** The lockfile watcher automatically reconnects within 5-10 seconds. Check logs with `log_level = "debug"` to see reconnection attempts. Adjust `lockfile_check_interval` if needed (default: 5000ms, range: 1-60 seconds).
- **Connection timeout?** Claude Code has 10 seconds to connect by default. For slow systems, increase `connection_timeout` (default: 10000ms).
- **@ mentions not working?** Check `:ClaudeCodeStatus` to verify connection. Mentions are queued for 5 seconds (`queue_timeout`) if sent before Claude connects.
- **Need detailed logs?** Use `:ClaudeCodeDebugState` to see internal state (server, connections, timers, queue status).
```

**Rationale**:
- 提供可操作的解决方案
- 说明相关配置项
- 帮助用户自行调试

**Validation**:
- [ ] 格式与现有条目一致
- [ ] 解决方案实用
- [ ] 引用正确的配置项

**If Fail**: 检查markdown列表格式

**Rollback**: 删除添加的条目

---

### TASK 6: 修正terminal_cmd到external_terminal_cmd

**File**: `README.md`

**Changes**: 将所有`terminal_cmd`引用更新为`external_terminal_cmd`

**Locations to update**:

1. Line ~96 (Local Installation Configuration):
```lua
opts = {
  external_terminal_cmd = "~/.claude/local/claude", -- Point to local installation
},
```

2. Line ~153 (Native Binary Configuration):
```lua
opts = {
  external_terminal_cmd = "/path/to/your/claude", -- Use output from 'which claude'
},
```

3. Line ~164 (Note):
```markdown
> **Note**: If Claude Code was installed globally via npm, you can use the default configuration without specifying `external_terminal_cmd`.
```

4. Line ~775-776 (Troubleshooting):
```markdown
- **Local installation not working?** If you used `claude migrate-installer`, set `external_terminal_cmd = "~/.claude/local/claude"` in your config. Check `which claude` vs `ls ~/.claude/local/claude` to verify your installation type.
- **Native binary installation not working?** If you used the alpha native binary installer, run `claude doctor` to verify installation health and use `which claude` to find the binary path. Set `external_terminal_cmd = "/path/to/claude"` with the detected path in your config.
```

**Rationale**:
- 与实际代码配置项名称一致
- 避免用户配置时的困惑

**Validation**:
- [ ] 所有terminal_cmd引用已更新
- [ ] 代码示例可直接使用
- [ ] 说明清晰

**If Fail**: 搜索是否还有遗漏的terminal_cmd

**Rollback**: 恢复原始命名

---

### TASK 7: 在Installation部分添加ClaudeCode命令说明

**File**: `README.md`

**Location**: After Installation section (line ~52)

**Add**:
```markdown
That's it! The plugin will auto-configure everything else.

> **Note**: The integration starts automatically by default (`auto_start = true`). Use `:ClaudeCodeStatus` to verify the connection. To manually control the integration, set `auto_start = false` in your config and use `:ClaudeCodeStart` / `:ClaudeCodeStop` commands.
```

**Rationale**:
- 用户了解auto_start行为
- 知道如何手动控制
- 知道如何验证状态

**Validation**:
- [ ] 位置合适
- [ ] 说明清晰
- [ ] Markdown格式正确

**If Fail**: 检查插入位置

**Rollback**: 删除添加的note

---

## Integration Validation

### Documentation Consistency Check

```bash
# 检查所有命令是否已文档化
grep "ClaudeCode[A-Z]" README.md | sort -u

# 检查所有配置项是否已文档化
grep -E "port_range|auto_start|external_terminal_cmd|workspace_folders_fn|log_level|track_selection|visual_demotion_delay_ms|connection_wait_delay|connection_timeout|queue_timeout|lockfile_check_interval|diff_opts|models" README.md

# 检查vim.loop是否还有残留
grep "vim\.loop" README.md
```

### Markdown Validation

```bash
# 如果有markdownlint
markdownlint README.md

# 检查格式
mdl README.md
```

---

## Completion Checklist

### Design Principle Compliance

- [x] KISS: 每个任务更新独立部分，简单直接
- [x] Ockham's Razor: 只添加必要的文档内容
- [x] YAGNI: 只文档化已实现的功能
- [x] DRY: 保持文档风格一致
- [x] SRP: 每个任务单一职责

### Task Completeness

- [x] 所有API更新已识别
- [x] 所有缺失命令已列出
- [x] 所有缺失配置已列出
- [x] 所有功能说明已补充
- [x] 命名不一致已修正
- [x] 每个任务有验证步骤
- [x] 每个任务有回滚方案

### Red Flags Check

- [x] 无不相关内容
- [x] 无未实现功能文档
- [x] 无过度复杂任务
- [x] 无格式不一致

---

## Documentation Quality Standards

### Technical Accuracy

- ✅ 所有命令名称与代码一致
- ✅ 所有配置项名称与代码一致
- ✅ 所有默认值与代码一致
- ✅ 所有功能描述准确

### User Experience

- ✅ 清晰说明每个功能的用途
- ✅ 提供可用的配置示例
- ✅ 说明如何调试问题
- ✅ 分组合理，易于查找

### Documentation Style

- ✅ 保持简洁
- ✅ 技术准确
- ✅ 实用性强
- ✅ 格式一致

---

## Success Criteria

- [ ] 用户能找到所有已实现的命令
- [ ] 用户能找到所有配置项
- [ ] 用户理解自动重连功能
- [ ] 用户知道如何调试连接问题
- [ ] 文档与代码实现完全一致
- [ ] Markdown格式正确渲染
- [ ] 无过时或错误信息

---

## Risk Assessment

### Known Risks

1. **文档太长** (LOW) - 通过合理分组和折叠缓解
2. **破坏现有链接** (MEDIUM) - 小心更新章节标题
3. **配置示例错误** (LOW) - 从实际代码复制

### Mitigation

- 保持现有章节结构
- 只扩展内容，不删除
- 所有示例从代码验证
