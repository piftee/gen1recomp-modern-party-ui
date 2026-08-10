-- Standalone: luajit mods/modern_party_ui/tests/modern_party_ui_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local PartyMenu = require("src.ui.PartyMenu")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local Runtime = require("src.mods.Runtime")
local SummaryMenu = require("src.ui.SummaryMenu")

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
local summaryRecord = run.data.screens and run.data.screens.SummaryMenu
T.check(type(summaryRecord) == "table" and type(summaryRecord.new) == "function",
  "the SummaryMenu screen record is registered")

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
  if mode == "fill" and w == 18 and h == 18 then
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
T.eq(trueColorMarks[1].x, 4,
  "true-colour protection includes the first icon's seam guard")
T.eq(trueColorMarks[1].y, 20,
  "the icon seam guard follows its responsive card row")
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

-- Summary pages retain the original controller but use the same responsive
-- type-card presentation and palette system as the party roster.
party[1].moves = {
  { id = "FIX_TACKLE", pp = 31 }, { id = "FIX_EMBERISH", pp = 20 },
  { id = "FIX_CUT", pp = 24 }, { id = "FIX_SCRATCH", pp = 35 },
}
party[1].ot, party[1].otId = "RED", 13839
local summary = summaryRecord.new(game, party[1])
T.check(summary.modernPartySummary == true,
  "the modern summary presentation is installed")
T.eq(summary.modernSummaryLayout, "responsive_cards",
  "the summary identifies its adaptive card layout")
T.eq(getmetatable(summary), SummaryMenu,
  "the summary keeps the original SummaryMenu controller")
T.eq(summary.update, SummaryMenu.update,
  "native page switching and closing behavior remain unchanged")

graphics.getPixelDimensions = function() return 1600, 845 end
T.eq(select(1, summary:uiSize()), 320,
  "a short Android landscape display exposes its full responsive width")
graphics.getPixelDimensions = function() return 360, 800 end
T.eq(select(1, summary:uiSize()), 160,
  "a narrow portrait display falls back to the readable classic width")
graphics.getPixelDimensions = function() return 1280, 720 end
T.eq(select(1, summary:uiSize()), 256,
  "a 16:9 desktop display matches the responsive party surface")
graphics.getPixelDimensions = function() return 5120, 720 end
T.eq(select(1, summary:uiSize()), 640,
  "an ultrawide display uses the engine's largest valid UI surface")
T.eq(select(1, screen:uiSize()), 640,
  "the party roster also avoids falling back on ultrawide displays")
graphics.getPixelDimensions = realPixelDimensions

game.renderer = { uiSize = function() return 256, 144 end }
summary.page = 1
local summaryZones = summary:sgbPalettes(game) or {}
T.eq(summaryZones[1].w, 256,
  "the summary base palette covers the complete wide surface")
T.check(exactBase(summaryZones[2], { 101, 188, 94 }),
  "the profile rail uses the same exact Grass card colour as the party")
T.eq(#summaryZones, 4,
  "summary palettes no longer recolour the entire sprite rectangle")
