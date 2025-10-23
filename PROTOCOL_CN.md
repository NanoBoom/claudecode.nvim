# Claude Code IDE 扩展的实际工作原理

本文档基于对 VS Code 扩展的逆向工程，解释了 Claude Code IDE 集成背后的协议和架构。使用本指南可以构建自己的集成或理解官方实现的工作原理。

## TL;DR

Claude Code 扩展在你的 IDE 中创建 WebSocket 服务器，Claude 连接到该服务器。它们使用 MCP (Model Context Protocol) 的 WebSocket 变体，这是 Claude 独有的。IDE 写入一个包含连接信息的锁文件，设置一些环境变量，Claude 启动时自动连接。

## 发现机制的工作原理

当你从 IDE 启动 Claude Code 时，发生以下过程：

### 1. IDE 创建 WebSocket 服务器

扩展启动一个监听来自 Claude 连接的 WebSocket 服务器，端口随机选择（10000-65535）。

### 2. 锁文件创建

IDE 将发现文件写入 `~/.claude/ide/[port].lock`：

```json
{
  "pid": 12345, // IDE 进程 ID
  "workspaceFolders": ["/path/to/project"], // 打开的文件夹
  "ideName": "VS Code", // 或 "Neovim"、"IntelliJ" 等
  "transport": "ws", // WebSocket 传输
  "authToken": "550e8400-e29b-41d4-a716-446655440000" // 随机 UUID 用于认证
}
```

### 3. 环境变量

启动 Claude 时，IDE 设置：

- `CLAUDE_CODE_SSE_PORT`: WebSocket 服务器端口
- `ENABLE_IDE_INTEGRATION`: 设置为 "true"

### 4. Claude 连接

Claude 读取锁文件，从环境变量中找到匹配的端口，然后连接到 WebSocket 服务器。

## 认证

当 Claude 连接到 IDE 的 WebSocket 服务器时，必须使用锁文件中的令牌进行认证。认证通过自定义 WebSocket 头部进行：

```
x-claude-code-ide-authorization: 550e8400-e29b-41d4-a716-446655440000
```

IDE 根据锁文件中的 `authToken` 值验证此头部。如果令牌不匹配，连接被拒绝。

## 协议

通信使用 WebSocket 和 JSON-RPC 2.0 消息：

```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": {
    /* 参数 */
  },
  "id": "unique-id" // 用于期望响应的请求
}
```

该协议基于 MCP (Model Context Protocol) 规范 2025-03-26，但使用 WebSocket 传输而不是 stdio/HTTP。

## 关键消息类型

### 从 IDE 到 Claude

这些是 IDE 发送的通知，用于保持 Claude 的信息同步：

#### 1. 选择更新

当用户的选择发生变化时发送：

```json
{
  "jsonrpc": "2.0",
  "method": "selection_changed",
  "params": {
    "text": "选中的文本内容",
    "filePath": "/absolute/path/to/file.js",
    "fileUrl": "file:///absolute/path/to/file.js",
    "selection": {
      "start": { "line": 10, "character": 5 },
      "end": { "line": 15, "character": 20 },
      "isEmpty": false
    }
  }
}
```

#### 2. At-提及

当用户显式地将选择作为上下文发送时：

```json
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file",
    "lineStart": 10,
    "lineEnd": 20
  }
}
```

### 从 Claude 到 IDE

根据 MCP 规范，Claude 应该能够调用工具，但**当前的实现主要是单向的**（IDE → Claude）。

#### 工具调用（未来）

```json
{
  "jsonrpc": "2.0",
  "id": "request-123",
  "method": "tools/call",
  "params": {
    "name": "openFile",
    "arguments": {
      "filePath": "/path/to/file.js"
    }
  }
}
```

#### 工具响应

```json
{
  "jsonrpc": "2.0",
  "id": "request-123",
  "result": {
    "content": [{ "type": "text", "text": "文件成功打开" }]
  }
}
```

## 可用的 MCP 工具

VS Code 扩展注册了 12 个 Claude 可以调用的工具。完整规范如下：

### 1. openFile

**描述**：在编辑器中打开文件并可选择性地选择一段文本

**输入**：

```json
{
  "filePath": "/path/to/file.js",
  "preview": false,
  "startText": "function hello",
  "endText": "}",
  "selectToEndOfLine": false,
  "makeFrontmost": true
}
```

