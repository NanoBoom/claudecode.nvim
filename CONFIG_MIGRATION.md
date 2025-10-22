# Configuration Migration Analysis - claudecode.nvim

## Executive Summary

This document provides comprehensive patterns and best practices for safely migrating configuration options in claudecode.nvim. The codebase demonstrates mature configuration management with clear patterns for backward compatibility, validation, and deprecation.

---

## 1. Configuration Architecture Overview

### Entry Points

**Main Configuration Flow:**
- User config → `lua/claudecode/init.lua` (line 326) → `config.apply()`
- Terminal config → `lua/claudecode/init.lua` (line 359) → `terminal.setup()`

**File Structure:**
- `/lua/claudecode/config.lua` - Core validation and application logic
- `/lua/claudecode/types.lua` - Type definitions for configuration
- `/lua/claudecode/terminal.lua` - Terminal configuration handling
- `/tests/unit/config_spec.lua` - Validation test patterns

### Configuration Flow Chain

```
M.setup(opts)                      (init.lua:322)
  ↓
config.apply(opts)                 (config.lua:182)
  ├→ Merge with defaults (line 183-203)
  ├→ Backward compatibility mapping (line 205-216)
  └→ Validate result (line 218)

terminal_module.setup(...)         (init.lua:359)
  ├→ Validate terminal_cmd type (terminal.lua:368)
  ├→ Validate env type (terminal.lua:378)
  └→ Apply user terminal config (terminal.lua:388-490)
```

---

## 2. Configuration Validation Pattern

### Core Validation Function

**Location:** `/lua/claudecode/config.lua` (lines 39-177)

**Function Signature:**
```lua
function M.validate(config)
  assert(
    condition,
    "error message"
  )
  return true
end
```

**Key Characteristics:**
- Uses `assert()` for synchronous validation
- Throws errors on invalid configuration
- Called at END of `M.apply()` after merging
- Each assertion has descriptive error message

### Validation Pattern by Type

#### 1. **Simple Type Checks**

```lua
-- String or nil validation (config.lua:56)
assert(
  config.terminal_cmd == nil or type(config.terminal_cmd) == "string",
  "terminal_cmd must be nil or a string"
)

-- Boolean validation (config.lua:94-96)
if config.focus_after_send ~= nil then
  assert(
    type(config.focus_after_send) == "boolean",
    "focus_after_send must be a boolean"
  )
end
```

#### 2. **Enum Validation**

```lua
-- Log level validation (config.lua:82-90)
local valid_log_levels = { "trace", "debug", "info", "warn", "error" }
local is_valid_log_level = false
for _, level in ipairs(valid_log_levels) do
  if config.log_level == level then
    is_valid_log_level = true
    break
  end
end
assert(
  is_valid_log_level,
  "log_level must be one of: " .. table.concat(valid_log_levels, ", ")
)
```

#### 3. **Nested Table Validation**

```lua
-- Provider options validation (config.lua:61-80)
if config.terminal.provider_opts then
  assert(
    type(config.terminal.provider_opts) == "table",
    "terminal.provider_opts must be a table"
  )
  
  if config.terminal.provider_opts.external_terminal_cmd then
    local cmd_type = type(config.terminal.provider_opts.external_terminal_cmd)
    assert(
      cmd_type == "string" or cmd_type == "function",
      "terminal.provider_opts.external_terminal_cmd must be a string or function"
    )
    -- Validate %s placeholder only for strings
    if cmd_type == "string" and 
       config.terminal.provider_opts.external_terminal_cmd ~= "" then
      assert(
        config.terminal.provider_opts.external_terminal_cmd:find("%%s"),
        "terminal.provider_opts.external_terminal_cmd must contain '%s' placeholder"
      )
    end
  end
end
```

#### 4. **Complex Validation with Sub-tables**

