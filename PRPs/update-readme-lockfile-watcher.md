# TASK PRP: Update README - Lockfile Watcher Auto-Reconnect Feature

## Context

### Problem Statement
刚刚实现了lockfile watcher自动重连功能，但README文档没有说明这个特性。用户不知道：
1. 当Claude CLI崩溃或退出时，插件会自动重连
2. 可以配置检查间隔
3. 这个功能是如何工作的

### Solution Overview
在README中添加关于lockfile watcher自动重连功能的文档说明。

### Design Principles Applied
- **KISS**: 简单描述功能和配置，用户能快速理解
- **YAGNI**: 只文档化已实现的功能，不涉及未来计划
- **DRY**: 复用README现有的结构和风格

### Key Files
- `README.md`: 需要更新的主文档

### Implemented Feature Analysis

**功能概述**:
- 插件启动时自动创建定时器，每5秒检查lockfile存在性
- 如果lockfile消失（Claude CLI退出/崩溃），自动调用restart重连
- 防止restart循环的安全机制

**配置项**:
```lua
lockfile_check_interval = 5000  -- 检查间隔(毫秒)，范围1-60秒
```

**实现细节**:
- 使用vim.uv.new_timer()创建定时器
- 在M.start()启动watcher，M.stop()停止watcher
- restart()自动处理watcher生命周期

### Documentation Placement

根据README结构分析，最合适的位置是：
1. **Advanced Configuration** 部分 - 添加`lockfile_check_interval`配置项
2. **How It Works** 部分 - 简要说明自动重连机制
3. 可选：在**Troubleshooting**添加相关说明

### Content Style

从现有README分析文档风格：
- 简洁直接，技术准确
- 使用代码块展示配置
- 关键特性用emoji标记
- 保持一致的Markdown格式

---

## Tasks

### TASK 1: 在Advanced Configuration添加lockfile_check_interval说明

**File**: `README.md`

**Location**: 在`Advanced Configuration`部分，`queue_timeout`后面添加

**Add**:
```markdown
    queue_timeout = 5000, -- Maximum time to keep @ mentions in queue (milliseconds)
    lockfile_check_interval = 5000, -- Interval to check lockfile existence for auto-reconnect (milliseconds, 1-60 seconds)
```

**Context**:
- 找到`queue_timeout`配置项（约line 20）
- 在其后添加新配置项
- 保持与其他配置项相同的格式和注释风格

**Validation**:
- [ ] 配置项位置正确，在queue_timeout之后
- [ ] 注释说明清晰（interval, auto-reconnect, milliseconds, range）
- [ ] 缩进和格式与周围代码一致

**If Fail**: 检查行号是否正确，确保在正确的代码块内

**Rollback**: 删除添加的行

---

### TASK 2: 在How It Works部分添加自动重连说明

**File**: `README.md`

**Location**: 在`How It Works`部分，现有内容之后添加

**Add**:
```markdown
## How It Works

This plugin creates a WebSocket server that Claude Code CLI connects to, implementing the same protocol as the official VS Code extension. When you launch Claude, it automatically detects Neovim and gains full access to your editor.

The protocol uses a WebSocket-based variant of MCP (Model Context Protocol) that:

1. Creates a WebSocket server on a random port
2. Writes a lock file to `~/.claude/ide/[port].lock` (or `$CLAUDE_CONFIG_DIR/ide/[port].lock` if `CLAUDE_CONFIG_DIR` is set) with connection info
3. Sets environment variables that tell Claude where to connect
4. Implements MCP tools that Claude can call

**Auto-Reconnect**: The plugin monitors the lockfile every 5 seconds (configurable via `lockfile_check_interval`). If Claude CLI exits or crashes and the lockfile is removed, the plugin automatically restarts the connection, ensuring seamless recovery without manual intervention.

📖 **[Read the full reverse-engineering story →](./STORY.md)**
🔧 **[Complete protocol documentation →](./PROTOCOL.md)**
```

**Context**:
- 定位到`## How It Works`部分（约line 211）
- 在现有4点说明之后，链接之前添加新段落
- 使用**粗体**标记"Auto-Reconnect"保持风格一致

**Validation**:
- [ ] 段落位置正确（在4点说明后，链接前）
- [ ] 格式与现有内容一致
- [ ] 技术描述准确（5秒检查，自动restart）
- [ ] Markdown格式正确

**If Fail**: 检查markdown格式，确保段落间有空行

**Rollback**: 删除添加的段落

---

### TASK 3: 在Troubleshooting添加相关条目（可选）

**File**: `README.md`

**Location**: `## Troubleshooting`部分末尾

**Add**:
```markdown
- **Claude disconnects frequently?** The lockfile watcher will automatically reconnect within 5-10 seconds. Check logs with `log_level = "debug"` to see reconnection attempts. Adjust `lockfile_check_interval` if needed (default: 5000ms).
```

**Context**:
- 找到`## Troubleshooting`部分（约line 770）
- 在最后一个问题之后添加
- 保持与其他问题相同的格式（- **问题?** 解决方案）

**Validation**:
- [ ] 格式与其他troubleshooting条目一致
- [ ] 提供actionable的解决建议
- [ ] 语气与现有内容匹配

**If Fail**: 检查markdown列表格式

**Rollback**: 删除添加的条目

---

## Integration Validation

### README Consistency Check

运行以下检查确保文档质量：

```bash
# 检查markdown格式
# 如果有markdownlint
markdownlint README.md

# 检查配置示例语法
grep -A 5 "lockfile_check_interval" README.md
```

### Content Review Checklist

- [ ] 技术描述准确无误
- [ ] 配置示例可复制粘贴使用
- [ ] 文档风格与现有内容一致
- [ ] 无拼写错误
- [ ] Markdown格式正确渲染

---

## Completion Checklist

### Design Principle Compliance

- [x] KISS: 简单清晰的功能描述
- [x] Ockham's Razor: 只添加必要的文档内容
- [x] YAGNI: 只文档化已实现的功能
- [x] DRY: 复用现有文档结构和风格
- [x] SRP: 每个任务只更新一个部分

### Task Completeness

- [x] 所有更新位置已确定
- [x] 文档内容准确描述实现
- [x] 格式与现有文档一致
- [x] 提供实用的配置建议
- [x] 无遗漏的关键信息

### Red Flags Check

- [x] 无不相关的内容添加
- [x] 无未实现功能的文档
- [x] 无过度复杂的说明
- [x] 无格式不一致

---

## Documentation Quality Standards

### Technical Accuracy

- ✅ 默认检查间隔5秒
- ✅ 配置范围1-60秒
- ✅ 自动调用restart()重连
- ✅ 检查~/.claude/ide/{port}.lock

### User Experience

- ✅ 清晰说明功能价值（自动重连，无需手动干预）
- ✅ 提供配置示例
- ✅ 说明如何调试（log_level = "debug"）

### Documentation Style

- ✅ 保持简洁
- ✅ 技术准确
- ✅ 实用性强
- ✅ 格式一致

---

## Success Criteria

- [ ] 用户能理解自动重连功能
- [ ] 用户知道如何配置检查间隔
- [ ] 用户知道如何调试连接问题
- [ ] 文档与代码实现完全一致
- [ ] Markdown格式正确渲染
