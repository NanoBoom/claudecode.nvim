require("tests.busted_setup") -- Ensure test helpers are loaded

describe("Tool: get_workspace_folders", function()
  local get_workspace_folders_handler

  before_each(function()
    package.loaded["claudecode.tools.get_workspace_folders"] = nil
    get_workspace_folders_handler = require("claudecode.tools.get_workspace_folders").handler

    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.json = _G.vim.json or {}

    -- Mock vim.json.encode
    _G.vim.json.encode = spy.new(function(data, opts)
      return require("tests.busted_setup").json_encode(data)
    end)

    -- Default mocks
    _G.vim.fn.getcwd = spy.new(function()
      return "/mock/project/root"
    end)
    _G.vim.fn.fnamemodify = spy.new(function(path, mod)
      if mod == ":t" then
        local parts = {}
        for part in string.gmatch(path, "[^/]+") do
          table.insert(parts, part)
        end
        return parts[#parts] or ""
      end
      return path
    end)
  end)

  after_each(function()
    package.loaded["claudecode.tools.get_workspace_folders"] = nil
    _G.vim.fn.getcwd = nil
    _G.vim.fn.fnamemodify = nil
    _G.vim.json.encode = nil
  end)

  it("should return the current working directory as the only workspace folder", function()
    local success, result = pcall(get_workspace_folders_handler, {})
    expect(success).to_be_true()
    expect(result).to_be_table()
    expect(result.content).to_be_table()
    expect(result.content[1]).to_be_table()
    expect(result.content[1].type).to_be("text")

    local parsed_result = require("tests.busted_setup").json_decode(result.content[1].text)
    expect(parsed_result.success).to_be_true()
    expect(parsed_result.folders).to_be_table()
    expect(#parsed_result.folders).to_be(1)
    expect(parsed_result.rootPath).to_be("/mock/project/root")

    local folder = parsed_result.folders[1]
    expect(folder.name).to_be("root")
    expect(folder.uri).to_be("file:///mock/project/root")
    expect(folder.path).to_be("/mock/project/root")

    assert.spy(_G.vim.fn.getcwd).was_called()
    assert.spy(_G.vim.fn.fnamemodify).was_called_with("/mock/project/root", ":t")
  end)

  it("should handle different CWD paths correctly", function()
    _G.vim.fn.getcwd = spy.new(function()
      return "/another/path/project_name"
    end)
    local success, result = pcall(get_workspace_folders_handler, {})
    expect(success).to_be_true()
    expect(result.content).to_be_table()

    local parsed_result = require("tests.busted_setup").json_decode(result.content[1].text)
    expect(#parsed_result.folders).to_be(1)
    local folder = parsed_result.folders[1]
    expect(folder.name).to_be("project_name")
    expect(folder.uri).to_be("file:///another/path/project_name")
    expect(folder.path).to_be("/another/path/project_name")
  end)

  -- TODO: Add tests when LSP workspace folder integration is implemented in the tool.
  -- This would involve mocking vim.lsp.get_clients() and its return structure.

  describe("with custom workspace_folders_fn", function()
    before_each(function()
      -- Mock tools module to return config with custom function
      package.loaded["claudecode.tools.init"] = nil
      local tools_module = require("claudecode.tools.init")
      tools_module.config = {
        workspace_folders_fn = function(basename)
          return {"/custom/path/1", "/custom/path/2"}
        end
      }

      -- Mock lockfile module to use custom function
      package.loaded["claudecode.lockfile"] = nil
      local lockfile_module = require("claudecode.lockfile")
      lockfile_module.get_workspace_folders = spy.new(function(config)
        if config and config.workspace_folders_fn then
          return config.workspace_folders_fn("test")
        end
        return {"/default/path"}
      end)
    end)

    after_each(function()
      package.loaded["claudecode.tools.init"] = nil
      package.loaded["claudecode.lockfile"] = nil
    end)

    it("should use custom workspace folders when configured", function()
      local success, result = pcall(get_workspace_folders_handler, {})
      expect(success).to_be_true()
      expect(result).to_be_table()
      expect(result.content).to_be_table()

      local parsed_result = require("tests.busted_setup").json_decode(result.content[1].text)
      expect(parsed_result.success).to_be_true()
      expect(parsed_result.folders).to_be_table()
      expect(#parsed_result.folders).to_be(2)

      local folder1 = parsed_result.folders[1]
      expect(folder1.name).to_be("1")
      expect(folder1.uri).to_be("file:///custom/path/1")
      expect(folder1.path).to_be("/custom/path/1")

      local folder2 = parsed_result.folders[2]
      expect(folder2.name).to_be("2")
      expect(folder2.uri).to_be("file:///custom/path/2")
      expect(folder2.path).to_be("/custom/path/2")

      -- Verify lockfile.get_workspace_folders was called with config
      assert.spy(require("claudecode.lockfile").get_workspace_folders).was_called_with(
        require("claudecode.tools.init").config
      )
    end)
  end)
end)