```lua
-- Model validation (config.lua:166-174)
assert(type(config.models) == "table", "models must be a table")
assert(#config.models > 0, "models must not be empty")

for i, model in ipairs(config.models) do
  assert(
    type(model) == "table",
    "models[" .. i .. "] must be a table"
  )
  assert(
    type(model.name) == "string" and model.name ~= "",
    "models[" .. i .. "].name must be a non-empty string"
  )
  assert(
    type(model.value) == "string" and model.value ~= "",
    "models[" .. i .. "].value must be a non-empty string"
  )
end
```

---

## 3. Backward Compatibility Pattern

### Current Implementation: Legacy Diff Options

**Location:** `/lua/claudecode/config.lua` (lines 205-216)

This is the PRODUCTION EXAMPLE of safe deprecation:

```lua
-- Backward compatibility: map legacy diff options to new fields if provided
if config.diff_opts then
  local d = config.diff_opts
  -- Map vertical_split -> layout (legacy option takes precedence)
  if type(d.vertical_split) == "boolean" then
    d.layout = d.vertical_split and "vertical" or "horizontal"
  end
  -- Map open_in_current_tab -> open_in_new_tab (legacy option takes precedence)
  if type(d.open_in_current_tab) == "boolean" then
    d.open_in_new_tab = not d.open_in_current_tab
  end
end
```

### Key Principles

1. **Check type before mapping** - Ensures legacy option is actually set
2. **Legacy takes precedence** - If both old and new provided, old wins
3. **Conditional logic** - Map old → new value
4. **Happens BEFORE validation** - Ensures validation sees normalized values

### Related Validation (Still Accepts Legacy)

**Location:** `/lua/claudecode/config.lua` (lines 145-157)

```lua
-- Legacy diff options (accept if present to avoid breaking old configs)
if config.diff_opts.auto_close_on_accept ~= nil then
  assert(
    type(config.diff_opts.auto_close_on_accept) == "boolean",
    "diff_opts.auto_close_on_accept must be a boolean"
  )
end
if config.diff_opts.show_diff_stats ~= nil then
  assert(
    type(config.diff_opts.show_diff_stats) == "boolean",
    "diff_opts.show_diff_stats must be a boolean"
  )
end
if config.diff_opts.vertical_split ~= nil then
  assert(
    type(config.diff_opts.vertical_split) == "boolean",
    "diff_opts.vertical_split must be a boolean"
  )
end
if config.diff_opts.open_in_current_tab ~= nil then
  assert(
    type(config.diff_opts.open_in_current_tab) == "boolean",
    "diff_opts.open_in_current_tab must be a boolean"
  )
end
```

### Git History Reference

**Commit:** `6af7df0` - "fix: legacy diff options not working due to merge order (#142)"

The issue demonstrates an important lesson:
- Initial implementation checked if values were `nil` AFTER merging with defaults
- This failed because merged configs already had default values
- **Fix:** Unconditionally check for legacy option presence using `type()`
- This ensures backward compatibility works correctly

---

## 4. Terminal Configuration Migration Patterns

### Pattern 1: Top-Level to Nested Migration

**Current State** (init.lua:334-352):

The codebase shows how to handle top-level config aliases that map to nested structure:

```lua
-- Map top-level cwd-related aliases into terminal config for convenience
do
  local t = opts.terminal or {}
  local had_alias = false
  if opts.git_repo_cwd ~= nil then
    t.git_repo_cwd = opts.git_repo_cwd
    had_alias = true
  end
  if opts.cwd ~= nil then
    t.cwd = opts.cwd
    had_alias = true
  end
  if opts.cwd_provider ~= nil then
    t.cwd_provider = opts.cwd_provider
    had_alias = true
  end
  if had_alias then
    opts.terminal = t
  end
end
```

**Key Pattern:**
1. Check if option is provided (`~= nil`)
2. Copy to nested structure
3. Track if any mapping happened
4. Update parent config only if changes made

### Pattern 2: Provider-Specific Option Migration

**Current State** (terminal.lua:413-434):

