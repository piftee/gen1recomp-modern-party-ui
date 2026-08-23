-- Modern Party UI keeps the engine's battle/field party controller intact
-- and replaces only its presentation.  Keeping the behavior in one place is
-- important: the party picker is also used by items, TM/HMs, trades, forced
-- battle switches and field moves.
return function(mod)
  local optionSchema = {
    { key = "card_color", label = "CARD COLOR", type = "choice",
      default = "species", choices = {
        -- Keep the original persisted value for the new default so existing
        -- installs automatically receive type colours after updating.
        { "TYPE", "species" }, { "SPECIES", "species_palette" },
        { "HEALTH", "health" }, { "BLUE", "blue" },
        { "MONO", "mono" },
      } },
    -- Keep the animation switch on the first settings page. It used to be
    -- the eighth row and was labelled PARTY ICON there, which made the
    -- control both easy to miss and unclear about what it changed.
    { key = "animate_icons", label = "ICON ANIMATION", type = "toggle",
      default = true },
    { key = "hp_text", label = "HP DISPLAY", type = "choice",
      default = "bar", choices = {
        { "VALUES", "values" }, { "PERCENT", "percent" },
        { "BAR ONLY", "bar" },
      } },
    { key = "exp_text", label = "EXP DISPLAY", type = "choice",
      default = "percent", choices = {
        { "VALUES", "values" }, { "PERCENT", "percent" },
        { "BAR ONLY", "bar" },
      } },
    { key = "exp_strip", label = "EXP STRIP", type = "toggle",
      default = true },
    { key = "empty_slots", label = "EMPTY SLOTS", type = "toggle",
      default = true },
    { key = "pattern", label = "BACKDROP", type = "choice",
      default = "grid", choices = {
        { "GRID", "grid" }, { "PLAIN", "plain" },
      } },
    { key = "responsive", label = "WIDESCREEN", type = "toggle",
      default = true },
  }
  mod.options:define(optionSchema)

  -- Expose the schema through one entry in the game's ordinary OPTIONS
  -- screen. Activating it opens a dedicated Options-style page containing
  -- every Modern Party UI setting, rather than appending eight loose rows to
  -- an already-long main list. The mod manager remains the canonical owner.
  local function setOption(game, key, value)
    local options = game and game.save and game.save.options
    if options then
      options.modOptions = options.modOptions or {}
      options.modOptions[mod.id] = options.modOptions[mod.id] or {}
      options.modOptions[mod.id][key] = value
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
      if loader.events then
        loader.events:emit("mod.options_changed",
          { mod = mod.id, key = key, value = value })
      end
    end
  end

  local function optionRows()
    local out = {}
    for _, sourceRow in ipairs(optionSchema) do
      local row = sourceRow
      local rendered = {
        id = "modern_party_ui_" .. row.key,
        label = row.label or row.key,
      }
      if row.type == "toggle" then
        rendered.value = function()
          return mod.options:get(row.key) and "ON" or "OFF"
        end
        rendered.step = function(g)
          setOption(g, row.key, not mod.options:get(row.key))
          return true
        end
      elseif row.type == "choice" then
        rendered.value = function()
          local current = mod.options:get(row.key)
          for _, choice in ipairs(row.choices or {}) do
            if choice[2] == current then return choice[1] end
          end
          return "----"
        end
        rendered.step = function(g, direction)
          local choices = row.choices or {}
          if #choices == 0 then return false end
          local current = mod.options:get(row.key)
          local index = 1
          for i, choice in ipairs(choices) do
            if choice[2] == current then index = i break end
          end
          index = (index - 1 + (direction or 1)) % #choices + 1
          setOption(g, row.key, choices[index][2])
          return true
        end
      end
      out[#out + 1] = rendered
    end
    return out
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "modern_party_ui",
      label = "MODERN PARTY UI",
      value = function() return "OPEN" end,
      activate = function(g)
        local OptionsMenu = require("src.ui.OptionsMenu")
        local page = OptionsMenu.new(g)
        -- OptionsMenu.new invokes this hook while constructing itself. Its
        -- resulting main rows are intentionally replaced with the dedicated
        -- schema page before the screen is shown.
        page.rows = optionRows()
        page.index, page.scroll = 1, 0
        g.stack:push(page)
      end,
    }
    return out
  end)

  local genderMod = mod.find("gender_mod")
  local genderExports = genderMod and genderMod.exports or nil
  local gen1ModernUi = mod.find("gen1_modern_ui")
  local kantoRibbons = mod.find("kanto_ribbons")
  local dramaticShape = mod.find("DRAMATIC_SHAPE")
  local crystal251 = mod.find("CRYSTAL_251")
  local wildsOfKanto = mod.find("overworld_wild_spawns")
  local compatibility = {
    dvTracker = mod.find("dv_tracker") ~= nil,
    kantoRibbons = kantoRibbons ~= nil,
    kantoRibbonsExports = kantoRibbons and kantoRibbons.exports or nil,
    gen1ModernUi = gen1ModernUi ~= nil,
    crystalSprites = mod.find(
      "crystal_animated_sprites_with_shiny_visuals") ~= nil,
    dramaticShape = dramaticShape ~= nil,
    dramaticShapeExports = dramaticShape and dramaticShape.exports or nil,
    crystal251 = crystal251 ~= nil,
    crystal251Summary = crystal251 and crystal251.exports
      and crystal251.exports.crystalSummary or nil,
    uniqueMenuIcons = mod.find("unique_menu_icons") ~= nil,
    hgssSprites = mod.find("HGSS_SPRITES") ~= nil,
    wildsOfKanto = wildsOfKanto ~= nil,
    wildsOfKantoExports = wildsOfKanto and wildsOfKanto.exports or nil,
  }

  local function loadScreen(filename, label)
    local source, readErr = mod:read(filename)
    if not source then
      mod.log:error("%s is missing (%s); reinstall the mod",
        filename, tostring(readErr or "unknown read error"))
      return nil
    end

    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. filename)
    if not chunk then
      mod.log:error("%s did not compile: %s", filename, tostring(compileErr))
      return nil
    end

    local ok, makeScreen = pcall(chunk)
    if not ok or type(makeScreen) ~= "function" then
      mod.log:error("%s must return a factory function: %s",
        filename, tostring(makeScreen))
      return nil
    end

    local made, record = pcall(makeScreen, mod, genderExports, compatibility)
    if not made or type(record) ~= "table"
        or type(record.new) ~= "function" then
      mod.log:error("%s screen factory failed: %s", label, tostring(record))
      return nil
    end
    return record
  end

  local record = loadScreen("screen.lua", "party")
  if not record then return end

  -- Screen records are presentation ownership, not controller inheritance.
  -- A compatibility mod may already have registered a classic PartyMenu or
  -- SummaryMenu before us. Registering again would fail the whole mod during
  -- load, which is why some larger Windows mod stacks silently fell back to
  -- the classic UI. Replace any existing record and keep composing behavior
  -- through the live engine controller and the explicit adapters below.
  local function installScreen(id, replacement)
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, replacement)
      return true
    end
    -- Both ids are normally engine fallbacks rather than registry records.
    mod.content.screens:register(id, replacement)
    return false
  end

  local replacedParty = installScreen("PartyMenu", record)
  local summary = loadScreen("summary.lua", "summary")
  if not summary then return end
  local replacedSummary = installScreen("SummaryMenu", summary)
  local replacedRibbons = false
  if compatibility.kantoRibbons then
    local ribbons = loadScreen("ribbons.lua", "Kanto Ribbons")
    if ribbons then
      replacedRibbons = installScreen("KantoRibbonsDetail", ribbons)
    end
  end

  -- Kanto Ribbons 0.18.0 opens its standalone detail screen after
  -- the final native summary page. DV Tracker and other controller mods can
  -- replace SummaryMenu.update after Kanto Ribbons captured it, so install a
  -- final presentation-aware bridge after every optional dependency. Mask the
  -- A/B edge while calling the downstream controller: animation wrappers still
  -- receive their update tick, but no nested page wrapper can close early or
  -- open the ribbons screen twice.
  if compatibility.kantoRibbons then
    local SummaryMenu = require("src.ui.SummaryMenu")
    local downstreamUpdate = SummaryMenu.update
    SummaryMenu.update = function(self, dt)
      local input = self and self.game and self.game.input
      local finalPage = tonumber(self and self.modernSummaryPages)
        or tonumber(self and self.pageCount) or 2
      local atRibbonHandoff = self and self.modernPartySummary == true
        and (tonumber(self.page) or 1) >= finalPage
        and input and type(input.wasPressed) == "function"
        and (input:wasPressed("a") or input:wasPressed("b"))
      if not atRibbonHandoff then return downstreamUpdate(self, dt) end

      local originalWasPressed = input.wasPressed
      input.wasPressed = function(source, key)
        if key == "a" or key == "b" then return false end
        return originalWasPressed(source, key)
      end
      local ok, result = pcall(downstreamUpdate, self, dt)
      input.wasPressed = originalWasPressed
      if not ok then error(result, 0) end

      local game = self.game
      if game and game.stack and type(game.stack.pop) == "function" then
        game.stack:pop()
      end
      mod.ui.push(game, "KantoRibbonsDetail", self.mon)
      return result
    end
  end

  -- Gen1 Modern UI intentionally falls back when a source screen publishes a
  -- complete custom renderer that cannot be represented by its generic row
  -- model. Register that relationship explicitly so its compositor never
  -- suppresses these two screens, while it remains free to present every
  -- other menu in the stack. The small models satisfy the public API contract;
  -- canSuppressNative=false keeps Modern Party UI's responsive renderer in
  -- charge and leaves all controller input source-owned.
  local function isModernPartyNamingScreen(state)
    if type(state) ~= "table" or state.screenId ~= "NamingScreen" then
      return false
    end
    local game = state.game
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return false end

    -- NamingScreen is pushed above PartyMenu by QoL Toggles (and compatible
    -- rename actions). Only claim that child transition; ordinary Name Rater,
    -- starter and player naming screens remain available to Gen1 Modern UI.
    for index = #states, 2, -1 do
      if states[index] == state then
        local parent = states[index - 1]
        return type(parent) == "table" and parent.modernPartyUI == true
      end
    end
    return false
  end

  mod.exports.gen1ModernUi = {
    apiVersion = 1,
    screens = {
      ModernPartyRoster = {
        match = function(state)
          return type(state) == "table" and state.modernPartyUI == true
        end,
        model = function(game, state)
          local rows = {}
          for _, mon in ipairs(state.party
              or (game and game.save and game.save.party) or {}) do
            rows[#rows + 1] = {
              label = mon.nickname or mon.species or "POKéMON",
              value = mon.level and ("LV%d"):format(mon.level) or "",
            }
          end
          return {
            title = "POKéMON",
            rows = rows,
            index = state.index or 1,
            footer = { "Modern Party UI" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
      ModernPartySummary = {
        match = function(state)
          return type(state) == "table"
            and state.modernPartySummary == true
        end,
        model = function(_, state)
          local titles = { "STATS", "MOVES", "DVS" }
          return {
            title = "SUMMARY",
            rows = { {
              label = titles[state.page or 1] or "SUMMARY",
              value = state.mon and (state.mon.nickname
                or state.mon.species) or "",
            } },
            index = 1,
            footer = { "Modern Party UI" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
      ModernPartyRibbons = {
        match = function(state)
          return type(state) == "table"
            and state.modernPartyRibbons == true
        end,
        model = function(_, state)
          return {
            title = "RIBBONS",
            rows = state.modernRibbonRows or {},
            index = math.min(#(state.modernRibbonRows or {}),
              (state.scroll or 0) + 1),
            scroll = state.scroll or 0,
            footer = { "A/B back" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
      ModernPartyNaming = {
        match = isModernPartyNamingScreen,
        model = function(_, state)
          return {
            title = state.title or "NICKNAME?",
            rows = {},
            index = 1,
            footer = { "NamingScreen remains source-owned" },
          }
        end,
        layer = "screen",
        canSuppressNative = false,
      },
    },
  }

  local uiExports = gen1ModernUi and gen1ModernUi.exports
  if uiExports and type(uiExports.registerAdapter) == "function" then
    local ok, registered, reason = pcall(uiExports.registerAdapter, {
      owner = mod.id,
      contract = mod.exports.gen1ModernUi,
    })
    if not ok or registered == false then
      mod.log:warn("Gen1 Modern UI adapter registration failed: %s",
        tostring(reason or registered))
    end
  end

  local adapters = {}
  if genderExports then adapters[#adapters + 1] = "Gender Mod" end
  if compatibility.dvTracker then adapters[#adapters + 1] = "DV Tracker" end
  if compatibility.kantoRibbons then
    adapters[#adapters + 1] = "Kanto Ribbons"
  end
  if compatibility.gen1ModernUi then
    adapters[#adapters + 1] = "Gen1 Modern UI"
  end
  if compatibility.crystalSprites then
    adapters[#adapters + 1] = "Crystal Animated Sprites"
  end
  if compatibility.dramaticShape then
    adapters[#adapters + 1] = "DramaticShape Shinies"
  end
  if compatibility.crystal251 then
    adapters[#adapters + 1] = "Crystal 251 Split Stats"
  end
  if compatibility.uniqueMenuIcons then
    adapters[#adapters + 1] = "Unique Menu Icons"
  end
  if compatibility.hgssSprites then
    adapters[#adapters + 1] = "HGSS Visual Overhaul"
  end
  local suffix = #adapters > 0 and (" with " .. table.concat(adapters, ", "))
    or ""
  mod.log:info(
    "modern party roster and summary enabled%s " ..
      "(replaced records: %s/%s/%s)",
    suffix, tostring(replacedParty), tostring(replacedSummary),
    tostring(replacedRibbons))
end
