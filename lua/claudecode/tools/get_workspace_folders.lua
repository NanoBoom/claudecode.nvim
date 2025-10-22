--- Tool implementation for getting workspace folders.

local schema = {
  description = "Get all workspace folders currently open in the IDE",
  inputSchema = {
    type = "object",
    additionalProperties = false,
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
  },
}

---Handles the getWorkspaceFolders tool invocation.
---Retrieves workspace folders using the same logic as lockfile.
---@return table MCP-compliant response with workspace folders data
local function handler(params)
  local tools = require("claudecode.tools.init")
  local lockfile = require("claudecode.lockfile")

  -- Get workspace folders using the same logic as lockfile
  local workspace_folders = lockfile.get_workspace_folders(tools.config)

  -- Convert to MCP format
  local folders = {}
  for _, folder_path in ipairs(workspace_folders) do
    table.insert(folders, {
      name = vim.fn.fnamemodify(folder_path, ":t"),
      uri = "file://" .. folder_path,
      path = folder_path,
    })
  end

  -- Return MCP-compliant format with JSON-stringified workspace data
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          success = true,
          folders = folders,
          rootPath = vim.fn.getcwd(),
        }, { indent = 2 }),
      },
    },
  }
end

return {
  name = "getWorkspaceFolders",
  schema = schema,
  handler = handler,
}
