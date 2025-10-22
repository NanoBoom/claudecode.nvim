# PRP: Remove Internal Terminal Integration from claudecode.nvim

**Status:** Ready for Implementation
**Created:** 2025-10-21
**Confidence Score:** 9/10 for one-pass implementation success

---

## Goal

**Feature Goal**: Eliminate all internal Neovim terminal management code from claudecode.nvim, transitioning to an external-terminal-only architecture where users run Claude CLI in their preferred terminal application.

**Deliverable**: A simplified plugin that:
- Manages only WebSocket server and MCP tool communication
- Supports diff functionality within Neovim
- Launches Claude Code only via external terminal applications
- Removes ~1,675 LOC of terminal UI management complexity

**Success Definition**:
- ✅ All internal terminal providers deleted (snacks, native, none)
- ✅ Plugin launches Claude CLI only via external terminal command
- ✅ WebSocket server runs independently of terminal
- ✅ Diff functionality works without terminal window management
- ✅ All tests pass with <5 failing tests allowed during transition
- ✅ Configuration simplified to single `external_terminal_cmd` requirement
- ✅ Zero linting errors: `make check` passes
- ✅ Zero formatting issues: `make format` passes

---

## Why

**Business Value:**
- **Reduced Complexity**: Remove 1,675 LOC (approximately 30% of plugin codebase)
- **Better User Experience**: Users control their own terminal workflow (tmux, terminal multiplexers, external apps)
- **Maintainability**: No more terminal UI edge cases, focus management, split sizing logic
- **Performance**: Faster plugin load (no provider detection), reduced memory usage (no buffer tracking)

**Integration with Existing Features:**
- WebSocket server continues serving all clients
- Diff functionality remains fully functional
- @ mention queue system preserved
- Selection tracking unchanged
- All MCP tools work identically

**Problems This Solves:**
- **For Users**: No need to configure complex terminal UI options; use their existing terminal setup
- **For Maintainers**: Dramatically reduced surface area for bugs; simpler testing; clearer architecture
- **For External Terminal Users**: No longer carrying dead weight of internal terminal code

---

## What

**User-Visible Behavior:**

**BEFORE (Internal Terminal)**:
```vim
:ClaudeCodeStart
" → Starts server + shows Claude in Neovim split

:ClaudeCodeToggle
" → Shows/hides internal terminal window

" Select code + :ClaudeCodeSend
" → Focuses internal terminal
```

**AFTER (External Terminal)**:
```bash
# Terminal 1: Start server in Neovim
:ClaudeCodeStart
# → Starts WebSocket server only

# Terminal 2: Start Claude manually
$ claude

# Terminal 1: Send @ mentions
# Select code + :ClaudeCodeSend
# → Sends to external Claude via WebSocket
```

**Technical Requirements:**

1. **Delete Files**:
   - `lua/claudecode/terminal/snacks.lua` (277 LOC)
   - `lua/claudecode/terminal/native.lua` (440 LOC)
   - `lua/claudecode/terminal/none.lua` (75 LOC)
   - `lua/claudecode/terminal.lua` (573 LOC → simplified to ~50 LOC stub)
   - `lua/claudecode/cwd.lua` (only used by terminal)
   - `tests/unit/terminal_spec.lua` (1,224 LOC)
   - `tests/unit/terminal/none_provider_spec.lua` (70 LOC)
   - `tests/unit/focus_after_send_spec.lua` (130 LOC)
   - `tests/unit/native_terminal_toggle_spec.lua` (532 LOC)

2. **Modify Files**:
   - `lua/claudecode/init.lua` - Remove terminal integration (~50 LOC removal)
   - `lua/claudecode/diff.lua` - Remove terminal UI dependencies (~200 LOC removal)
   - `lua/claudecode/config.lua` - Simplify terminal config (~100 LOC removal)
   - `lua/claudecode/selection.lua` - Remove terminal buffer checking (~10 LOC removal)
   - 6 test files - Update terminal mocks and assertions

3. **Configuration Changes**:
   - **REMOVE**: `focus_after_send`, `terminal.*`, `diff_opts.keep_terminal_focus`, `diff_opts.hide_terminal_in_new_tab`
   - **ADD**: `external_terminal_cmd` (required)
   - **KEEP**: All server, diff, and MCP tool config

### Success Criteria

- [ ] Plugin starts server without launching terminal
- [ ] User can manually start Claude CLI in external terminal
- [ ] @ mentions sent via WebSocket when Claude connected
- [ ] @ mentions queued when Claude not connected, sent on connection
- [ ] Diff opens in Neovim without terminal window management
- [ ] Configuration validation rejects old terminal config with helpful errors
- [ ] All user commands work except removed terminal controls
- [ ] Test suite maintains >95% success rate
- [ ] `make` passes (format, lint, test)
- [ ] Documentation updated with migration guide

