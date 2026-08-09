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
    local first
    for i, row in ipairs(options.rows) do
      if row.id == "modern_party_ui_card_color" then first = i break end
    end
    if not first then
      U.log("FAIL Modern Party UI rows are missing from Options")
      return
    end
    options.index, options.scroll = first, first - 1
    U.wait(8)
    U.log("PASS first four Modern Party UI settings are in Options")
    U.shot(game, DIR .. "/modern_party_ui_options_1.png")
    options.index, options.scroll = first + 4, first + 3
    U.wait(8)
    U.log("PASS remaining Modern Party UI settings are in Options")
    U.shot(game, DIR .. "/modern_party_ui_options_2.png")
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
  menu.subItems = {
    { label = "STATS", action = "stats" },
    { label = "SWITCH", action = "switch" },
  }
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
end
