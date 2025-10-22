# Testing Infrastructure Analysis for claudecode.nvim

## Overview
The claudecode.nvim project uses a sophisticated testing infrastructure with **320+ tests** organized in three layers:
- Unit tests (`tests/unit/`)
- Component tests (`tests/component/`)
- Integration tests (`tests/integration/`)

All tests use **busted** framework with custom setup and mocking layers.

---

## 1. Test File Naming Conventions

### Patterns Used in Project

| Pattern | Location | Usage |
|---------|----------|-------|
| `*_spec.lua` | All directories | Standard busted test files (PREFERRED) |
| `*_test.lua` | `tests/` root only | Alternative pattern (lockfile_test.lua, selection_test.lua) |
| `*_spec.lua` | `tests/unit/tools/` | Tool-specific tests |
| `*_spec.lua` | `tests/unit/terminal/` | Terminal provider tests |
| `*_spec.lua` | `tests/unit/` | General unit tests (config, diff, commands) |

### Key Files to Update After Code Deletion

**Terminal-related tests that may need updates:**
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/terminal_spec.lua` - Main terminal wrapper tests
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/terminal/external_spec.lua` - External provider tests
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/terminal/none_provider_spec.lua` - None provider tests

**Command/Integration tests that reference terminal:**
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/claudecode_send_command_spec.lua`
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/claudecode_add_command_spec.lua`
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/focus_after_send_spec.lua`
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/diff_hide_terminal_new_tab_spec.lua`

**Config tests that validate terminal options:**
- `/Users/fanlz/Projects/doodleEsc/claudecode.nvim/tests/unit/config_spec.lua` (Lines 141-229)

---

## 2. Test Setup/Teardown Patterns

### Global Setup: `tests/busted_setup.lua` (Lines 1-350)

**Purpose:** Initialize test environment and provide helper functions
**Key Sections:**

1. **Vim Mock Initialization** (Lines 4-6):
```lua
if not _G.vim then
  _G.vim = require("tests.mocks.vim")
end
```

2. **Custom Expectation API** (Lines 15-64):
```lua
_G.expect = function(value)
  return {
    to_be = function(expected) ... end,
    to_be_nil = function() ... end,
    to_be_table = function() ... end,
    to_be_function = function() ... end,
    to_have_key = function(key) ... end,
    -- etc.
  }
end
```

3. **JSON Encoding/Decoding Helpers** (Lines 119-343):
```lua
_G.json_encode = function(data) ... end  -- Custom JSON encoder
_G.json_decode = function(str) ... end   -- Custom JSON decoder
```

4. **Container Assertion Helpers** (Lines 66-116):
```lua
_G.assert_contains = function(actual_value, expected_pattern) ... end
_G.assert_not_contains = function(actual_value, expected_pattern) ... end
```

### Per-Test Setup/Teardown Pattern

**Example from config_spec.lua (Lines 1-18):**
```lua
require("tests.busted_setup")  -- Load global setup

describe("Configuration", function()
  local config

  local function setup()
    package.loaded["claudecode.config"] = nil      -- Clear cache
    package.loaded["claudecode.terminal"] = nil    -- Clear dependencies
    config = require("claudecode.config")          -- Fresh require
  end

  local function teardown()
    -- Cleanup as needed
  end

  setup()  -- Called at describe() time
  -- ... test cases ...
  teardown()  -- Called after tests
end)
```

### Before/After Hooks Pattern

**Example from get_current_selection_spec.lua (Lines 7-45):**
```lua
before_each(function()
  -- Mock dependencies
  mock_selection_module = {
    get_latest_selection = spy.new(function() return nil end),
  }
  package.loaded["claudecode.selection"] = mock_selection_module
  
  -- Clear module cache
  package.loaded["claudecode.tools.get_current_selection"] = nil
  
  -- Require module under test
  get_current_selection_handler = require("claudecode.tools.get_current_selection").handler
  
  -- Setup vim mocks
  _G.vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
end)