---

## All Needed Context

### Context Completeness Check

✅ **"No Prior Knowledge" Test**: An AI agent with no knowledge of this codebase would have:
- Complete file paths and line numbers for all changes
- Exact patterns to follow from existing code
- Validation commands that work in this project
- Specific gotchas and constraints documented
- External library documentation for testing framework (Busted)

---

### Documentation & References

```yaml
# MUST READ - Critical Project Context
- file: CLAUDE.md
  why: |
    Project development guidelines, testing commands, architecture overview.
    Contains exact `make` commands for validation.
  critical: |
    - Run `make` before committing (format, lint, test)
    - Test pattern: `busted tests/unit/specific_spec.lua`
    - Never skip `make` - many PRs fail CI because of this

- file: PRPs/remove-internal-terminal-prd.md
  why: Complete PRD with line-by-line analysis of what to remove
  pattern: Use PRD as checklist for verification
  section: Sections 2-6 (Current State, Removal Plan, Implementation Tasks)

# External Library Documentation
- url: https://lunarmodules.github.io/busted/
  why: Testing framework used for all unit and integration tests
  critical: |
    - Use `describe()` for grouping tests
    - Use `it()` for individual test cases
    - Use `before_each()` / `after_each()` for setup/teardown
    - Spy framework: `spy.new()`, `assert.spy(x).was_called()`
    - Must reset package.loaded between tests

- url: https://neovim.io/doc/user/lua.html#vim.fn.jobstart()
  why: External terminal provider uses jobstart() for launching external processes
  critical: |
    - `detach = true` makes job independent of Neovim
    - `env` parameter passes environment variables
    - `cwd` parameter sets working directory
    - `on_exit` callback runs when job terminates

# Codebase Patterns to Follow
- file: lua/claudecode/terminal/external.lua
  why: PRESERVE THIS FILE - it's the only terminal provider we're keeping
  pattern: |
    - Lines 54-116: Command building with function OR string template support
    - Lines 118-139: jobstart() with detach mode for external processes
    - State management: jobid tracking, cleanup on exit
  gotcha: |
    - External provider returns nil for get_active_bufnr() - no Neovim buffer
    - Cannot programmatically focus external terminals
    - Two-placeholder format: "alacritty --working-directory %s -e %s"

- file: lua/claudecode/config.lua
  why: Configuration validation and merging patterns
  pattern: |
    - Lines 43-177: Assertion-based validation with descriptive errors
    - Lines 182-221: Deep merge with vim.tbl_deep_extend("force", ...)
    - Lines 205-216: Backward compatibility mapping for legacy options
  gotcha: |
    - Validation happens AFTER merging user config
    - Use pcall for optional module loading (avoid circular deps)
    - Lazy-load terminal defaults to break circular dependency

- file: tests/busted_setup.lua
  why: Custom test infrastructure and JSON handling
  pattern: |
    - Custom JSON encoder/decoder for MCP message testing
    - Spy system for function call tracking
    - Package.loaded reset pattern for test isolation
  gotcha: |
    - Must export LUA_PATH before running busted
    - Tests use custom expect() DSL, not assert()
    - Mocks must be set up before requiring modules

- file: lua/claudecode/diff.lua (lines 1113-1139)
  why: Pattern for creating new tab without terminal
  pattern: |
    - vim.cmd("tabnew") for new tab creation
    - Mark initial buffer as ephemeral to prevent buffer leak
    - Track original tab for cleanup
  gotcha: |
    - Ephemeral buffer check: empty name, not modified, 1 line
    - Set bufhidden=wipe to auto-delete on window close
```

---

### Current Codebase Tree

