---
name: "Fix Lock File Disappearing When Claude CLI Starts in Devcontainer"
description: "Root cause: Claude CLI clears lock files from different PID namespace"
---

## Original Story

```
我在宿主机运行 Neovim，~/.claude 目录挂载到容器中。
当在 devcontainer 中启动 Claude CLI 后，整个 ~/.claude/ide/ 目录下的所有文件都消失了。
```

## Story Metadata

**Story Type**: Bug
**Estimated Complexity**: High
**Primary Systems Affected**:
- Lock file management (`lua/claudecode/lockfile.lua`)
- Devcontainer configuration (`.devcontainer/`)
- Claude CLI 交互

---

## ROOT CAUSE ANALYSIS

### 场景重现

```
1. 宿主机（macOS）运行 Neovim
   → 创建 ~/.claude/ide/12345.lock
   → 内容：{ "pid": 67890, "workspaceFolders": ["/Users/fanlz/..."] }

2. ~/.claude 通过 bind mount 映射到容器
   → 宿主机：/Users/fanlz/.claude
   → 容器内：/home/node/.claude

3. 在 devcontainer 中启动 Claude CLI
   → Claude CLI 读取 ~/.claude/ide/12345.lock
   → 检查 pid 67890 → ps -p 67890 → 不存在（PID namespace 隔离）
   → 检查路径 /Users/fanlz/... → 可能存在（因为软链接）但 PID 不存在
   → 结论：这是僵尸 lock 文件
   → 清理操作：rm -rf ~/.claude/ide/*

4. 结果：整个 ide/ 目录被清空
```

### Linus式判断

【核心判断】
🔴 **这是个 PID namespace 隔离的灾难**

"你在不同的 namespace 里共享状态文件，当然会出问题。这就像两个内核试图管理同一个文件系统，互相不知道对方的存在。"

【致命问题】

**问题 1：PID 在容器内无效**
- Lock 文件存储 `vim.fn.getpid()`（宿主机 PID）
- Claude CLI 在容器内运行 `ps -p <pid>`
- 容器有独立的 PID namespace
- **宿主机的 PID 在容器内根本不存在**

**问题 2：Claude CLI 的清理逻辑**
- Claude CLI 启动时检查所有 lock 文件
- 对于每个 lock 文件，检查 PID 是否存活：`kill -0 <pid>`
- 如果进程不存在 → 删除 lock 文件
- **这是正常的清理逻辑，但在跨 namespace 场景下是灾难**

**问题 3：Bind mount 共享目录**
- 两个不同的进程空间共享同一个文件系统位置
- 没有协调机制
- 互相破坏对方的状态

### 技术分析

#### PID Namespace 隔离

```bash
# 宿主机
$ ps aux | grep nvim
fanlz  67890  ...  nvim

# 容器内
$ ps aux | grep nvim
# （没有结果）

$ ps -p 67890
# error: PID not found

# 容器的 PID 1 是容器的 init 进程，不是宿主机的 PID 1
```

#### Lock 文件内容

```json
{
  "pid": 67890,                      // ← 宿主机 PID，容器内无效
  "workspaceFolders": [
    "/Users/fanlz/Projects/..."      // ← 软链接可能让路径有效，但 PID 仍无效
  ],
  "ideName": "Neovim",
  "transport": "ws",
  "authToken": "..."
}
```

#### Claude CLI 的清理逻辑（推测）

```javascript
// Claude CLI 启动时的伪代码
async function cleanupStaleLocks(lockDir) {
  const lockFiles = await fs.readdir(lockDir);

  for (const file of lockFiles) {
    const lock = JSON.parse(await fs.readFile(file));

    // 检查进程是否存活
    try {
      process.kill(lock.pid, 0);  // 不发送信号，只检查进程是否存在
    } catch (err) {
      if (err.code === 'ESRCH') {
        // 进程不存在，删除 lock 文件
        console.log(`Removing stale lock: ${file}`);
        await fs.unlink(file);
      }
    }
  }
}
```

在容器内，`process.kill(67890, 0)` 总是抛出 `ESRCH`（进程不存在），导致删除。

---

## CONTEXT REFERENCES

### 核心文件
- `lua/claudecode/lockfile.lua:76-152` - Lock 文件创建逻辑
- `.devcontainer/devcontainer.json:19` - Bind mount 配置
- `.devcontainer/Dockerfile:28-34` - 路径软链接（部分缓解，但 PID 问题仍存在）

### 相关模式
- Docker PID namespace 文档
- Claude CLI 的 lock 文件管理机制（需要查阅）

---

## SOLUTION OPTIONS

### 方案 A：使用独立的 lock 目录 ⭐⭐⭐⭐⭐ 推荐

**思路**：宿主机和容器使用不同的 lock 子目录

