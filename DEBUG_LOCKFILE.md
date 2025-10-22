# 🔍 Lock File 调试指南

## 第一步：在 devcontainer 中启动 Neovim

```bash
# 1. 确保在 devcontainer 内
cd /workspace

# 2. 清空旧的 lock 文件
rm -rf ~/.claude/ide/*.lock

# 3. 启动 Neovim 并查看调试输出
nvim

# 4. 在 Neovim 中执行
:ClaudeCodeStart
```

## 第二步：观察调试输出

你应该看到这些调试信息：

### 🔵 蓝色：模块加载时
```
🔵 DEBUG: Lock directory on module load: /home/node/.claude/ide
🔵 DEBUG: Lock directory exists? true
🔵 DEBUG: CLAUDE_CONFIG_DIR env: nil
```

### 🟢 绿色：文件创建时
```
🟢 DEBUG: Lock file created at: /home/node/.claude/ide/xxxxx.lock
🟢 DEBUG: Lock file exists after close? true
🟢 DEBUG: Lock file size: xxx bytes
```

### 🔴 红色：文件删除时（如果发生）
```
🔴 DEBUG: lockfile.remove() called from: [stack trace]
🔴 DEBUG: Removing lock file: /home/node/.claude/ide/xxxxx.lock
🔴 DEBUG: Lock file successfully removed
```

## 第三步：并行监控文件系统

在另一个终端（同样在 devcontainer 内）：

```bash
# 方法 1：持续监控
watch -n 0.5 'ls -la ~/.claude/ide/*.lock 2>&1'

# 方法 2：使用 inotifywait（如果可用）
inotifywait -m ~/.claude/ide/ -e create -e delete -e modify
```

## 第四步：关键测试场景

### 场景 1：正常启动
```vim
:ClaudeCodeStart
" 观察调试输出
" 检查文件是否存在
:!ls -la ~/.claude/ide/*.lock
```

### 场景 2：检查文件是否立即消失
```bash
# 在 Neovim 启动后立即执行
ls -la ~/.claude/ide/*.lock
cat ~/.claude/ide/*.lock | jq .
```

### 场景 3：检查是否是 VimLeavePre 触发
```vim
" 在 Neovim 中
:ClaudeCodeStart
:autocmd VimLeavePre * echom "VimLeavePre triggered!"
" 等待几秒，看看是否有意外触发
```

## 预期结果

### ✅ 正常情况
- 🔵 显示正确的 lock_dir 路径
- 🟢 显示文件创建成功
- **没有** 🔴 删除日志
- 文件持续存在

### ❌ 异常情况 A：立即删除
- 🔵 显示正确路径
- 🟢 显示创建成功
- 🔴 **立即**显示删除日志 + 堆栈跟踪
- **→ 这说明代码逻辑有问题**

### ❌ 异常情况 B：延迟消失（无删除日志）
- 🔵 显示正确路径
- 🟢 显示创建成功
- **没有** 🔴 删除日志
- 但文件消失了
- **→ 这说明是文件系统问题**

### ❌ 异常情况 C：路径错误
- 🔵 显示路径不是 `/home/node/.claude/ide`
- **→ 这说明 vim.fn.expand() 有问题**

## 报告格式

请把以下信息发给我：

```
1. 调试输出（完整的 🔵🟢🔴 日志）
2. 文件监控输出
3. 异常情况类型（A/B/C）
4. lock 文件内容（如果存在）：cat ~/.claude/ide/*.lock
```

这样我就能精确定位问题了。