```bash
lua/claudecode/
├── init.lua              # Main entry point (remove terminal integration)
├── config.lua            # Configuration (simplify terminal options)
├── lockfile.lua          # Lock file management (no changes)
├── logger.lua            # Logging (no changes)
├── selection.lua         # Selection tracking (remove terminal buffer check)
├── cwd.lua               # ❌ DELETE (only used by terminal for git root)
├── diff.lua              # Diff management (remove terminal UI dependencies)
├── server/
│   ├── init.lua          # WebSocket server (no changes)
│   ├── tcp.lua           # TCP server (no changes)
│   ├── handshake.lua     # WebSocket handshake (no changes)
│   ├── frame.lua         # WebSocket frames (no changes)
│   ├── client.lua        # Client management (no changes)
│   └── utils.lua         # Server utilities (no changes)
├── tools/
│   ├── init.lua          # MCP tool registration (no changes)
│   ├── *.lua             # Individual tools (no changes)
├── terminal.lua          # ❌ DELETE OR SIMPLIFY TO STUB
└── terminal/
    ├── snacks.lua        # ❌ DELETE (215 LOC)
    ├── native.lua        # ❌ DELETE (440 LOC)
    ├── none.lua          # ❌ DELETE (70 LOC)
    └── external.lua      # ✅ PRESERVE (207 LOC) - for external launch

tests/
├── unit/
│   ├── init_spec.lua                          # ⚠️ MODIFY (remove terminal mocks)
│   ├── config_spec.lua                        # ⚠️ MODIFY (update validation tests)
│   ├── diff_ui_cleanup_spec.lua               # ⚠️ MODIFY (remove ensure_visible)
│   ├── claudecode_send_command_spec.lua       # ⚠️ MODIFY (remove ensure_visible)
│   ├── diff_hide_terminal_new_tab_spec.lua    # ⚠️ MODIFY (update assertions)
│   ├── terminal_spec.lua                      # ❌ DELETE (1,224 LOC)
│   ├── focus_after_send_spec.lua              # ❌ DELETE (130 LOC)
│   ├── native_terminal_toggle_spec.lua        # ❌ DELETE (532 LOC)
│   └── terminal/
│       ├── none_provider_spec.lua             # ❌ DELETE (70 LOC)
│       └── external_spec.lua                  # ✅ KEEP (24 tests)
└── integration/
    └── mcp_tools_spec.lua                     # ⚠️ VERIFY (should have no changes)
```

---

### Desired Codebase Tree

```bash
lua/claudecode/
├── init.lua              # Simplified (no terminal integration)
├── config.lua            # Simplified (single external_terminal_cmd)
├── lockfile.lua          # No changes
├── logger.lua            # No changes
├── selection.lua         # No terminal buffer checking
├── diff.lua              # No terminal UI dependencies
├── server/               # No changes (entire directory)
├── tools/                # No changes (entire directory)
└── terminal/
    └── external.lua      # ✅ ONLY FILE REMAINING - external terminal launcher

tests/
├── unit/
│   ├── init_spec.lua                          # Updated mocks
│   ├── config_spec.lua                        # Updated validation tests
│   ├── diff_ui_cleanup_spec.lua               # Removed ensure_visible assertions
│   ├── claudecode_send_command_spec.lua       # Removed ensure_visible mock
│   ├── diff_hide_terminal_new_tab_spec.lua    # Updated assertions
│   └── terminal/
│       └── external_spec.lua                  # Updated to test as standalone
└── integration/
    └── mcp_tools_spec.lua                     # No changes needed
```

**Files Deleted**: 9 files, ~2,773 LOC
**Files Modified**: 8 files, ~360 LOC changes
**Net Reduction**: ~1,675 LOC

---

### Known Gotchas & Library Quirks

```lua
-- CRITICAL: External terminal provider interface
-- Location: lua/claudecode/terminal/external.lua
-- Gotcha: get_active_bufnr() MUST return nil (no Neovim buffer for external terminals)
-- Pattern:
function M.get_active_bufnr()
  return nil  -- External terminals don't have Neovim buffers
end

-- CRITICAL: WebSocket server is INDEPENDENT of terminal
-- Location: lua/claudecode/server/init.lua
-- Gotcha: Server can run without ANY terminal being open
-- Pattern: Server just listens on TCP port, accepts WebSocket connections
--          Claude CLI connects from external terminal, reads port from lock file

-- CRITICAL: @ mention queue works WITHOUT terminal
-- Location: lua/claudecode/init.lua:126-249
-- Gotcha: Queue system uses WebSocket broadcast, not terminal interaction
-- Pattern: Mentions queued when disconnected, sent when Claude connects via WebSocket

-- CRITICAL: Diff new tab creation WITHOUT terminal
-- Location: lua/claudecode/diff.lua:1113-1139
-- Gotcha: Must mark initial buffer as ephemeral to prevent buffer leak
-- Pattern:
local initial_buf = vim.api.nvim_get_current_buf()
if initial_buf and vim.api.nvim_buf_is_valid(initial_buf) then
  local name = vim.api.nvim_buf_get_name(initial_buf)
  local modified = vim.api.nvim_buf_get_option(initial_buf, "modified")
  local linecount = vim.api.nvim_buf_line_count(initial_buf)
  if (name == "" or name == nil) and not modified and linecount <= 1 then
    pcall(vim.api.nvim_buf_set_option, initial_buf, "bufhidden", "wipe")
  end
end

-- CRITICAL: Test isolation requires package.loaded reset
-- Location: tests/busted_setup.lua, all test files
-- Gotcha: Must reset package.loaded["claudecode.*"] between tests
-- Pattern:
before_each(function()
  package.loaded["claudecode.terminal"] = nil
  package.loaded["claudecode.config"] = nil
  -- ... reset other modules
end)

-- CRITICAL: Busted tests need correct LUA_PATH
-- Location: Makefile, CLAUDE.md
-- Gotcha: Tests will fail with "module not found" without proper LUA_PATH
-- Pattern:
export LUA_PATH="./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;$LUA_PATH"
busted tests/unit/specific_spec.lua

-- CRITICAL: Config validation happens AFTER merging
-- Location: lua/claudecode/config.lua:182-221
-- Gotcha: Old config detection must happen BEFORE validation
-- Pattern:
function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)

  -- FIRST: Detect old config and error/migrate
  if user_config and user_config.terminal then
    -- Check for removed options and error with migration guide
  end

  -- SECOND: Merge configs
  config = vim.tbl_deep_extend("force", config, user_config)

  -- THIRD: Validate merged result
  M.validate(config)

  return config
end

-- CRITICAL: Diff cleanup must NOT call terminal functions
-- Location: lua/claudecode/diff.lua:975-1071
-- Gotcha: _cleanup_diff_state() currently calls terminal_module.ensure_visible()
-- Action: Remove lines 1013-1026 (new tab terminal restoration)
--         Remove lines 1040-1048 (same tab terminal width restoration)
```

