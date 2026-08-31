-- Modern presentation adapters for party actions contributed by other mods.
--
-- Rename and Relearn remain owned by their source mods: this module wraps
-- only the screen they push, preserving every callback and controller rule.
return function(mod)
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Strings = require("src.core.Strings")

  local WHITE, LIGHT, DARK, BLACK = 1, 170 / 255, 85 / 255, 0
  local unpackArgs = table.unpack or unpack
  local function packArgs(...) return { n = select("#", ...), ... } end

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function fitText(text, width)
    text = tostring(text or "")
    width = math.max(0, math.floor(width or 0))
    if Font.width(text) <= width then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, width)
    if count < 1 then return "" end
    return text:sub(1, spans[count].to)
  end

  local function drawText(text, x, y, width, shade)
    text = fitText(text, width)
    gray(shade == nil and BLACK or shade)
    Font.draw(text, math.floor(x), math.floor(y))
    return Font.width(text)
  end

  local function centered(text, x, y, width, shade)
    text = fitText(text, width)
    return drawText(text, x + math.floor((width - Font.width(text)) / 2),
      y, width, shade)
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(1, math.min(cut or 3,
      math.floor(w / 2), math.floor(h / 2)))
    if love.graphics.polygon then
      love.graphics.polygon(mode, {
        x + cut, y, x + w - cut, y,
        x + w, y + cut, x + w, y + h - cut,
        x + w - cut, y + h, x + cut, y + h,
        x, y + h - cut, x, y + cut,
      })
    else
      love.graphics.rectangle(mode, x, y, w, h)
    end
  end

  local function card(x, y, w, h, selected)
    gray(BLACK)
    chamfer("fill", x + 2, y + 2, w - 2, h - 2, 3)
    -- The extracted Gen 1 tile font is black ink rather than a tintable alpha
    -- mask.  A paper-white selected face keeps every glyph readable while the
    -- heavier black edge still makes the active control unmistakable.
    gray(selected and WHITE or LIGHT)
    chamfer("fill", x, y, w - 2, h - 2, 3)
    gray(selected and BLACK or DARK)
    love.graphics.rectangle("fill", x + 2, y + 2, 1,
      math.max(1, h - 7))
  end

  local function surfaceSize(game, parent)
    if parent and type(parent.uiSize) == "function" then
      local ok, w, h = pcall(parent.uiSize, parent)
      if ok and tonumber(w) and tonumber(h) then
        return math.max(160, math.floor(w)), math.max(144, math.floor(h))
      end
    end
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or 144
    local scale = math.max(1, math.floor(math.min(
      width / Renderer.WIDTH, height / 144)))
    return math.max(160, math.floor(width / scale)),
      math.max(144, math.floor(height / scale))
  end

  local function installSurface(state, parent)
    -- Resolve the surface on every frame.  Rename/Relearn are pushed while
    -- their parent is still drawing; caching graphics dimensions at that
    -- moment captures the old 160x144 canvas and clips the responsive right
    -- edge on the following frame.
    state.uiSize = function(self)
      local width, height = surfaceSize(self.game, parent)
      self.modernPartyToolWidth = width
      self.modernPartyToolHeight = height
      return width, height
    end
    -- Game:draw centres a child it considers "classic" inside a wide party
    -- canvas.  These adapters already draw the complete responsive surface,
    -- so identify them as its owner whenever either logical axis is extended;
    -- otherwise the extra centring offset pushes one edge off-canvas.
    state.isWideBattleLayout = function(self)
      local width, height = self:uiSize()
      return width ~= Renderer.WIDTH or height ~= Renderer.HEIGHT
    end
    state:uiSize()
    state.sgbPalettes = function(self, game)
      local colors = game and game.data
        and PaletteFX.pal(game.data, "BLUEMON")
      if not colors then return nil end
      local width, height = self:uiSize()
      -- PaletteFX.wholeNamed is the original 160x144 rectangle.  Supplying
      -- that fixed zone on a responsive canvas made the uncovered edge blit
      -- as a black strip even though the screen itself had the right size.
      return { { colors = colors, x = 0, y = 0,
        w = width, h = height } }
    end
  end

  local function backdrop(width, height, title, footer)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, width, height)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, width, 16)
    love.graphics.rectangle("fill", 0, height - 8, width, 8)
    centered(title, 4, 4, width - 8, WHITE)
    centered(footer, 4, height - 8, width - 8, WHITE)
  end

  local function checkerHorizontal(x, y, width)
    for offset = 0, width - 1, 4 do
      gray(DARK)
      love.graphics.rectangle("fill", x + offset, y, 2, 2)
      gray(LIGHT)
      love.graphics.rectangle("fill", x + offset + 2, y + 2, 2, 2)
    end
  end

  local function checkerVertical(x, y, height)
    for offset = 0, height - 1, 4 do
      gray(DARK)
      love.graphics.rectangle("fill", x, y + offset, 2, 2)
      gray(LIGHT)
      love.graphics.rectangle("fill", x + 2, y + offset + 2, 2, 2)
    end
  end

  local function namingFrame(x, y, width, height)
    checkerHorizontal(x, y, width)
    checkerHorizontal(x, y + height - 4, width)
    checkerVertical(x, y, height)
    checkerVertical(x + width - 4, y, height)
  end

  local function selectionBox(x, y, width, height)
    -- Keep the selected label black and readable.  The reference uses a
    -- simple ink outline rather than filling the whole key with black.
    gray(WHITE)
    love.graphics.rectangle("fill", x, y, width, height)
    gray(BLACK)
    love.graphics.rectangle("line", x + 0.5, y + 0.5,
      width - 1, height - 1)
  end

  local function namingTrainer(state, x, y)
    if state.modernPartyNamingTrainer == false then return end
    if not state.modernPartyNamingTrainer then
      local data = state.game and state.game.data
      local field = data and data.field or {}
      local ids = field.playerSprites or {}
      local sprites = data and data.sprites or {}
      local definition = sprites[ids.walk or "SPRITE_RED"]
        or sprites.SPRITE_RED
      if not definition then
        state.modernPartyNamingTrainer = false
        return
      end
      local ok, renderer = pcall(SpriteRenderer.new,
        definition, "modern-party-naming")
      state.modernPartyNamingTrainer = ok and renderer or false
    end
    local renderer = state.modernPartyNamingTrainer
    if renderer then
      -- SpriteRenderer applies the normal OBJ transparency/palette rules.
      -- Its field-space origin sits four pixels below the visible frame.
      renderer:draw(x, y + 4, 0, 0, "down", 0, false)
    end
  end

  local function namingFace(state, shade)
    local data = state.game and state.game.data
    local colors = data and PaletteFX.pal(data, "BLUEMON")
    colors = PaletteFX.effectiveColors(colors) or colors
    local index = shade == WHITE and 1 or shade == LIGHT and 2 or 3
    return colors and colors[index] or { shade * 255, shade * 255,
      shade * 255 }
  end

  local function namingPokemon(state, x, y, shade)
    local mon = state.modernPartyNamingMon
    local drawIcon = mod.exports and mod.exports.drawPartyToolIcon
    if mon and type(drawIcon) == "function" then
      local counter = 0
      if love.timer and type(love.timer.getTime) == "function" then
        counter = math.floor(love.timer.getTime() * 60)
      end
      local ok, drawn = pcall(drawIcon, state.game, mon,
        math.floor(x), math.floor(y), {
          size = 16,
          selected = true,
          counter = counter,
          background = namingFace(state, shade),
        })
      if ok and drawn then return true end
    end
    namingTrainer(state, x, y)
    return false
  end

  local function namingCommand(label, x, y, width, selected)
    if selected then selectionBox(x, y - 2, width, 12) end
    centered(label, x, y, width, BLACK)
  end

  local function namingMeta(grid)
    local caseRow, endRow, endCol = #grid, 5, 9
    for row, cells in ipairs(grid) do
      for col, glyph in ipairs(cells) do
        if glyph == "ED" then endRow, endCol = row, col end
      end
    end
    return caseRow, endRow, endCol
  end

  local function namingSelectedCommand(state, caseRow, endRow, endCol)
    local command = state.modernPartyNamingCommand
    if command then return command end
    if state.row == caseRow then return "case" end
    if state.row == endRow and state.col == endCol then return "end" end
    return nil
  end

  local function commandForColumn(column, count)
    count = math.max(1, tonumber(count) or 9)
    local position = (math.max(1, tonumber(column) or 1) - 0.5) / count
    if position < 0.44 then return "case" end
    if position < 0.67 then return "delete" end
    return "end"
  end

  local function commandColumn(command, count)
    count = math.max(1, tonumber(count) or 9)
    if command == "case" then return math.min(count, 2) end
    if command == "delete" then return math.max(1, math.ceil(count * 0.56)) end
    return math.max(1, count - 1)
  end

  local function namingSlots(state)
    local slots = {}
    for i = 1, state.maxLen or 7 do
      slots[i] = state.glyphs[i] or "-"
    end
    return table.concat(slots)
  end

  local function drawClassicNaming(state, width, height)
    -- The faithful naming keyboard is a fixed 160x144 composition. Centre it
    -- without stretching its letter grid on wide or portrait surfaces.
    local panelW, panelH = 160, 144
    local panelX = math.floor((width - panelW) / 2)
    local panelY = math.floor((height - panelH) / 2)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, width, height)
    namingFrame(panelX, panelY, panelW, panelH)

    namingPokemon(state, panelX + 16, panelY + 9, WHITE)
    centered(state.title or "NICKNAME?", panelX + 38, panelY + 12,
      panelW - 46, BLACK)
    centered(namingSlots(state), panelX + 12, panelY + 31,
      panelW - 24, BLACK)
    checkerHorizontal(panelX + 4, panelY + 43, panelW - 8)

    local grid = state:grid()
    local caseRow, endRow, endCol = namingMeta(grid)
    local selectedCommand = namingSelectedCommand(state,
      caseRow, endRow, endCol)
    local glyphTop, rowStep = panelY + 50, 13
    for row = 1, math.min(5, #grid) do
      local cells = grid[row]
      local y = glyphTop + (row - 1) * rowStep
      for col, glyph in ipairs(cells) do
        if not (row == endRow and col == endCol) then
          local x = panelX + 8 + (col - 1) * 16
          local selected = state.row == row and state.col == col
          if selected then selectionBox(x - 2, y - 2, 12, 12) end
          centered(Strings(glyph), x - 2, y, 12, BLACK)
        end
      end
    end

    checkerHorizontal(panelX + 4, panelY + 115, panelW - 8)
    local caseLabel = tostring(grid[caseRow] and grid[caseRow][1] or "LOWER")
    caseLabel = caseLabel:lower():find("lower", 1, true)
      and "lower" or "UPPER"
    namingCommand(caseLabel, panelX + 8, panelY + 126, 48,
      selectedCommand == "case")
    namingCommand("DEL", panelX + 66, panelY + 126, 28,
      selectedCommand == "delete")
    namingCommand("END", panelX + 112, panelY + 126, 38,
      selectedCommand == "end")
  end

  local function drawModernNaming(state, width, height)
    backdrop(width, height, state.title or "RENAME?",
      "A TYPE   B ERASE   START OK")
    local contentH = 114
    local top = math.max(19,
      math.floor((height - 8 - contentH) / 2))
    local nameX, nameW = 5, width - 10
    card(nameX, top, nameW, 22, false)
    namingPokemon(state, nameX + 4, top + 2, LIGHT)
    centered(namingSlots(state), nameX + 23, top + 7,
      nameW - 28, BLACK)

    local grid = state:grid()
    local caseRow, endRow, endCol = namingMeta(grid)
    local selectedCommand = namingSelectedCommand(state,
      caseRow, endRow, endCol)
    local margin, gap = 4, 1
    local columns = 9
    local keyW = math.max(12,
      math.floor((width - margin * 2 - gap * (columns - 1)) / columns))
    local gridW = keyW * columns + gap * (columns - 1)
    local gridX = math.floor((width - gridW) / 2)
    local rowH, gridTop = 14, top + 25
    for row = 1, math.min(5, #grid) do
      for col, glyph in ipairs(grid[row]) do
        -- END belongs with the other commands on the bottom row. Its native
        -- grid coordinate is retained so controller navigation and callbacks
        -- remain exactly the same.
        if not (row == endRow and col == endCol) then
          local x = gridX + (col - 1) * (keyW + gap)
          local y = gridTop + (row - 1) * rowH
          local selected = state.row == row and state.col == col
          card(x, y, keyW, rowH - 1, selected)
          centered(Strings(glyph), x + 2, y + 3, keyW - 6, BLACK)
        end
      end
    end

    local caseLabel = tostring(grid[caseRow] and grid[caseRow][1] or "LOWER")
    caseLabel = caseLabel:lower():find("lower", 1, true)
      and "lower" or "UPPER"
    local commandY, commandX = gridTop + rowH * 5 + 1, 5
    local commandGap, commandW = 2, width - 10
    local usable = commandW - commandGap * 2
    local caseW = math.floor(usable * 0.44)
    local deleteW = math.floor(usable * 0.23)
    local endW = usable - caseW - deleteW
    card(commandX, commandY, caseW, 16, selectedCommand == "case")
    centered(caseLabel, commandX + 2, commandY + 4,
      caseW - 6, BLACK)
    local deleteX = commandX + caseW + commandGap
    card(deleteX, commandY, deleteW, 16, selectedCommand == "delete")
    centered("DEL", deleteX + 2, commandY + 4,
      deleteW - 6, BLACK)
    local endX = deleteX + deleteW + commandGap
    card(endX, commandY, endW, 16, selectedCommand == "end")
    centered("END", endX + 2, commandY + 4,
      endW - 6, BLACK)
  end

  local top

  -- Party icon packs publish true-colour rectangles while PartyMenu draws.
  -- A naming prompt can be pushed before that same rendered frame finishes,
  -- so those old party-space rectangles would otherwise be re-blitted over
  -- the keyboard as grey squares.  Naming is an opaque UI owner just like the
  -- modern stats and ribbons pages: replace inherited UI claims at its screen
  -- boundary while leaving the world pass untouched.
  local function clearInheritedUiTrueColor()
    local rects = PaletteFX.trueColorRects
      and PaletteFX.trueColorRects("ui") or nil
    if type(rects) ~= "table" then return end
    for i = #rects, 1, -1 do rects[i] = nil end
  end

  -- The Gen 1 grid has native cursor targets for case switching and ED, but
  -- erase is normally B-only.  Both cohesive layouts present CASE, DEL and
  -- END as peer buttons, so bridge those three visual controls into one real
  -- arrow-navigable command row without replacing the source NamingScreen's
  -- typing, callbacks or confirmation behavior.
  local function installNamingCommandRow(state)
    local sourceUpdate = state.update
    if type(sourceUpdate) ~= "function" then return end
    state.update = function(self, dt)
      local grid = self:grid()
      local caseRow, endRow, endCol = namingMeta(grid)
      local command = namingSelectedCommand(self,
        caseRow, endRow, endCol)
      local input = self.game.input

      if command then
        if input:wasPressed("start") then
          self:confirm()
          return
        elseif input:wasPressed("select") then
          self.lower = not self.lower
          return
        elseif input:wasPressed("up") then
          self.modernPartyNamingCommand = nil
          if command == "end" then
            self.row = math.max(1, endRow - 1)
            self.col = math.min(endCol, #(grid[self.row] or {}))
          else
            self.row = endRow
            self.col = math.min(commandColumn(command,
              #(grid[endRow] or {})), #(grid[endRow] or {}))
          end
          return
        elseif input:wasPressed("down") then
          self.modernPartyNamingCommand = nil
          self.row = 1
          self.col = math.min(commandColumn(command,
            #(grid[1] or {})), #(grid[1] or {}))
          return
        elseif input:wasPressed("left") then
          self.modernPartyNamingCommand = command == "case" and "end"
            or command == "delete" and "case" or "delete"
          return
        elseif input:wasPressed("right") then
          self.modernPartyNamingCommand = command == "case" and "delete"
            or command == "delete" and "end" or "case"
          return
        end

        local pressedA = input:wasPressed("a")
        local pressedB = input:wasPressed("b")
        if pressedA and pressedB then pressedB = false end
        if pressedB or (pressedA and command == "delete") then
          table.remove(self.glyphs)
          return
        elseif pressedA and command == "case" then
          self.lower = not self.lower
          return
        elseif pressedA and command == "end" then
          self:confirm()
          return
        end
        return
      end

      -- Up from the first letter row and down from the final glyph row enter
      -- the closest visual command instead of jumping to a hidden grid cell.
      if input:wasPressed("up") and self.row == 1 then
        self.modernPartyNamingCommand = commandForColumn(self.col,
          #(grid[1] or {}))
        return
      elseif input:wasPressed("down") and self.row == endRow then
        self.modernPartyNamingCommand = commandForColumn(self.col,
          #(grid[endRow] or {}))
        return
      end
      sourceUpdate(self, dt)
    end
  end

  local function decorateNaming(state, parent, mon)
    -- A screen opened through Screens.push can be identified as a Pokémon
    -- nickname prompt before a party-action provider returns control to us.
    -- Let that later, explicit party selection replace the conservative
    -- roster inference rather than locking the first candidate in place.
    if state.modernPartyNaming then
      if mon then state.modernPartyNamingMon = mon end
      return true
    end
    if type(state.grid) ~= "function" then
      return false
    end
    installSurface(state, parent)
    installNamingCommandRow(state)
    state.modernPartyNaming = true
    state.modernPartyNamingMon = mon or state.modernPartyNamingMon
    state.draw = function(self)
      clearInheritedUiTrueColor()
      local width, height = self:uiSize()
      if setting("rename_style", "classic") == "modern" then
        drawModernNaming(self, width, height)
      else
        drawClassicNaming(self, width, height)
      end
      gray(WHITE)
    end
    return true
  end

  local function looksLikeMon(value)
    return type(value) == "table" and value.species ~= nil
      and (value.level ~= nil or value.hp ~= nil or value.moves ~= nil)
  end

  local function parentMon(parent)
    if type(parent) ~= "table" then return nil end
    -- A caught Pokémon is still the battle's enemy model when the nickname
    -- prompt is built. Prefer it to the player's active battler and to any
    -- older duplicate species already in the party.
    local enemy = parent.enemy
    if type(enemy) == "table" and looksLikeMon(enemy.mon) then
      return enemy.mon
    end
    for _, key in ipairs({
      "caughtMon", "pendingMon", "giftMon", "pokemon", "mon", "target",
    }) do
      if looksLikeMon(parent[key]) then return parent[key] end
    end
    return nil
  end

  local function speciesName(game, mon)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return tostring((def and def.name) or mon.species or ""):upper()
  end

  local function rosterCandidates(game)
    local candidates = {}
    local save = game and game.save or {}
    -- Newly received party Pokémon are appended, so newest-first is the
    -- useful order when two members share a species.
    for i = #(save.party or {}), 1, -1 do
      local mon = save.party[i]
      if looksLikeMon(mon) then candidates[#candidates + 1] = mon end
    end
    -- A full party sends the new Pokémon to the first box with room. Search
    -- every box tail rather than assuming currentBox was the destination.
    for _, box in ipairs(save.boxes or {}) do
      for i = #box, 1, -1 do
        local mon = box[i]
        if looksLikeMon(mon) then candidates[#candidates + 1] = mon end
      end
    end
    return candidates
  end

  local function inferredNicknameMon(game, parent, opts)
    opts = type(opts) == "table" and opts or {}
    for _, key in ipairs({ "mon", "pokemon", "target" }) do
      if looksLikeMon(opts[key]) then return opts[key] end
    end
    local direct = parentMon(parent)
    if direct then return direct end

    local candidates = rosterCandidates(game)
    local wanted = tostring(game and game.stringBuffer or ""):upper()
    if wanted ~= "" then
      for _, mon in ipairs(candidates) do
        if mon.nickname == nil and speciesName(game, mon) == wanted then
          return mon
        end
      end
      for _, mon in ipairs(candidates) do
        if speciesName(game, mon) == wanted then return mon end
      end
    end
    for _, mon in ipairs(candidates) do
      if mon.nickname == nil then return mon end
    end
    return candidates[1]
  end

  local function pokemonNicknamePrompt(state, opts)
    opts = type(opts) == "table" and opts or {}
    local title = tostring(opts.title or (state and state.title) or "")
    return title == tostring(Strings("NICKNAME?"))
      or title:upper() == "NICKNAME?"
  end

  -- Compose with an earlier NamingScreen provider instead of taking over
  -- trainer/player naming. Only the Pokémon-specific NICKNAME? prompt is
  -- decorated; every other title is returned exactly as the provider built
  -- it. If a generic presenter has no Gen 1 grid, fall back to the native
  -- controller for this one prompt so typing behavior remains deterministic.
  local function namingScreenRecord(inherited)
    local builtin = require("src.ui.NamingScreen")
    local inheritedNew = type(inherited) == "function" and inherited
      or (type(inherited) == "table" and inherited.new)
    return {
      new = function(game, opts)
        local parent = top(game)
        local maker = inheritedNew or builtin.new
        local state = maker(game, opts)
        if not pokemonNicknamePrompt(state, opts) then return state end
        if type(state) ~= "table" or type(state.grid) ~= "function" then
          state = builtin.new(game, opts)
        end
        decorateNaming(state, parent,
          inferredNicknameMon(game, parent, opts))
        return state
      end,
    }
  end

  local function itemLabel(item)
    if type(item) == "string" then return item end
    if type(item) ~= "table" then return "MOVE" end
    return item.label or item.name or item.moveName
      or (item.move and (item.move.name or item.move.id))
      or item.id or "MOVE"
  end

  local function decorateRelearn(state, parent)
    if state.modernPartyRelearn then return false end
    local items = state.items or state.moves or state.rows
    if type(items) ~= "table" or #items == 0 then return false end
    installSurface(state, parent)
    state.modernPartyRelearn = true
    state.draw = function(self)
      -- Relearn can be pushed while the party roster is still contributing
      -- true-colour menu-icon regions to the current UI pass.  It owns an
      -- opaque screen, so discard those inherited claims before drawing its
      -- cards just as the summary and naming screens do.  World/voxel claims
      -- live in a separate pass and are deliberately left untouched.
      clearInheritedUiTrueColor()
      local width, height = self:uiSize()
      local rows = self.items or self.moves or self.rows or {}
      backdrop(width, height, "RELEARN", "A CHOOSE    B BACK")
      local top, bottom = 19, height - 11
      local visible = math.max(1, math.min(#rows,
        math.floor((bottom - top) / 20)))
      local index = math.max(1, math.min(#rows, tonumber(self.index) or 1))
      local scroll = math.max(0, math.min(index - 1,
        math.max(0, #rows - visible)))
      if index > scroll + visible then scroll = index - visible end
      local rowH = math.max(18, math.floor((bottom - top) / visible))
      for slot = 1, visible do
        local i = scroll + slot
        local item = rows[i]
        if not item then break end
        local y = top + (slot - 1) * rowH
        local selected = i == index
        card(5, y, width - 10, rowH - 2, selected)
        drawText(itemLabel(item), 11,
          y + math.floor((rowH - 10) / 2), width - 22,
          BLACK)
      end
      gray(WHITE)
    end
    return true
  end

  local function movesFooter(model)
    local footer = model and model.footer
    if type(footer) ~= "table" then return tostring(footer or "B BACK") end
    local labels = {}
    for _, label in ipairs(footer) do
      label = tostring(label or "")
      if label ~= "" then labels[#labels + 1] = label end
    end
    return #labels > 0 and table.concat(labels, "   ") or "B BACK"
  end

  local function fallbackMovesModel(state)
    local rows = {}
    if state.mode == "pool" then
      for _, entry in ipairs(state.pool or {}) do
        rows[#rows + 1] = {
          label = entry.name or entry.label or entry.id or "MOVE",
          value = entry.type or "",
          enabled = true,
        }
      end
      return {
        title = "REMEMBERED MOVES",
        rows = rows,
        index = state.poolIndex or state.index or 1,
        scroll = state.poolScroll or state.scroll or 0,
        footer = { "A DETAILS", "B BACK" },
      }
    end

    if state.mode == "known" or state.mode == nil then
      local gameMoves = state.game and state.game.data
        and state.game.data.moves or {}
      for i = 1, 4 do
        local move = state.mon and state.mon.moves and state.mon.moves[i]
        local def = move and gameMoves[move.id] or nil
        rows[i] = {
          label = move and ((def and def.name) or move.id) or "EMPTY SLOT",
          value = move and ("PP %d/%d"):format(move.pp or 0,
            (def and def.pp) or move.pp or 0) or "--",
          marker = state.swapSlot == i,
          enabled = true,
        }
      end
      return {
        title = "MOVES",
        rows = rows,
        index = state.slot or state.index or 1,
        footer = state.swapSlot
          and { "A/SELECT SWAP", "B CANCEL" }
          or { "A DETAILS", "SELECT SWAP", "B BACK" },
      }
    end

    return {
      title = "MOVE DETAILS",
      rows = { { label = "MOVE DATA", value = "PAGE "
        .. tostring(state.detailPage or 1), enabled = false } },
      index = 1,
      footer = { "L/R PAGE", "A CHOOSE", "B BACK" },
    }
  end

  local function movesModel(state)
    local descriptor = state.modernPartyMovesDescriptor
    if descriptor and type(descriptor.model) == "function" then
      local ok, model = pcall(descriptor.model, state.game, state)
      if ok and type(model) == "table" then return model end
    end
    return fallbackMovesModel(state)
  end

  local function drawMoveRow(row, x, y, width, height, selected)
    row = type(row) == "table" and row or { label = tostring(row or "MOVE") }
    card(x, y, width, height, selected)
    local inset = 6
    local label = tostring(row.label or row.name or "MOVE")
    local value = tostring(row.value or "")
    local twoLine = value ~= "" and height >= 22
    if twoLine then
      drawText(label, x + inset, y + 5, width - inset * 2, BLACK)
      drawText(value, x + width - inset - Font.width(value),
        y + height - 12, Font.width(value), BLACK)
    else
      local lineY = y + math.max(4, math.floor((height - 10) / 2))
      local rightWidth = Font.width(value)
      local labelWidth = width - inset * 2
      if rightWidth > 0 then labelWidth = labelWidth - rightWidth - 4 end
      drawText(label, x + inset, lineY, math.max(8, labelWidth), BLACK)
      if value ~= "" then
        drawText(value, x + width - inset - rightWidth, lineY,
          rightWidth, BLACK)
      end
    end
    -- A small solid wedge is legible in every Gen 1 font pack and does not
    -- compete with PP. It reflects the source model's marker (swap/choose)
    -- without inventing another controller state.
    if row.marker then
      gray(BLACK)
      local markerY = y + height - 7
      if love.graphics.polygon then
        love.graphics.polygon("fill", {
          x + inset, markerY - 2,
          x + inset + 4, markerY + 1,
          x + inset, markerY + 4,
        })
      else
        love.graphics.rectangle("fill", x + inset, markerY, 3, 3)
      end
    end
  end

  local function drawMovesManager(state)
    clearInheritedUiTrueColor()
    local width, height = state:uiSize()
    local model = movesModel(state)
    local rows = type(model.rows) == "table" and model.rows or {}
    local index = math.max(1, tonumber(model.index) or 1)
    backdrop(width, height, model.title or "MOVES", movesFooter(model))

    local left, topY = 5, 19
    local usableW, usableH = width - 10, height - 30
    if #rows == 0 then
      card(left, topY, usableW, math.min(28, usableH), true)
      centered("NO MOVES AVAILABLE", left + 4, topY + 9,
        usableW - 10, BLACK)
      gray(WHITE)
      return
    end

    if state.mode == "known" or state.mode == nil then
      local gap = 3
      local cellW = math.floor((usableW - gap) / 2)
      local cellH = math.floor((usableH - gap) / 2)
      for i = 1, math.min(4, #rows) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        drawMoveRow(rows[i], left + col * (cellW + gap),
          topY + row * (cellH + gap), cellW, cellH, i == index)
      end
    elseif state.mode == "pool" then
      local visible = math.max(1, math.min(#rows,
        math.floor(usableH / 18)))
      local scroll = math.max(0, tonumber(model.scroll) or 0)
      if index <= scroll then scroll = index - 1 end
      if index > scroll + visible then scroll = index - visible end
      scroll = math.max(0, math.min(scroll, math.max(0, #rows - visible)))
      local rowH = math.max(16, math.floor(usableH / visible))
      for slot = 1, visible do
        local i = scroll + slot
        if not rows[i] then break end
        drawMoveRow(rows[i], left, topY + (slot - 1) * rowH,
          usableW, rowH - 2, i == index)
      end
    else
      -- Detail pages can contain up to ten semantic rows. Two balanced
      -- columns preserve every field on the native 160x144 surface and avoid
      -- the clipped right edge that a scaled source renderer would create.
      local columns = #rows > 5 and 2 or 1
      local perColumn = math.ceil(#rows / columns)
      local gap = 3
      local cellW = math.floor((usableW - gap * (columns - 1)) / columns)
      local cellH = math.max(15, math.floor(usableH / perColumn))
      for i, item in ipairs(rows) do
        local col = math.floor((i - 1) / perColumn)
        local row = (i - 1) % perColumn
        drawMoveRow(item, left + col * (cellW + gap),
          topY + row * cellH, cellW, cellH - 2,
          i == index and item.enabled ~= false)
      end
    end
    gray(WHITE)
  end

  local function decorateMovesManager(state, parent, descriptor)
    if type(state) ~= "table" or state.modernPartyMovesManager then
      return false
    end
    installSurface(state, parent)
    state.modernPartyMovesManager = true
    state.modernPartyMovesDescriptor = descriptor
    state.draw = drawMovesManager
    return true
  end

  top = function(game)
    local stack = game and game.stack
    if not stack then return nil end
    if type(stack.top) == "function" then return stack:top() end
    local states = stack.states
    return type(states) == "table" and states[#states] or nil
  end

  local function actionKind(entry)
    local token = tostring(entry.id or entry.action or entry.label or "")
      :upper():gsub("[^A-Z]", "")
    if token:find("RENAME", 1, true)
        or token:find("NICKNAME", 1, true) then
      return "rename"
    end
    if token:find("RELEARN", 1, true)
        or token:find("REMEMBER", 1, true) then
      return "relearn"
    end
  end

  local installed = false
  local movesManagerInstalled = false
  local function installMovesManager()
    if movesManagerInstalled then return true end
    local handle = type(mod.find) == "function" and mod.find("moves_manager")
      or nil
    local exports = handle and handle.exports or nil
    local contract = exports and exports.gen1ModernUi or nil
    local descriptor = contract and contract.screens
      and contract.screens.moves_manager or nil
    local inherited = mod.content.screens:get("MovesManager")
    local inheritedNew = type(inherited) == "function" and inherited
      or (type(inherited) == "table" and inherited.new)
    if type(inheritedNew) ~= "function" then return false end

    -- Moves Manager registers its Gen1 Modern UI adapter before this mod.
    -- Exclude only the states we decorate so that compositor reaches Modern
    -- Party UI's non-suppressing adapter below; raw Moves Manager screens keep
    -- their original responsive Modern UI path.
    if descriptor and type(descriptor.match) == "function"
        and not descriptor._modernPartySourceMatch then
      local sourceMatch = descriptor.match
      descriptor._modernPartySourceMatch = sourceMatch
      descriptor.match = function(state)
        if type(state) == "table" and state.modernPartyMovesManager then
          return false
        end
        return sourceMatch(state)
      end
    end

    mod.content.screens:override("MovesManager", {
      new = function(game, mon, ...)
        local parent = top(game)
        local state = inheritedNew(game, mon, ...)
        decorateMovesManager(state, parent, descriptor)
        return state
      end,
    })
    movesManagerInstalled = true
    return true
  end

  local function install()
    if installed then return end
    installed = true
    -- Run outside action-provider hooks so their appended rows are present
    -- before we decorate the callbacks.  Equal-priority ordering is not a
    -- public guarantee and varies with the enabled mod set.
    mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
      local out = next(game, items, mon, ctx)
      if type(out) ~= "table" then return out end
      for _, entry in ipairs(out) do
        local kind = actionKind(entry)
        if kind and type(entry.onSelect) == "function"
            and not entry._modernPartyToolWrapped then
          local original = entry.onSelect
          entry.onSelect = function(...)
            local parent = top(game)
            local args = { ... }
            local result = packArgs(original(unpackArgs(args)))
            local child = top(game)
            if child and child ~= parent then
              if kind == "rename" then
                decorateNaming(child, parent, mon)
              else
                decorateRelearn(child, parent)
              end
            end
            return unpackArgs(result, 1, result.n)
          end
          entry._modernPartyToolWrapped = true
        end
      end
      return out
    end, 10000)
    installMovesManager()
  end

  return {
    new = function() return {} end,
    install = install,
    decorateNaming = decorateNaming,
    decorateRelearn = decorateRelearn,
    decorateMovesManager = decorateMovesManager,
    installMovesManager = installMovesManager,
    movesManagerModel = movesModel,
    namingScreenRecord = namingScreenRecord,
  }
end