```
~/.claude/
  ├── ide-host/         ← 宿主机 Neovim 使用
  └── ide-container/    ← 容器内 Claude CLI 使用（如果需要）
```

**优点**：
- 完全隔离，零冲突
- 简单、可靠
- 不需要修改 Claude CLI

**缺点**：
- Claude CLI 看不到宿主机的 Neovim lock 文件
- **需要通过其他方式让两者通信**（WebSocket 端口仍然可以工作）

**实现**：设置环境变量 `CLAUDE_IDE_LOCK_SUBDIR`

---

### 方案 B：在 devcontainer 中使用 host PID namespace ⭐⭐⭐

**思路**：让容器共享宿主机的 PID namespace

在 `.devcontainer/devcontainer.json` 中添加：

```json
"runArgs": [
  "--network=host",
  "--pid=host"        // ← 添加这个
]
```

**优点**：
- PID 在容器内可见，Claude CLI 能正确检测 Neovim 进程
- Lock 文件机制正常工作

**缺点**：
- 安全性降低（容器可以看到和操作宿主机的所有进程）
- 不是最佳实践
- 可能在某些平台不支持（如 macOS 的 Docker Desktop）

---

### 方案 C：让 Claude CLI 跳过 lock 文件清理 ⭐⭐

**思路**：配置 Claude CLI 不清理 lock 文件

可能的配置（需要查阅 Claude CLI 文档）：

```bash
# 环境变量
export CLAUDE_SKIP_LOCK_CLEANUP=1

# 或配置文件
~/.claude/config.json:
{
  "skipLockCleanup": true
}
```

**优点**：
- 保留原有的文件共享
- 不修改 Neovim 代码

**缺点**：
- 需要 Claude CLI 支持这个配置（可能不存在）
- 僵尸 lock 文件会累积

---

### 方案 D：修改 Neovim lock 文件，不存储 PID ⭐

**思路**：从 lock 文件中移除 PID 字段

```lua
local lock_content = {
  -- pid = vim.fn.getpid(),  -- 删除这个
  workspaceFolders = workspace_folders,
  ideName = "Neovim",
  transport = "ws",
  authToken = auth_token,
}
```

**优点**：
- 避免 PID 检查失败

**缺点**：
- **破坏 Claude CLI 的假设**（lock 文件必须有 PID）
- Claude CLI 可能仍然删除"无效"的 lock 文件
- 失去僵尸进程检测能力

---

## RECOMMENDED SOLUTION: 方案 A（独立 lock 目录）

这是最干净、最可靠的方案。

---

## IMPLEMENTATION TASKS

### TASK 1: ADD lock directory configuration

**目标**：支持自定义 lock 子目录

- **LOCATION**: `lua/claudecode/lockfile.lua:11-18`

- **MODIFY**:
  ```lua
  local function get_lock_dir()
    local claude_config_dir = os.getenv("CLAUDE_CONFIG_DIR")
    local lock_subdir = os.getenv("CLAUDE_IDE_LOCK_SUBDIR") or "ide"  -- ← 添加

    if claude_config_dir and claude_config_dir ~= "" then
      return vim.fn.expand(claude_config_dir .. "/" .. lock_subdir)
    else
      return vim.fn.expand("~/.claude/" .. lock_subdir)
    end
  end
  ```

- **WHY**:
  - 允许通过环境变量配置 lock 子目录
  - 默认仍为 `ide`，保持向后兼容
  - 在宿主机设置 `CLAUDE_IDE_LOCK_SUBDIR=ide-host` 即可隔离

- **VALIDATE**:
  ```bash
  # 测试默认行为
  lua -e "
    os.getenv = function(k)
      if k == 'CLAUDE_CONFIG_DIR' then return nil end
      if k == 'CLAUDE_IDE_LOCK_SUBDIR' then return nil end
    end
    vim = {fn = {expand = function(p) return p:gsub('^~', '/home/test') end}}
    assert(loadfile('lua/claudecode/lockfile.lua'))
    print(require('claudecode.lockfile').lock_dir)
  "
  # 预期输出：/home/test/.claude/ide

  # 测试自定义子目录
  CLAUDE_IDE_LOCK_SUBDIR=ide-host lua -e "..."
  # 预期输出：/home/test/.claude/ide-host
  ```

---

### TASK 2: UPDATE devcontainer documentation

**目标**：在 `.devcontainer/devcontainer.json` 中添加环境变量注释

- **LOCATION**: `.devcontainer/devcontainer.json:32-34`

- **ADD COMMENT**:
  ```json
  // 环境变量
  "containerEnv": {
    "TERM": "xterm-256color"
    // 如果宿主机运行 Neovim，在宿主机设置：
    // export CLAUDE_IDE_LOCK_SUBDIR=ide-host
    // 以避免与容器内的 Claude CLI 冲突
  },
  ```