after_each(function()
  -- Cleanup
  package.loaded["claudecode.selection"] = nil
  package.loaded["claudecode.tools.get_current_selection"] = nil
  _G.vim.api.nvim_get_current_buf = nil
end)
```

---

## 3. Mock Patterns for Removed Functionality

### Vim API Mocking (`tests/mocks/vim.lua`, 1028 lines)

**Critical Mock Components:**

#### 3.1 Mock State Management (Lines 62-75)
```lua
local vim = {
  _buffers = {},                    -- Maps bufnr -> {name, lines, options}
  _windows = { [1000] = {...} },   -- Maps winid -> {buf, width, cursor}
  _win_tab = { [1000] = 1 },       -- Maps winid -> tabpage
  _tab_windows = { [1] = {1000} }, -- Maps tabpage -> {winids}
  _next_winid = 1001,
  _commands = {},                   -- User commands registry
  _autocmds = {},                   -- Autocmds registry
  _vars = {},                       -- Global variables
  _options = {},                    -- Global options
  _current_window = 1000,
  _tabs = { [1] = true },
  _current_tabpage = 1,
}
```

#### 3.2 Handling Missing Module: Pattern for External Terminal (Lines 868-919)

When external terminal code is removed, mock it as a stub:
```lua
-- In tests/mocks/vim.lua or test-specific mock
package.loaded["claudecode.terminal.external"] = {
  setup = function() end,
  open = function(cmd, env) end,
  close = function() end,
  get_active_bufnr = function() return nil end,
  is_available = function() return false end,
}
```

#### 3.3 Spy Pattern for Terminal Removal Detection (external_spec.lua, Lines 50-62)

```lua
before_each(function()
  package.loaded["claudecode.terminal.external"] = nil
  package.loaded["claudecode.logger"] = {
    debug = spy.new(function() end),
    info = spy.new(function() end),
    warn = spy.new(function() end),
    error = spy.new(function() end),
  }
  
  external_provider = require("claudecode.terminal.external")
end)
```

#### 3.4 Mock Reset for Clean Test State (vim.lua, Lines 993-1006)

```lua
vim._mock = {
  reset = function()
    vim._buffers = {}
    vim._windows = {}
    vim._win_tab = {}
    vim._tab_windows = {}
    vim._next_winid = 1000
    vim._commands = {}
    vim._autocmds = {}
    vim._vars = {}
    vim._options = {}
    vim._last_command = nil
    vim._last_echo = nil
    vim._last_error = nil
  end,
}
```

### Pattern: Conditional Terminal Provider Setup (none_provider_spec.lua, Lines 42-49)

```lua
-- Clear multiple provider modules
package.loaded["claudecode.terminal"] = nil
package.loaded["claudecode.terminal.none"] = nil
package.loaded["claudecode.terminal.native"] = nil
package.loaded["claudecode.terminal.snacks"] = nil

terminal = require("claudecode.terminal")
terminal.setup({ provider = "none" }, nil, {})
```

### Pattern: Verify No-Op Implementation (none_provider_spec.lua, Lines 52-64)

After removing functionality, verify it's truly a no-op:
```lua
it("does not invoke any terminal APIs", function()
  terminal.open({}, "--help")
  terminal.simple_toggle({}, "--resume")
  terminal.focus_toggle({}, "--continue")
  terminal.ensure_visible({}, nil)
  terminal.toggle_open_no_focus({}, nil)
  terminal.close()

  assert.are.equal(0, termopen_calls)  -- Verify no calls made
  assert.are.equal(0, jobstart_calls)
end)
```

---

## 4. How Tests Handle Configuration Changes

### Configuration Validation Pattern (config_spec.lua)

#### 4.1 Module Cache Clearing (Lines 7-11)
```lua
local function setup()
  package.loaded["claudecode.config"] = nil      -- Clear config module
  package.loaded["claudecode.terminal"] = nil    -- Clear dependent modules
  config = require("claudecode.config")          -- Fresh require
