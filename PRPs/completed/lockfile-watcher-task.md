# TASK PRP: Lockfile Watcher with Auto-Restart

## Context

### Problem Statement
When Claude Code CLI exits (crash/normal exit), the lockfile is removed but the Neovim plugin doesn't automatically reconnect. Users must manually call `:ClaudeCodeRestart`.

### Solution Overview
Add a periodic timer that checks lockfile existence. If missing, automatically call `M.restart()` to reconnect.

### Design Principles Applied
- **KISS**: Simple file check + callback
- **Ockham's Razor**: No unnecessary intermediate steps
- **YAGNI**: Only what's needed for auto-reconnect
- **DRY**: Reuse existing `M.restart()` method
- **SRP**: Each task changes ONE thing

### Key Files
- `lua/claudecode/init.lua`: Main plugin logic (M.start/stop/restart)
- `lua/claudecode/lockfile.lua`: Lockfile utilities
- `lua/claudecode/config.lua`: Configuration defaults

### Existing Patterns
```lua
-- Pattern: Timer lifecycle (from mention_timer in init.lua:79-84)
-- NOTE: Existing code uses vim.loop, but NEW code should use vim.uv
-- vim.loop and vim.uv are aliases in current Neovim (vim.loop == vim.uv)
-- We use vim.uv for new code per latest Neovim documentation
if M.state.timer then
  M.state.timer:stop()
  M.state.timer:close()
  M.state.timer = nil
end

-- Pattern: File existence check (from lockfile.lua:166)
if vim.fn.filereadable(lock_path) == 0 then
  -- file does not exist
end

-- Pattern: Restart method (init.lua:463-491)
function M.restart(show_notification)
  -- existing logic
end
```

### Critical Constraints
1. **Prevent restart loop**: Timer must be stopped BEFORE calling restart()
2. **Only check when running**: Timer should only exist when server is active
3. **Idempotent restart**: M.restart() is already safe to call multiple times
4. **Resource cleanup**: Timer must be cleaned up in stop()
5. **API safety**: Timer callbacks must use vim.schedule() for vim.api calls (vim.uv constraint)

### Configuration
```lua
-- Add to config.lua defaults
{
  lockfile_check_interval = 5000,  -- 5 seconds (in milliseconds)
}
```

---

## Tasks

### TASK 1: Add lockfile watcher timer to state
**File**: `lua/claudecode/init.lua`

**Changes**:
```lua
-- Line ~30: Add to M.state
M.state = {
  config = require("claudecode.config").defaults,
  server = nil,
  port = nil,
  auth_token = nil,
  initialized = false,
  mention_queue = {},
  mention_timer = nil,
  connection_timer = nil,
  lockfile_watcher_timer = nil,  -- ADD THIS LINE
}
```

**Validation**:
- [ ] `lua -l lua/claudecode/init -e "print('syntax ok')"` passes
- [ ] No existing code references this field

**If Fail**: Check for typos in field name

**Rollback**: Remove the added line

---

### TASK 2: Add config option for check interval
**File**: `lua/claudecode/config.lua`

**Changes**:
```lua
-- Add to M.defaults (near connection_timeout line)
M.defaults = {
  -- ... existing fields ...
  connection_timeout = 30000,
  lockfile_check_interval = 5000,  -- ADD THIS LINE (5 seconds)
  -- ... rest of config ...
}

-- Add to M.schema validation
M.schema = {
  -- ... existing fields ...
  lockfile_check_interval = function(value)
    if type(value) ~= "number" then
      return false, "lockfile_check_interval must be a number"
    end
    if value < 1000 or value > 60000 then
      return false, "lockfile_check_interval must be between 1000 and 60000 (1-60 seconds)"
    end
    return true
  end,
}
```

**Validation**:
- [ ] `lua -l lua/claudecode/config -e "print('syntax ok')"` passes
- [ ] Config schema validation works

**If Fail**: Check schema syntax

**Rollback**: Remove added lines

---

### TASK 3: Implement lockfile check function
**File**: `lua/claudecode/init.lua`

**Location**: After `clear_mention_queue()` function (~line 84)

