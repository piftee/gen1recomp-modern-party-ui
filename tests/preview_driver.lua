-- Visual smoke test for the Modern Party UI. Run from the repository root:
--   SHOT_DIR=/tmp/modern-party-ui \
--   POKEPORT_DRIVER=mods/modern_party_ui/tests/preview_driver.lua \
--   POKEPORT_IDENTITY=modern-party-ui-preview POKEPORT_VERSION=red love .
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local Growth = require("src.pokemon.Growth")
  local Screens = require("src.ui.Screens")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/modern-party-ui"

  if os.getenv("PREVIEW_SQUARE") == "1" then
    love.window.setMode(1024, 768, { resizable = true, minwidth = 640,
      minheight = 576 })
  elseif os.getenv("PREVIEW_WIDE") == "1" then
    love.window.setMode(1280, 720, { resizable = true, minwidth = 640,
      minheight = 576 })
  elseif os.getenv("PREVIEW_ANDROID") == "1" then
    love.window.setMode(1600, 845, { resizable = true,
      minwidth = 640, minheight = 360 })
  elseif os.getenv("PREVIEW_PORTRAIT") == "1" then
    love.window.setMode(390, 844, { resizable = true,
      minwidth = 320, minheight = 480 })
  end

  if os.getenv("PREVIEW_OPTIONS") == "1" then
    while game.stack:top() do game.stack:pop() end
    local OptionsMenu = require("src.ui.OptionsMenu")
    local options = OptionsMenu.new(game)
    game.stack:push(options)
    local entry
    for i, row in ipairs(options.rows) do
      if row.id == "modern_party_ui" then entry = row break end
    end
    if not entry or type(entry.activate) ~= "function" then
      U.log("FAIL Modern Party UI page is missing from Options")
      return
    end
    entry.activate(game)
    options = game.stack:top()
    options.index, options.scroll = 1, 0
    U.wait(8)
    U.log("PASS icon animation is visible on the first Modern Party UI page")
    U.shot(game, DIR .. "/modern_party_ui_options_1.png")
    options.index = #options.rows
    options.scroll = math.max(0, #options.rows - 4)
    U.wait(8)
    U.log("PASS all remaining settings are on the Modern Party UI page")
    U.shot(game, DIR .. "/modern_party_ui_options_2.png")
    return
  end

  if os.getenv("PREVIEW_PARTY_TOOLS") == "1" then
    while game.stack:top() do game.stack:pop() end
    local exports = game.mods and game.mods.exports
      and game.mods.exports.modern_party_ui
    local tools = exports and exports.partyTools
    if not tools then
      U.log("FAIL Modern Party UI party tools are unavailable")
      return
    end

    -- These tools normally open above the responsive party screen and inherit
    -- its logical width. Recreate that parent relationship in the standalone
    -- preview so the capture does not fall back to the original 160px canvas.
    local windowW, windowH = love.window.getMode()
    local previewWidth, previewHeight
    if windowH >= windowW * 1.35 then
      local portraitScale = math.max(1, math.floor(windowW / 160))
      previewWidth = 160
      previewHeight = math.min(400, math.floor(windowH / portraitScale))
      previewHeight = previewHeight - ((previewHeight - 24) % 6)
    else
      local previewScale = math.max(1,
        math.floor(math.min(windowW / 160, windowH / 144)))
      previewWidth = math.max(160, math.floor(windowW / previewScale))
      previewHeight = 144
    end
    local previewParent = {
      uiSize = function()
        return previewWidth, previewHeight
      end,
    }

    local NamingScreen = require("src.ui.NamingScreen")
    local previewMon = Pokemon.new(game.data, "CHARIZARD", 36)
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.modern_party_ui =
      game.mods.modOptions.modern_party_ui or {}
    game.mods.modOptions.modern_party_ui.rename_style = "classic"
    local naming = NamingScreen.new(game, {
      title = "RENAME?",
      maxLen = 10,
      default = "CHARIZARD",
      onDone = function() end,
    })
    naming.glyphs = { "C", "H", "A", "R" }
    tools.decorateNaming(naming, previewParent, previewMon)
    game.stack:push(naming)
    U.wait(8)
    U.log("PASS modern Rename screen prepared")
    U.shot(game, DIR .. "/modern_party_rename.png")

    while game.stack:top() do game.stack:pop() end
    game.mods.modOptions.modern_party_ui.rename_style = "modern"
    naming = NamingScreen.new(game, {
      title = "RENAME?",
      maxLen = 10,
      default = "CHARIZARD",
      onDone = function() end,
    })
    naming.glyphs = { "C", "H", "A", "R" }
    tools.decorateNaming(naming, previewParent, previewMon)
    game.stack:push(naming)
    U.wait(8)
    U.log("PASS optional modern Rename screen prepared")
    U.shot(game, DIR .. "/modern_party_rename_modern.png")

    while game.stack:top() do game.stack:pop() end
    local Menu = require("src.ui.Menu")
    local relearn = Menu.new(game, {
      { label = "EMBER", onSelect = function() end },
      { label = "SMOKESCREEN", onSelect = function() end },
      { label = "DRAGON RAGE", onSelect = function() end },
      { label = "SLASH", onSelect = function() end },
    }, { maxVisible = 4 })
    relearn.index = 2
    tools.decorateRelearn(relearn, previewParent)
    game.stack:push(relearn)
    U.wait(8)
    U.log("PASS modern Relearn screen prepared")
    U.shot(game, DIR .. "/modern_party_relearn.png")
    return
  end

  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  if os.getenv("PREVIEW_VALUES") == "1" and game.mods then
    game.mods.modOptions = game.mods.modOptions or {}
    local current = game.mods.modOptions.modern_party_ui or {}
    current.hp_text = "values"
    current.exp_text = "percent"
    current.exp_strip = true
    game.mods.modOptions.modern_party_ui = current
  end

  local specs = {
    { "VENUSAUR", 52, 1.00 },
    { "CHARIZARD", 50, 0.52, "PAR" },
    { "BLASTOISE", 51, 0.18 },
    { "PIKACHU", 42, 0.00 },
    { "SNORLAX", 38, 0.77, "SLP" },
    { "MEW", 35, 1.00 },
  }
  local party = {}
  for i, spec in ipairs(specs) do
    local mon = Pokemon.new(game.data, spec[1], spec[2])
    mon.hp = math.floor(mon.stats.hp * spec[3])
    mon.status = spec[4]
    local def = game.data.pokemon[mon.species]
    local nextExp = Growth.expForLevel(def.growthRate, mon.level + 1,
      game.data.growth_rates)
    mon.exp = math.floor((mon.exp + nextExp) / 2)
    party[i] = mon
  end
  game.save.party = party

  -- Remove the intro screen so only the screen under test is captured.
  while game.stack:top() do game.stack:pop() end
  local menu = Screens.push(game, "PartyMenu", {})
  menu.index = 2
  U.wait(12)

  U.log(menu.modernPartyUI and "PASS modern screen is active"
    or "FAIL modern screen was not registered")
  U.shot(game, DIR .. "/modern_party_ui.png")

  -- Capture the interaction overlay in a deterministic visual state. The
  -- behavior test separately drives the original controller's input path.
  menu.submenu = true
  menu.subIndex = 1
  if os.getenv("PREVIEW_TALL_ACTIONS") == "1" then
    menu.subItems = {
      { label = "STATS", action = "stats" },
      { label = "SWITCH", action = "switch" },
      { label = "RELEARN", action = "relearn" },
      { label = "RENAME", action = "rename" },
      { label = "FOLLOW", action = "follow" },
    }
  else
    menu.subItems = {
      { label = "STATS", action = "stats" },
      { label = "SWITCH", action = "switch" },
    }
  end
  U.wait(8)
  U.log("PASS action menu prepared")
  U.shot(game, DIR .. "/modern_party_ui_actions.png")

  while game.stack:top() do game.stack:pop() end
  local summary = Screens.push(game, "SummaryMenu", party[2])
  U.wait(8)
  U.log(summary.modernPartySummary
    and "PASS modern stats summary prepared"
    or "FAIL modern summary was not registered")
  U.shot(game, DIR .. "/modern_party_summary_stats.png")
  summary.page = 2
  U.wait(8)
  U.log("PASS modern moves summary prepared")
  U.shot(game, DIR .. "/modern_party_summary_moves.png")
  summary.modernMoveIndex = 2
  summary.modernMoveDetail = true
  U.wait(8)
  U.log("PASS modern move details prepared")
  U.shot(game, DIR .. "/modern_party_summary_move_detail.png")
end