local summaryText, summaryMarks = {}, {}
Font.draw = function(text, x, y)
  summaryText[#summaryText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  summaryMarks[#summaryMarks + 1] = { x = x, y = y, w = w, h = h }
end
local summaryOK, summaryErr = pcall(summary.draw, summary)
Font.draw = realFontDraw
PaletteFX.markTrueColor = realMarkTrueColor
T.check(summaryOK,
  "the modern stats summary draws headlessly: " .. tostring(summaryErr))
T.eq(#summaryMarks, 1,
  "the sprite-only colour result is protected from the card palette")
local protectedSpriteW, protectedSpriteH = summary.sprite:getDimensions()
T.eq(summaryMarks[1].w, protectedSpriteW + 2,
  "summary artwork protection includes a horizontal seam guard")
T.eq(summaryMarks[1].h, protectedSpriteH + 2,
  "summary artwork protection includes a vertical seam guard")
local attackLabel, attackValue
for i, call in ipairs(summaryText) do
  if call.text == "ATTACK" then
    attackLabel, attackValue = call, summaryText[i + 1]
    break
  end
end
T.check(attackLabel and attackValue
    and attackValue.text == tostring(summary.mon.stats.attack or 0)
    and attackLabel.y == attackValue.y,
  "wide stat labels and values form one centred group")

game.renderer = { uiSize = function() return 208, 144 end }
local squareText = {}
Font.draw = function(text, x, y)
  squareText[#squareText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local squareOK, squareErr = pcall(summary.draw, summary)
Font.draw = realFontDraw
T.check(squareOK,
  "the square-aspect stats summary draws headlessly: " .. tostring(squareErr))
local compactLabel, compactValue
for i, call in ipairs(squareText) do
  if call.text == "ATK" or call.text == "ATTACK" then
    compactLabel, compactValue = call, squareText[i + 1]
    break
  end
end
T.check(compactLabel and compactValue and compactLabel.y == compactValue.y,
  "square-aspect stat labels and values stay grouped centrally")

game.renderer = { uiSize = function() return 256, 144 end }
summary.page = 2
local moveZones = summary:sgbPalettes(game) or {}
T.eq(#moveZones, 7,
  "the moves summary emits profile, EXP and four move palettes")
T.check(moveZones[4].x < moveZones[5].x,
  "wide summaries arrange the first two moves as a two-column row")
T.check(exactBase(moveZones[5], { 254, 156, 85 }),
  "summary move cards use the shared exact Fire reference colour")
local moveText = {}
Font.draw = function(text, x, y)
  moveText[#moveText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local movesOK, movesErr = pcall(summary.draw, summary)
Font.draw = realFontDraw
T.check(movesOK,
  "the modern moves summary draws headlessly: " .. tostring(movesErr))
local firstMove
for _, call in ipairs(moveText) do
  if call.text:match("^FIX TACK") then firstMove = call break end
end
local firstMoveZone = moveZones[4]
T.check(firstMove and math.abs(firstMove.x + Font.width(firstMove.text) / 2
    - (firstMoveZone.x + firstMoveZone.w / 2)) <= 1,
  "wide move names are centred within their cards")

game.renderer = { uiSize = function() return 160, 144 end }
local compactMoveZones = summary:sgbPalettes(game) or {}
T.eq(compactMoveZones[4].x, compactMoveZones[5].x,
  "compact summaries stack move cards instead of crushing two columns")
game.renderer = nil

while stack:top() do stack:pop() end
stack:push(summary)
summary.page = 1
input.pressed.a = true
summary:update(0)
input.pressed.a = nil
T.eq(summary.page, 2,
  "A still advances from the stats page through the native controller")
input.pressed.b = true
summary:update(0)
input.pressed.b = nil
T.check(stack:top() ~= summary,
  "B still closes the moves page through the native controller")

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

-- Gender Mod 0.3.5 registers complete classic PartyMenu and SummaryMenu
-- records. Modern Party UI must intentionally replace those two records,
-- keep its responsive controllers, and consume Gender Mod's public exports
-- so gender remains visible on both modern surfaces.
local compatData = T.fixtures.fresh()
compatData.icons = data.icons
compatData.palettes = data.palettes
Font.load(compatData)
PaletteFX.setMode("gbc")
local genderRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/gender_mod",
  "mods/modern_party_ui",
}, { data = compatData, dev = true })
T.eq(#genderRun.errors, 0,
  "loads beside Gender Mod 0.3.5 without a screen-registry collision")

local genderRecord = genderRun.data.screens.PartyMenu
local genderSummaryRecord = genderRun.data.screens.SummaryMenu
local genderMon = mon("FIXMON_A", "NIDORAN♂", 12, 45, 45)
genderMon.gender_mod = "M"
local genderGame = {
  data = genderRun.data,
  save = { party = { genderMon }, inventory = {}, options = {} },
  stack = stack,
  input = input,
}
local genderScreen = genderRecord.new(genderGame, {})
T.check(genderScreen.modernPartyUI == true,
  "Modern Party UI remains the party presentation when Gender Mod is enabled")
local genderText, genderBackings, genderMarks = {}, {}, {}
Font.draw = function(text, x, y)
  genderText[#genderText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
graphics.rectangle = function(mode, x, y, w, h)
  if mode == "fill" and w == 10 and h == 10 then
    local r, g, b = graphics.getColor()
    genderBackings[#genderBackings + 1] = { r = r, g = g, b = b }
  end
  return realRectangle(mode, x, y, w, h)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  genderMarks[#genderMarks + 1] = { x = x, y = y, w = w, h = h }
end
local genderPartyOK, genderPartyErr = pcall(genderScreen.draw, genderScreen)
Font.draw = realFontDraw
graphics.rectangle = realRectangle
PaletteFX.markTrueColor = realMarkTrueColor
T.check(genderPartyOK,
  "the gender-aware modern party draws: " .. tostring(genderPartyErr))
local partyGlyph, strippedPartyName
for _, call in ipairs(genderText) do
  if call.text == "♂" then partyGlyph = call end
  if call.text:match("^NIDOR")
      and not call.text:find("♂", 1, true)
      and not call.text:find("♀", 1, true) then
    strippedPartyName = call
  end
end
T.check(partyGlyph and partyGlyph.x == 23,
  "the exported gender glyph sits directly before the modern level row")
T.check(strippedPartyName ~= nil,
  "the gender glyph replaces the nickname's baked-in symbol")
T.check(genderBackings[1] and genderBackings[1].g > genderBackings[1].r
    and genderBackings[1].g > genderBackings[1].b,
  "the gender marker backing matches the final Grass card instead of grey")
local guardedGenderMark
for _, rect in ipairs(genderMarks) do
  if rect.w == 10 and rect.h == 10 then guardedGenderMark = rect break end
end
T.check(guardedGenderMark ~= nil,
  "gender true-colour protection includes a one-pixel seam guard")

local genderSummary = genderSummaryRecord.new(genderGame, genderMon)
T.check(genderSummary.modernPartySummary == true,
  "Modern Party UI remains the summary presentation with Gender Mod")
local summaryGenderText = {}
Font.draw = function(text, x, y)
  summaryGenderText[#summaryGenderText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local genderSummaryOK, genderSummaryErr = pcall(
  genderSummary.draw, genderSummary)
Font.draw = realFontDraw
T.check(genderSummaryOK,
  "the gender-aware modern summary draws: " .. tostring(genderSummaryErr))
local summaryGlyph
for _, call in ipairs(summaryGenderText) do
  if call.text == "♂" then summaryGlyph = call break end
end
T.check(summaryGlyph ~= nil,
  "the modern summary renders Gender Mod's exported marker")
local genderCalls = genderRun.loader.exports.gender_mod.calls
T.check(genderCalls.gender >= 2 and genderCalls.symbol >= 2
    and genderCalls.palette >= 2,
  "party and summary markers are resolved through Gender Mod's public API")

genderRun.release()

-- Kanto Ribbons 0.18.0 owns the icon-rich screen after the last summary
-- page, while Gen1 Modern UI 0.8.4 can otherwise suppress and redraw ordinary
-- PartyMenu/SummaryMenu states. Modern Party UI publishes an explicit source
-- adapter that asks Gen1 Modern UI to preserve these custom renderers, and it
-- hands the native controller to Kanto Ribbons deterministically.
local ribbonData = T.fixtures.fresh()
ribbonData.icons = data.icons
ribbonData.palettes = data.palettes
Font.load(ribbonData)
PaletteFX.setMode("gbc")
local ribbonRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/gen1_modern_ui",
  "mods/modern_party_ui/tests/fixtures/kanto_ribbons",
  "mods/modern_party_ui",
}, { data = ribbonData, dev = true })
T.eq(#ribbonRun.errors, 0,
  "loads beside Kanto Ribbons and Gen1 Modern UI")

local ribbonMon = mon("FIXMON_A", "DECORATED", 18, 52, 52)
ribbonMon.ribbons = {
  STARTER = true, HALL_OF_FAME = true, RARE = true,
  EFFORT = true, EARTH = true,
}
local ribbonGame = {
  data = ribbonRun.data,
  save = { party = { ribbonMon }, inventory = {}, options = {} },
  stack = stack,
  input = input,
  renderer = { uiSize = function() return 256, 144 end },
}
local ribbonParty = ribbonRun.data.screens.PartyMenu.new(ribbonGame, {})
local ribbonSummary = ribbonRun.data.screens.SummaryMenu.new(
  ribbonGame, ribbonMon)
T.check(ribbonSummary.kantoRibbonsCompatible == true,
  "the summary reports its Kanto Ribbons handoff")
T.eq(ribbonSummary.pageCount, 2,
  "Kanto Ribbons follows the two native pages when DV Tracker is absent")

local modernUiExports = ribbonRun.loader.exports.gen1_modern_ui
local registrations = modernUiExports.registrations or {}
T.eq(#registrations, 1,
  "Modern Party UI registers one public Gen1 Modern UI contract")
T.eq(registrations[1].owner, "modern_party_ui",
  "the Gen1 Modern UI contract remains owned by the source mod")
T.check(registrations[1].contract
    == ribbonRun.loader.exports.modern_party_ui.gen1ModernUi,
  "the registered contract is the same table published in public exports")
T.eq(modernUiExports.shouldSuppress(ribbonParty), false,
  "Gen1 Modern UI leaves the responsive party renderer visible")
T.eq(modernUiExports.shouldSuppress(ribbonSummary), false,
  "Gen1 Modern UI leaves the responsive summary renderer visible")
T.eq(modernUiExports.shouldSuppress({ screenId = "OptionsMenu" }), nil,
  "the adapter does not interfere with other Gen1 Modern UI screens")

ribbonSummary.page = 2
local ribbonText = {}
Font.draw = function(text, x, y)
  ribbonText[#ribbonText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local ribbonDrawOK, ribbonDrawErr = pcall(ribbonSummary.draw, ribbonSummary)
Font.draw = realFontDraw
T.check(ribbonDrawOK,
  "the final move page draws before the ribbon handoff: "
    .. tostring(ribbonDrawErr))
local sawRibbonHint
for _, call in ipairs(ribbonText) do
  if call.text == "A/B RIBBONS" then sawRibbonHint = true break end
end
T.check(sawRibbonHint,
  "the final summary footer clearly advertises Kanto Ribbons")

while stack:top() do stack:pop() end
stack:push(ribbonSummary)
input.pressed.a = true
ribbonSummary:update(0)
input.pressed.a = nil
T.check(stack:top() and stack:top().modernPartyRibbons == true,
  "A on the final summary page opens Kanto Ribbons exactly once")
T.eq(stack:top() and stack:top().mon, ribbonMon,
  "the Kanto Ribbons detail screen receives the selected Pokémon")
local modernRibbonScreen = stack:top()
T.eq(modernUiExports.shouldSuppress(modernRibbonScreen), false,
  "Gen1 Modern UI also preserves the cohesive ribbon renderer")
T.eq(select(1, modernRibbonScreen:uiSize()), 256,
  "the ribbon screen uses the same responsive width as the summary")
local modernRibbonText = {}
Font.draw = function(text, x, y)
  modernRibbonText[#modernRibbonText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local modernRibbonOK, modernRibbonErr = pcall(
  modernRibbonScreen.draw, modernRibbonScreen)
Font.draw = realFontDraw
T.check(modernRibbonOK,
  "the modern ribbon cards draw: " .. tostring(modernRibbonErr))
local sawRibbonTitle, sawStarter, sawRibbonDescription, sawScrollHint
for _, call in ipairs(modernRibbonText) do
  if call.text == "RIBBONS" then sawRibbonTitle = true end
  if call.text == "STARTER" then sawStarter = true end
  if call.text == "FIRST PARTNER." then sawRibbonDescription = true end
  if call.text == "UP/DOWN SCROLL    A/B BACK" then sawScrollHint = true end
end
T.check(sawRibbonTitle and sawStarter and sawRibbonDescription,
  "the cohesive screen keeps ribbon names and descriptions")
T.check(sawScrollHint,
  "the widescreen footer explains the original scrolling controls")
local modernRibbonZones = modernRibbonScreen:sgbPalettes(ribbonGame) or {}
T.eq(#modernRibbonZones, 6,
  "the ribbon profile and four visible cards receive cohesive colour zones")
T.check(modernRibbonZones[3].x ~= modernRibbonZones[4].x,
  "wide ribbon cards use the responsive two-column layout")
ribbonGame.renderer = { uiSize = function() return 160, 144 end }
local compactRibbonZones = modernRibbonScreen:sgbPalettes(ribbonGame) or {}
T.eq(compactRibbonZones[3].x, compactRibbonZones[4].x,
  "compact ribbon cards stack without squeezing their text")
local compactRibbonOK, compactRibbonErr = pcall(
  modernRibbonScreen.draw, modernRibbonScreen)
T.check(compactRibbonOK,
  "the cohesive ribbon screen draws at 160x144: "
    .. tostring(compactRibbonErr))
ribbonGame.renderer = { uiSize = function() return 256, 144 end }
input.pressed.down = true
modernRibbonScreen:update(0)
input.pressed.down = nil
T.eq(modernRibbonScreen.scroll, 1,
  "the restyled ribbon screen retains Kanto Ribbons scrolling")
input.pressed.b = true
modernRibbonScreen:update(0)
input.pressed.b = nil
T.check(stack:top() ~= modernRibbonScreen,
  "the restyled ribbon screen retains Kanto Ribbons back behavior")

ribbonRun.release()

-- DV Tracker 1.0.0 owns a third native-controller page. Modern Party UI
-- should keep its exact A/B page flow, draw all DV/Stat EXP values in modern
-- responsive cards, and hand the composed final page to Kanto Ribbons.
local dvDataFixture = T.fixtures.fresh()
dvDataFixture.icons = data.icons
dvDataFixture.palettes = data.palettes
Font.load(dvDataFixture)
PaletteFX.setMode("gbc")
local dvRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/dv_tracker",
  "mods/modern_party_ui/tests/fixtures/kanto_ribbons",
  "mods/modern_party_ui/tests/fixtures/gen1_modern_ui",
  "mods/modern_party_ui/tests/fixtures/legacy_screen_skin",
  "mods/modern_party_ui/tests/fixtures/crystal_sprites",
  "mods/modern_party_ui",
}, { data = dvDataFixture, dev = true })
T.eq(#dvRun.errors, 0,
  "loads beside DV Tracker, Kanto Ribbons, Gen1 Modern UI and Crystal")

local dvRecord = dvRun.data.screens.SummaryMenu
local stackedPartyRecord = dvRun.data.screens.PartyMenu
local dvMon = mon("FIXMON_A", "TRACKER", 12, 45, 45)
dvMon.stats = { hp = 45, attack = 24, defense = 20, speed = 18, special = 22 }
dvMon.dvs = { attack = 15, defense = 13, speed = 11, special = 9 }
dvMon.statExp = {
  hp = 4321, attack = 1234, defense = 2345,
  speed = 3456, special = 4567,
}
local dvGame = {
  data = dvRun.data,
  save = { party = { dvMon }, inventory = {}, options = {} },
  stack = stack,
  input = input,
  renderer = { uiSize = function() return 256, 144 end },
}
local dvSummary = dvRecord.new(dvGame, dvMon)
local stackedParty = stackedPartyRecord.new(dvGame, {})
T.check(stackedParty.modernPartyUI == true,
  "an unknown earlier PartyMenu record cannot disable the modern roster")
T.check(dvSummary.modernPartySummary == true,
  "an unknown earlier SummaryMenu record cannot disable the modern summary")
T.eq(dvSummary.modernSummaryPages, 3,
  "DV Tracker expands the modern summary to three pages")
T.eq(dvSummary.pageCount, 3,
  "the composed page count keeps Kanto Ribbons after the DV page")
T.check(dvSummary.dvTrackerCompatible == true,
  "the summary reports its active DV Tracker adapter")
T.check(dvSummary.kantoRibbonsCompatible == true,
  "the summary reports its active Kanto Ribbons adapter")
T.check(dvSummary.crystalAnimatedSprite == true
    and dvSummary.spriteTrueColor == true,
  "the live Crystal animated summary sprite remains installed")
T.eq(dvSummary.update, SummaryMenu.update,
  "the composed Crystal/DV controller remains the live update method")

dvSummary.page = 3
local dvText = {}
Font.draw = function(text, x, y)
  dvText[#dvText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local dvDrawOK, dvDrawErr = pcall(dvSummary.draw, dvSummary)
Font.draw = realFontDraw
T.check(dvDrawOK,
  "the modern DV page draws responsively: " .. tostring(dvDrawErr))
T.check(not dvSummary.dvTrackerClassicDrawn,
  "the classic fixed-width DV renderer does not replace the modern page")
local sawPage, sawTitle, sawHpDv, sawHpExp, sawAttackDv, sawAttackExp,
  sawComposedRibbonHint
for _, call in ipairs(dvText) do
  if call.text == "3/3" then sawPage = true end
  if call.text == "DVS" then sawTitle = true end
  if call.text == "HP DV 15" then sawHpDv = true end
  if call.text == "EXP 4321" then sawHpExp = true end
  if call.text:find("DV15", 1, true) then sawAttackDv = true end
  if call.text == "EXP 1234" then sawAttackExp = true end
  if call.text == "A/B RIBBONS" then sawComposedRibbonHint = true end
end
T.check(sawPage and sawTitle,
  "the compatibility page has a clear three-page DV header")
T.check(sawHpDv and sawHpExp and sawAttackDv and sawAttackExp,
  "HP and core-stat DV/Stat EXP values are all rendered")
T.check(sawComposedRibbonHint,
  "the DV page advertises the following Kanto Ribbons screen")
T.eq(dvRun.loader.exports.gen1_modern_ui.shouldSuppress(dvSummary), false,
  "Gen1 Modern UI preserves the composed DV and ribbons summary renderer")
local dvZones = dvSummary:sgbPalettes(dvGame) or {}
T.eq(#dvZones, 3,
  "the DV page keeps the responsive base, profile and highlighted HP cards")

dvGame.renderer = { uiSize = function() return 160, 144 end }
local compactDvOK, compactDvErr = pcall(dvSummary.draw, dvSummary)
T.check(compactDvOK,
  "the DV page collapses cleanly on a compact 160x144 surface: "
    .. tostring(compactDvErr))

while stack:top() do stack:pop() end
stack:push(dvSummary)
dvSummary.page = 1
input.pressed.a = true
dvSummary:update(0)
input.pressed.a = nil
T.eq(dvSummary.page, 2, "DV flow advances from stats to moves")
input.pressed.b = true
dvSummary:update(0)
input.pressed.b = nil
T.eq(dvSummary.page, 3, "DV flow advances from moves to the DV page")
input.pressed.a = true
dvSummary:update(0)
input.pressed.a = nil
T.check(stack:top() and stack:top().modernPartyRibbons == true,
  "DV flow opens Kanto Ribbons only after the third page")
T.eq(stack:top() and stack:top().mon, dvMon,
  "the composed handoff retains the tracked Pokémon")
T.eq(dvSummary.crystalUpdateCalls, 3,
  "Crystal's animation update still wraps all three navigation steps")

dvRun.release()
PaletteFX.setMode(previousMode)
T.finish("modern_party_ui")
