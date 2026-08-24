-- Standalone: luajit mods/modern_party_ui/tests/modern_party_ui_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Assets = require("src.render.Assets")
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

do
local optionGame = {
  data = run.data,
  save = { options = {} },
  mods = run.loader,
  stack = { push = function(self, page) self.page = page end },
}
local mainOptionRows = Runtime.call("ui.options.rows",
  function(_, rows) return rows end, optionGame, { { id = "text_speed" } })
T.eq(#mainOptionRows, 2,
  "one Modern Party UI entry is added to the main Options menu")
T.eq(mainOptionRows[2].id, "modern_party_ui",
  "the consolidated party settings entry follows the game's own rows")
T.eq(mainOptionRows[2].value(optionGame), "OPEN",
  "the consolidated entry clearly indicates that it opens a page")
mainOptionRows[2].activate(optionGame)
local partyOptionRows = optionGame.stack.page and optionGame.stack.page.rows or {}
T.eq(#partyOptionRows, 8,
  "the dedicated Modern Party UI page contains every presentation setting")
T.eq(partyOptionRows[1].id, "modern_party_ui_card_color",
  "the dedicated page starts with party colour")
T.eq(partyOptionRows[1].value(optionGame), "TYPE",
  "the dedicated page reads the same default as the mod manager")
partyOptionRows[1].step(optionGame, 1)
T.eq(run.loader.modOptions.modern_party_ui.card_color, "species_palette",
  "the dedicated page exposes the species palette after the type default")
T.eq(optionGame.save.options.modOptions.modern_party_ui.card_color,
  "species_palette",
  "the dedicated page persists the explicit species-palette choice")
T.eq(partyOptionRows[2].id, "modern_party_ui_animate_icons",
  "icon animation is visible on the first dedicated settings page")
T.eq(partyOptionRows[2].label, "ICON ANIMATION",
  "the animation control has an explicit player-facing label")
T.eq(partyOptionRows[2].value(optionGame), "ON",
  "icon animation is enabled by default")
T.eq(partyOptionRows[4].id, "modern_party_ui_exp_text",
  "the EXP display has its own row on the dedicated page")
T.eq(partyOptionRows[4].value(optionGame), "PERCENT",
  "the EXP display defaults to a useful percentage")
partyOptionRows[4].step(optionGame, -1)
T.eq(run.loader.modOptions.modern_party_ui.exp_text, "values",
  "the EXP display cycles independently through its configured modes")
run.loader.modOptions.modern_party_ui = nil
end

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
T.eq(select(2, screen:uiSize()), 144,
  "a 16:9 window keeps the reference-height party surface")
run.loader.modOptions.modern_party_ui = { responsive = false }
T.eq(select(1, screen:uiSize()), 160,
  "the WIDESCREEN setting can restore the classic width")
T.eq(select(2, screen:uiSize()), 144,
  "disabling WIDESCREEN also restores the classic height")
run.loader.modOptions.modern_party_ui = nil
graphics.getPixelDimensions = realPixelDimensions

-- Direct menu entry and Bag item targeting resolve to one portrait surface.
-- The parent stays on the stack while PartyMenu owns input, matching the
-- native Bag -> USE -> choose a POKéMON flow.
do
  graphics.getPixelDimensions = function() return 998, 1980 end
  local directW, directH = screen:uiSize()
  T.eq(directW, 160,
    "a directly opened party uses the phone-width portrait surface")
  T.eq(directH, 330,
    "a directly opened party uses the phone's available portrait height")
  local portraitBag = {
    modernBagUI = true,
    uiSize = function() return directW, directH end,
  }
  stack:push(portraitBag)
  stack:push(screen)
  local targetW, targetH = screen:uiSize()
  T.eq(targetW, 160,
    "a Bag-opened party target keeps the Bag's portrait width")
  T.eq(targetH, 330,
    "a Bag-opened party target keeps the Bag's full portrait height")
  game.renderer = { uiSize = function() return targetW, targetH end }
  local targetLayout = screen:modernPartyLayoutInfo()
  T.eq(targetLayout.height, 330,
    "the party target layout fills the inherited portrait surface")
  T.eq(targetLayout.columns, 1,
    "the portrait party target stacks full-width readable cards")
  T.eq(targetLayout.rows, 6,
    "the portrait target uses the Bag's height for all six party slots")
  T.eq(targetLayout.footerY, 322,
    "the party target footer stays at the bottom of the inherited surface")
  local targetZones = screen:sgbPalettes(game) or {}
  T.eq(targetZones[1] and targetZones[1].h, 330,
    "the party target palette covers the inherited portrait surface")
  T.eq(screen.modernPartyParentSurface, "modern_bag_ui",
    "the active parent surface is identified for compatibility diagnostics")
  stack:pop()
  stack:pop()
  game.renderer = nil
  local reopenedW, reopenedH = screen:uiSize()
  T.eq(reopenedW, targetW,
    "menu and Bag entry use the same portrait width")
  T.eq(reopenedH, targetH,
    "menu and Bag entry use the same portrait height")
  local directLayout = screen:modernPartyLayoutInfo()
  T.eq(directLayout.columns, targetLayout.columns,
    "menu and Bag entry use the same portrait card columns")
  T.eq(directLayout.rows, targetLayout.rows,
    "menu and Bag entry use the same portrait card rows")
  graphics.getPixelDimensions = realPixelDimensions
end

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
_G.__modernPartyTestDebug = _G.debug
_G.debug = nil
local ok, drawErr = pcall(screen.draw, screen)
_G.debug = _G.__modernPartyTestDebug
_G.__modernPartyTestDebug = nil
PartyMenu.drawIcon = realDrawIcon
PaletteFX.markTrueColor = realMarkTrueColor
graphics.scale = realScale
graphics.rectangle = realRectangle
graphics.polygon = realPolygon
Font.draw = realFontDraw
run.loader.modOptions.modern_party_ui = nil
T.check(ok, "the card grid draws in the production sandbox without debug: "
  .. tostring(drawErr))