```lua
elseif k == "provider_opts" then
  -- Handle nested provider options
  if type(v) == "table" then
    defaults[k] = defaults[k] or {}
    for opt_k, opt_v in pairs(v) do
      if opt_k == "external_terminal_cmd" then
        if opt_v == nil or type(opt_v) == "string" or type(opt_v) == "function" then
          defaults[k][opt_k] = opt_v
        else
          vim.notify(
            "claudecode.terminal.setup: Invalid value for provider_opts.external_terminal_cmd: " 
            .. tostring(opt_v),
            vim.log.levels.WARN
          )
        end
      else
        -- For other provider options, just copy them
        defaults[k][opt_k] = opt_v
      end
    end
  else
    vim.notify(
      "claudecode.terminal.setup: Invalid value for provider_opts: " .. tostring(v),
      vim.log.levels.WARN
    )
  end
```

**Key Features:**
- Validates nested options individually
- Uses `vim.notify()` with `WARN` level for non-fatal issues
- Continues processing other options
- Allows future extensibility for new provider options

---

## 5. Error Handling and User Notification Pattern

### Assertion-Based Validation (Fatal)

**Usage:** When configuration prevents plugin from functioning at all

**Location:** `config.lua:39-177`

```lua
assert(condition, "descriptive error message")
```

**Flow:**
1. Assertion fails during `config.apply()`
2. Error thrown (caught by caller)
3. Plugin fails to start
4. User sees error in log

**Example Test:** `tests/unit/config_spec.lua` (lines 50-62)

```lua
it("should reject invalid port range", function()
  local invalid_config = {
    port_range = { min = -1, max = 65536 },
    -- ...
  }
  
  local success, _ = pcall(function()
    config.validate(invalid_config)
  end)
  
  expect(success).to_be_false()
end)
```

### Notification-Based Validation (Non-Fatal)

**Usage:** When user provides invalid option but sensible default exists

**Location:** `terminal.lua:368-490`

```lua
vim.notify(
  "claudecode.terminal.setup: Invalid terminal_cmd provided: " .. tostring(p_terminal_cmd) .. ". Using default.",
  vim.log.levels.WARN
)
```

**Flow:**
1. Type check fails in `setup()`
2. Notify user with warning
3. Fall back to default value
4. Plugin continues functioning

**Examples:**
- Invalid `terminal_cmd` type (line 371-375)
- Invalid `split_side` value (line 393)
- Invalid provider name (line 408-411)
- Invalid `external_terminal_cmd` (line 422-425)

### Error Message Patterns

**Good Pattern Examples from Codebase:**

1. **Type Error with Context**
   ```lua
   "terminal.provider_opts.external_terminal_cmd must be a string or function"
   ```

2. **Enum Error with Choices**
   ```lua
   "log_level must be one of: " .. table.concat(valid_log_levels, ", ")
   ```

3. **Structural Error with Path**
   ```lua
   "models[" .. i .. "].name must be a non-empty string"
   ```

4. **Placeholder Error**
   ```lua
   "external_terminal_cmd must contain '%s' placeholder for the Claude command"
   ```

5. **User-Action Error**
   ```lua
   "external_terminal_cmd not configured. Please set terminal.provider_opts.external_terminal_cmd in your config."
   ```

---

## 6. Safe Migration Procedure

### Recommended Process for Config Option Changes

#### Step 1: Design the Change

Define:
- What is being removed/changed
- What is the new pattern
- How long will legacy support last
- What user messages are needed

#### Step 2: Add Backward Compatibility Mapping

**Pattern (follows config.lua:205-216):**

```lua
function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)
  
  -- Merge with user config
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end
  
  -- BACKWARD COMPATIBILITY SECTION
  if config.new_section then
    local ns = config.new_section
    
    -- If old option provided, map to new
    if config.old_option ~= nil then
      ns.new_option = config.old_option
      config.old_option = nil  -- Optional: remove old key
    end
  end
  
  M.validate(config)
  return config
end
```

#### Step 3: Add Validation for Both Old and New

**Pattern (follows config.lua:145-157):**

