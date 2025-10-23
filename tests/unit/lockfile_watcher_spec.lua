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