---

## Implementation Blueprint

### Data Models and Structure

**Configuration Structure Changes**:

```lua
-- BEFORE (lua/claudecode/config.lua:10-37)
M.defaults = {
  port_range = { min = 10000, max = 65535 },
  auto_start = true,
  terminal_cmd = nil,                    -- ❌ REMOVE
  env = {},                              -- ❌ REMOVE
  focus_after_send = false,              -- ❌ REMOVE
  terminal = nil,                        -- ❌ REMOVE (entire nested table)
  diff_opts = {
    layout = "vertical",
    open_in_new_tab = false,
    keep_terminal_focus = false,         -- ❌ REMOVE
    hide_terminal_in_new_tab = false,    -- ❌ REMOVE
    on_new_file_reject = "keep_empty",
  },
  -- ... other fields
}

-- AFTER (simplified)
M.defaults = {
  port_range = { min = 10000, max = 65535 },
  auto_start = true,
  external_terminal_cmd = nil,           -- ✅ NEW (required)
  diff_opts = {
    layout = "vertical",
    open_in_new_tab = false,
    on_new_file_reject = "keep_empty",
  },
  -- ... other fields (unchanged)
}
```

**State Structure** (no changes needed):

```lua
-- lua/claudecode/init.lua:29-39
-- ✅ NO TERMINAL STATE - all state is server/queue related
M.state = {
  config = require("claudecode.config").defaults,
  server = nil,               -- ✅ KEEP
  port = nil,                 -- ✅ KEEP
  auth_token = nil,           -- ✅ KEEP
  initialized = false,        -- ✅ KEEP
  mention_queue = {},         -- ✅ KEEP
  mention_timer = nil,        -- ✅ KEEP
  connection_timer = nil,     -- ✅ KEEP
}
```

**Diff State Changes**:

```lua
-- lua/claudecode/diff.lua:1201-1222
-- REMOVE these fields from diff_data:
{
  -- ... other fields
  had_terminal_in_original = ...,      -- ❌ REMOVE
  terminal_win_in_new_tab = ...,       -- ❌ REMOVE
  -- ... other fields
}
```

---

### Implementation Tasks (Ordered by Dependencies)