```lua
function M.validate(config)
  -- Validate new option
  if config.new_section.new_option ~= nil then
    assert(
      type(config.new_section.new_option) == "expected_type",
      "descriptive error"
    )
  end
  
  -- Still validate old option if provided (for backward compat)
  if config.old_option ~= nil then
    assert(
      type(config.old_option) == "expected_type",
      "old_option: descriptive error"
    )
  end
end
```

#### Step 4: Add Tests

**Pattern (follows tests/unit/config_spec.lua:141-192):**

```lua
it("should accept new option", function()
  local config = config.apply({
    new_section = {
      new_option = "value"
    }
  })
  expect(config.new_section.new_option).to_be("value")
end)

it("should map legacy option to new", function()
  local config = config.apply({
    old_option = "value"
  })
  expect(config.new_section.new_option).to_be("value")
end)

it("should prefer old option if both provided", function()
  local config = config.apply({
    old_option = "old",
    new_section = { new_option = "new" }
  })
  expect(config.new_section.new_option).to_be("old")
end)
```

#### Step 5: Document in CLAUDE.md

Add section explaining:
- Old pattern and why it changed
- New pattern with examples
- When old pattern will be removed
- Migration instructions

---

## 7. External Terminal Command Validation Pattern

### Location
- Validation: `config.lua:65-79`
- Runtime: `terminal/external.lua:40-116`
- Type def: `types.lua:46`

### Comprehensive Validation Pattern

**Phase 1: Configuration Validation** (config.lua:65-79)

```lua
if config.terminal.provider_opts.external_terminal_cmd then
  local cmd_type = type(config.terminal.provider_opts.external_terminal_cmd)
  assert(
    cmd_type == "string" or cmd_type == "function",
    "terminal.provider_opts.external_terminal_cmd must be a string or function"
  )
  -- Only validate %s placeholder for strings
  if cmd_type == "string" and 
     config.terminal.provider_opts.external_terminal_cmd ~= "" then
    assert(
      config.terminal.provider_opts.external_terminal_cmd:find("%%s"),
      "terminal.provider_opts.external_terminal_cmd must contain '%s' placeholder"
    )
  end
end
```

**Phase 2: Runtime Validation** (terminal/external.lua:40-116)

```lua
local external_cmd = config.provider_opts and config.provider_opts.external_terminal_cmd

if not external_cmd then
  vim.notify(
    "external_terminal_cmd not configured. Please set terminal.provider_opts.external_terminal_cmd in your config.",
    vim.log.levels.ERROR
  )
  return
end

if type(external_cmd) == "function" then
  -- Call function and validate return
  local result = external_cmd(cmd_string, env_table)
  if not result then
    vim.notify("external_terminal_cmd function returned nil or false", vim.log.levels.ERROR)
    return
  end
  if type(result) == "string" then
    cmd_parts = vim.split(result, " ")
  elseif type(result) == "table" then
    cmd_parts = result
  else
    vim.notify(
      "external_terminal_cmd function must return a string or table, got: " .. type(result),
      vim.log.levels.ERROR
    )
    return
  end

elseif type(external_cmd) == "string" then
  if external_cmd == "" then
    vim.notify("external_terminal_cmd string cannot be empty", vim.log.levels.ERROR)
    return
  end
  
  -- Support 1 or 2 %s placeholders
  local _, placeholder_count = external_cmd:gsub("%%s", "")
  if placeholder_count == 0 then
    vim.notify("external_terminal_cmd must contain '%s' placeholder(s)", vim.log.levels.ERROR)
    return
  elseif placeholder_count == 1 then
    full_command = string.format(external_cmd, cmd_string)
  elseif placeholder_count == 2 then
    local cwd = vim.fn.getcwd()
    full_command = string.format(external_cmd, cwd, cmd_string)
  else
    vim.notify(
      string.format(
        "external_terminal_cmd must use 1 or 2 '%%s' placeholders; got %d",
        placeholder_count
      ),
      vim.log.levels.ERROR
    )
    return
  end
else
  vim.notify(
    "external_terminal_cmd must be a string or function, got: " .. type(external_cmd),
    vim.log.levels.ERROR
  )
  return
end
```