end
```

#### 4.2 Configuration Merging Test (Lines 126-139)
```lua
it("should merge user config with defaults", function()
  local user_config = {
    auto_start = true,
    log_level = "debug",
  }

  local merged_config = config.apply(user_config)

  expect(merged_config.auto_start).to_be_true()
  expect(merged_config.log_level).to_be("debug")
  expect(merged_config.port_range.min).to_be(config.defaults.port_range.min)
  expect(merged_config.track_selection).to_be(config.defaults.track_selection)
end)
```

#### 4.3 External Terminal Configuration Test (config_spec.lua, Lines 194-229)

These tests validate terminal configuration - if removing internal terminal, update acceptance tests:
```lua
it("should accept string for external_terminal_cmd", function()
  local valid_config = {
    terminal = {
      provider = "external",
      provider_opts = {
        external_terminal_cmd = "alacritty -e %s",
      },
    },
  }
  local success, _ = pcall(function()
    config.validate(valid_config)
  end)
  expect(success).to_be_true()
end)
```

### Testing Validation Failures

When tests check invalid configurations, ensure they still validate properly:
```lua
it("should reject invalid keep_terminal_focus configuration", function()
  local invalid_config = {
    diff_opts = {
      keep_terminal_focus = "invalid", -- Should be boolean
    },
  }
  
  local success, _ = pcall(function()
    config.validate(invalid_config)
  end)
  
  expect(success).to_be_false()
end)
```

---

## 5. Examples of Tests Updated After Code Removal

### Historical Pattern: Terminal Provider Refactor

**From commit 5d7ab85 (feat: add support for custom terminal providers):**
- Files modified: `tests/unit/terminal_spec.lua` (+523 lines)
- Pattern: When refactoring terminal to support multiple providers, tests were split into provider-specific files:
  - Old: Single `tests/unit/terminal_spec.lua`
  - New: `tests/unit/terminal_spec.lua` + `tests/unit/terminal/external_spec.lua` + `tests/unit/terminal/none_provider_spec.lua`

### Historical Pattern: Native Terminal Improvements

**From commit e1def67 (feat: implement bufhidden=hide for native terminal toggle):**
- Updated tests to verify native terminal behavior stays valid
- Tests verify that removing/hiding buffers follows expected patterns

### Pattern: When Provider Removal is Needed

**From none_provider_spec.lua:**
Shows how to test "do nothing" provider - serves as template when removing terminal functionality:

```lua
it("does not invoke any terminal APIs", function()
  -- Call all public methods
  terminal.open({}, "--help")
  terminal.simple_toggle({}, "--resume")
  terminal.focus_toggle({}, "--continue")
  terminal.ensure_visible({}, nil)
  terminal.toggle_open_no_focus({}, nil)
  terminal.close()

  -- Verify NO calls were made
  assert.are.equal(0, termopen_calls)
  assert.are.equal(0, jobstart_calls)
end)
```

---

## 6. How Tests Mock Vim APIs

### Comprehensive Vim Mock (tests/mocks/vim.lua, ~1000 lines)

#### 6.1 Spy Functionality (Lines 3-60)

```lua
if _G.spy == nil then
  _G.spy = {
    on = function(table, method_name)
      local original = table[method_name]
      local calls = {}

      table[method_name] = function(...)
        table.insert(calls, { vals = { ... } })
        if original then
          return original(...)
        end
      end

      table[method_name].calls = calls
      table[method_name].spy = function()
        return {
          was_called = function(n) ... end,
          was_not_called = function() ... end,
          was_called_with = function(...) ... end,
        }
      end

      return table[method_name]
    end,
  }
end
```

#### 6.2 Buffer and Window Management (Lines 195-432)

Critical functions for testing terminal removal:
```lua
-- Buffer operations
nvim_create_buf = function(listed, scratch) ... end
nvim_buf_set_lines = function(bufnr, start, end_line, strict_indexing, replacement) ... end
nvim_buf_delete = function(bufnr, opts) ... end

-- Window operations
nvim_create_win = function(bufnr, enter, config) ... end  -- Not implemented, but structure present
nvim_win_close = function(winid, force)                   -- Handles bufhidden=wipe
nvim_win_set_buf = function(winid, bufnr) ... end
nvim_win_get_buf = function(winid) ... end

-- Tab management
nvim_get_current_tabpage = function() ... end
nvim_set_current_tabpage = function(tab) ... end
nvim_tabpage_is_valid = function(tab) ... end
```

#### 6.3 Autocmd Management (Lines 84-114)

Critical for testing plugin lifecycle:
```lua
nvim_create_augroup = function(name, opts)
  vim._autocmds[name] = { opts = opts, events = {} }
  return name
end

nvim_create_autocmd = function(events, opts)
  local group = opts.group or "default"
  if not vim._autocmds[group] then
    vim._autocmds[group] = { opts = {}, events = {} }
  end
  
  local id = #vim._autocmds[group].events + 1
  vim._autocmds[group].events[id] = {
    events = events,
    opts = opts,
  }
  
  return id
end

nvim_clear_autocmds = function(opts)
  if opts.group then
    vim._autocmds[opts.group] = nil
  end