- `filePath` (string, 必需): 要打开的文件路径
- `preview` (boolean, 默认: false): 是否以预览模式打开
- `startText` (string, 可选): 查找选择起始位置的文本模式
- `endText` (string, 可选): 查找选择结束位置的文本模式
- `selectToEndOfLine` (boolean, 默认: false): 将选择扩展到行尾
- `makeFrontmost` (boolean, 默认: true): 使文件成为活动编辑器标签

**输出**：当 `makeFrontmost=true` 时，返回简单消息：

```json
{
  "content": [
    {
      "type": "text",
      "text": "Opened file: /path/to/file.js"
    }
  ]
}
```

当 `makeFrontmost=false` 时，返回详细 JSON：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": true, \"filePath\": \"/absolute/path/to/file.js\", \"languageId\": \"javascript\", \"lineCount\": 42}"
    }
  ]
}
```

### 2. openDiff

**描述**：为文件打开 git diff（阻塞操作）

**输入**：

```json
{
  "old_file_path": "/path/to/original.js",
  "new_file_path": "/path/to/modified.js",
  "new_file_contents": "// 修改后的内容...",
  "tab_name": "建议的更改"
}
```

- `old_file_path` (string): 原始文件路径
- `new_file_path` (string): 新文件路径
- `new_file_contents` (string): 新文件的内容
- `tab_name` (string): diff 视图的标签名称

**输出**：返回 MCP 格式的响应：

```json
{
  "content": [
    {
      "type": "text",
      "text": "FILE_SAVED"
    }
  ]
}
```

或

```json
{
  "content": [
    {
      "type": "text",
      "text": "DIFF_REJECTED"
    }
  ]
}
```

取决于用户是保存还是拒绝 diff。

### 3. getCurrentSelection

**描述**：获取活动编辑器中的当前文本选择

**输入**：无

**输出**：返回 JSON 字符串化的选择数据：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": true, \"text\": \"选中的内容\", \"filePath\": \"/path/to/file\", \"selection\": {\"start\": {\"line\": 0, \"character\": 0}, \"end\": {\"line\": 0, \"character\": 10}}}"
    }
  ]
}
```

或当没有活动编辑器时：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": false, \"message\": \"未找到活动编辑器\"}"
    }
  ]
}
```

### 4. getLatestSelection

**描述**：获取最近的文本选择（即使不在活动编辑器中）

**输入**：无

**输出**：JSON 字符串化的选择数据或 `{success: false, message: "无可用选择"}`

### 5. getOpenEditors

**描述**：获取当前打开的编辑器的信息

**输入**：无

**输出**：返回 JSON 字符串化的打开标签数组：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"tabs\": [{\"uri\": \"file:///path/to/file\", \"isActive\": true, \"label\": \"filename.ext\", \"languageId\": \"javascript\", \"isDirty\": false}]}"
    }
  ]
}
```

### 6. getWorkspaceFolders

**描述**：获取 IDE 中当前打开的所有工作区文件夹

**输入**：无

**输出**：返回 JSON 字符串化的工作区信息：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": true, \"folders\": [{\"name\": \"project-name\", \"uri\": \"file:///path/to/workspace\", \"path\": \"/path/to/workspace\"}], \"rootPath\": \"/path/to/workspace\"}"
    }
  ]
}
```

### 7. getDiagnostics

**描述**：从 VS Code 获取语言诊断信息

**输入**：

```json
{
  "uri": "file:///path/to/file.js"
}
```

- `uri` (string, 可选): 要获取诊断信息的文件 URI。如果未提供，则获取所有文件的诊断信息。

**输出**：返回 JSON 字符串化的每个文件的诊断数组：

```json
{
  "content": [
    {
      "type": "text",
      "text": "[{\"uri\": \"file:///path/to/file\", \"diagnostics\": [{\"message\": \"错误消息\", \"severity\": \"Error\", \"range\": {\"start\": {\"line\": 0, \"character\": 0}}, \"source\": \"typescript\"}]}]"
    }
  ]
}
```

### 8. checkDocumentDirty

**描述**：检查文档是否有未保存的更改（是否为脏状态）

**输入**：

```json
{
  "filePath": "/path/to/file.js"
}
```

- `filePath` (string, 必需): 要检查的文件路径

**输出**：返回文档脏状态：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": true, \"filePath\": \"/path/to/file.js\", \"isDirty\": true, \"isUntitled\": false}"
    }
  ]
}
```