**Add Function**:
```lua
---Check if lockfile exists and restart if missing
---@private
local function check_lockfile_and_restart()
  -- Safety check: Only proceed if server is supposed to be running
  if not M.state.server or not M.state.port then
    logger.debug("watcher", "Lockfile watcher triggered but server not running, stopping watcher")
    stop_lockfile_watcher() -- Will be defined in TASK 4
    return
  end

  local lockfile = require("claudecode.lockfile")
  local lock_path = lockfile.lock_dir .. "/" .. M.state.port .. ".lock"

  -- Check if lockfile exists
  if vim.fn.filereadable(lock_path) == 0 then
    logger.warn("watcher", "Lockfile missing, attempting restart: " .. lock_path)

    -- Stop watcher FIRST to prevent restart loop
    stop_lockfile_watcher() -- Will be defined in TASK 4

    -- Schedule restart on main thread
    -- NOTE: Using vim.schedule instead of vim.schedule_wrap for clarity
    vim.schedule(function()
      M.restart(true) -- show_notification = true
    end)
  end
end
```

**Validation**:
- [ ] Function compiles without syntax errors
- [ ] Uses existing patterns (filereadable, vim.schedule)

**If Fail**: Check function syntax, ensure lockfile module exists

**Rollback**: Remove the added function

---

### TASK 4: Implement start/stop watcher functions
**File**: `lua/claudecode/init.lua`

**Location**: After `check_lockfile_and_restart()` function

**Add Functions**:
```lua
---Start the lockfile watcher timer
---@private
local function start_lockfile_watcher()
  -- Only start if not already running
  if M.state.lockfile_watcher_timer then
    logger.debug("watcher", "Lockfile watcher already running")
    return
  end

  if not M.state.port then
    logger.error("watcher", "Cannot start lockfile watcher: no port configured")
    return
  end

  local interval = M.state.config.lockfile_check_interval or 5000

  -- Use vim.uv (new standard) instead of vim.loop (legacy alias)
  -- Both are identical (vim.loop == vim.uv), but vim.uv is the documented API
  M.state.lockfile_watcher_timer = vim.uv.new_timer()

  -- Timer callbacks cannot directly call vim.api functions
  -- Must wrap with vim.schedule per vim.uv documentation
  M.state.lockfile_watcher_timer:start(
    interval,  -- initial delay
    interval,  -- repeat interval
    function()
      vim.schedule(function()
        check_lockfile_and_restart()
      end)
    end
  )

  logger.debug("watcher", "Lockfile watcher started (interval: " .. interval .. "ms)")
end

---Stop the lockfile watcher timer
---@private
local function stop_lockfile_watcher()
  if M.state.lockfile_watcher_timer then
    M.state.lockfile_watcher_timer:stop()
    M.state.lockfile_watcher_timer:close()
    M.state.lockfile_watcher_timer = nil
    logger.debug("watcher", "Lockfile watcher stopped")
  end
end
```

**Validation**:
- [ ] Functions follow existing timer patterns (mention_timer, connection_timer)
- [ ] Proper lifecycle: new_timer → start → stop → close → nil

**If Fail**: Check timer API usage

**Rollback**: Remove the added functions

---

### TASK 5: Integrate watcher into M.start()
**File**: `lua/claudecode/init.lua`

**Location**: In `M.start()` function, after lockfile creation (~line 410)

**Add**:
```lua
function M.start(show_startup_notification)
  -- ... existing code ...

  if show_startup_notification then
    logger.info("init", "Claude Code integration started on port " .. tostring(M.state.port))
  end

  -- ADD THIS: Start lockfile watcher
  start_lockfile_watcher()

  return true, M.state.port
end
```

**Validation**:
- [ ] Manual test: `:ClaudeCodeStart` succeeds
- [ ] Timer is created: `lua print(vim.inspect(require('claudecode').state.lockfile_watcher_timer))`

**If Fail**: Check function is called after M.state.port is set

**Rollback**: Remove the added line

---

### TASK 6: Integrate watcher cleanup into M.stop()
**File**: `lua/claudecode/init.lua`

**Location**: In `M.stop()` function, before clearing state (~line 450)

**Add**:
```lua
function M.stop()
  if not M.state.server then
    logger.warn("init", "Claude Code integration is not running")
    return false, "Not running"
  end

  -- ADD THIS: Stop lockfile watcher
  stop_lockfile_watcher()

  local lockfile = require("claudecode.lockfile")
  -- ... rest of existing code ...
```

**Validation**:
- [ ] Manual test: `:ClaudeCodeStop` succeeds
- [ ] Timer is nil: `lua print(require('claudecode').state.lockfile_watcher_timer)`

**If Fail**: Check function exists

**Rollback**: Remove the added line

---

### TASK 7: Fix restart() to properly handle watcher lifecycle
**File**: `lua/claudecode/init.lua`

**Location**: `M.restart()` function (~line 463)

**Analysis**: Current restart() calls M.stop() then M.start(). This should already handle the watcher lifecycle correctly:
- M.stop() will call stop_lockfile_watcher()
- M.start() will call start_lockfile_watcher()

