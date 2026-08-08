-- Standalone: luajit mods/modern_party_ui/tests/modern_party_ui_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local PartyMenu = require("src.ui.PartyMenu")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Runtime = require("src.mods.Runtime")

local data = T.fixtures.fresh()
data.icons = {
  icons = {}, byDex = {},
  bySpecies = {
    -- Represents a menu-icon record supplied by a separate content mod.
    FIXMON_A = {
      image = "mods/companion_sprite_pack/assets/fixmon_a_icon.png",
      frames = 2,
    },
  },
}
data.palettes = {
  palettes = {
    BLUEMON = {
      { 255, 255, 255 }, { 130, 180, 245 },
      { 30, 80, 175 }, { 0, 0, 0 },
    },
    EXP = {
      { 255, 255, 255 }, { 190, 220, 255 },
      { 25, 120, 245 }, { 0, 0, 0 },
    },
    GRAYMON = {
      { 255, 255, 255 }, { 170, 170, 170 },
      { 85, 85, 85 }, { 0, 0, 0 },
    },
    GREENMON = {
      { 255, 255, 255 }, { 150, 220, 150 },
      { 30, 130, 45 }, { 0, 0, 0 },
    },
    REDMON = {
      { 255, 255, 255 }, { 240, 160, 145 },
      { 175, 45, 35 }, { 0, 0, 0 },
    },
    GREENBAR = {
      { 255, 255, 255 }, { 170, 220, 170 },
      { 40, 150, 40 }, { 0, 0, 0 },
    },
    YELLOWBAR = {
      { 255, 255, 255 }, { 240, 220, 120 },
      { 190, 145, 20 }, { 0, 0, 0 },
    },
    REDBAR = {
      { 255, 255, 255 }, { 240, 160, 150 },
      { 190, 55, 45 }, { 0, 0, 0 },
    },
    MEWMON = {
      { 255, 255, 255 }, { 210, 185, 235 },
      { 115, 75, 160 }, { 0, 0, 0 },
    },
  },
  pokemon = {
    FIXMON_A = "GREENMON", FIXMON_B = "REDMON", FIXMON_C = "BLUEMON",
  },
}

Font.load(data)
local previousMode = PaletteFX.mode
PaletteFX.setMode("gbc")