end
```

#### 6.4 Command Execution (Lines 536-666)

Mock `vim.cmd()` for diff and terminal commands:
```lua
vim.cmd = function(command)
  vim._last_command = command
  
  if command == "tabnew" then
    -- Create new tab with buffer and window
    local new_tab = 1
    for k, _ in pairs(vim._tabs) do
      if k >= new_tab then
        new_tab = k + 1
      end
    end
    vim._tabs[new_tab] = true
    -- ... create buffer and window ...
  elseif command:match("vsplit") then
    -- Handle vertical split
  elseif command:match("[^%w]split$") or command == "split" then
    -- Handle horizontal split
  elseif command:match("^edit ") then
    -- Handle file editing
  elseif command:match("^tabclose") then
    -- Handle tab closing
  end
end
```

---

## 7. Test Coverage Requirements

### Makefile Test Commands (Lines 25-35)

```makefile
test:
	@echo "Running all tests..."
	@export LUA_PATH="./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;$$LUA_PATH"; \
	TEST_FILES=$$(find tests -type f -name "*_test.lua" -o -name "*_spec.lua" | sort); \
	echo "Found test files:"; \
	echo "$$TEST_FILES"; \
	if [ -n "$$TEST_FILES" ]; then \
		$(NIX_PREFIX) busted --coverage -v $$TEST_FILES; \
	else \
		echo "No test files found"; \
	fi
