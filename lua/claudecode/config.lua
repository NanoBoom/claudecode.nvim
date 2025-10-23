---@brief [[
--- Manages configuration for the Claude Code Neovim integration.
--- Provides default settings, validation, and application of user-defined configurations.
---@brief ]]
---@module 'claudecode.config'

local M = {}

---@type ClaudeCodeConfig
M.defaults = {
  port_range = { min = 10000, max = 65535 },
  auto_start = true,
  external_terminal_cmd = nil, -- Required: command to launch Claude in external terminal (e.g., "alacritty -e %s")
  workspace_folders_fn = nil, -- Optional: custom function to compute workspace folders
  log_level = "info",
  track_selection = true,
  visual_demotion_delay_ms = 50, -- Milliseconds to wait before demoting a visual selection
  connection_wait_delay = 600, -- Milliseconds to wait after connection before sending queued @ mentions
  connection_timeout = 10000, -- Maximum time to wait for Claude Code to connect (milliseconds)
  queue_timeout = 5000, -- Maximum time to keep @ mentions in queue (milliseconds)
  lockfile_check_interval = 5000, -- Interval to check lockfile existence (milliseconds, 5 seconds)
  diff_opts = {
    layout = "vertical",
    open_in_new_tab = false, -- Open diff in a new tab (false = use current tab)
    on_new_file_reject = "keep_empty", -- "keep_empty" leaves an empty buffer; "close_window" closes the placeholder split
  },
  models = {
    { name = "Claude Opus 4.1 (Latest)", value = "opus" },
    { name = "Claude Sonnet 4.5 (Latest)", value = "sonnet" },
    { name = "Opusplan: Claude Opus 4.1 (Latest) + Sonnet 4.5 (Latest)", value = "opusplan" },
    { name = "Claude Haiku 4.5 (Latest)", value = "haiku" },
  },
}