**Validation**:
- [ ] Review restart() logic: confirms it calls stop() then start()
- [ ] Manual test: `:ClaudeCodeRestart` succeeds
- [ ] Timer restarts correctly

**No code changes needed** - restart() already has correct lifecycle

**If Fail**: If timer doesn't restart, check that start() is being called

---

### TASK 8: Add test for lockfile watcher
**File**: `tests/unit/lockfile_watcher_spec.lua` (NEW FILE)

**Create Test**:
```lua
describe("lockfile watcher", function()
  local claudecode
  local lockfile

  before_each(function()
    -- Setup test environment
    claudecode = require("claudecode")
    lockfile = require("claudecode.lockfile")

    -- Reset state
    if claudecode.state.server then
      claudecode.stop()
    end
  end)

  after_each(function()
    if claudecode.state.server then
      claudecode.stop()
    end
  end)

  it("should start watcher when server starts", function()
    claudecode.setup({ auto_start = false, lockfile_check_interval = 1000 })
    claudecode.start(false)

    -- Check timer exists
    assert.is_not_nil(claudecode.state.lockfile_watcher_timer)

    claudecode.stop()
  end)

  it("should stop watcher when server stops", function()
    claudecode.setup({ auto_start = false, lockfile_check_interval = 1000 })
    claudecode.start(false)
    claudecode.stop()

    -- Check timer is cleaned up
    assert.is_nil(claudecode.state.lockfile_watcher_timer)
  end)

  it("should restart watcher on restart", function()
    claudecode.setup({ auto_start = false, lockfile_check_interval = 1000 })
    claudecode.start(false)

    local first_timer = claudecode.state.lockfile_watcher_timer

    claudecode.restart(false)

    -- Give restart time to complete (it uses vim.defer_fn)
    vim.wait(200)

    local second_timer = claudecode.state.lockfile_watcher_timer
    assert.is_not_nil(second_timer)
    -- Timer should be a new instance after restart
  end)
end)
```

**Validation**:
- [ ] Run test: `make test TEST=tests/unit/lockfile_watcher_spec.lua`
- [ ] All tests pass

**If Fail**: Check test setup, ensure vim.loop is available in test env

**Rollback**: Delete test file

---

## Integration Test Plan

### Manual Test Scenario
1. Start Neovim with plugin loaded
2. Run `:ClaudeCodeStart`
3. Verify timer started: `:lua print(vim.inspect(require('claudecode').state.lockfile_watcher_timer))`
4. Manually delete lockfile: `rm ~/.claude/ide/<port>.lock`
5. Wait 5-10 seconds
6. Verify restart triggered (check logs or run `:ClaudeCodeStatus`)
7. Verify new lockfile created

### Expected Behavior
- Timer runs every 5 seconds (configurable)
- When lockfile missing → logs warning → calls restart()
- Restart creates new server + lockfile
- No infinite restart loop

### Rollback Strategy
If integration fails:
1. Set `lockfile_check_interval = 999999` in config (effectively disable)
2. Or revert all changes using git

---

## Completion Checklist

### Design Principle Compliance
- [x] KISS: Simple file check + callback (3 concepts)
- [x] Ockham's Razor: No unnecessary steps
- [x] YAGNI: Only for current auto-reconnect need
- [x] DRY: Reuses M.restart(), existing timer patterns
- [x] SRP: Each task changes ONE thing

### Task Completeness
- [x] All changes identified and scoped
- [x] Dependencies mapped (config → state → functions → integration)
- [x] Each task has specific validation
- [x] Rollback steps included
- [x] Debug strategies provided
- [x] Performance impact: minimal (5s interval)
- [x] Security: none (uses existing lockfile)
- [x] No missing edge cases

### Red Flags Check
- [x] No bundled unrelated changes
- [x] No "preparatory" tasks for hypothetical needs
- [x] Tasks are simple (largest is ~30 lines)
- [x] No scope creep

---

## Risk Assessment

### Known Risks
1. **Restart Loop** (HIGH) - Mitigated by stopping timer before restart
2. **Timer leak** (MEDIUM) - Mitigated by proper cleanup in stop()
3. **Race condition** (LOW) - vim.schedule ensures main thread safety

### Success Criteria
- [ ] Plugin starts and creates timer
- [ ] Timer checks lockfile every 5 seconds
- [ ] Manual lockfile deletion triggers restart within 10 seconds
- [ ] No restart loop observed
- [ ] stop/restart properly cleanup and recreate timer