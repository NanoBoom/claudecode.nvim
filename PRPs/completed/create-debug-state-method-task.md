# TASK PRP: Create Debug Method for M.state and M.state.server

## Context

### Architecture Analysis
- **M.state** (`lua/claudecode/init.lua:30-39`): Main plugin state containing:
  - `config`: Plugin configuration
  - `server`: Server module reference (from `claudecode.server.init`)
  - `port`: WebSocket port number
  - `auth_token`: Authentication token
  - `initialized`: Plugin initialization status
  - `mention_queue`: Queue for @mentions
  - `mention_timer`: Timer for mention processing
  - `connection_timer`: Connection timeout timer

- **M.state.server** (`lua/claudecode/server/init.lua:18-25`): Server module state containing:
  - `server`: TCP server instance
  - `port`: Server port
  - `auth_token`: Server auth token
  - `clients`: Connected WebSocket clients
  - `handlers`: Message handlers
  - `ping_timer`: Ping timer for connection keepalive

### Existing Patterns
- **Logging**: Uses `claudecode.logger` module with levels (ERROR, WARN, INFO, DEBUG, TRACE)
- **Status Command**: `ClaudeCodeStatus` shows basic running status
- **Debug Output**: Uses `vim.inspect` for table inspection
- **Command Structure**: User commands defined in `M._create_commands()`

## Task Breakdown

### 1. CREATE debug state function in main module
**FILE**: `lua/claudecode/init.lua`
- **OPERATION**: Add `M._debug_state()` function that returns formatted state information
- **VALIDATE**: Function exists and returns table with proper structure
- **IF_FAIL**: Check function syntax and return value format
- **ROLLBACK**: Remove function definition

### 2. CREATE debug state function in server module
**FILE**: `lua/claudecode/server/init.lua`
- **OPERATION**: Add `M._debug_state()` function that returns server-specific state
- **VALIDATE**: Function exists and returns server state information
- **IF_FAIL**: Check server module structure and function placement
- **ROLLBACK**: Remove function definition

### 3. CREATE user command for debug display
**FILE**: `lua/claudecode/init.lua` (in `M._create_commands()`)
- **OPERATION**: Add `ClaudeCodeDebugState` command that calls debug functions
- **VALIDATE**: Command is registered and accessible via `:ClaudeCodeDebugState`
- **IF_FAIL**: Check command registration syntax and function references
- **ROLLBACK**: Remove command registration

### 4. IMPLEMENT debug output formatting
**FILE**: `lua/claudecode/init.lua`
- **OPERATION**: Format debug output using `vim.inspect` and logger
- **VALIDATE**: Output is readable and shows all state fields
- **IF_FAIL**: Check `vim.inspect` usage and logger integration
- **ROLLBACK**: Revert to simple table return

### 5. TEST debug functionality
**OPERATION**: Test command execution and output
- **VALIDATE**: `:ClaudeCodeDebugState` shows comprehensive state information
- **IF_FAIL**: Check command execution and debug function calls
- **ROLLBACK**: Disable debug command temporarily

## Implementation Details

### Debug Function Structure
```lua
function M._debug_state()
  return {
    plugin = {
      initialized = M.state.initialized,
      port = M.state.port,
      auth_token = M.state.auth_token and "[REDACTED]" or nil,
      mention_queue_size = #(M.state.mention_queue or {}),
      config = M.state.config and {
        auto_start = M.state.config.auto_start,
        track_selection = M.state.config.track_selection,
        log_level = M.state.config.log_level,
      } or nil
    },
    server = M.state.server and M.state.server._debug_state and M.state.server._debug_state() or "Not running",
    connection_status = M.is_claude_connected() and "Connected" or "Disconnected"
  }
end
```

### Server Debug Function
```lua
function M._debug_state()
  return {
    running = M.state.server ~= nil,
    port = M.state.port,
    client_count = #M.state.clients,
    auth_enabled = M.state.auth_token ~= nil,
    handlers_registered = #vim.tbl_keys(M.state.handlers or {})
  }
end
```

### Command Implementation
```lua
vim.api.nvim_create_user_command("ClaudeCodeDebugState", function()
  local debug_info = M._debug_state()
  logger.info("debug", "Claude Code Debug State:")
  logger.info("debug", vim.inspect(debug_info))
end, {
  desc = "Show detailed Claude Code debug state information",
})
```

## Quality Gates

- [ ] **KISS**: Each task changes one specific component
- [ ] **Ockham's Razor**: No unnecessary debug features added
- [ ] **YAGNI**: Only implements requested debug functionality
- [ ] **DRY**: Reuses existing patterns (logger, vim.inspect)
- [ ] **SRP**: Each task has single responsibility

## Success Criteria

- `:ClaudeCodeDebugState` command available and functional
- Shows comprehensive state information for both main and server modules
- Output is readable and properly formatted
- No impact on existing functionality
- Follows existing codebase patterns

## Risk Assessment

- **Low Risk**: Debug functions are isolated and don't affect core functionality
- **Rollback Strategy**: Remove debug functions and command if issues arise
- **Performance Impact**: Minimal - debug functions only called on demand
- **Security**: Auth tokens are redacted in debug output