---Validates the provided configuration table.
---Throws an error if any validation fails.
---@param config table The configuration table to validate.
---@return boolean true if the configuration is valid.
function M.validate(config)
  assert(
    type(config.port_range) == "table"
      and type(config.port_range.min) == "number"
      and type(config.port_range.max) == "number"
      and config.port_range.min > 0
      and config.port_range.max <= 65535
      and config.port_range.min <= config.port_range.max,
    "Invalid port range"
  )

  assert(type(config.auto_start) == "boolean", "auto_start must be a boolean")

  -- Validate external_terminal_cmd (optional but recommended)
  if config.external_terminal_cmd ~= nil then
    local cmd_type = type(config.external_terminal_cmd)
    assert(
      cmd_type == "string" or cmd_type == "function",
      "external_terminal_cmd must be a string or function"
    )
    -- Only validate %s placeholder for strings
    if cmd_type == "string" and config.external_terminal_cmd ~= "" then
      assert(
        config.external_terminal_cmd:find("%%s"),
        "external_terminal_cmd must contain '%s' placeholder for the Claude command"
      )
    end
  end

  -- Validate workspace_folders_fn (optional)
  if config.workspace_folders_fn ~= nil then
    local fn_type = type(config.workspace_folders_fn)
    assert(
      fn_type == "function",
      "workspace_folders_fn must be a function"
    )
  end

  local valid_log_levels = { "trace", "debug", "info", "warn", "error" }
  local is_valid_log_level = false
  for _, level in ipairs(valid_log_levels) do
    if config.log_level == level then
      is_valid_log_level = true
      break
    end
  end
  assert(is_valid_log_level, "log_level must be one of: " .. table.concat(valid_log_levels, ", "))

  assert(type(config.track_selection) == "boolean", "track_selection must be a boolean")

  assert(
    type(config.visual_demotion_delay_ms) == "number" and config.visual_demotion_delay_ms >= 0,
    "visual_demotion_delay_ms must be a non-negative number"
  )

  assert(
    type(config.connection_wait_delay) == "number" and config.connection_wait_delay >= 0,
    "connection_wait_delay must be a non-negative number"
  )

  assert(
    type(config.connection_timeout) == "number" and config.connection_timeout > 0,
    "connection_timeout must be a positive number"
  )

  assert(type(config.queue_timeout) == "number" and config.queue_timeout > 0, "queue_timeout must be a positive number")

  assert(
    type(config.lockfile_check_interval) == "number"
      and config.lockfile_check_interval >= 1000
      and config.lockfile_check_interval <= 60000,
    "lockfile_check_interval must be a number between 1000 and 60000 (1-60 seconds)"
  )

  assert(type(config.diff_opts) == "table", "diff_opts must be a table")
  -- New diff options (optional validation to allow backward compatibility)
  if config.diff_opts.layout ~= nil then
    assert(
      config.diff_opts.layout == "vertical" or config.diff_opts.layout == "horizontal",
      "diff_opts.layout must be 'vertical' or 'horizontal'"
    )
  end
  if config.diff_opts.open_in_new_tab ~= nil then
    assert(type(config.diff_opts.open_in_new_tab) == "boolean", "diff_opts.open_in_new_tab must be a boolean")
  end
  if config.diff_opts.on_new_file_reject ~= nil then
    assert(
      type(config.diff_opts.on_new_file_reject) == "string"
        and (
          config.diff_opts.on_new_file_reject == "keep_empty" or config.diff_opts.on_new_file_reject == "close_window"
        ),
      "diff_opts.on_new_file_reject must be 'keep_empty' or 'close_window'"
    )
  end

  -- Legacy diff options (accept if present to avoid breaking old configs)
  if config.diff_opts.auto_close_on_accept ~= nil then
    assert(type(config.diff_opts.auto_close_on_accept) == "boolean", "diff_opts.auto_close_on_accept must be a boolean")
  end
  if config.diff_opts.show_diff_stats ~= nil then
    assert(type(config.diff_opts.show_diff_stats) == "boolean", "diff_opts.show_diff_stats must be a boolean")
  end
  if config.diff_opts.vertical_split ~= nil then
    assert(type(config.diff_opts.vertical_split) == "boolean", "diff_opts.vertical_split must be a boolean")
  end
  if config.diff_opts.open_in_current_tab ~= nil then
    assert(type(config.diff_opts.open_in_current_tab) == "boolean", "diff_opts.open_in_current_tab must be a boolean")
  end

  -- Validate models
  assert(type(config.models) == "table", "models must be a table")
  assert(#config.models > 0, "models must not be empty")

  for i, model in ipairs(config.models) do
    assert(type(model) == "table", "models[" .. i .. "] must be a table")
    assert(type(model.name) == "string" and model.name ~= "", "models[" .. i .. "].name must be a non-empty string")
    assert(type(model.value) == "string" and model.value ~= "", "models[" .. i .. "].value must be a non-empty string")
  end

  return true
end

---Applies user configuration on top of default settings and validates the result.
---@param user_config table|nil The user-provided configuration table.
---@return ClaudeCodeConfig config The final, validated configuration table.
function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)

  -- Detect old terminal configuration and provide migration guidance
  if user_config and user_config.terminal then
    local terminal = user_config.terminal
    local old_config_keys = {
      "split_side",
      "split_width_percentage",
      "provider",
      "show_native_term_exit_tip",
      "auto_close",
      "snacks_win_opts",
      "cwd",
      "git_repo_cwd",
      "cwd_provider",
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
      -- Note: Logger might not be available yet, so we'll skip the warning
    end
  end

  -- Detect and warn about other removed top-level options
  if user_config and user_config.focus_after_send ~= nil then
    -- Silently ignore - this option is no longer used
  end

  if user_config then
    -- Use vim.tbl_deep_extend if available, otherwise simple merge
    if vim.tbl_deep_extend then
      config = vim.tbl_deep_extend("force", config, user_config)
    else
      -- Simple fallback for testing environment
      for k, v in pairs(user_config) do
        config[k] = v
      end
    end
  end

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

  M.validate(config)

  return config
end

return M
