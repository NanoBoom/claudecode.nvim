# ClaudeCodeRestart 命令

## 功能

`ClaudeCodeRestart` 命令用于快速重启 Claude Code 集成。

当 lock 文件被 devcontainer 中的 Claude CLI 清理后，使用此命令可以：
1. 停止当前的 WebSocket 服务器
2. 清理旧的状态
3. 重新启动服务器
4. 创建新的 lock 文件

## 使用方法

在 Neovim 中执行：

```vim
:ClaudeCodeRestart
```

## 工作流程

```
:ClaudeCodeRestart
  ↓
1. 停止现有服务器（如果运行中）
  ↓
2. 等待 100ms 确保清理完成
  ↓
3. 启动新的服务器
  ↓
4. 创建新的 lock 文件
```

## 日志输出

重启时会看到类似的日志：

```
[ClaudeCode] Restarting Claude Code integration...
[ClaudeCode] Claude Code integration stopped
[ClaudeCode] Claude Code integration started on port 12345
[ClaudeCode] Claude Code integration restarted successfully on port 12345
```

## Lua API

你也可以在 Lua 中调用：

```lua
-- 带通知（默认）
require('claudecode').restart()

-- 静默重启
require('claudecode').restart(false)
```

## 键盘映射建议

可以在配置中添加快捷键：

```lua
vim.keymap.set('n', '<leader>cr', '<cmd>ClaudeCodeRestart<cr>', {
  desc = 'Restart Claude Code',
  silent = true
})
```

## 常见场景

### 场景 1：Lock 文件被删除

```bash
# devcontainer 中的 Claude CLI 清理了 lock 文件
# 在 Neovim 中：
:ClaudeCodeRestart

# 重新创建 lock 文件，恢复正常
```

### 场景 2：端口冲突

```bash
# 如果端口被占用
:ClaudeCodeStop
# 关闭占用端口的进程
:ClaudeCodeStart

# 或者直接重启（会尝试停止旧连接）
:ClaudeCodeRestart
```

### 场景 3：连接异常

```bash
# 如果 Claude CLI 连接出现问题
:ClaudeCodeRestart

# 重置所有连接状态
```

## 相关命令

- `:ClaudeCodeStart` - 启动集成
- `:ClaudeCodeStop` - 停止集成
- `:ClaudeCodeRestart` - 重启集成 ⭐ 新增
- `:ClaudeCodeStatus` - 查看状态

## 实现细节

```lua
function M.restart(show_notification)
  -- 1. 停止当前服务器
  if M.state.server then
    M.stop()
  end

  -- 2. 延迟启动（确保资源释放）
  vim.defer_fn(function()
    M.start(show_notification)
  end, 100)
end
```

## 注意事项

1. **队列清理**：重启会清空所有待处理的 @ mention 队列
2. **连接断开**：已连接的 Claude CLI 会断开，需要等待重新连接
3. **端口变化**：重启可能使用不同的端口（如果原端口被占用）

## 故障排查

### 问题：重启后 Claude CLI 无法连接

**原因**：Lock 文件创建失败或端口冲突

**解决**：

```vim
:ClaudeCodeStatus
" 检查端口号

:lua print(require('claudecode.lockfile').lock_dir)
" 检查 lock 目录

" 手动检查 lock 文件
:!ls -la ~/.claude/ide/*.lock
```

### 问题：重启很慢

**原因**：旧服务器停止时间长

**解决**：检查是否有大量未处理的消息或连接

```vim
:ClaudeCodeDebugState
" 查看详细状态
```