```yaml
Task 1: DELETE internal terminal provider files
  - DELETE: lua/claudecode/terminal/snacks.lua
  - DELETE: lua/claudecode/terminal/native.lua
  - DELETE: lua/claudecode/terminal/none.lua
  - DELETE: lua/claudecode/cwd.lua
  - VERIFY: grep -r "terminal/snacks\|terminal/native\|terminal/none\|claudecode.cwd" lua/
  - EXPECTED: No matches after deletion

Task 2: DELETE terminal-related test files
  - DELETE: tests/unit/terminal_spec.lua
  - DELETE: tests/unit/terminal/none_provider_spec.lua
  - DELETE: tests/unit/focus_after_send_spec.lua
  - DELETE: tests/unit/native_terminal_toggle_spec.lua
  - VERIFY: find tests -name "*terminal*" -o -name "*focus_after*"
  - EXPECTED: Only tests/unit/terminal/external_spec.lua remains

Task 3: SIMPLIFY lua/claudecode/config.lua
  - REMOVE from M.defaults (lines 10-37):
    - terminal_cmd (line 13)
    - env (line 14)
    - focus_after_send (line 18)
    - terminal = nil (line 36)
  - ADD to M.defaults:
    - external_terminal_cmd = nil  (after auto_start line)
  - REMOVE from diff_opts (lines 23-29):
    - keep_terminal_focus (line 26)
    - hide_terminal_in_new_tab (line 27)
  - REMOVE validation (lines 43-177):
    - Lines 56: terminal_cmd validation
    - Lines 59-80: terminal table validation
    - Lines 94-96: focus_after_send validation
    - Lines 126-128: keep_terminal_focus validation
    - Lines 129-133: hide_terminal_in_new_tab validation
  - ADD validation for external_terminal_cmd:
    - Must be string with %s OR function
    - String must contain at least one %s placeholder
    - Follow pattern from lines 66-79 (existing external_terminal_cmd validation)
  - ADD old config detection in M.apply() (before merge, lines 182-221):
    - Check for user_config.terminal existence
    - Check for user_config.focus_after_send
    - Error with migration guide if found
    - Follow pattern from lines 205-216 (backward compat mapping)
  - VERIFY: luacheck lua/claudecode/config.lua

Task 4: MODIFY lua/claudecode/init.lua - Remove terminal integration
  - DELETE function _ensure_terminal_visible_if_connected() (lines 252-274)
  - MODIFY send_at_mention() function (lines 283-317):
    - REMOVE lines 296-302: focus_after_send conditional
    - REMOVE lines 310-311: terminal.open() when disconnected
    - ADD warning message when queueing: "Claude not connected. Please start Claude CLI."
  - DELETE terminal module setup in M.setup() (lines 354-363)
  - DELETE terminal command registration (lines 984-1028):
    - ClaudeCode (toggle)
    - ClaudeCodeFocus (focus toggle)
    - ClaudeCodeOpen (open)
    - ClaudeCodeClose (close)
  - MODIFY M.open_with_model() (lines 1045-1080):
    - Remove :ClaudeCode call or update to not use terminal
  - VERIFY: grep -n "terminal\." lua/claudecode/init.lua
  - EXPECTED: Zero matches (no terminal module calls)

Task 5: MODIFY lua/claudecode/diff.lua - Remove terminal UI dependencies
  - DELETE find_claudecode_terminal_window() (lines 89-114)
  - DELETE get_default_terminal_options() (lines 170-192)
  - DELETE display_terminal_in_new_tab() (lines 194-292)
  - MODIFY choose_original_window() (lines 469-505):
    - Change signature: remove terminal_win_in_new_tab parameter
    - Add in_new_tab boolean parameter instead
  - MODIFY setup_new_buffer() (lines 551-631):
    - Remove terminal_win_in_new_tab parameter from signature
    - DELETE keep_terminal_focus block (lines 590-604)
    - DELETE terminal width adjustment (lines 606-628)
  - MODIFY _create_diff_view_from_window() (lines 887-973):
    - Remove terminal_win_in_new_tab parameter from signature
    - Update all calls to match new signature
  - MODIFY _setup_blocking_diff() (lines 1081-1174):
    - REPLACE display_terminal_in_new_tab() call (lines 1113-1124) with simple tab creation:
      ```lua
      if config and config.diff_opts and config.diff_opts.open_in_new_tab then
        original_tab_number = vim.api.nvim_get_current_tabpage()
        vim.cmd("tabnew")
        new_tab_handle = vim.api.nvim_get_current_tabpage()
        created_new_tab = true

        -- Mark initial buffer as ephemeral
        local initial_buf = vim.api.nvim_get_current_buf()
        if initial_buf and vim.api.nvim_buf_is_valid(initial_buf) then
          local name = vim.api.nvim_buf_get_name(initial_buf)
          local modified = vim.api.nvim_buf_get_option(initial_buf, "modified")
          local linecount = vim.api.nvim_buf_line_count(initial_buf)
          if (name == "" or name == nil) and not modified and linecount <= 1 then
            pcall(vim.api.nvim_buf_set_option, initial_buf, "bufhidden", "wipe")
          end
        end

        target_window = nil
        existing_buffer = nil
      end
      ```
  - MODIFY _cleanup_diff_state() (lines 975-1071):
    - REMOVE terminal restoration (lines 1013-1026) - new tab case
    - REMOVE terminal width restoration (lines 1040-1048) - same tab case
  - MODIFY _register_diff_state() (lines 1201-1222):
    - REMOVE had_terminal_in_original field
    - REMOVE terminal_win_in_new_tab field
  - VERIFY: grep -n "terminal" lua/claudecode/diff.lua
  - EXPECTED: Zero matches

Task 6: MODIFY lua/claudecode/selection.lua - Remove terminal buffer checking
  - MODIFY update_selection() (lines 143-154):
    - REMOVE terminal buffer checking block
    - Lines to delete: 143-154
  - VERIFY: grep -n "terminal" lua/claudecode/selection.lua
  - EXPECTED: Zero matches

Task 7: UPDATE test files - Remove terminal mocks
  - MODIFY tests/unit/config_spec.lua:
    - Lines 9, 34, 44: Remove terminal_cmd references
    - Keep external_terminal_cmd validation tests (lines 194-300)
    - Add test for missing external_terminal_cmd (should error)
  - MODIFY tests/unit/init_spec.lua:
    - Lines 71-74: Remove ensure_visible from mock_terminal
    - Keep only open() mock for external launch
  - MODIFY tests/unit/diff_ui_cleanup_spec.lua:
    - Lines 71-79: Remove ensure_visible from terminal mock
    - Line 114: Remove ensure_calls assertion
  - MODIFY tests/unit/claudecode_send_command_spec.lua:
    - Line 74: Remove ensure_visible from mock_terminal
  - MODIFY tests/unit/diff_hide_terminal_new_tab_spec.lua:
    - Line 37: Remove ensure_visible from mock
  - VERIFY: Run tests after each file modification
    ```bash
    busted tests/unit/config_spec.lua -v
    busted tests/unit/init_spec.lua -v
    # ... etc
    ```

Task 8: UPDATE lua/claudecode/terminal/external.lua - Standalone provider
  - VERIFY file still works independently
  - ADD comments indicating this is the ONLY terminal provider
  - NO CODE CHANGES needed
  - VERIFY: busted tests/unit/terminal/external_spec.lua -v

Task 9: UPDATE documentation
  - UPDATE CLAUDE.md:
    - Remove "Terminal Integration Options" internal providers
    - Update configuration examples to show external_terminal_cmd only
    - Remove terminal toggle commands from command list
    - Update "Development Workflow" section
  - UPDATE CHANGELOG.md:
    - Add breaking changes entry
    - List removed features
    - Provide migration guide
  - UPDATE README.md (if exists):
    - Update installation/configuration sections
    - Remove internal terminal screenshots/examples
    - Add external terminal workflow

Task 10: FINAL VALIDATION - Run complete test suite
  - RUN: make format
  - RUN: make check
  - RUN: make test
  - VERIFY: All commands pass
  - VERIFY: Test success rate >95%
  - FIX: Any failing tests (up to 5 allowed)
```