T.eq(#iconCalls, #party, "every occupied card uses the shared icon renderer")
T.eq(iconCalls[1].mon, party[1], "the shared renderer receives the live mon")
T.eq(iconCalls[1].x, 5,
  "the compact icon is horizontally centered in its available column")
T.eq(iconCalls[1].y, 21,
  "the icon is vertically centered above the meter rows")
T.eq(#trueColorMarks, 16,
  "authored replacement icons protect opaque rows instead of full canvases")
T.eq(trueColorMarks[1].x, 5,
  "true-colour protection starts at the icon's opaque pixels")
T.eq(trueColorMarks[1].y, 21,
  "opaque-row protection follows its responsive card row")
T.eq(trueColorMarks[1].w, 8,
  "the headless icon mask protects only its decoded opaque width")
T.eq(trueColorMarks[1].h, 1,
  "true-colour protection is split into individual opaque rows")
T.eq(#iconBackgrounds, 0,
  "replacement icon transparency never receives a rectangular backing")
T.eq(cardLayers[2].color[1], 0,
  "the selected party card uses a dominant black outer frame")
T.eq(cardLayers[2].points[1], 4,
  "the selected frame grows one pixel beyond its normal card geometry")
T.eq(cardLayers[2].points[2], 16,
  "the selected frame is raised one pixel without moving card contents")
T.eq(#fractionalScales, 0,
  "the native tile font is never fractionally scaled")

-- Unique Menu Icons 1.5.0 renamed its three asset folders from icons_* to
-- icon_*.  ORIGINAL remains palette-aware; protecting its grayscale source
-- as literal true colour would bypass the card palette and make it look gray.
do
local savedEntries = game.data.icons.bySpecies
local savedDrawIcon = PartyMenu.drawIcon
local savedMarkTrueColor = PaletteFX.markTrueColor
local function uniqueEntry(folder, species)
  return {
    image = "mods/unique_menu_icons/assets/" .. folder .. "/"
      .. species .. ".png",
    frames = 2,
  }
end

game.data.icons.bySpecies = {
  FIXMON_A = uniqueEntry("icon_original", "FIXMON_A"),
  FIXMON_B = uniqueEntry("icon_original", "FIXMON_B"),
  FIXMON_C = uniqueEntry("icon_original", "FIXMON_C"),
}
PartyMenu.drawIcon = function() return true end
local originalModeMarks = {}
PaletteFX.markTrueColor = function(x, y, w, h)
  originalModeMarks[#originalModeMarks + 1] = { x = x, y = y, w = w, h = h }
end
local originalModeOK, originalModeErr = pcall(screen.draw, screen)
T.check(originalModeOK,
  "Unique Menu Icons 1.5.0 ORIGINAL mode draws: "
    .. tostring(originalModeErr))
T.eq(#originalModeMarks, 0,
  "Unique Menu Icons 1.5.0 ORIGINAL art remains card-palette aware")

game.data.icons.bySpecies.FIXMON_A =
  uniqueEntry("icon_color", "FIXMON_A")
local savedImageData = Assets.imageData
local uniqueColorData = {}
function uniqueColorData:getDimensions() return 16, 32 end
function uniqueColorData:getPixel(px, py)
  local row = py % 16
  local opaque = row == 5 and px >= 4 and px <= 7
    or row == 6 and px >= 3 and px <= 8
  return 1, 1, 1, opaque and 1 or 0
end
Assets.imageData = function(path)
  if tostring(path):find("icon_color", 1, true) then
    return uniqueColorData
  end
  return savedImageData(path)
end
local colorModeMarks = {}
PaletteFX.markTrueColor = function(x, y, w, h)
  colorModeMarks[#colorModeMarks + 1] = { x = x, y = y, w = w, h = h }
end
local colorModeOK, colorModeErr = pcall(screen.draw, screen)
Assets.imageData = savedImageData
T.check(colorModeOK,
  "Unique Menu Icons 1.5.0 UNIQUE COLORS mode draws: "
    .. tostring(colorModeErr))
T.eq(#colorModeMarks, 4,
  "Unique Menu Icons colour art protects only its opaque runs")
T.eq(colorModeMarks[1].x, 9,
  "Unique Menu Icons transparent left padding is not restored")
T.eq(colorModeMarks[1].w, 4,
  "Unique Menu Icons does not publish its full transparent canvas")

game.data.icons.bySpecies = savedEntries
PartyMenu.drawIcon = savedDrawIcon
PaletteFX.markTrueColor = savedMarkTrueColor
end

-- Gender Mod is intentionally absent from this run. A missing third-party
-- sprite must not leave its old colour backing behind, and the renderer must
-- retry after temporarily removing the broken per-species override so the
-- game's normal definition/dex icon can draw instead.
do
local savedEntries = game.data.icons.bySpecies
local savedDrawIcon = PartyMenu.drawIcon
local savedMarkTrueColor = PaletteFX.markTrueColor
local savedImageData = Assets.imageData
local brokenCalls, fallbackCalls, missingMarks = 0, 0, {}
game.data.icons.bySpecies = {
  FIXMON_A = {
    image = "mods/missing_icon_pack/assets/not_present.png",
    frames = 2,
  },
}
Assets.imageData = function(path)
  if tostring(path):find("not_present", 1, true) then
    error("missing test asset")
  end
  return savedImageData(path)
end
PartyMenu.drawIcon = function(game_, drawn)
  if game_.data.icons.bySpecies[drawn.species] ~= nil then
    brokenCalls = brokenCalls + 1
    PaletteFX.markTrueColor(0, 0, 16, 16)
    return nil
  end
  fallbackCalls = fallbackCalls + 1
  return true
end
PaletteFX.markTrueColor = function(x, y, w, h)
  missingMarks[#missingMarks + 1] = { x = x, y = y, w = w, h = h }
end
local missingOK, missingErr = pcall(screen.draw, screen)
T.check(missingOK,
  "a missing icon draws without Gender Mod: " .. tostring(missingErr))
T.eq(brokenCalls, 2,
  "each affected party member tries its third-party sprite once")
T.eq(fallbackCalls, #party,
  "missing third-party sprites fall back while unaffected cards still draw")
T.eq(#missingMarks, 0,
  "failed sprite colour claims cannot leave white or grey boxes")
T.check(game.data.icons.bySpecies.FIXMON_A ~= nil,
  "the third-party icon registry is restored after fallback")
game.data.icons.bySpecies = savedEntries
PartyMenu.drawIcon = savedDrawIcon
PaletteFX.markTrueColor = savedMarkTrueColor
Assets.imageData = savedImageData
end
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
T.eq(#modalMarks, 8,
  "only the opaque rows of an uncovered replacement icon are restored")
local popup = { x = 20, y = 48, w = 122, h = 42 }
for _, rect in ipairs(modalMarks) do
  local overlaps = rect.x < popup.x + popup.w
    and popup.x < rect.x + rect.w
    and rect.y < popup.y + popup.h
    and popup.y < rect.y + rect.h
  T.check(not overlaps,
    "true-colour icon protection never overlaps the action menu or shadow")
end

-- Wilds of Kanto 2.1.7 wraps PartyMenu.drawIcon and calls markTrueColor from
-- inside the shared icon renderer. A taller FOLLOW/field-move popup overlaps
-- several icon cells, so those third-party claims must pass through the same
-- dynamic popup cut-out instead of re-blitting the popup as raw grey pixels.
local tallModalMarks = {}
PartyMenu.drawIcon = function(_, _, x, y)
  PaletteFX.markTrueColor(x, y, 16, 16)
  return true
end
PaletteFX.markTrueColor = function(x, y, w, h)
  tallModalMarks[#tallModalMarks + 1] = { x = x, y = y, w = w, h = h }
end
screen.submenu = true
screen.subIndex = 1
screen.subItems = {
  { label = "STATS" }, { label = "SWITCH" }, { label = "RELEARN" },
  { label = "RENAME" }, { label = "FOLLOW" },
}
local tallModalOK, tallModalErr = pcall(screen.draw, screen)
screen.submenu = false
screen.subItems = nil
PartyMenu.drawIcon = realDrawIcon
PaletteFX.markTrueColor = realMarkTrueColor
T.check(tallModalOK,
  "a tall companion submenu draws: " .. tostring(tallModalErr))
T.check(#tallModalMarks > 0,
  "companion icon colour claims remain active outside a tall submenu")
local tallPopup = { x = 20, y = 24, w = 122, h = 78 }
for _, rect in ipairs(tallModalMarks) do
  local overlaps = rect.x < tallPopup.x + tallPopup.w
    and tallPopup.x < rect.x + rect.w
    and rect.y < tallPopup.y + tallPopup.h
    and tallPopup.y < rect.y + rect.h
  T.check(not overlaps,
    "companion true-colour claims never repaint a tall action menu grey")
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
_G.__modernPartyRealSpritePath = require("src.pokemon.Sprites").path
_G.__modernPartySpriteContexts = {}
require("src.pokemon.Sprites").path = function(data_, species, side, opts)
  _G.__modernPartySpriteContexts[#_G.__modernPartySpriteContexts + 1] = {
    species = species, side = side, kind = opts and opts.kind,
  }
  return _G.__modernPartyRealSpritePath(data_, species, side, opts)
end
local summary = summaryRecord.new(game, party[1])
require("src.pokemon.Sprites").path = _G.__modernPartyRealSpritePath
T.check(summary.modernPartySummary == true,
  "the modern summary presentation is installed")
T.eq(_G.__modernPartySpriteContexts[#_G.__modernPartySpriteContexts]
    and _G.__modernPartySpriteContexts[#_G.__modernPartySpriteContexts].kind,
  "battle",
  "the summary's displayed artwork resolves through the battle context")
_G.__modernPartyRealSpritePath = nil
_G.__modernPartySpriteContexts = nil
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
T.eq(select(1, summary:uiSize()), 180,
  "a narrow portrait display uses the width-fitting integer scale")
T.eq(select(1, screen:uiSize()), 160,
  "the party roster matches Modern Bag UI's readable portrait width")
T.eq(select(2, screen:uiSize()), 396,
  "the party roster snaps the tall-phone surface to six equal card rows")
;(function()
  local FaithfulRes = require("src.core.FaithfulRes")
  local portraitZones = screen:sgbPalettes(game) or {}
  for i = 0, 5 do
    local card = portraitZones[2 + i * 3]
    T.eq(card and card.h, 62,
      "portrait card " .. tostring(i + 1) .. " has an equal native height")
    if i > 0 then
      local previous = portraitZones[2 + (i - 1) * 3]
      T.eq(card and card.y, previous and previous.y + previous.h,
        "portrait card " .. tostring(i + 1) .. " shares its preceding edge")
    end
  end

  -- Portrait frame joins cover the patterned layer before their chamfers are
  -- drawn. This is the native one-pixel seam that becomes a broad band at a
  -- phone's 5x/6x output scale.
  local realRectangle = graphics.rectangle
  local realDrawIcon = PartyMenu.drawIcon
  local seamlessCells = 0
  graphics.rectangle = function(mode, x, y, w, h)
    if mode == "fill" and x == 0 and w == 160 and h == 62 then
      local r, g, b = graphics.getColor()
      if math.abs(r - 85 / 255) < 0.001
          and math.abs(g - r) < 0.001 and math.abs(b - r) < 0.001 then
        seamlessCells = seamlessCells + 1
      end
    end
    return realRectangle(mode, x, y, w, h)
  end
  PartyMenu.drawIcon = function() return true end
  local portraitOK, portraitErr = pcall(screen.draw, screen)
  PartyMenu.drawIcon = realDrawIcon
  graphics.rectangle = realRectangle
  T.check(portraitOK,
    "the seamless portrait roster draws: " .. tostring(portraitErr))
  T.eq(seamlessCells, 6,
    "all six portrait cells cover the backdrop at their shared edges")


  -- Faithful Ratio owns a classic 160x144 native viewport on mobile. Ignore a
  -- stale responsive renderer size and a tall Modern Bag parent while locked.
  local realScaleCap = FaithfulRes.scaleCap
  FaithfulRes.scaleCap = function() return 6 end
  local faithfulBag = {
    modernBagUI = true,
    uiSize = function() return 160, 396 end,
  }
  stack:push(faithfulBag)
  stack:push(screen)
  game.renderer = { uiSize = function() return 160, 396 end }
  T.eq(select(1, screen:uiSize()), 160,
    "Faithful Ratio keeps the native party width")
  T.eq(select(2, screen:uiSize()), 144,
    "Faithful Ratio restores the native party height")
  local faithfulLayout = screen:modernPartyLayoutInfo()
  T.eq(faithfulLayout.height, 144,
    "a stale tall renderer cannot override the faithful party viewport")
  T.eq(faithfulLayout.columns, 2,
    "Faithful Ratio uses the complete classic party composition")
  game.renderer = { uiSize = function() return 180, 144 end }
  T.eq(select(1, summary:uiSize()), 160,
    "Faithful Ratio also keeps summary pages at the native width")
  local faithfulSummaryZones = summary:sgbPalettes(game) or {}
  T.eq(faithfulSummaryZones[1] and faithfulSummaryZones[1].w, 160,
    "a stale wide renderer cannot override the faithful summary viewport")
  stack:pop()
  stack:pop()
  game.renderer = nil
  FaithfulRes.scaleCap = realScaleCap
end)()
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
T.eq(summaryMarks[1].x, 4,
  "summary artwork protection starts at the card's inner edge")
T.eq(summaryMarks[1].y, 20,
  "summary artwork protection starts at the card's structural edge")
T.eq(summaryMarks[1].w, 73,
  "summary artwork protection spans the borderless card face")
T.eq(summaryMarks[1].h, 110,
  "summary artwork protection reaches the card's bottom structure")
T.check(summaryMarks[1].w > protectedSpriteW + 2
    or summaryMarks[1].h > protectedSpriteH + 2,
  "summary artwork protection no longer traces the source canvas")

-- Unique Menu Icons publishes fixed party-row true-colour rectangles.  A
-- PartyMenu -> SummaryMenu transition may happen during the same frame, so
-- the opaque summary must replace those claims with its own artwork claim.
PaletteFX.setPass("ui")
for i = 1, 6 do PaletteFX.markTrueColor(8, i * 16 - 8, 16, 16) end
T.eq(#PaletteFX.trueColorRects("ui"), 6,
  "the compatibility fixture seeds six external party-icon colour claims")
local iconSummaryOK, iconSummaryErr = pcall(summary.draw, summary)
T.check(iconSummaryOK,
  "the summary replaces Unique Menu Icons claims: "
    .. tostring(iconSummaryErr))
local summaryTrueColor = PaletteFX.trueColorRects("ui")
T.eq(#summaryTrueColor, 1,
  "only the current summary artwork remains true-colour protected")
T.check(not (summaryTrueColor[1].x == 8
    and summaryTrueColor[1].w == 16 and summaryTrueColor[1].h == 16),
  "party-icon rectangles cannot leak onto stats or moves pages")
PaletteFX.clearTrueColor()

-- Anytime Rename 1.2.1 injects a callback-backed NICKNAME party action.
-- Modern Party UI must leave that action and its native NamingScreen stack
-- transition intact rather than interpreting it as a presentation command.
do
local renameData = T.fixtures.fresh()
renameData.icons = data.icons
renameData.palettes = data.palettes
Font.load(renameData)
local renameRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/anytime_rename",
  "mods/modern_party_ui",
}, { data = renameData, dev = true })
T.eq(#renameRun.errors, 0, "loads beside Anytime Rename 1.2.1")
local renameStack = { states = {} }
function renameStack:push(state) self.states[#self.states + 1] = state end
function renameStack:pop() return table.remove(self.states) end
local renameGame = {
  data = renameRun.data,
  save = { party = { party[1] }, inventory = {}, options = {} },
  stack = renameStack,
  input = { wasPressed = function() return false end },
}
local renameItems = Runtime.call("ui.party.submenu",
  function(_, items) return items end,
  renameGame, { { label = "STATS" } }, party[1], {})
local nicknameAction
for _, item in ipairs(renameItems) do
  if item.label == "NICKNAME" then nicknameAction = item break end
end
T.check(nicknameAction and type(nicknameAction.onSelect) == "function",
  "the injected NICKNAME action remains reachable")
local renameOK, renameErr = pcall(nicknameAction.onSelect,
  party[1], renameGame)
T.check(renameOK,
  "the NICKNAME action opens without freezing: " .. tostring(renameErr))
T.eq(renameStack.states[1] and renameStack.states[1].screenId,
  "NamingScreen", "the native naming screen is pushed onto the game stack")
renameRun.release()
end

-- Gen1 Modern UI 0.9.2 added its own NamingScreen presenter. QoL Toggles'
-- RENAME action opens that built-in screen above PartyMenu; explicitly hand
-- that one child screen back to the native renderer so it remains visible and
-- interactive while leaving unrelated naming flows modernizable.
do
local renameData = T.fixtures.fresh()
renameData.icons = data.icons
renameData.palettes = data.palettes
Font.load(renameData)
local renameRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/gen1_modern_ui",
  "mods/modern_party_ui/tests/fixtures/qol_toggles",
  "mods/modern_party_ui",
}, { data = renameData, dev = true })
T.eq(#renameRun.errors, 0,
  "loads beside Gen1 Modern UI 0.9.2 and QoL Toggles 1.27.0")
local renameStack = { states = {} }
function renameStack:push(state) self.states[#self.states + 1] = state end
function renameStack:pop() return table.remove(self.states) end
local renameGame = {
  data = renameRun.data,
  save = { party = { party[1] }, inventory = {}, options = {} },
  stack = renameStack,
  input = { wasPressed = function() return false end },
}
local roster = renameRun.data.screens.PartyMenu.new(renameGame, {})
renameStack:push(roster)
local renameItems = Runtime.call("ui.party.submenu",
  function(_, items) return items end,
  renameGame, { { label = "STATS" } }, party[1], {})
local renameAction
for _, item in ipairs(renameItems) do
  if item.id == "RENAME" then renameAction = item break end
end
T.check(renameAction and type(renameAction.onSelect) == "function",
  "QoL Toggles' RENAME action remains reachable")
local renameOK, renameErr = pcall(renameAction.onSelect, party[1], renameGame)
T.check(renameOK,
  "QoL Toggles' RENAME action opens without freezing: " .. tostring(renameErr))
local naming = renameStack.states[#renameStack.states]
T.eq(naming and naming.screenId, "NamingScreen",
  "QoL Toggles pushes the native naming screen above the modern party")
local modernUi = renameRun.loader.exports.gen1_modern_ui
T.eq(modernUi.shouldSuppress(naming), false,
  "Gen1 Modern UI leaves the party child NamingScreen source-owned")

local unrelatedNaming = { screenId = "NamingScreen", game = renameGame }
T.eq(modernUi.shouldSuppress(unrelatedNaming), true,
  "unrelated naming screens remain available to Gen1 Modern UI")
renameRun.release()
end

-- HGSS Visual Overhaul 1.0.0 publishes padded 32x32 true-colour party frames.
-- Fit the visible alpha bounds into the complete card rail and protect only
-- those visible pixels, rather than scaling the transparent source canvas.
do
local hgssData = T.fixtures.fresh()
hgssData.icons = { icons = {}, byDex = {}, bySpecies = {} }
for _, species in ipairs({ "FIXMON_A", "FIXMON_B", "FIXMON_C" }) do
  hgssData.icons.bySpecies[species] = {
    image = "mods/HGSS_SPRITES/assets/icons/"
      .. species:lower() .. ".png",
    frames = 2,
    trueColor = true,
  }
end
hgssData.palettes = data.palettes
Font.load(hgssData)
local drawIconBeforeHgss = PartyMenu.drawIcon
local hgssRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/hgss_sprites",
  "mods/modern_party_ui",
}, { data = hgssData, dev = true })
T.eq(#hgssRun.errors, 0, "loads beside HGSS Visual Overhaul 1.0.0")
local hgssGame = {
  data = hgssRun.data,
  save = { party = party, inventory = {}, options = {} },
  stack = { states = {} },
  input = { wasPressed = function() return false end },
  -- Match the two 160px-wide columns in the reported desktop layout.
  renderer = { uiSize = function() return 320, 240 end },
}
local hgssScreen = hgssRun.data.screens.PartyMenu.new(hgssGame, {})
local hgssMarks, fittedDraws, scaledFills = {}, {}, {}
local hgssRealMark = PaletteFX.markTrueColor
local hgssRealRectangle = graphics.rectangle
local hgssRealDraw = graphics.draw
local hgssRealImageData = Assets.imageData
local hgssRealImage = Assets.image
local fakeHgssImage = {}
local fakeHgssData = {}
function fakeHgssData:getDimensions() return 32, 64 end
function fakeHgssData:getPixel(px, py)
  local frameY = py % 32
  local opaque = py < 32
    and px >= 8 and px <= 23 and frameY >= 6 and frameY <= 25
    or py >= 32
      and px >= 8 and px <= 23 and frameY >= 7 and frameY <= 26
  return 1, 1, 1, opaque and 1 or 0
end
Assets.imageData = function(path)
  if tostring(path):lower():find("hgss", 1, true) then
    return fakeHgssData
  end
  return hgssRealImageData(path)
end
Assets.image = function(path)
  if tostring(path):lower():find("hgss", 1, true) then
    return fakeHgssImage
  end
  return hgssRealImage(path)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  hgssMarks[#hgssMarks + 1] = { x = x, y = y, w = w, h = h }
end
graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if image == fakeHgssImage then
    fittedDraws[#fittedDraws + 1] = {
      quad = quad, x = x, y = y, sx = sx or 1, sy = sy or sx or 1,
    }
  end
  return hgssRealDraw(image, quad, x, y, rotation, sx, sy, ...)
end
graphics.rectangle = function(mode, x, y, w, h)
  if mode == "fill" and w == 32 and h == 32 then
    local r, g, b = graphics.getColor()
    scaledFills[#scaledFills + 1] = { r = r, g = g, b = b }
  end
  return hgssRealRectangle(mode, x, y, w, h)
end
local hgssOK, hgssErr = pcall(hgssScreen.draw, hgssScreen)
PaletteFX.markTrueColor = hgssRealMark
graphics.rectangle = hgssRealRectangle
T.check(hgssOK,
  "the HGSS party icon renderer draws headlessly: " .. tostring(hgssErr))
T.eq(#fittedDraws, #party,
  "roomy cards alpha-fit every HGSS creature independently")
local firstFitted = fittedDraws[1]
T.check(firstFitted
    and math.max(firstFitted.quad.w * firstFitted.sx,
      firstFitted.quad.h * firstFitted.sy) >= 31.5,
  "the visible HGSS creature fills the native 32px party rail")
T.check(#hgssMarks > #party,
  "HGSS true-colour protection follows fitted opaque pixel rows")
T.eq(#scaledFills, 0,
  "fitted HGSS icons do not restore rectangular card backings")

local hgssCalls = hgssRun.loader.exports.HGSS_SPRITES.calls
T.eq(#hgssCalls, 0,
  "the fitted path bypasses HGSS's padded full-frame renderer")

-- Frame 48 reaches frame two at every healthy/yellow/red HGSS cadence, but
-- only the focused card may use it.
hgssScreen.blink = 48
local beforeAnimated = #fittedDraws
local animateOK, animateErr = pcall(hgssScreen.draw, hgssScreen)
T.check(animateOK,
  "the animated HGSS frame draws headlessly: " .. tostring(animateErr))
for i = beforeAnimated + 1, beforeAnimated + #party do
  local resting = fittedDraws[i - beforeAnimated]
  local moving = fittedDraws[i]
  local card = i - beforeAnimated
  T.check(moving and ((card == hgssScreen.index and moving.quad.y >= 32)
      or (card ~= hgssScreen.index and moving.quad.y < 32)),
    "only the highlighted HGSS party card advances to frame two")
  T.check(resting and moving
      and resting.quad.x == moving.quad.x
      and resting.quad.y % 32 == moving.quad.y % 32
      and resting.quad.w == moving.quad.w
      and resting.quad.h == moving.quad.h
      and resting.x == moving.x and resting.y == moving.y
      and resting.sx == moving.sx and resting.sy == moving.sy,
    "card " .. i .. " keeps a shared crop so the authored bob remains visible")
end

hgssScreen.index = 2
local beforeMovedFocus = #fittedDraws
local movedFocusOK, movedFocusErr = pcall(hgssScreen.draw, hgssScreen)
T.check(movedFocusOK,
  "moving HGSS party focus redraws: " .. tostring(movedFocusErr))
for i = beforeMovedFocus + 1, beforeMovedFocus + #party do
  local card = i - beforeMovedFocus
  local draw = fittedDraws[i]
  T.check(draw and ((card == 2 and draw.quad.y >= 32)
      or (card ~= 2 and draw.quad.y < 32)),
    "HGSS animation follows the newly highlighted party card")
end

hgssRun.loader.modOptions.modern_party_ui = { animate_icons = false }
hgssScreen.blink = 10
local beforeStill = #fittedDraws
local stillOK, stillErr = pcall(hgssScreen.draw, hgssScreen)
T.check(stillOK,
  "the disabled animation frame draws headlessly: " .. tostring(stillErr))
for i = beforeStill + 1, beforeStill + #party do
  T.check(fittedDraws[i] and fittedDraws[i].quad.y < 32,
    "ICON ANIMATION OFF holds fitted HGSS card " .. i
      .. " on its resting frame")
end
graphics.draw = hgssRealDraw
Assets.imageData = hgssRealImageData
Assets.image = hgssRealImage
PartyMenu.drawIcon = drawIconBeforeHgss
hgssRun.release()
end

-- Wilds of Kanto exposes its configured follower sheet independently of its
-- PartyMenu.drawIcon wrapper. Another late-loading icon mod can legitimately
-- replace that shared wrapper; Modern Party UI must still draw Wilds artwork
-- instead of leaving all six card rails empty.
do
local wildsData = T.fixtures.fresh()
wildsData.icons = { icons = {}, byDex = {}, bySpecies = {} }
wildsData.palettes = data.palettes
Font.load(wildsData)
local drawIconBeforeWilds = PartyMenu.drawIcon
local wildsRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/wilds_of_kanto",
  "mods/modern_party_ui",
}, { data = wildsData, dev = true })
T.eq(#wildsRun.errors, 0, "loads beside Wilds of Kanto 2.1.7")

local wildsGame = {
  data = wildsRun.data,
  save = { party = party, inventory = {}, options = {} },
  stack = { states = {} },
  input = { wasPressed = function() return false end },
  renderer = { uiSize = function() return 320, 240 end },
}
local wildsScreen = wildsRun.data.screens.PartyMenu.new(wildsGame, {})
wildsScreen.blink = 5
local graphics = love.graphics
local realWildsDraw = graphics.draw
local realWildsImage = Assets.image
local realWildsImageData = Assets.imageData
local realWildsMark = PaletteFX.markTrueColor
local wildsDraws, wildsMarks = {}, {}
local fakeWildsData = {}
function fakeWildsData:getDimensions() return 16, 96 end
function fakeWildsData:getPixel(px, py)
  -- A deliberately narrow creature proves true-colour protection follows
  -- visible pixels instead of restoring its transparent 16x16 canvas.
  local localY = py % 16
  local opaque = px >= 4 and px <= 11 and localY >= 3 and localY <= 12
  return 1, 1, 1, opaque and 1 or 0
end
Assets.image = function(path)
  if tostring(path):find("overworld_wild_spawns", 1, true) then
    return {
      path = path,
      getDimensions = function() return 16, 96 end,
      getWidth = function() return 16 end,
      getHeight = function() return 96 end,
    }
  end
  return realWildsImage(path)
end
Assets.imageData = function(path)
  if tostring(path):find("overworld_wild_spawns", 1, true) then
    return fakeWildsData
  end
  return realWildsImageData(path)
end
-- Reproduce the reported load order: the global renderer no longer belongs
-- to Wilds and cannot draw any of its sprite sheets.
PartyMenu.drawIcon = function() return false end
graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if type(image) == "table"
      and tostring(image.path):find("overworld_wild_spawns", 1, true) then
    wildsDraws[#wildsDraws + 1] = {
      path = image.path, quad = quad, x = x, y = y,
      sx = sx or 1, sy = sy or sx or 1,
    }
  end
  return realWildsDraw(image, quad, x, y, rotation, sx, sy, ...)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  wildsMarks[#wildsMarks + 1] = { x = x, y = y, w = w, h = h }
end

local wildsOK, wildsErr = pcall(wildsScreen.draw, wildsScreen)
graphics.draw = realWildsDraw
Assets.image = realWildsImage
Assets.imageData = realWildsImageData
PaletteFX.markTrueColor = realWildsMark
PartyMenu.drawIcon = drawIconBeforeWilds
T.check(wildsOK,
  "Wilds artwork draws without its global icon hook: " .. tostring(wildsErr))
T.eq(#wildsDraws, #party,
  "every occupied party card consumes Wilds' exported sprite sheet")
local wildsCalls = wildsRun.loader.exports.overworld_wild_spawns.calls
T.eq(#wildsCalls, 3,
  "each distinct party species is resolved once through Wilds' public API")
for i, call in ipairs(wildsCalls) do
  T.eq(call.species, party[i].species,
    "Wilds resolver receives party species " .. i)
  T.eq(call.role, "party_menu",
    "Wilds resolver receives the party-menu role")
end
T.check(wildsDraws[1] and wildsDraws[1].quad.y == 48,
  "the highlighted healthy card uses Wilds' authored walk frame")
for i = 2, #wildsDraws do
  T.check(wildsDraws[i].quad.y == 0,
    "unselected Wilds card " .. i .. " stays on its authored idle frame")
end
T.check(#wildsMarks > #party,
  "Wilds true-colour protection follows opaque sprite rows")
for _, rect in ipairs(wildsMarks) do
  T.check(rect.w < 16,
    "Wilds transparent padding is never restored as a square")
end

wildsRun.release()
end

-- QoL Toggles PARTY SCROLL changes the live SummaryMenu's mon and native
-- sprite in place. The modern masked-art cache must follow that species even
-- when both Pokémon resolve to the same palette key.
do
local firstModernSprite = summary.modernSprite
local firstModernPath = summary.modernSpritePath
local firstSummaryMon, firstSummarySprite = summary.mon, summary.sprite
local switchedMon = party[2]
local switchedPath = require("src.pokemon.Sprites").path(
  game.data, switchedMon.species, "front",
  { mon = switchedMon, kind = "battle" })
summary.mon = switchedMon
summary.sprite = love.graphics.newImage(switchedPath)
summary.spriteTrueColor = false
local switchOK, switchErr = pcall(summary.draw, summary)
T.check(switchOK,
  "a QoL-style in-place party switch redraws: " .. tostring(switchErr))
T.check(summary.modernSpriteSpecies == switchedMon.species
    and summary.modernSpritePath == switchedPath
    and summary.modernSpritePath ~= firstModernPath,
  "the modern summary artwork path follows PARTY SCROLL's new Pokémon")
T.check(summary.modernSprite ~= firstModernSprite,
  "the previous Pokémon's masked sprite cache is discarded")
summary.mon, summary.sprite = firstSummaryMon, firstSummarySprite
summary.spriteTrueColor = false
summary.modernSpriteSpecies = nil
summary.modernSprite = nil
summary.modernSpriteKey = nil
end
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

-- DramaticShape 1.8.2 owns the shiny decision and species-specific colour
-- transform, but installs them through a class-level SummaryMenu palette wrap.
-- Modern Party UI owns an instance palette method, so it must consume the
-- mod's exported modules directly and apply the transform only to the art.
local dramaticData = T.fixtures.fresh()
dramaticData.icons = data.icons
dramaticData.palettes = data.palettes
Font.load(dramaticData)
PaletteFX.setMode("gbc")
local dramaticRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/dramatic_shape_shinies",
  "mods/modern_party_ui",
}, { data = dramaticData, dev = true })
T.eq(#dramaticRun.errors, 0,
  "loads beside DramaticShape shiny sprites")

local shinyMon = mon("FIXMON_A", "SPARKLE", 12, 45, 45)
shinyMon.stats = {
  hp = 45, attack = 24, defense = 20, speed = 18, special = 22,
}
shinyMon.shiny = true
local dramaticGame = {
  data = dramaticRun.data,
  save = {
    party = { shinyMon }, inventory = {}, options = {},
    player = { name = "RED", id = 13839 },
  },
  stack = stack,
  input = input,
  renderer = { uiSize = function() return 256, 144 end },
}
local shinySummary = dramaticRun.data.screens.SummaryMenu.new(
  dramaticGame, shinyMon)
T.check(shinySummary.dramaticShapeShinyCompatible == true,
  "the modern summary detects DramaticShape's public shiny modules")
local normalProfile = shinySummary:sgbPalettes(dramaticGame)[2].colors
local shinyCalls = dramaticRun.loader.exports.DRAMATIC_SHAPE.fixtureCalls
local shinyDrawOK, shinyDrawErr = pcall(shinySummary.draw, shinySummary)
T.check(shinyDrawOK,
  "DramaticShape shiny artwork draws in the modern stats screen: "
    .. tostring(shinyDrawErr))
T.check(shinySummary.modernDramaticShapeShiny == true,
  "the summary records that its artwork uses the shiny palette")
T.check(shinyCalls.paletteRequests > 0 and shinyCalls.colorTransforms >= 4,
  "the artwork consumes DramaticShape's species-specific palette transform")
T.check(shinySummary:sgbPalettes(dramaticGame)[2].colors == normalProfile,
  "DramaticShape changes the Pokemon artwork without recolouring its card")

local commonMon = mon("FIXMON_A", "COMMON", 12, 45, 45)
commonMon.stats = shinyMon.stats
local commonSummary = dramaticRun.data.screens.SummaryMenu.new(
  dramaticGame, commonMon)
local transformCount = shinyCalls.colorTransforms
local commonDrawOK, commonDrawErr = pcall(commonSummary.draw, commonSummary)
T.check(commonDrawOK,
  "ordinary artwork still draws beside DramaticShape: "
    .. tostring(commonDrawErr))
T.check(commonSummary.modernDramaticShapeShiny ~= true
    and shinyCalls.colorTransforms == transformCount,
  "ordinary Pokemon keep their normal summary colours")
dramaticRun.release()
PaletteFX.setMode(previousMode)

-- Crystal 251 0.10.3 exposes recalculated split stats through
-- exports.crystalSummary.statsFor. Use that public interface while replacing
-- its fixed classic overlay with five responsive Modern Party UI cards.
local splitData = T.fixtures.fresh()
splitData.icons = data.icons
splitData.palettes = data.palettes
Font.load(splitData)
PaletteFX.setMode("gbc")
local splitRun = T.sdk.loadMods({
  "mods/modern_party_ui/tests/fixtures/crystal_251_split",
  "mods/modern_party_ui/tests/fixtures/dv_tracker",
  "mods/modern_party_ui",
}, { data = splitData, dev = true })
T.eq(#splitRun.errors, 0,
  "loads beside Crystal 251 split stats and DV Tracker")

local splitMon = mon("FIXMON_A", "DUAL", 30, 88, 88)
splitMon.stats = {
  hp = 88, attack = 71, defense = 66, speed = 92, special = 101,
}
splitMon.crystal251Stats = {
  hp = 88, attack = 71, defense = 66, speed = 92,
  specialAttack = 137, specialDefense = 84,
}
splitMon.dvs = { attack = 7, defense = 8, speed = 9, special = 12 }
splitMon.statExp = {
  hp = 1111, attack = 2222, defense = 3333, speed = 6666,
  special = 4000, specialAttack = 4444, specialDefense = 5555,
}
local splitGame = {
  data = splitRun.data,
  save = {
    party = { splitMon }, inventory = {}, options = {},
    player = { name = "RED", id = 13839 },
  },
  stack = stack,
  input = input,
  renderer = { uiSize = function() return 256, 144 end },
}
local splitSummary = splitRun.data.screens.SummaryMenu.new(
  splitGame, splitMon)
T.check(splitSummary.splitSpecialCompatible == true,
  "the modern summary detects Crystal 251's public split-stat helper")

local splitText = {}
Font.draw = function(text, x, y)
  splitText[#splitText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local splitOK, splitErr = pcall(splitSummary.draw, splitSummary)
Font.draw = realFontDraw
T.check(splitOK,
  "Crystal 251 split stats draw responsively: " .. tostring(splitErr))
T.check(splitSummary.modernSplitSpecial == true,
  "a split-stat Pokémon selects the five-card presentation")
T.check(not splitSummary.crystal251ClassicSplitDrawn,
  "Crystal 251's classic overlay does not cover the modern cards")
T.check(splitRun.loader.exports.CRYSTAL_251.fixtureCalls.statsFor > 0,
  "the stats screen consumes Crystal 251's recalculated public values")

local splitCalls = {}
for _, call in ipairs(splitText) do splitCalls[call.text] = call end
T.check(splitCalls["SP.ATK"] and splitCalls["137"],
  "Special Attack is displayed independently with Crystal's live value")
T.check(splitCalls["SP.DEF"] and splitCalls["84"],
  "Special Defense is displayed independently with Crystal's live value")
T.check(not splitCalls["SPECIAL"] and not splitCalls["101"],
  "the obsolete combined Special value is omitted when a split is present")
T.check(splitCalls["SP.ATK"].y == splitCalls["SP.DEF"].y
    and splitCalls["SPEED"].y > splitCalls["SP.DEF"].y,
  "standard widescreen pairs the Special cards and centres Speed below")

splitGame.renderer = { uiSize = function() return 208, 144 end }
local squareSplitOK, squareSplitErr = pcall(
  splitSummary.draw, splitSummary)
T.check(squareSplitOK,
  "five stats reflow on a square surface: " .. tostring(squareSplitErr))
splitGame.renderer = { uiSize = function() return 160, 144 end }
local compactSplitOK, compactSplitErr = pcall(
  splitSummary.draw, splitSummary)
T.check(compactSplitOK,
  "five stats remain functional at 160x144: " .. tostring(compactSplitErr))

splitGame.renderer = { uiSize = function() return 640, 144 end }
local ultraText = {}
Font.draw = function(text, x, y)
  ultraText[#ultraText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local ultraSplitOK, ultraSplitErr = pcall(splitSummary.draw, splitSummary)
Font.draw = realFontDraw
T.check(ultraSplitOK,
  "five stats use the expanded ultrawide surface: "
    .. tostring(ultraSplitErr))
local ultraCalls = {}
for _, call in ipairs(ultraText) do ultraCalls[call.text] = call end
T.check(ultraCalls["SP.ATK"] and ultraCalls["SP.DEF"]
    and ultraCalls["SP.ATK"].y == ultraCalls["SP.DEF"].y,
  "ultrawide layouts keep Special Attack and Special Defense paired")

splitGame.renderer = { uiSize = function() return 256, 144 end }
splitSummary.page = 3
local splitDvText = {}
Font.draw = function(text, x, y)
  splitDvText[#splitDvText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
local splitDvOK, splitDvErr = pcall(splitSummary.draw, splitSummary)
Font.draw = realFontDraw
T.check(splitDvOK,
  "Crystal's five-DV page draws responsively: " .. tostring(splitDvErr))
T.check(splitSummary.modernSplitSpecialDVs == true,
  "Crystal's Special split activates separate DV cards")
local splitDvCalls = {}
for _, call in ipairs(splitDvText) do splitDvCalls[call.text] = call end
T.check(splitDvCalls["SP.A DV12"] and splitDvCalls["SP.D DV12"],
  "Special Attack and Special Defense reuse Crystal's shared Special DV")
T.check(splitDvCalls["EXP 4444"] and splitDvCalls["EXP 5555"],
  "split DV cards retain distinct Special Stat EXP when provided")

splitGame.renderer = { uiSize = function() return 160, 144 end }
local compactSplitDvOK, compactSplitDvErr = pcall(
  splitSummary.draw, splitSummary)
T.check(compactSplitDvOK,
  "five DV cards remain functional at 160x144: "
    .. tostring(compactSplitDvErr))
splitSummary.page = 1

-- Other split-stat mods can expose the conventional aliases directly on the
-- Pokémon without pretending to be Crystal 251.
local aliasMon = mon("FIXMON_A", "ALIASES", 25, 70, 70)
aliasMon.stats = {
  hp = 70, attack = 55, defense = 61, speed = 73,
  special = 80, spAtk = 99, spDef = 77,
}
local aliasSummary = splitRun.data.screens.SummaryMenu.new(
  splitGame, aliasMon)
local aliasOK, aliasErr = pcall(aliasSummary.draw, aliasSummary)
T.check(aliasOK and aliasSummary.modernSplitSpecial == true,
  "common spAtk/spDef fields activate the generic split-stat fallback: "
    .. tostring(aliasErr))

splitRun.release()
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
  if mode == "fill" and w == 8 and h == 8 then
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
local genderLevel
for _, call in ipairs(genderText) do
  if call.text == "♂" then partyGlyph = call end
  if call.text:match("^L%d") then genderLevel = call.text end
  if call.text:match("^NIDOR")
      and not call.text:find("♂", 1, true)
      and not call.text:find("♀", 1, true) then
    strippedPartyName = call
  end
end
T.check(partyGlyph and partyGlyph.x == 23,
  "the exported gender glyph sits directly before the modern level row")
T.eq(genderLevel, "L12",
  "gender spacing never clips a two-digit party level to LV1")
T.check(strippedPartyName ~= nil,
  "the gender glyph replaces the nickname's baked-in symbol")
T.check(genderBackings[1] and genderBackings[1].g > genderBackings[1].r
    and genderBackings[1].g > genderBackings[1].b,
  "the gender marker's exact glyph cell matches the final Grass card")
local fittedGenderMark
for _, rect in ipairs(genderMarks) do
  if rect.w == 8 and rect.h == 8 then fittedGenderMark = rect break end
end
T.check(fittedGenderMark ~= nil,
  "gender true-colour protection has no expanded square frame")

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
-- page, while Gen1 Modern UI 0.9.2 can otherwise suppress and redraw ordinary
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
  "mods/modern_party_ui/tests/fixtures/hgss_sprites",
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
;(function()
  local FaithfulRes = require("src.core.FaithfulRes")
  local realScaleCap = FaithfulRes.scaleCap
  FaithfulRes.scaleCap = function() return 6 end
  T.eq(select(1, modernRibbonScreen:uiSize()), 160,
    "Faithful Ratio keeps the ribbon collection at the native width")
  local faithfulZones = modernRibbonScreen:sgbPalettes(ribbonGame) or {}
  T.eq(faithfulZones[1] and faithfulZones[1].w, 160,
    "a stale wide renderer cannot override the faithful ribbon viewport")
  FaithfulRes.scaleCap = realScaleCap
end)()
local modernRibbonText = {}
Font.draw = function(text, x, y)
  modernRibbonText[#modernRibbonText + 1] = { text = text, x = x, y = y }
  return realFontDraw(text, x, y)
end
PaletteFX.setPass("ui")
for i = 1, 6 do PaletteFX.markTrueColor(8, i * 16 - 8, 16, 16) end
local modernRibbonOK, modernRibbonErr = pcall(
  modernRibbonScreen.draw, modernRibbonScreen)
Font.draw = realFontDraw
T.check(modernRibbonOK,
  "the modern ribbon cards draw: " .. tostring(modernRibbonErr))
local ribbonTrueColor = PaletteFX.trueColorRects("ui")
T.check(#ribbonTrueColor >= 1,
  "the ribbon screen replaces inherited claims with its profile icon")
local leakedRibbonClaim = false
for _, rect in ipairs(ribbonTrueColor) do
  if rect.x == 8 and rect.w == 16 and rect.h == 16 then
    leakedRibbonClaim = true
  end
end
T.check(not leakedRibbonClaim,
  "party-icon rectangles cannot leak onto the ribbon collection")
PaletteFX.clearTrueColor()
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

-- HGSS uses a padded two-frame canvas. The ribbon profile must crop, enlarge,
-- centre, and animate its visible creature without restoring a grey rectangle.
;(function()
ribbonRun.data.icons.bySpecies.FIXMON_A = {
  image = "mods/HGSS_SPRITES/assets/icons/fixmon_a.png",
  frames = 2,
  trueColor = true,
}
local fakeRibbonImage, fakeRibbonData = {}, {}
function fakeRibbonData:getDimensions() return 32, 64 end
function fakeRibbonData:getPixel(px, py)
  local frameY = py % 32
  local opaque = py < 32
    and px >= 8 and px <= 23 and frameY >= 6 and frameY <= 25
    or py >= 32
      and px >= 8 and px <= 23 and frameY >= 7 and frameY <= 26
  return 1, 1, 1, opaque and 1 or 0
end
local oldRibbonImageData, oldRibbonImage = Assets.imageData, Assets.image
local oldRibbonDraw = graphics.draw
local ribbonSpriteDraws, ribbonMarks = {}, {}
local oldRibbonMark = PaletteFX.markTrueColor
Assets.imageData = function(path)
  if tostring(path):lower():find("hgss", 1, true) then
    return fakeRibbonData
  end
  return oldRibbonImageData(path)
end
Assets.image = function(path)
  if tostring(path):lower():find("hgss", 1, true) then
    return fakeRibbonImage
  end
  return oldRibbonImage(path)
end
graphics.draw = function(image, quad, x, y, rotation, sx, sy, ...)
  if image == fakeRibbonImage then
    ribbonSpriteDraws[#ribbonSpriteDraws + 1] = {
      quad = quad, x = x, y = y, sx = sx or 1, sy = sy or sx or 1,
    }
  end
  return oldRibbonDraw(image, quad, x, y, rotation, sx, sy, ...)
end
PaletteFX.markTrueColor = function(x, y, w, h)
  ribbonMarks[#ribbonMarks + 1] = { x = x, y = y, w = w, h = h }
end
local hgssRibbon = ribbonRun.data.screens.KantoRibbonsDetail.new(
  ribbonGame, ribbonMon)
hgssRibbon.blink = 0
local hgssRibbonRestOK, hgssRibbonRestErr = pcall(
  hgssRibbon.draw, hgssRibbon)
local restingRibbonSprite = ribbonSpriteDraws[1]
hgssRibbon.blink = 48
local hgssRibbonOK, hgssRibbonErr = pcall(hgssRibbon.draw, hgssRibbon)
Assets.imageData, Assets.image = oldRibbonImageData, oldRibbonImage
graphics.draw = oldRibbonDraw
PaletteFX.markTrueColor = oldRibbonMark
T.check(hgssRibbonOK,
  "the fitted HGSS ribbon profile draws: " .. tostring(hgssRibbonErr))
T.check(hgssRibbonRestOK,
  "the resting HGSS ribbon profile draws: " .. tostring(hgssRibbonRestErr))
local ribbonSprite = ribbonSpriteDraws[2]
local ribbonSpriteW = ribbonSprite and ribbonSprite.quad.w * ribbonSprite.sx or 0
local ribbonSpriteH = ribbonSprite and ribbonSprite.quad.h * ribbonSprite.sy or 0
T.check(ribbonSprite and ribbonSprite.quad.y >= 32,
  "the ribbon profile advances to HGSS frame two")
T.check(restingRibbonSprite and ribbonSprite
    and restingRibbonSprite.quad.x == ribbonSprite.quad.x
    and restingRibbonSprite.quad.y % 32 == ribbonSprite.quad.y % 32
    and restingRibbonSprite.quad.w == ribbonSprite.quad.w
    and restingRibbonSprite.quad.h == ribbonSprite.quad.h
    and restingRibbonSprite.x == ribbonSprite.x
    and restingRibbonSprite.y == ribbonSprite.y
    and restingRibbonSprite.sx == ribbonSprite.sx
    and restingRibbonSprite.sy == ribbonSprite.sy,
  "the ribbon profile preserves HGSS's internal one-pixel animation")
T.check(math.max(ribbonSpriteW, ribbonSpriteH) >= 17.5
    and math.max(ribbonSpriteW, ribbonSpriteH) <= 18.1,
  "the visible HGSS ribbon sprite fills its 18px profile rail")
T.check(ribbonSprite.x >= 8 and ribbonSprite.y >= 21
    and ribbonSprite.x + ribbonSpriteW <= 26.1
    and ribbonSprite.y + ribbonSpriteH <= 39.1,
  "the fitted HGSS ribbon sprite remains centred inside its profile rail")
T.check(#ribbonMarks > 1,
  "the HGSS ribbon profile protects opaque rows instead of a grey rectangle")
end)()

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
