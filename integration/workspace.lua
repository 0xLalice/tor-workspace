-- Named workspace: the onion remains separate from Omarchy's numbered slots.
local target = "name:Tor"
hl.workspace_rule({ workspace = target, persistent = true })

-- Retire the numbered workspace allocated by the short-lived numbered layout.
-- Only the saved plugin-owned number is migrated; ordinary workspace moves
-- are never intercepted or reversed.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local state = config .. "/omarchy/tor-workspace-number"
local file = io.open(state, "r")
local number = file and tonumber(file:read("*l")) or nil
if file then file:close() end
if number and number > 0 and number % 1 == 0 then
  hl.workspace_rule({ workspace = tostring(number), persistent = false })
  hl.timer(function()
    local active = hl.get_active_workspace()
    for _, window in ipairs(hl.get_windows()) do
      if window.workspace and window.workspace.id == number then
        hl.dispatch(hl.dsp.window.move({window = "address:" .. window.address, workspace = target, follow = false}))
      end
    end
    if active and active.id == number then hl.dispatch(hl.dsp.focus({workspace = target})) end
    os.remove(state)
  end, {timeout = 1, type = "oneshot"})
else
  os.remove(state)
end

-- Initial placement only; users can move these windows with their usual bindings.
o.window('^org\\.omarchy\\.tor-terminal$', { workspace = target })
o.window('^org\\.omarchy\\.tor-browser$', { workspace = target })

-- Reapply user-owned shortcuts after defaults and user bindings have loaded.
-- The helper checks live bindings and only removes handles it created itself.
if hl.exec_cmd then
  local source = debug.getinfo(1, "S").source:sub(2)
  local helper = source:gsub("integration/workspace.lua$", "backend/shortcuts.py")
  local quoted = "'" .. helper:gsub("'", "'\\''") .. "'"
  hl.timer(function() hl.exec_cmd("python3 -B " .. quoted .. " sync") end,
           {timeout = 1000, type = "oneshot"})
end