---

### Implementation Patterns & Key Details

```lua
-- Pattern: Configuration Validation with Helpful Errors
-- File: lua/claudecode/config.lua
-- Add this BEFORE merging user config (line ~185)
if user_config and user_config.terminal then
  local terminal = user_config.terminal
  local old_config_keys = {
    "split_side", "split_width_percentage", "provider",
    "show_native_term_exit_tip", "auto_close", "snacks_win_opts",
    "cwd", "git_repo_cwd", "cwd_provider"
  }

  for _, key in ipairs(old_config_keys) do
    if terminal[key] ~= nil then
      error(string.format([[
claudecode.nvim: Breaking change detected!

The configuration option 'terminal.%s' has been removed.
Internal terminal providers (snacks, native) are no longer supported.

Please update your configuration:

require("claudecode").setup({
  external_terminal_cmd = "alacritty -e %%s",
})

See: https://github.com/doodleEsc/claudecode.nvim#migration
      ]], key))
    end
  end

  -- Auto-migrate external_terminal_cmd if found
  if terminal.provider_opts and terminal.provider_opts.external_terminal_cmd then
    user_config.external_terminal_cmd = terminal.provider_opts.external_terminal_cmd
    logger.warn("config", "Auto-migrated terminal.provider_opts.external_terminal_cmd")
  end
end

-- Pattern: New Tab Creation Without Terminal
-- File: lua/claudecode/diff.lua
-- Replace display_terminal_in_new_tab() call with this:
if config and config.diff_opts and config.diff_opts.open_in_new_tab then
  original_tab_number = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  new_tab_handle = vim.api.nvim_get_current_tabpage()
  created_new_tab = true

  -- Mark initial buffer as ephemeral (prevent buffer leak)
  local initial_buf = vim.api.nvim_get_current_buf()
  if initial_buf and vim.api.nvim_buf_is_valid(initial_buf) then
    local name = vim.api.nvim_buf_get_name(initial_buf)
    local modified = vim.api.nvim_buf_get_option(initial_buf, "modified")
    local linecount = vim.api.nvim_buf_line_count(initial_buf)
    -- Only wipe if it's truly empty/unmodified
    if (name == "" or name == nil) and not modified and linecount <= 1 then
      pcall(vim.api.nvim_buf_set_option, initial_buf, "bufhidden", "wipe")
    end
  end

  target_window = nil
  existing_buffer = nil
end

-- Pattern: Test Mock Setup (Remove Terminal)
-- File: tests/unit/*/
-- BEFORE:
local mock_terminal = {
  open = spy.new(function() end),
  ensure_visible = spy.new(function() end),
  get_active_terminal_bufnr = function() return nil end,
}

-- AFTER (if terminal mock still needed):
local mock_terminal = {
  -- No methods needed - terminal module not used
}

-- Pattern: send_at_mention Without Terminal Launch
-- File: lua/claudecode/init.lua:283-317
function M.send_at_mention(file_path, start_line, end_line, context)
  context = context or "command"

  if not M.state.server then
    logger.error(context, "Claude Code integration is not running")
    return false, "Claude Code integration is not running"
  end

  if M.is_claude_connected() then
    -- Claude is connected, send immediately
    local success, error_msg = M._broadcast_at_mention(file_path, start_line, end_line)
    return success, error_msg
  else
    -- Claude not connected, queue the mention
    queue_mention(file_path, start_line, end_line)

    logger.warn(context, string.format(
      "Claude not connected. Queued @ mention: %s. Please ensure Claude CLI is running in an external terminal.",
      file_path
    ))

    return true, nil
  end
end
```