或当文档未打开时：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": false, \"message\": \"文档未打开: /path/to/file.js\"}"
    }
  ]
}
```

### 9. saveDocument

**描述**：保存有未保存更改的文档

**输入**：

```json
{
  "filePath": "/path/to/file.js"
}
```

- `filePath` (string, 必需): 要保存的文件路径

**输出**：返回保存操作结果：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": true, \"filePath\": \"/path/to/file.js\", \"saved\": true, \"message\": \"文档保存成功\"}"
    }
  ]
}
```

或当文档未打开时：

```json
{
  "content": [
    {
      "type": "text",
      "text": "{\"success\": false, \"message\": \"文档未打开: /path/to/file.js\"}"
    }
  ]
}
```

### 10. close_tab

**描述**：按名称关闭标签

**输入**：

```json
{
  "tab_name": "filename.js"
}
```

- `tab_name` (string, 必需): 要关闭的标签名称

**输出**：返回 `{content: [{type: "text", text: "TAB_CLOSED"}]}`

### 11. closeAllDiffTabs

**描述**：关闭编辑器中的所有 diff 标签

**输入**：无

**输出**：返回 `{content: [{type: "text", text: "CLOSED_${count}_DIFF_TABS"}]}`

### 12. executeCode

**描述**：在当前笔记本文件的 Jupyter 内核中执行 Python 代码

**输入**：

```json
{
  "code": "print('Hello, World!')"
}
```

- `code` (string, 必需): 要在内核上执行的代码

**输出**：返回混合内容类型的执行结果：

```json
{
  "content": [
    {
      "type": "text",
      "text": "Hello, World!"
    },
    {
      "type": "image",
      "data": "base64_encoded_image_data",
      "mimeType": "image/png"
    }
  ]
}
```

**注意事项**：

- 所有执行的代码将在调用之间持久化，除非重启内核
- 除非明确要求，否则避免声明变量或修改内核状态
- 仅在使用 Jupyter 笔记本时可用
- 可以返回多种内容类型，包括文本输出和图像

### 实现注意事项

- 大多数工具遵循驼峰命名法，除了 `close_tab`（使用蛇形命名法）
- `openDiff` 工具是**阻塞的**，会等待用户交互
- 工具返回带有内容数组的 MCP 格式响应
- 所有模式在 VS Code 扩展中使用 Zod 验证
- 选择相关的工具使用当前编辑器状态

## 构建你自己的集成

最小可行实现如下：

### 1. 创建 WebSocket 服务器

```lua
-- 仅监听 localhost（重要！）
local server = create_websocket_server("127.0.0.1", random_port)
```

### 2. 写入锁文件

```lua
-- ~/.claude/ide/[port].lock
local auth_token = generate_uuid() -- 生成随机 UUID
local lock_data = {
  pid = vim.fn.getpid(),
  workspaceFolders = { vim.fn.getcwd() },
  ideName = "YourEditor",
  transport = "ws",
  authToken = auth_token
}
write_json(lock_path, lock_data)
```

### 3. 设置环境变量

```bash
export CLAUDE_CODE_SSE_PORT=12345
export ENABLE_IDE_INTEGRATION=true
claude  # Claude 现在会连接！
```

### 4. 处理消息

```lua
-- 在 WebSocket 握手时验证认证
function validate_auth(headers)
  local auth_header = headers["x-claude-code-ide-authorization"]
  return auth_header == auth_token
end

-- 发送选择更新
send_message({
  jsonrpc = "2.0",
  method = "selection_changed",
  params = { ... }
})

-- 实现工具（如果需要）
register_tool("openFile", function(params)
  -- 打开文件逻辑
  return { content = {{ type = "text", text = "完成" }} }
end)
```

## 安全考虑

**始终仅绑定到 localhost (`127.0.0.1`)！** 这确保 WebSocket 服务器不会暴露到网络。

## 下一步？

有了这些协议知识，你可以：

- 为任何编辑器构建集成
- 创建连接到现有 IDE 扩展的代理
- 使用自定义工具扩展协议
- 在不同的 AI 助手和 IDE 之间构建桥梁

WebSocket MCP 变体目前是 Claude 特有的，但这些概念可以适配到其他 AI 编码助手。

## 资源

- [MCP 规范](https://spec.modelcontextprotocol.io)
- [Claude Code Neovim 实现](https://github.com/coder/claudecode.nvim)
- [官方 VS Code 扩展](https://github.com/anthropic-labs/vscode-mcp)（压缩源代码）