local run = T.sdk.loadMod("mods/modern_party_ui", { data = data, dev = true })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local schema = run.loader.optionSchemas.modern_party_ui or {}
T.eq(#schema, 8, "all eight presentation settings are registered")
T.eq(run.loader.modOptions.modern_party_ui, nil,
  "defaults require no persisted option bucket")

local optionGame = {
  data = run.data,
  save = { options = {} },
  mods = run.loader,
}
local mainOptionRows = Runtime.call("ui.options.rows",
  function(_, rows) return rows end, optionGame, { { id = "text_speed" } })
T.eq(#mainOptionRows, 9,
  "all eight mod settings are mirrored into the main Options menu")
T.eq(mainOptionRows[2].id, "modern_party_ui_card_color",
  "the party settings follow the game's own option rows")
T.eq(mainOptionRows[2].value(optionGame), "TYPE",
  "main Options reads the same default as the mod manager")
mainOptionRows[2].step(optionGame, 1)
T.eq(run.loader.modOptions.modern_party_ui.card_color, "species_palette",
  "main Options exposes the original species palette after the type default")
T.eq(optionGame.save.options.modOptions.modern_party_ui.card_color,
  "species_palette",
  "main Options persists the explicit species-palette choice")
T.eq(mainOptionRows[4].id, "modern_party_ui_exp_text",
  "the EXP display has its own main Options row")
T.eq(mainOptionRows[4].value(optionGame), "PERCENT",
  "the EXP display defaults to a useful percentage")
mainOptionRows[4].step(optionGame, -1)
T.eq(run.loader.modOptions.modern_party_ui.exp_text, "values",
  "the EXP display cycles independently through its configured modes")
run.loader.modOptions.modern_party_ui = nil

local record = run.data.screens and run.data.screens.PartyMenu
T.check(type(record) == "table" and type(record.new) == "function",
  "the PartyMenu screen record is registered")

local function mon(species, name, level, hp, maxHP, status)
  return {
    species = species, nickname = name, level = level,
    exp = level * level * level,
    hp = hp, stats = { hp = maxHP }, status = status,
    moves = { { id = "FIX_TACKLE" } },
  }
end

local party = {
  mon("FIXMON_A", "LEAF", 12, 45, 45),
  mon("FIXMON_B", "EMBER", 10, 20, 39, "PSN"),
  mon("FIXMON_C", "SPLASH", 14, 6, 44),
  mon("FIXMON_A", "BUD", 8, 0, 30),
  mon("FIXMON_B", "CINDER", 20, 50, 60),
  mon("FIXMON_C", "BUBBLE", 18, 34, 50),
}

local stack = { states = {} }
function stack:push(state) self.states[#self.states + 1] = state end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local input = { pressed = {} }
function input:wasPressed(key) return self.pressed[key] == true end

local game = {
  data = run.data,
  save = { party = party, inventory = {}, options = {} },
  stack = stack,
  input = input,
}

local screen = record.new(game, {})
T.check(screen.modernPartyUI == true, "the modern presentation is installed")
T.eq(screen.modernPartyLayout, "cards", "the card-grid layout is identified")
T.eq(getmetatable(screen), PartyMenu,
  "the screen keeps the original PartyMenu controller")
T.eq(screen.animateTo, PartyMenu.animateTo,
  "the original medicine animation behavior is retained")
T.eq(screen:bottomMessage(), "Choose a POKéMON.",
  "the original contextual prompt is retained")

-- Responsive sizing uses as much integer-scaled horizontal room as the
-- current window permits, and collapses to the classic surface by setting.
local graphics = love.graphics
local realPixelDimensions = graphics.getPixelDimensions
graphics.getPixelDimensions = function() return 1280, 720 end
T.eq(select(1, screen:uiSize()), 256,
  "a 16:9 window exposes a 256x144 responsive UI surface")
run.loader.modOptions.modern_party_ui = { responsive = false }
T.eq(select(1, screen:uiSize()), 160,
  "the WIDESCREEN setting can restore the classic width")
run.loader.modOptions.modern_party_ui = nil
graphics.getPixelDimensions = realPixelDimensions

game.renderer = { uiSize = function() return 256, 144 end }
local wideZones = screen:sgbPalettes(game) or {}
T.eq(wideZones[1].w, 256, "palette coverage expands with the wide surface")
T.eq(wideZones[2].w, 128, "wide cards divide the full width into two columns")
T.check(screen:isWideBattleLayout(),
  "the screen opts into full-width rendering inside wide battles")
run.loader.modOptions.modern_party_ui = { responsive = false }
T.check(not screen:isWideBattleLayout(),
  "disabling WIDESCREEN restores centered behavior inside wide battles")
run.loader.modOptions.modern_party_ui = nil
game.renderer = nil

-- Drawing delegates every occupied card to PartyMenu.drawIcon. That helper
-- is the engine's compatibility seam for icons.bySpecies, asset overrides,
-- animation, and pokemon.icon hooks from other mods.
local realDrawIcon = PartyMenu.drawIcon
local iconCalls = {}
local trueColorMarks = {}
local fractionalScales = {}
local iconBackgrounds = {}
local cardLayers = {}
local drawnText = {}
local realMarkTrueColor = PaletteFX.markTrueColor
local realScale = graphics.scale
local realRectangle = graphics.rectangle
local realPolygon = graphics.polygon
local realFontDraw = Font.draw
PartyMenu.drawIcon = function(_, drawn, x, y, selected)
  iconCalls[#iconCalls + 1] = {
    mon = drawn, x = x, y = y, selected = selected,
  }
  return true
end
PaletteFX.markTrueColor = function(x, y, w, h)
  trueColorMarks[#trueColorMarks + 1] = { x = x, y = y, w = w, h = h }
end
graphics.scale = function(x, y)
  fractionalScales[#fractionalScales + 1] = { x = x, y = y }
end
graphics.rectangle = function(mode, x, y, w, h)
  if mode == "fill" and w == 16 and h == 16 then
    local r, g, b = graphics.getColor()
    iconBackgrounds[#iconBackgrounds + 1] = { r = r, g = g, b = b }
  end
  return realRectangle(mode, x, y, w, h)
end
graphics.polygon = function(mode, points)
  local r, g, b, a = graphics.getColor()
  cardLayers[#cardLayers + 1] = {
    mode = mode, points = points, color = { r, g, b, a },
  }
  if realPolygon then return realPolygon(mode, points) end
end
Font.draw = function(text, x, y)
  drawnText[#drawnText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
run.loader.modOptions.modern_party_ui = {
  hp_text = "values", exp_text = "percent",
}
local ok, drawErr = pcall(screen.draw, screen)
PartyMenu.drawIcon = realDrawIcon
PaletteFX.markTrueColor = realMarkTrueColor
graphics.scale = realScale
graphics.rectangle = realRectangle
graphics.polygon = realPolygon
Font.draw = realFontDraw
run.loader.modOptions.modern_party_ui = nil
T.check(ok, "the card grid draws headlessly: " .. tostring(drawErr))
T.eq(#iconCalls, #party, "every occupied card uses the shared icon renderer")
T.eq(iconCalls[1].mon, party[1], "the shared renderer receives the live mon")
T.eq(iconCalls[1].x, 5,
  "the compact icon is horizontally centered in its available column")
T.eq(iconCalls[1].y, 21,
  "the icon is vertically centered above the meter rows")
T.eq(#trueColorMarks, 2,
  "authored replacement icons are protected from the card palette")
T.eq(trueColorMarks[1].x, 5,
  "true-colour protection follows the first card's icon position")
T.eq(trueColorMarks[1].y, 21,
  "true-colour protection follows the first card's icon row")
T.eq(#iconBackgrounds, 2,
  "replacement icon transparency receives a colour-matched card backing")
T.eq(iconBackgrounds[1].g, 208 / 255,
  "the selected replacement icon backing uses its card's display colour")
T.eq(cardLayers[2].color[1], 0,
  "the selected party card uses a dominant black outer frame")
T.eq(cardLayers[2].points[1], 4,
  "the selected frame grows one pixel beyond its normal card geometry")
T.eq(cardLayers[2].points[2], 16,
  "the selected frame is raised one pixel without moving card contents")
T.eq(#fractionalScales, 0,
  "the native tile font is never fractionally scaled")
local hpOverlay, expOverlay
for _, call in ipairs(drawnText) do
  if call.text == "45/45" then hpOverlay = call end
  if call.y == 47 and call.text:match("^%d+$") then expOverlay = call end
end
T.check(hpOverlay and hpOverlay.y == 39,
  "configured HP values draw directly over the first HP meter")
T.check(expOverlay ~= nil,
  "the configured EXP percentage draws directly over the EXP meter")

-- The renderer restores true-colour icon rectangles after palette work. An
-- icon beneath the centered action menu must not restore the underlying card
-- over that menu as a square.
local modalMarks = {}
PartyMenu.drawIcon = function() return true end
PaletteFX.markTrueColor = function(x, y, w, h)
  modalMarks[#modalMarks + 1] = { x = x, y = y, w = w, h = h }
end
screen.submenu = true
screen.subIndex = 1
screen.subItems = { { label = "STATS" }, { label = "SWITCH" } }
local modalOK, modalErr = pcall(screen.draw, screen)
screen.submenu = false
screen.subItems = nil
PartyMenu.drawIcon = realDrawIcon
PaletteFX.markTrueColor = realMarkTrueColor
T.check(modalOK,
  "the action menu draws with colour-icon clipping: " .. tostring(modalErr))
T.eq(#modalMarks, 1,
  "a replacement icon fully covered by the action menu is not restored")
local popup = { x = 20, y = 48, w = 122, h = 42 }
for _, rect in ipairs(modalMarks) do
  local overlaps = rect.x < popup.x + popup.w
    and popup.x < rect.x + rect.w
    and rect.y < popup.y + popup.h
    and popup.y < rect.y + rect.h
  T.check(not overlaps,
    "true-colour icon protection never overlaps the action menu or shadow")
end

local drawnPaths = {}
local realDraw = graphics.draw
graphics.draw = function(image, ...)
  if type(image) == "table" and image.path then drawnPaths[image.path] = true end
  return realDraw(image, ...)
end
local spriteOK, spriteErr = pcall(screen.draw, screen)
graphics.draw = realDraw
T.check(spriteOK, "a companion mod's icon draws: " .. tostring(spriteErr))
T.check(drawnPaths["mods/companion_sprite_pack/assets/fixmon_a_icon.png"] == true,
  "icons.bySpecies replacement art is resolved instead of a private asset")

-- Classic width is two columns. Directional input moves geometrically and
-- is then masked from the original one-dimensional navigation for that tick.
local function press(key)
  input.pressed[key] = true
  screen:update(0)
  input.pressed[key] = nil
end
screen.index = 1
press("right")
T.eq(screen.index, 2, "RIGHT moves to the neighboring card")
press("down")
T.eq(screen.index, 4, "DOWN stays in the same card column")
press("left")
T.eq(screen.index, 3, "LEFT moves across the current row")
press("up")
T.eq(screen.index, 1, "UP stays in the same card column")
T.eq(game.partyMenuSavedIndex, 1, "grid navigation keeps cursor persistence")

-- Card and HP palette regions follow the responsive geometry rather than
-- fixed 160px coordinates.
local zones = screen:sgbPalettes(game) or {}
T.eq(#zones, 19,
  "base + six card, HP, and EXP palettes are emitted")
T.eq(zones[1].w, 160, "the base palette spans the current classic surface")
T.eq(zones[2].x, 0, "the first card begins at the left edge")
T.eq(zones[2].w, 80, "the first card occupies half the classic surface")
T.eq(zones[3].x, 23,
  "the first HP bar aligns with the compact card's text column")
T.eq(zones[4].x, zones[3].x,
  "the EXP bar aligns directly below the HP bar")
T.eq(zones[4].colors, run.data.palettes.palettes.EXP,
  "every EXP bar uses the dedicated blue palette")
local function exactBase(zone, rgb)
  local actual = zone and zone.colors and zone.colors[3]
  return actual and actual[1] == rgb[1] and actual[2] == rgb[2]
    and actual[3] == rgb[3]
end
T.check(exactBase(zones[2], { 101, 188, 94 }),
  "Grass party cards use the exact supplied reference colour")
T.check(exactBase(zones[5], { 254, 156, 85 }),
  "Fire party cards use the exact supplied reference colour")
T.check(exactBase(zones[8], { 77, 144, 214 }),
  "Water party cards use the exact supplied reference colour")
run.loader.modOptions.modern_party_ui = { card_color = "species_palette" }
local speciesZones = screen:sgbPalettes(game) or {}
T.eq(speciesZones[2].colors, run.data.palettes.palettes.GREENMON,
  "the Species option retains live per-species palette compatibility")
run.loader.modOptions.modern_party_ui = { card_color = "health" }
local healthZones = screen:sgbPalettes(game) or {}
T.eq(healthZones[2].colors, run.data.palettes.palettes.GREENBAR,
  "CARD COLOR changes the live card palette without reopening the screen")
PaletteFX.setMode("og")
T.eq(PaletteFX.effectiveColors(zones[2].colors), PaletteFX.GRAYS,
  "monochrome display mode still replaces the type palette")
PaletteFX.setMode("classic")
T.eq(PaletteFX.effectiveColors(zones[2].colors), PaletteFX.CLASSIC,
  "Classic display mode still replaces the type palette")
PaletteFX.setMode("gbc")
run.loader.modOptions.modern_party_ui = { exp_strip = false }
local noExpZones = screen:sgbPalettes(game) or {}
T.eq(#noExpZones, 13,
  "disabling PARTY EXP removes all six EXP palette regions")
run.loader.modOptions.modern_party_ui = nil

-- TM/HM mode retains learnability but emits no HP regions.
local tm = record.new(game, { tmhm = { move = "FIX_CUT", kind = "HM" } })
local tmZones = tm:sgbPalettes(game) or {}
T.eq(#tmZones, 7, "TM/HM mode emits base + cards but no HP palettes")
local tmOK, tmErr = pcall(tm.draw, tm)
T.check(tmOK, "TM/HM mode draws headlessly: " .. tostring(tmErr))

-- Forced battle selection still takes the native callback path.
local chosen
local forced = record.new(game, {
  battle = {}, forceSwitch = true,
  onSwitch = function(chosenMon) chosen = chosenMon end,
})
stack:push(forced)
input.pressed.a = true
local savedData = game.data
game.data = nil -- avoids audio in the focused behavior-only assertion
forced:update(0)
game.data = savedData
input.pressed.a = false
T.eq(chosen, party[1], "forced battle selection returns the focused mon")
T.check(stack:top() ~= forced, "forced battle selection closes the picker")

run.release()
PaletteFX.setMode(previousMode)
T.finish("modern_party_ui")