```

### Test Discovery Pattern

The Makefile auto-discovers tests matching:
- `*_test.lua` OR
- `*_spec.lua`

**When removing internal terminal code:**
1. Keep tests for other providers (external_spec.lua, none_provider_spec.lua)
2. Remove or stub test files like `tests/unit/terminal_snacks_spec.lua` if it exists
3. Ensure discovery finds all remaining test files

---

## 8. Integration Test Patterns That May Break

### MCP Tools Integration (tests/integration/mcp_tools_spec.lua)

**Pattern for module clearing at describe() time (Lines 5-29):**
```lua
describe("MCP Tools Integration", function()
  -- Clear module cache at the start
  package.loaded["claudecode.server.init"] = nil
  package.loaded["claudecode.tools.init"] = nil
  package.loaded["claudecode.diff"] = nil

  -- Mock selection module BEFORE loading other modules
  package.loaded["claudecode.selection"] = {
    get_latest_selection = function()
      return { ... }
    end,
  }

  -- Verify mocks are initialized
  assert(_G.vim, "Global vim mock not initialized by busted_setup.lua")
  assert(_G.vim.fn, "Global vim.fn mock not initialized")
  assert(_G.vim.api, "Global vim.api mock not initialized")

  -- Load modules with fresh state
  local server = require("claudecode.server.init")
  local tools = require("claudecode.tools.init")
```

**If removing internal terminal, also mock:**
```lua
package.loaded["claudecode.terminal"] = {
  setup = function() end,
  open = function() end,
  close = function() end,
  -- ... other methods ...
}
```

### Pattern: Teardown Restoration (mcp_tools_spec.lua, Lines 68-84)

```lua
local function teardown()
  -- Restore any original vim functions
  for path, func in pairs(original_vim_functions) do
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
      table.insert(parts, part)
    end
    local obj = _G.vim
    for i = 1, #parts - 1 do
      obj = obj[parts[i]]
    end
    obj[parts[#parts]] = func
  end
  original_vim_functions = {}
  -- Don't nil _G.vim, busted_setup manages it
end
```

---

## 9. Error Handling and Module Loading

### Pattern: Testing Require Failures (get_current_selection_spec.lua, Lines 124-143)

```lua
it("should handle pcall failure when requiring selection module", function()
  package.loaded["claudecode.selection"] = nil -- Ensure not cached
  local original_require = _G.require
  _G.require = function(mod_name)
    if mod_name == "claudecode.selection" then
      error("Simulated require failure for claudecode.selection")
    end
    return original_require(mod_name)
  end

  local success, err = pcall(get_current_selection_handler, {})
  _G.require = original_require -- Restore

  expect(success).to_be_false()
  expect(err).to_be_table()
  expect(err.code).to_be(-32000)  -- Internal server error code
  assert_contains(err.message, "Internal server error")
  assert_contains(err.data, "Failed to load selection module")
end)
```

### Pattern: Dependency Injection in Tests (init_spec.lua, Lines 91-170)

```lua
before_each(function()
  -- Override global mocks
  vim.api = {
    nvim_create_autocmd = SpyObject.new(function() end),
    nvim_create_augroup = SpyObject.new(function() return 1 end),
    nvim_create_user_command = SpyObject.new(function() end),
    nvim_echo = SpyObject.new(function() end),
  }

  vim.deepcopy = function(t) return t end

  vim.notify = spy.new(function() end)

  vim.fn = {
    getpid = function() return 123 end,
    expand = function() return "/mock/path" end,
    mode = function() return "n" end,
    -- ... more functions ...
  }
end)
```

---

## 10. Specific Patterns for Removing Internal Terminal

### Step 1: Identify Tests to Update

Search for all terminal references:
```bash
grep -r "terminal\|Terminal\|snacks\|native\|Snacks" tests/ --include="*.lua" -l
```

Tests likely to break or need updates:
- `tests/unit/terminal_spec.lua` - Main terminal wrapper
- `tests/unit/terminal/external_spec.lua` - External provider
- `tests/unit/terminal/none_provider_spec.lua` - None provider (might need deprecation)
- `tests/unit/config_spec.lua` - Terminal configuration validation
- `tests/unit/init_spec.lua` - Plugin initialization with terminal setup
- `tests/unit/claudecode_send_command_spec.lua` - Commands using terminal
- `tests/unit/focus_after_send_spec.lua` - Terminal focus behavior
- `tests/unit/diff_*.lua` - Tests that use terminal in diff scenarios

### Step 2: Mock Pattern for Missing Terminal Module

```lua
-- In any test that tries to require() terminal module:
before_each(function()
  package.loaded["claudecode.terminal"] = {
    setup = function(opts, server, config) end,
    open = function(env, args) end,
    close = function() end,
    simple_toggle = function(env, args) end,
    focus_toggle = function(env, args) end,
    ensure_visible = function() end,
    toggle_open_no_focus = function(env, args) end,
    get_active_terminal_bufnr = function() return nil end,
    send_to_terminal = function(text) end,
  }
  
  -- Clear dependent modules
  package.loaded["claudecode.init"] = nil
  package.loaded["claudecode.server.init"] = nil
end)
```

### Step 3: Update Tests to Handle Removed Snacks Provider

Before:
```lua
package.loaded["claudecode.terminal.snacks"] = require("claudecode.terminal.snacks")
```

After (if snacks removed):
```lua
package.loaded["claudecode.terminal.snacks"] = nil  -- Not available
package.loaded["claudecode.terminal"] = {
  setup = function() end,
  -- ... stub methods ...
}
```

### Step 4: Configuration Tests - Remove Terminal Options

Update `config_spec.lua` to remove tests for removed terminal features:

Before:
```lua
it("should accept snacks_win_opts configuration", function()
  local valid_config = { terminal = { provider = "snacks", snacks_win_opts = {...} } }
  -- ... test ...
end)
```

After: Delete this test entirely

### Step 5: Verify No-Op Tests Pass

Ensure terminal operations gracefully handle missing implementation:
```lua
it("terminal operations are no-ops when provider removed", function()
  local result = terminal.open({}, "claude --help")
  assert.is_nil(result)  -- Should not error, just return nil
  
  result = terminal.get_active_terminal_bufnr()
  assert.is_nil(result)
end)
```

---

## Summary of Key Patterns

| Pattern | File | Lines | Usage |
|---------|------|-------|-------|
| **Module Cache Clear** | All tests | Before `require()` | `package.loaded["module"] = nil` |
| **Mock Setup** | `*_spec.lua` | `before_each()` | Create spy objects, mock modules |
| **Vim API Mock** | `tests/mocks/vim.lua` | 1-1028 | Comprehensive API mock with state |
| **Spy Verification** | All tests | `after_each()` | `assert.spy(...).was_called(n)` |
| **JSON Helper** | `busted_setup.lua` | 119-343 | `json_encode()`, `json_decode()` |
| **Expect API** | `busted_setup.lua` | 15-64 | `expect(val).to_be_table()` |
| **Error Handling** | Tool tests | `pcall()` calls | Test errors with `-32000` code |
| **Configuration** | `config_spec.lua` | 1-304 | Validate config merging & validation |
| **Terminal Stub** | Removed code | N/A | Return `nil` or empty stub |

---

## Test Run Command

```bash
cd /Users/fanlz/Projects/doodleEsc/claudecode.nvim
export LUA_PATH="./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;$LUA_PATH"
make test
# Or individually:
busted tests/unit/terminal_spec.lua -v
busted tests/unit/config_spec.lua -v
busted tests/integration/mcp_tools_spec.lua -v
```

