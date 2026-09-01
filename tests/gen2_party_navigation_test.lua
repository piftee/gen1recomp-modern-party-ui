-- Standalone: luajit mods/modern_party_ui/tests/gen2_party_navigation_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local total, failed = 0, 0
local function eq(actual, expected, label)
  total = total + 1
  if actual ~= expected then
    failed = failed + 1
    io.stderr:write(("not ok %d - %s (expected %s, got %s)\n"):format(
      total, label, tostring(expected), tostring(actual)))
  else
    print(("ok %d - %s"):format(total, label))
  end
end

local NativePartyMenu = {}
function NativePartyMenu.new(game, opts)
  local menu = {
    game = game,
    party = opts.party,
    index = 1,
    clock = 0,
  }
  function menu:update()
    self.clock = self.clock + 1
    if self.game.input:wasPressed("up") then
      self.index = self.index > 1 and self.index - 1 or #self.party
    elseif self.game.input:wasPressed("down") then
      self.index = self.index < #self.party and self.index + 1 or 1
    end
  end
  return menu
end

local screens = {}
local stubs = {
  ["src.ui.gen2.Chrome"] = {},
  ["src.render.Font"] = {},
  ["src.render.GbcPalette"] = {},
  ["src.battle.gen2.HpBar"] = {},
  ["src.battle.gen2.Mon"] = {},
  ["src.world.gen2.Palettes"] = {},
  ["src.ui.gen2.PartyMenu"] = NativePartyMenu,
  ["src.ui.gen2.SummaryMenu"] = { new = function() return {} end },
  ["src.ui.gen2.NamingScreen"] = { new = function() return {} end },
}
for name, value in pairs(stubs) do package.loaded[name] = value end

local mod = {
  options = { get = function() return nil end },
  exports = {},
  log = { info = function() end },
  content = { screens = {
    get = function(_, id) return screens[id] end,
    register = function(_, id, record) screens[id] = record end,
    override = function(_, id, record) screens[id] = record end,
  } },
}
dofile("mods/modern_party_ui/gen2.lua")(mod)

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end
local party = { {}, {}, {}, {}, {}, {} }
local menu = screens.Gen2PartyMenu.new({ input = input }, { party = party })
menu.modernPartyLastWideWidth = 246

local function press(key)
  input.pressed[key] = true
  menu:update(0)
  input.pressed[key] = nil
end

press("right")
eq(menu.index, 2, "wide RIGHT crosses the first card row")
press("down")
eq(menu.index, 4, "wide DOWN stays in the right card column")
press("left")
eq(menu.index, 3, "wide LEFT crosses the second card row")
press("down")
eq(menu.index, 5, "wide DOWN reaches the bottom-left card")
press("right")
eq(menu.index, 6, "wide RIGHT crosses the bottom card row")
press("up")
eq(menu.index, 4, "wide UP stays in the right card column")
eq(menu.clock, 6, "the native controller receives every input update")

if failed > 0 then
  error(("%d of %d Gen 2 party navigation checks failed"):format(
    failed, total), 0)
end
print(("%d/%d Gen 2 party navigation checks passed"):format(total, total))