- **VALIDATE**: 无需验证（仅注释）

---

### TASK 3: CREATE setup guide

**目标**：创建设置指南

- **CREATE**: `docs/DEVCONTAINER_SETUP.md`

- **CONTENT**:
  ````markdown
  # Devcontainer 与 Neovim 集成指南

  ## 问题背景

  当在宿主机运行 Neovim 并在 devcontainer 中运行 Claude CLI 时，会发生 lock 文件冲突：

  - Neovim 在 `~/.claude/ide/` 创建 lock 文件（包含宿主机的 PID）
  - Claude CLI 在容器内检测到 PID 无效，清理所有 lock 文件

  ## 解决方案：使用独立 lock 目录

  ### 在宿主机

  在 `~/.zshrc` 或 `~/.bashrc` 中添加：

  ```bash
  # 让 Neovim 使用独立的 lock 目录
  export CLAUDE_IDE_LOCK_SUBDIR=ide-host
  ```

  重新加载配置：
  ```bash
  source ~/.zshrc  # 或 source ~/.bashrc
  ```

  ### 验证

  ```bash
  # 1. 在宿主机启动 Neovim
  nvim
  :ClaudeCodeStart

  # 2. 在另一个终端检查 lock 文件位置
  ls -la ~/.claude/ide-host/
  # 应该看到 *.lock 文件

  # 3. 在 devcontainer 中启动 Claude CLI
  claude

  # 4. 检查宿主机的 lock 文件仍然存在
  ls -la ~/.claude/ide-host/
  # lock 文件应该还在
  ```

  ### 目录结构

  ```
  ~/.claude/
    ├── ide-host/       # 宿主机 Neovim 的 lock 文件
    │   └── 12345.lock
    └── ide/            # 容器内 Claude CLI 的 lock 文件（如果有）
        └── 54321.lock
  ```

  ## 替代方案（不推荐）

  ### 方案 B：使用 host PID namespace

  在 `.devcontainer/devcontainer.json` 中：

  ```json
  "runArgs": [
    "--network=host",
    "--pid=host"
  ]
  ```

  **警告**：这会降低容器的安全隔离性。

  ## 故障排查

  ### 问题：lock 文件仍然消失

  1. 检查环境变量是否生效：
     ```bash
     echo $CLAUDE_IDE_LOCK_SUBDIR
     # 应该输出：ide-host
     ```

  2. 检查 Neovim 是否使用了正确的目录：
     ```vim
     :lua print(require('claudecode.lockfile').lock_dir)
     " 应该输出：/Users/fanlz/.claude/ide-host
     ```

  3. 检查容器内的 Claude CLI 是否看到不同的目录：
     ```bash
     # 在容器内
     ls -la ~/.claude/
     # 应该看到 ide/ 和 ide-host/ 两个目录
     ```
  ````

- **VALIDATE**:
  ```bash
  # 检查文档格式
  markdownlint docs/DEVCONTAINER_SETUP.md
  ```

---

### TASK 4: ADD debug logging (temporary)

**目标**：添加调试日志以验证方案

- **LOCATION**: `lua/claudecode/lockfile.lua:20-25`

- **ADD**:
  ```lua
  M.lock_dir = get_lock_dir()

  -- Inform user about lock directory for devcontainer scenarios
  if os.getenv("CLAUDE_IDE_LOCK_SUBDIR") then
    print(string.format(
      "[ClaudeCode] Using custom lock directory: %s (CLAUDE_IDE_LOCK_SUBDIR=%s)",
      M.lock_dir,
      os.getenv("CLAUDE_IDE_LOCK_SUBDIR")
    ))
  end
  ```

- **VALIDATE**:
  ```bash
  CLAUDE_IDE_LOCK_SUBDIR=ide-host nvim -c "lua require('claudecode')" -c "qa"
  # 应该看到输出：[ClaudeCode] Using custom lock directory: ...
  ```

---

## Validation Loop

### Level 1: Unit Tests

```bash
# 测试 lock_dir 配置
lua -e "
  -- Mock 环境
  local original_getenv = os.getenv
  os.getenv = function(k)
    if k == 'CLAUDE_IDE_LOCK_SUBDIR' then return 'ide-test' end
    return original_getenv(k)
  end

  vim = {
    fn = {
      expand = function(p) return p:gsub('^~', '/home/test') end,
      mkdir = function() return 1 end,
      getpid = function() return 12345 end,
      getcwd = function() return '/test' end
    },
    json = { encode = function(t) return '{}' end }
  }

  package.loaded['claudecode.lockfile'] = nil
  local lockfile = require('claudecode.lockfile')

  assert(lockfile.lock_dir:match('ide%-test'), 'Lock dir should use custom subdir')
  print('✓ Custom lock directory test passed')
"
```