**Phase 3: Test Coverage** (tests/unit/external_spec.lua)

```lua
it("should error if string command missing %s placeholder", function()
  local config = {
    provider_opts = {
      external_terminal_cmd = "alacritty -e claude"  -- Missing %s
    }
  }
  external_provider.setup(config)
  external_provider.open("claude --help", {})
  
  assert.spy(mock_vim.notify).was_called_with(
    "external_terminal_cmd must contain '%s' placeholder(s)",
    mock_vim.log.levels.ERROR
  )
end)
```

### Key Requirements for External Command

1. **String with %s placeholder:**
   - Single %s: Just the command
   - Double %s: CWD + command
   
2. **Function callable:**
   - Input: `(cmd_string: string, env_table: table)`
   - Output: `string or table`
   - Errors: Return nil/false

3. **Validation Points:**
   - Config-time: Type and %s presence
   - Runtime: Not nil, not empty string
   - Function result: Not nil, correct type

---

## 8. Migration Checklist

### For Removing a Configuration Option

- [ ] **Identify impact**: Search codebase for all usages
  ```bash
  grep -r "config\.old_option" lua/claudecode
  grep -r "opts\.old_option" lua/claudecode
  grep -r "old_option" lua/claudecode/terminal.lua
  ```

- [ ] **Create mapping code**: In `config.apply()` or provider `setup()`
  ```lua
  if config.old_option ~= nil then
    config.new_section.new_option = config.old_option
  end
  ```

- [ ] **Update validation**: Accept old option, validate both forms
  ```lua
  if config.old_option ~= nil then
    assert(type(config.old_option) == "expected", "error")
  end
  ```

- [ ] **Add tests**:
  - Test old option acceptance
  - Test new option acceptance
  - Test both provided (verify precedence)
  - Test invalid types for both

- [ ] **Update types.lua**: Keep old field if needed for compat

- [ ] **Update CLAUDE.md**: Document deprecation pattern

- [ ] **Create deprecation notice** (optional, for user visibility):
  ```lua
  if config.old_option ~= nil then
    logger.warn(
      "config",
      "old_option is deprecated, use new_section.new_option instead"
    )
  end
  ```

- [ ] **Run tests**: `make test`

- [ ] **Verify**: `make check`

- [ ] **Git history**: Reference similar migrations
  ```bash
  git log --oneline --grep="deprecated\|migration\|backward"
  ```

### For Adding a New Required Option

- [ ] **Add to defaults**: `config.lua:10-37`

- [ ] **Add to types**: `types.lua` with proper `@class` annotation

- [ ] **Add validation**: With clear error message

- [ ] **Add tests**: Both valid and invalid cases

- [ ] **Document**: In CLAUDE.md with examples

- [ ] **Update fixtures**: If relevant for manual testing
  ```bash
  ls fixtures/*/
  ```

---

## 9. Real-World Example: terminal_cmd Migration

### Scenario
Moving `config.terminal_cmd` from top-level to nested `config.terminal.terminal_cmd`

### Implementation

**Step 1: Add backward compat in config.lua** (after line 203)

```lua
-- Backward compatibility: map terminal_cmd to terminal.terminal_cmd
if config.terminal_cmd ~= nil and config.terminal == nil then
  config.terminal = { terminal_cmd = config.terminal_cmd }
elseif config.terminal_cmd ~= nil and config.terminal.terminal_cmd == nil then
  config.terminal.terminal_cmd = config.terminal_cmd
end
```

**Step 2: Update validation** (config.lua:56-57)

```lua
-- Accept terminal_cmd at both levels for backward compat
assert(
  config.terminal_cmd == nil or type(config.terminal_cmd) == "string",
  "terminal_cmd must be nil or a string"
)

-- Also validate nested version if present
if config.terminal and config.terminal.terminal_cmd then
  assert(
    type(config.terminal.terminal_cmd) == "string",
    "terminal.terminal_cmd must be a string"
  )
end
```