---

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Run after each file modification
luacheck lua/claudecode/init.lua
luacheck lua/claudecode/config.lua
luacheck lua/claudecode/diff.lua
luacheck lua/claudecode/selection.lua

# Project-wide validation
make check

# Expected: Zero errors, zero warnings
```

### Level 2: Code Formatting (Consistency)

```bash
# Auto-format modified files
make format

# Or with stylua directly
stylua lua/claudecode/

# Expected: No changes if already formatted
```

### Level 3: Unit Tests (Component Validation)

```bash
# Test each component as modified
export LUA_PATH="./lua/?.lua;./lua/?/init.lua;./?.lua;./?/init.lua;$LUA_PATH"

busted tests/unit/config_spec.lua -v
# Expected: All tests pass

busted tests/unit/init_spec.lua -v
# Expected: All tests pass (or known failures documented)

busted tests/unit/diff_ui_cleanup_spec.lua -v
# Expected: All tests pass

busted tests/unit/claudecode_send_command_spec.lua -v
# Expected: All tests pass

busted tests/unit/diff_hide_terminal_new_tab_spec.lua -v
# Expected: All tests pass

busted tests/unit/terminal/external_spec.lua -v
# Expected: All 24 tests pass

# Full test suite
make test

# Expected: >95% success rate (allow up to 5 failures during transition)
```

### Level 4: Integration Testing (System Validation)

```bash
# Manual integration test workflow
# Terminal 1: Start Neovim
nvim

# In Neovim:
:ClaudeCodeStart
# Expected: Server starts, no terminal launched
# Verify: cat ~/.claude/ide/*.lock shows port and authToken

# Terminal 2: Start Claude CLI
cd /path/to/project
claude
# Expected: Claude CLI connects to WebSocket
# Verify: :ClaudeCodeStatus shows "Connected"

# Terminal 1: Send @ mention
# Open a file, select code, run:
:ClaudeCodeSend
# Expected: @ mention sent via WebSocket
# Verify: Claude CLI receives mention (visible in terminal 2)

# Test diff functionality
# Let Claude suggest changes, verify diff opens in Neovim
# Expected: Diff opens in current tab or new tab (based on config)
# Verify: No terminal window created in diff tab

# Test queue system
# In Neovim, stop Claude CLI (Ctrl+C in terminal 2)
:ClaudeCodeSend
# Expected: Mention queued, warning logged
# Restart Claude CLI
# Expected: Queued mention sent automatically

