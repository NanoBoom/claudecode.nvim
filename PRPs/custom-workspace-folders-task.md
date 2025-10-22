# TASK PRP: Custom Workspace Folders Function

## Context

### Current State

- Lockfile creates workspace folders from CWD + LSP workspace folders
- No user customization available for workspace folders
- Configuration system supports function-based options (external_terminal_cmd precedent)

### Target State

Allow users to define custom workspace folders logic via config function:

```lua
require("claudecode").setup({
  workspace_folders_fn = function(basename)
    -- Return custom workspace folders array
    return {"/custom/path"}
  end
})
```

## Tasks

### TASK 1: Add workspace_folders_fn to config schema

**FILE**: `lua/claudecode/config.lua`

- Add `workspace_folders_fn` to default config with nil value
- Add validation: must be function or nil
- Update type definitions in `lua/claudecode/types.lua`

**VALIDATE**: `make check` passes
**IF_FAIL**: Check type definitions and validation logic
**ROLLBACK**: Remove config field and validation

### TASK 2: Modify lockfile workspace folders logic

**FILE**: `lua/claudecode/lockfile.lua`

- In `get_workspace_folders()` function, check if `config.workspace_folders_fn` exists
- If exists: call function with basename parameter and return result
- If not exists: use existing logic (CWD + LSP folders)

**VALIDATE**: Test with mock function in config
**IF_FAIL**: Check function calling and error handling
**ROLLBACK**: Revert to original get_workspace_folders logic

### TASK 3: Update MCP tool to use same logic

**FILE**: `lua/claudecode/tools/get_workspace_folders.lua`

- Extract workspace folders logic to shared function
- Ensure MCP tool uses same logic as lockfile
- Maintain VS Code extension compatibility

**VALIDATE**: MCP tool returns same folders as lockfile
**IF_FAIL**: Check shared logic implementation
**ROLLBACK**: Revert MCP tool to original implementation

### TASK 4: Add comprehensive tests

**FILE**: Create `tests/unit/custom_workspace_folders_spec.lua`

- Test with nil function (default behavior)
- Test with custom function returning folders
- Test error handling for invalid function returns
- Test basename parameter passing

**VALIDATE**: `make test` passes all new tests
**IF_FAIL**: Fix test assertions and function logic
**ROLLBACK**: Remove test file

### TASK 5: Update documentation

**FILE**: `CLAUDE.md`

- Add workspace_folders_fn configuration example
- Document function signature and expected return type
- Update configuration section

**VALIDATE**: Documentation renders correctly
**IF_FAIL**: Fix markdown formatting
**ROLLBACK**: Revert documentation changes

## Risk Assessment

### High Risk Areas

- **MCP compatibility**: Must maintain VS Code extension format
- **Backward compatibility**: Default behavior must remain unchanged

### Mitigation Strategies

- Extensive testing with both function and nil configurations
- Validate MCP tool output format matches existing
- Ensure lockfile format remains compatible

## Success Criteria

- [ ] Users can define custom workspace folders via function
- [ ] Default behavior unchanged when function not provided
- [ ] MCP tool and lockfile use identical logic
- [ ] All existing tests pass
- [ ] New feature documented

## Debug Patterns

### Function Not Called

- Check config validation passes
- Verify function exists before calling
- Add debug logging to function call

### Invalid Return Type

- Validate function returns table/array
- Handle nil/empty returns gracefully
- Add type checking in shared logic

### MCP Format Mismatch

- Compare tool output with existing format
- Ensure URI/path fields properly formatted
- Test with Claude CLI integration