**Step 3: Update types.lua**

```lua
---@class ClaudeCodeConfig
---@field terminal_cmd string|nil  -- DEPRECATED: use terminal.terminal_cmd
```

**Step 4: Add tests** (tests/unit/config_spec.lua)

```lua
it("should map top-level terminal_cmd to nested structure", function()
  local config = config.apply({
    terminal_cmd = "custom-claude"
  })
  expect(config.terminal.terminal_cmd).to_be("custom-claude")
end)

it("should prefer nested terminal_cmd if both provided", function()
  local config = config.apply({
    terminal_cmd = "top-level",
    terminal = { terminal_cmd = "nested" }
  })
  expect(config.terminal.terminal_cmd).to_be("nested")
end)
```

**Step 5: Document** (CLAUDE.md)

```markdown
### Deprecated: terminal_cmd at top level

As of v0.3.0, `terminal_cmd` should be placed inside `terminal` config:

**Old (still works):**
```lua
require("claudecode").setup({
  terminal_cmd = "claude"
})
```

**New:**
```lua
require("claudecode").setup({
  terminal = {
    terminal_cmd = "claude"
  }
})
```

Both patterns work for now. This change groups all terminal-related 
configuration in one place.
```

---

## 10. Files to Reference

### Core Configuration Files

| File | Lines | Purpose |
|------|-------|---------|
| `lua/claudecode/config.lua` | 1-223 | Validation and application |
| `lua/claudecode/terminal.lua` | 360-494 | Terminal setup and validation |
| `lua/claudecode/init.lua` | 320-389 | Main entry point |
| `lua/claudecode/types.lua` | 1-143 | Type definitions |

### Test Files

| File | Lines | Purpose |
|------|-------|---------|
| `tests/unit/config_spec.lua` | 1-303 | Config validation tests |
| `tests/unit/terminal/external_spec.lua` | 1-300+ | External terminal tests |

### Related Commits

| Commit | Message | Relevance |
|--------|---------|-----------|
| `6af7df0` | fix: legacy diff options | Backward compat lesson |
| `678a582` | feat: redesign diff view | New option introduction |
| `e737c52` | feat: support function | Option type expansion |
| `fe08db9` | feat: add working directory | Nested config example |

---

## 11. Summary of Safe Patterns

### Three-Phase Validation Approach

```lua
Phase 1: Merge
  config = vim.tbl_deep_extend("force", defaults, user_config)

Phase 2: Normalize (Backward Compat)
  if config.old_option ~= nil then
    config.new_section.new_option = config.old_option
  end

Phase 3: Validate
  M.validate(config)
```

### Error Handling Strategy

```lua
Config-Time (setup):
  - Use assert() for fatal issues
  - Throw errors that prevent plugin load
  - Provide full context in message

Runtime (terminal setup):
  - Use vim.notify() for warnings
  - Continue with defaults
  - Allow plugin to function partially
```

### Backward Compatibility Pattern

```lua
1. Check if old option is provided
   if config.old_option ~= nil then

2. Map to new location
   config.new_section.new_option = config.old_option

3. Validate both old and new
   if config.old_option ~= nil then
     assert(valid_check, "error")
   end

4. Prefer old over new if both provided
   -- Old mapping overwrites new in merge
```

---

## 12. Key Takeaways for Safe Migration

1. **Backward compatibility first** - Users have existing configs
2. **Two-phase validation** - Accept both old and new formats
3. **Clear error messages** - Tell users what they should change
4. **Type flexibility** - Use `type()` checks, not nil checks
5. **Test thoroughly** - Both old and new usage patterns
6. **Document changes** - Update CLAUDE.md with migration guide
7. **Gradual deprecation** - Support old pattern for at least one release
8. **Validate at merge time** - After all merging, before use

---

**Generated:** Configuration Analysis for Safe Migration
**Relevant Version:** 0.2.0+
**Last Updated:** Based on commit 1552086