# Cleanup
:ClaudeCodeStop
# Expected: Server stops, lock file removed
```

---

## Final Validation Checklist

### Technical Validation

- [ ] All 4 validation levels completed successfully
- [ ] `make check` passes (zero luacheck errors/warnings)
- [ ] `make format` passes (zero formatting issues)
- [ ] `make test` passes (>95% test success rate)
- [ ] Test count: Started with 52 files, now ~49 files
- [ ] LOC reduction: ~1,675 LOC removed

### Feature Validation

- [ ] ClaudeCodeStart starts server without launching terminal
- [ ] Lock file created with port and authToken
- [ ] Manual Claude CLI start connects to WebSocket
- [ ] ClaudeCodeSend sends @ mention when connected
- [ ] ClaudeCodeSend queues mention when disconnected
- [ ] Queue processes when Claude connects
- [ ] Diff opens without terminal window management
- [ ] Diff open_in_new_tab works correctly
- [ ] Diff accept/reject works
- [ ] Selection tracking works

### Code Quality Validation

- [ ] No `require("claudecode.terminal")` in init.lua
- [ ] No `require("claudecode.terminal")` in diff.lua
- [ ] No `require("claudecode.terminal")` in selection.lua
- [ ] Config validation rejects old terminal options with helpful errors
- [ ] Config auto-migrates terminal.provider_opts.external_terminal_cmd
- [ ] All terminal provider files deleted
- [ ] All terminal test files deleted (except external_spec.lua)
- [ ] No dead code (grep for unused functions)

### Documentation & Migration

- [ ] CLAUDE.md updated (removed internal terminal docs)
- [ ] CHANGELOG.md updated (breaking changes documented)
- [ ] Migration guide created (old config → new config)
- [ ] Error messages are helpful and include migration instructions

### Breaking Change Verification

- [ ] Old config with `terminal.provider = "snacks"` errors with migration guide
- [ ] Old config with `terminal.provider = "native"` errors with migration guide
- [ ] Old config with `focus_after_send` warns or auto-migrates
- [ ] Old config with `diff_opts.keep_terminal_focus` warns or auto-migrates
- [ ] Config with missing `external_terminal_cmd` errors helpfully

---

## Anti-Patterns to Avoid

- ❌ Don't leave dead code - remove all unused functions completely
- ❌ Don't create new abstractions - simplify to direct external terminal launch
- ❌ Don't skip validation - run `make` after EVERY change
- ❌ Don't ignore test failures - fix them before proceeding
- ❌ Don't hardcode values - use config for external_terminal_cmd
- ❌ Don't catch all exceptions - be specific (pcall for optional features only)
- ❌ Don't batch test runs - test each component as you modify it
- ❌ Don't forget package.loaded reset in tests - leads to intermittent failures
- ❌ Don't modify terminal/external.lua - it's already correct, preserve as-is

---

## Risk Assessment & Mitigation

**Risk: Breaking existing user configurations**
- **Likelihood:** High (all users with internal terminal config)
- **Impact:** High (plugin won't work without external_terminal_cmd)
- **Mitigation:**
  - Detailed error messages with migration examples
  - Auto-migration for terminal.provider_opts.external_terminal_cmd
  - Comprehensive migration guide in CHANGELOG.md
  - Check for old config BEFORE merging to catch errors early

**Risk: Test failures during transition**
- **Likelihood:** Medium (many terminal-related tests)
- **Impact:** Medium (slows development, but not user-facing)
- **Mitigation:**
  - Allow up to 5 failing tests during transition
  - Test each component immediately after modification
  - Update test mocks systematically
  - Maintain >95% success rate

**Risk: Diff functionality regression**
- **Likelihood:** Low (diff module is well-tested)
- **Impact:** High (core feature)
- **Mitigation:**
  - Keep all core diff logic unchanged
  - Only remove terminal UI management code
  - Test diff workflows manually and automatically
  - Verify open_in_new_tab still works

**Risk: WebSocket communication breaks**
- **Likelihood:** Very Low (server module untouched)
- **Impact:** Critical (entire plugin broken)
- **Mitigation:**
  - DO NOT modify lua/claudecode/server/ at all
  - Verify server tests still pass
  - Manual integration test with external Claude CLI
  - Test @ mention queue system

---

## Success Metrics

**Code Metrics:**
- ✅ Removed ~1,675 LOC (30% of plugin)
- ✅ Deleted 9 files
- ✅ Modified 8 files with targeted changes
- ✅ Zero new dependencies
- ✅ Zero luacheck warnings
- ✅ Zero formatting issues

**Quality Metrics:**
- ✅ >95% test success rate
- ✅ All validation commands pass (`make check`, `make format`, `make test`)
- ✅ Manual integration test successful
- ✅ External Claude CLI connects and receives @ mentions
- ✅ Diff functionality works without terminal
- ✅ Configuration validation catches old config

**User Experience Metrics:**
- ✅ Simplified configuration (1 field vs 12+ fields)
- ✅ Helpful error messages with migration examples
- ✅ Auto-migration for common cases
- ✅ Documentation updated with clear migration guide
- ✅ Faster plugin load (no provider detection)
- ✅ More screen space for diffs (no terminal split)

---

**Document Version:** 1.0
**Created:** 2025-10-21
**Estimated Implementation Time:** 3-4 hours for experienced developer
**Confidence Score:** 9/10 (comprehensive research, clear patterns, validated approach)
