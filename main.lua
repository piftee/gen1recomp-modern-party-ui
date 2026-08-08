-- Modern Party UI keeps the engine's battle/field party controller intact
-- and replaces only its presentation.  Keeping the behavior in one place is
-- important: the party picker is also used by items, TM/HMs, trades, forced
-- battle switches and field moves.
return function(mod)
  local optionSchema = {
    { key = "card_color", label = "CARD COLOR", type = "choice",
      default = "species", choices = {
        { "SPECIES", "species" }, { "HEALTH", "health" },
        { "BLUE", "blue" }, { "MONO", "mono" },
      } },
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
    { key = "animate_icons", label = "ICON ANIM", type = "toggle",
      default = true },
  }
  mod.options:define(optionSchema)

  -- Mirror the same schema into the game's ordinary OPTIONS screen. The mod
  -- manager remains the canonical options owner; these rows write the exact
  -- same options.modOptions bucket and update the live loader so an open
  -- party screen reflects a change immediately.
  local mainLabels = {
    card_color = "PARTY COLOR",
    hp_text = "PARTY HP TEXT",
    exp_text = "PARTY EXP TEXT",
    exp_strip = "PARTY EXP BAR",
    empty_slots = "PARTY SLOTS",
    pattern = "PARTY BG",
    responsive = "PARTY WIDE",
    animate_icons = "PARTY ICON",
  }

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

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    for _, sourceRow in ipairs(optionSchema) do
      local row = sourceRow
      local rendered = {
        id = "modern_party_ui_" .. row.key,
        label = mainLabels[row.key] or row.label or row.key,
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
  end)

  local source, readErr = mod:read("screen.lua")
  if not source then
    mod.log:error("screen.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end

  local chunk, compileErr = load(source, "@" .. mod.path .. "/screen.lua")
  if not chunk then
    mod.log:error("screen.lua did not compile: %s", tostring(compileErr))
    return
  end

  local ok, makeScreen = pcall(chunk)
  if not ok or type(makeScreen) ~= "function" then
    mod.log:error("screen.lua must return a factory function: %s",
      tostring(makeScreen))
    return
  end

  local made, record = pcall(makeScreen, mod)
  if not made or type(record) ~= "table" or type(record.new) ~= "function" then
    mod.log:error("party screen factory failed: %s", tostring(record))
    return
  end

  -- PartyMenu is normally a built-in fallback rather than a registry record,
  -- so registering this id makes the mod-owned factory win in Screens.resolve.
  mod.content.screens:register("PartyMenu", record)
  mod.log:info("modern party roster enabled")
end