### Level 2: Integration Test (Devcontainer)

```bash
# 在宿主机
export CLAUDE_IDE_LOCK_SUBDIR=ide-host
nvim -c "ClaudeCodeStart" &
sleep 2

# 检查 lock 文件位置
ls -la ~/.claude/ide-host/*.lock
test -f ~/.claude/ide-host/*.lock && echo "✓ Lock file created in ide-host"

# 在 devcontainer 中启动 Claude CLI
# （在另一个终端）
docker exec -it <container> bash
claude &  # 启动 Claude CLI
sleep 5

# 在宿主机检查 lock 文件是否还在
ls -la ~/.claude/ide-host/*.lock
test -f ~/.claude/ide-host/*.lock && echo "✓ Lock file survived" || echo "✗ Lock file deleted"

# 清理
killall nvim
killall claude
```

### Level 3: End-to-End Test

```bash
# 完整工作流测试
./scripts/test_devcontainer_lock.sh
```

创建测试脚本 `scripts/test_devcontainer_lock.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 Testing devcontainer lock file isolation"

# 1. 设置环境变量
export CLAUDE_IDE_LOCK_SUBDIR=ide-host

# 2. 在宿主机启动 Neovim
echo "1️⃣  Starting Neovim on host..."
nvim -c "ClaudeCodeStart" -c "sleep 1000ms" &
NVIM_PID=$!
sleep 3

# 3. 检查 lock 文件创建
echo "2️⃣  Checking lock file creation..."
LOCK_FILE=$(ls ~/.claude/ide-host/*.lock 2>/dev/null | head -1)
if [ -z "$LOCK_FILE" ]; then
  echo "❌ Lock file not created"
  kill $NVIM_PID
  exit 1
fi
echo "✓ Lock file created: $LOCK_FILE"

# 4. 模拟 Claude CLI 清理（如果在容器外测试）
echo "3️⃣  Testing lock file persistence..."
sleep 2

# 5. 验证 lock 文件仍然存在
if [ -f "$LOCK_FILE" ]; then
  echo "✓ Lock file persists"
else
  echo "❌ Lock file was deleted"
  kill $NVIM_PID
  exit 1
fi

# 清理
echo "4️⃣  Cleanup..."
kill $NVIM_PID
rm -f "$LOCK_FILE"

echo "✅ All tests passed"
```

---

## COMPLETION CHECKLIST

- [ ] `lockfile.lua` 支持 `CLAUDE_IDE_LOCK_SUBDIR` 环境变量
- [ ] `.devcontainer/devcontainer.json` 添加配置说明注释
- [ ] 创建 `docs/DEVCONTAINER_SETUP.md` 设置指南
- [ ] 添加调试日志
- [ ] 单元测试通过
- [ ] 在 devcontainer 环境中验证 lock 文件隔离
- [ ] 端到端测试通过
- [ ] 更新主 README 提及 devcontainer 支持

---

## Notes

### Why not use PID namespace sharing?

使用 `--pid=host` 确实能解决问题，但：

1. **安全风险**：容器进程可以看到和操作宿主机的所有进程
2. **违反容器隔离原则**：容器应该与宿主机隔离
3. **可移植性问题**：某些平台（如 macOS Docker Desktop）可能不支持

### Why not remove PID from lock file?

Lock 文件的 PID 用于：
1. 检测僵尸进程（进程已退出但 lock 文件残留）
2. 多实例检测（防止同一端口被多个实例使用）

移除 PID 会破坏这些功能。

### Alternative: Use socket file instead of PID

更好的跨 namespace 方案是使用 **Unix socket 文件** 代替 PID：

```lua
local lock_content = {
  socket = "/tmp/claudecode-" .. port .. ".sock",  -- Unix socket
  workspaceFolders = workspace_folders,
  ideName = "Neovim",
  transport = "ws",
  authToken = auth_token,
}
```

进程存活检查：
```javascript
// 尝试连接 socket，如果失败则进程不存在
try {
  const sock = net.connect(lock.socket);
  sock.end();  // 进程存活
} catch (err) {
  // Socket 不存在，进程已退出，删除 lock
}
```

但这需要：
1. 修改 Claude CLI 的 lock 文件检查逻辑（不可行）
2. 修改 Neovim 的 WebSocket 服务器创建 Unix socket（可行但复杂）

因此，**独立 lock 目录**仍是最实用的方案。

---

**Linus说**：
"别搞那些花哨的 namespace 共享。分离状态，各管各的。这是最简单、最可靠的方案。如果你非要共享，那就准备好处理所有的边界情况和竞争条件吧。"
