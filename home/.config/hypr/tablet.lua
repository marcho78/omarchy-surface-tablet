-- Tablet mode. Active while ~/.local/state/tablet-mode/on exists; switched by
-- ~/.local/bin/tablet-mode, which reloads Hyprland so this file runs again.
local M = {}

local STATE = os.getenv("HOME") .. "/.local/state/tablet-mode"
local FLAG = STATE .. "/on"
local TAG = "tablet-maximized"

-- Windows smaller than this (in logical px) are dialogs and popups, left alone.
local MIN_WIDTH, MIN_HEIGHT = 700, 560

function M.active()
  local file = io.open(FLAG, "r")
  if file then
    file:close()
    return true
  end
  return false
end

-- Titlebar buttons are added by Omarchy with a fixed size, so the add call is
-- wrapped to make them finger-sized. Runs before Omarchy's defaults load.
local function patch_titlebar_buttons(size)
  local function patch(bars)
    if not bars then
      return
    end
    bars.__tablet_add = bars.__tablet_add or bars.add_button
    local add = bars.__tablet_add
    bars.add_button = size and function(button)
      button.size = size
      return add(button)
    end or add
  end

  patch(hl.plugin.hyprbars)
  hl.plugin.__tablet_load = hl.plugin.__tablet_load or hl.plugin.load
  local load = hl.plugin.__tablet_load
  hl.plugin.load = function(...)
    local result = load(...)
    patch(hl.plugin.hyprbars)
    return result
  end
end

function M.before()
  patch_titlebar_buttons(M.active() and 36 or nil)
end

local function is_app_window(window)
  if not window or window.pinned then
    return false
  end
  local workspace = window.workspace
  local id = workspace and tonumber(workspace.id)
  if not id or id < 1 then
    return false
  end
  local size = window.size or {}
  return (size[1] or size.x or 0) >= MIN_WIDTH or (size[2] or size.y or 0) >= MIN_HEIGHT
end

-- The area between the bar and the dock, "x y w h" in logical px, written by
-- tablet-mode once the tablet bar has settled.
local function app_area()
  local file = io.open(STATE .. "/geometry", "r")
  if not file then
    return nil
  end
  local x, y, w, h = file:read("*l"):match("(%d+) (%d+) (%d+) (%d+)")
  file:close()
  if not x then
    return nil
  end
  return tonumber(x), tonumber(y), tonumber(w), tonumber(h)
end

-- Remember where a window was on the desktop, once, so desktop mode can put
-- it back.
local function remember(window)
  local path = STATE .. "/original/" .. window.address
  local existing = io.open(path, "r")
  if existing then
    existing:close()
    return
  end
  local file = io.open(path, "w")
  if file then
    local at, size = window.at or {}, window.size or {}
    file:write(string.format("%d %d %d %d\n", at.x or 0, at.y or 0, size.x or 0, size.y or 0))
    file:close()
  end
end

-- Apps fill the screen between the bar and the dock rather than maximizing,
-- so they keep their titlebar (minimize/close) and the dock stays in view.
local function fill(window)
  if not is_app_window(window) or not window.floating or (window.fullscreen or 0) == 2 then
    return
  end
  local x, y, w, h = app_area()
  if not x then
    return
  end
  local at, size = window.at or {}, window.size or {}
  if (window.fullscreen or 0) == 0 and at.x == x and at.y == y and size.x == w and size.y == h then
    return
  end
  remember(window)
  if (window.fullscreen or 0) == 1 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = window }))
  end
  hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = window }))
  hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = window }))
  hl.dispatch(hl.dsp.window.tag({ tag = "+" .. TAG, window = window }))
end

local function fill_soon(window)
  -- Let Omarchy's own open/arrange handlers settle first.
  hl.timer(function()
    fill(window)
  end, { type = "oneshot", timeout = 120 })
end

-- Swiping between workspaces, in desktop and tablet mode alike: drag in from
-- the left or right edge of the touchscreen, or three fingers on the Type
-- Cover's touchpad.
local function workspace_swipes()
  hl.config({ gestures = { workspace_swipe_touch = true } })
  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
end

function M.after()
  workspace_swipes()

  if not M.active() then
    return
  end

  -- Motion, tablet style. Omarchy has workspace animations off; here the
  -- workspaces slide, so a swipe glides on into place after the finger
  -- lifts. Apps open with a slight spring, and resize smoothly when the
  -- keyboard comes and goes.
  hl.curve("tabletSpring", { type = "bezier", points = { { 0.3, 1.12 }, { 0.5, 1 } } })
  hl.curve("tabletGlide", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
  hl.curve("tabletAway", { type = "bezier", points = { { 0.4, 0 }, { 0.8, 0.6 } } })
  hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "tabletGlide", style = "slide" })
  hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.6, bezier = "tabletSpring", style = "popin 85%" })
  hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "tabletAway", style = "popin 90%" })
  hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "tabletGlide" })
  hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "tabletGlide", style = "slide" })
  hl.animation({ leaf = "layersOut", enabled = true, speed = 2.2, bezier = "tabletAway", style = "slide" })

  -- Frosted glass behind the Notification Center and app drawer, as on an
  -- iPad. Only see-through surfaces get blurred; the Control Center stays clear.
  hl.config({
    decoration = {
      blur = {
        enabled = true,
        size = 10,
        passes = 3,
        new_optimizations = true,
        xray = false,
        brightness = 0.7,
        vibrancy = 0.3,
        noise = 0.01,
      },
    },
  })
  hl.layer_rule({ match = { namespace = "^devsecai-(notification-center|app-drawer|app-switcher)$" }, blur = true, ignore_alpha = 0.05 })

  -- The keyboard and its suggestion strip slide up from the bottom edge together.
  -- The panels animate themselves: a full-screen sheet slid in by Hyprland
  -- comes down from the top edge, over the bar, as if dragging it along.
  -- The swipe strips are invisible.
  hl.layer_rule({ match = { namespace = "^(wvkbd|osk|devsecai-osk-strip)$" }, animation = "slide" })
  hl.layer_rule({ match = { namespace = "^devsecai-(control-center|notification-center|app-drawer|app-switcher|radial-menu|gesture-.*)$" }, no_anim = true, animation = "none" })

  hl.config({
    general = { gaps_in = 6, gaps_out = 10, border_size = 2 },
    decoration = { rounding = 14 },
    cursor = { hide_on_touch = true },
  })

  if hl.plugin.hyprbars then
    hl.config({
      plugin = {
        hyprbars = {
          bar_height = 52,
          bar_text_font = "sans-serif",
          bar_text_size = 15,
          bar_text_weight = "bold",
          bar_text_align = "center",
          bar_padding = 18,
          bar_button_padding = 14,
          button_rounding = 18,
        },
      },
    })
  end

  -- Every app opens full screen, and one brought back from the dock fills the
  -- screen again when it takes focus.
  hl.on("window.open", fill_soon)
  hl.on("window.active", fill_soon)
end

return M
