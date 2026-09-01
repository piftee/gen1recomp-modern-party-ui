-- Modern presentation over Gold/Silver/Crystal's native party, summary and
-- naming controllers. All selection, held-item, TM/HM and battle behavior
-- remains in the generation-2 engine.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local GbcPalette = require("src.render.GbcPalette")
  local HpBar = require("src.battle.gen2.HpBar")
  local Mon = require("src.battle.gen2.Mon")
  local Palettes = require("src.world.gen2.Palettes")
  local PartyMenu = require("src.ui.gen2.PartyMenu")
  local SummaryMenu = require("src.ui.gen2.SummaryMenu")
  local NamingScreen = require("src.ui.gen2.NamingScreen")

  local INK_BLACK = { 0, 0, 0 }
  local INK_WHITE = { 1, 1, 1 }
  local INK_LIGHT = { 0.72, 0.84, 1 }
  local HEADER = { 0.20, 0.34, 0.58 }
  local HEADER_LIGHT = { 0.53, 0.65, 0.84 }
  local BACKDROP = { 0.94, 0.91, 0.95 }
  local MODAL = { 0.53, 0.62, 0.88 }
  local MODAL_DARK = { 0.16, 0.19, 0.38 }

  -- Exact Gen 1 card faces, shared with Typed Move Colors and Modern Pokedex.
  local TYPE_COLORS = {
    normal = { 144 / 255, 152 / 255, 162 / 255 },
    fighting = { 206 / 255, 63 / 255, 107 / 255 },
    flying = { 143 / 255, 168 / 255, 222 / 255 },
    poison = { 171 / 255, 106 / 255, 200 / 255 },
    ground = { 217 / 255, 119 / 255, 70 / 255 },
    rock = { 201 / 255, 182 / 255, 139 / 255 },
    bug = { 144 / 255, 192 / 255, 44 / 255 },
    ghost = { 82 / 255, 105 / 255, 173 / 255 },
    fire = { 254 / 255, 156 / 255, 85 / 255 },
    water = { 77 / 255, 144 / 255, 214 / 255 },
    grass = { 101 / 255, 188 / 255, 94 / 255 },
    electric = { 244 / 255, 210 / 255, 59 / 255 },
    psychic = { 249 / 255, 113 / 255, 119 / 255 },
    ice = { 115 / 255, 206 / 255, 191 / 255 },
    dragon = { 9 / 255, 109 / 255, 195 / 255 },
    dark = { 91 / 255, 82 / 255, 101 / 255 },
    steel = { 91 / 255, 142 / 255, 161 / 255 },
    fairy = { 236 / 255, 144 / 255, 231 / 255 },
  }

  local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
  end

  local function inkPalette(color)
    color = color or INK_BLACK
    local ink = {}
    for i = 1, 3 do
      local value = color[i] or 0
      ink[i] = math.floor((value <= 1 and value * 255 or value) + 0.5)
    end
    return {
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    if not maxWidth or Font.width(text) <= maxWidth then return text end
    local budget = math.max(0, maxWidth - Font.width("."))
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, budget)
      return count > 0 and text:sub(1, spans[count].to) .. "." or ""
    end
    while #text > 0 and Font.width(text) > budget do text = text:sub(1, -2) end
    return text .. "."
  end

  local function drawInk(text, x, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs(
      inkPalette(color), false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw(text, math.floor(x), math.floor(y))
      return Font.width(text)
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function drawInkRight(text, right, y, maxWidth, color)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawInk(text, math.floor(right) - width, y, width, color)
    return width
  end

  local function drawInkCentered(text, x, y, width, color)
    text = fitText(text, width)
    return drawInk(text, x + math.floor((width - Font.width(text)) / 2), y,
      width, color)
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = math.max(0, math.min(cut or 0, math.floor(math.min(w, h) / 2)))
    if cut == 0 or not love.graphics.polygon then
      love.graphics.rectangle(mode, x, y, w, h)
      return
    end
    love.graphics.polygon(mode, {
      x + cut, y, x + w - cut, y, x + w, y + cut,
      x + w, y + h - cut, x + w - cut, y + h,
      x + cut, y + h, x, y + h - cut, x, y + cut,
    })
  end

  local function option(key, fallback)
    local value = mod.options:get(key)
    if value == nil then return fallback end
    return value
  end

  local function installWideDraw(menu, drawPanel, surround)
    menu.drawWidescreen = function(self, winW, winH)
      local G = love.graphics
      local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
      local width = math.max(160, math.min(640, math.floor(winW / scale)))
      local ox = math.floor((winW - width * scale) / 2)
      local oy = math.floor((winH - 144 * scale) / 2)
      setColor(surround)
      G.rectangle("fill", 0, 0, winW, winH)
      G.push()
      G.translate(ox, oy)
      G.scale(scale, scale)
      self.modernPartyLastWideWidth = width
      self.modernPartyWideWidth = width
      drawPanel(self)
      self.modernPartyWideWidth = nil
      G.pop()
      G.setColor(1, 1, 1, 1)
    end
  end

  local function speciesType(menu, mon)
    local def = menu.pokemon and mon and menu.pokemon[mon.species]
    if not def then return "normal" end
    local value = def.type1 or def.type or (def.types and def.types[1])
    return tostring(value or "normal"):lower()
  end

  local function cardColor(menu, mon)
    local mode = option("card_color", "species")
    local flat = {
      mono = { 0.91, 0.91, 0.91 },
      blue = { 0.72, 0.84, 0.96 },
    }
    if flat[mode] then return flat[mode][1], flat[mode][2], flat[mode][3] end
    if mode == "health" then
      local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 1
      local ratio = math.max(0, math.min(1, (mon.hp or 0) / math.max(1, maxHp)))
      if ratio <= 0.2 then return 0.94, 0.58, 0.55 end
      if ratio <= 0.5 then return 0.95, 0.82, 0.48 end
      return 0.62, 0.84, 0.58
    end
    local color = TYPE_COLORS[speciesType(menu, mon)] or TYPE_COLORS.normal
    if mode == "species_palette" and mon.shiny then
      return math.min(1, color[1] + 0.12), math.min(1, color[2] + 0.12),
        math.min(1, color[3] + 0.12)
    end
    return color[1], color[2], color[3]
  end

  local function expFraction(menu, mon)
    local def = menu.pokemon and mon and menu.pokemon[mon.species]
    if not def then return 0 end
    local data = menu.game and menu.game.data or { pokemon = menu.pokemon }
    local growth = Mon.growthFor(data, def.growthRate)
    return HpBar.expFraction(mon, growth, Mon.experienceForLevel)
  end

  local function hpFraction(mon)
    local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 1
    return math.max(0, math.min(1, (mon.hp or 0) / math.max(1, maxHp)))
  end

  local function drawMeter(x, y, width, fraction, kind)
    local G = love.graphics
    setColor({ 0.10, 0.12, 0.16 })
    G.rectangle("fill", x, y, width, 4)
    local color
    if kind == "exp" then
      color = { 0.34, 0.70, 0.94 }
    elseif fraction <= 0.20 then
      color = { 0.90, 0.22, 0.19 }
    elseif fraction <= 0.50 then
      color = { 0.96, 0.68, 0.12 }
    else
      color = { 0.16, 0.72, 0.25 }
    end
    setColor(color)
    G.rectangle("fill", x + 1, y + 1,
      math.floor(math.max(0, width - 2) * fraction), 2)
  end

  local function shortType(menu, mon)
    local value = speciesType(menu, mon):upper()
    local short = {
      NORMAL = "NRM", FIGHTING = "FGT", FLYING = "FLY", POISON = "PSN",
      GROUND = "GRD", ROCK = "RCK", BUG = "BUG", GHOST = "GHO",
      FIRE = "FIR", WATER = "WTR", GRASS = "GRS", ELECTRIC = "ELC",
      PSYCHIC = "PSY", ICE = "ICE", DRAGON = "DRG", DARK = "DRK",
      STEEL = "STL", FAIRY = "FAI",
    }
    return short[value] or value:sub(1, 3)
  end

  local function drawPartySubmenu(self)
    local menu = self.submenu
    if not menu then return end
    local G = love.graphics
    local items = menu.items or {}
    local count = #items
    local rowStep = count > 0 and math.max(11,
      math.min(16, math.floor(92 / count))) or 16
    local h = count * rowStep + 22
    local width = self.modernPartyWideWidth or 160
    local x, y, w = width - 86, math.max(18, 132 - h), 84
    setColor(MODAL)
    chamfer("fill", x, y, w, h, 4)
    setColor(MODAL_DARK)
    love.graphics.setLineWidth(2)
    chamfer("line", x + 1, y + 1, w - 2, h - 2, 4)
    drawInk("ACTIONS", x + 8, y + 5, w - 16, INK_WHITE)
    for i, item in ipairs(items) do
      local rowY = y + 18 + (i - 1) * rowStep
      local selected = i == menu.index
      if selected then
        setColor(MODAL_DARK)
        G.rectangle("fill", x + 5, rowY, w - 10, rowStep - 2)
        setColor(INK_WHITE)
        G.rectangle("fill", x + 8, rowY + math.max(2,
          math.floor((rowStep - 5) / 2)), 3, 5)
      end
      drawInk(item.label or item.id or "ACTION", x + 14,
        rowY + math.max(1, math.floor((rowStep - 8) / 2)),
        w - 22, selected and INK_WHITE or INK_BLACK)
    end
  end

  local function modernPartyPanel(self)
    local G = love.graphics
    local wasBattle = Font.useBattleExtra(true)
    local width = self.modernPartyWideWidth or 160
    setColor(BACKDROP)
    G.rectangle("fill", 0, 0, width, 144)
    setColor({ 0.82, 0.82, 0.90 })
    for x = -144, width, 16 do
      G.line(x, 16, x + 128, 128)
      G.line(x + 128, 16, x, 128)
    end

    setColor(HEADER)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    drawInk(("%d/6"):format(#self.party), 4, 4, 32, INK_WHITE)
    drawInkCentered("POKéMON", math.floor((width - 64) / 2), 3, 64,
      INK_WHITE)
    local selectedMon = self.party[self.index]
    if selectedMon then
      drawInkRight(shortType(self, selectedMon), width - 4, 4, 32, INK_WHITE)
    end

    local slots = option("empty_slots", true) and 6 or math.max(1, #self.party)
    for i = 1, slots do
      local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
      local x1 = math.floor(col * width / 2) + 2
      local x2 = math.floor((col + 1) * width / 2) - 2
      local x, y, w, h = x1, 18 + rowIndex * 31, x2 - x1, 29
      local mon = self.party[i]
      local selected = i == self.index
      local held = i == self.switchFrom
      local face
      if mon then
        local r, g, b = cardColor(self, mon)
        face = { r, g, b }
      else
        face = { 0.80, 0.82, 0.86 }
      end
      setColor({ 0.10, 0.11, 0.15 })
      chamfer("fill", x + 2, y + 2, w - 1, h - 1, 3)
      setColor(face, mon and 0.96 or 0.80)
      chamfer("fill", x, y, w - 2, h - 2, 3)
      setColor(selected and INK_WHITE or (held and HEADER or { 0.26, 0.28, 0.34 }))
      G.setLineWidth(selected and 2 or 1)
      chamfer("line", x + 0.5, y + 0.5, w - 3, h - 3, 3)
      if selected then
        setColor(INK_WHITE)
        G.rectangle("fill", x + 3, y + 5, 2, h - 12)
      elseif held then
        setColor(HEADER)
        G.rectangle("line", x + 2.5, y + 2.5, w - 7, h - 7)
      end

      if mon then
        self:drawIcon(mon, x + 3, y + 6 + self:iconBob(i))
        local data = PartyMenu.rowFor(mon)
        drawInk(data.name, x + 21, y + 3, w - 25, INK_BLACK)
        if self.tmhm then
          drawInk(self:tmhmAble(mon) or "", x + 21, y + 13, w - 25,
            INK_BLACK)
        else
          drawInk(data.level or "", x + 21, y + 13, 25, INK_BLACK)
          if data.status then
            drawInkRight(data.status, x + w - 5, y + 13, 28, INK_BLACK)
          elseif option("hp_text", "bar") == "percent" then
            drawInkRight(("%d%%"):format(math.floor(hpFraction(mon) * 100)),
              x + w - 5, y + 13, 30, INK_BLACK)
          end
          drawMeter(x + 21, y + 22, w - 27, hpFraction(mon), "hp")
        end
        if option("exp_strip", true) and not mon.isEgg then
          drawMeter(x + 5, y + h - 4, w - 11, expFraction(self, mon), "exp")
        end
      else
        drawInkCentered("EMPTY", x + 10, y + 10, w - 22, INK_BLACK)
      end
    end

    setColor(HEADER)
    G.rectangle("fill", 0, 112, width, 32)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 112, width, 2)
    local prompt = self.switchFrom and PartyMenu.PROMPTS.moveTo or self.prompt
    if self:isCancel() then
      setColor(MODAL_DARK)
      chamfer("fill", 4, 116, 72, 16, 3)
      drawInk("CANCEL", 16, 120, 54, INK_WHITE)
      setColor(INK_WHITE)
      G.rectangle("fill", 9, 122, 3, 5)
    else
      drawInk("B CANCEL", 5, 119, 66, INK_LIGHT)
    end
    drawInkRight(#self.party == 0 and PartyMenu.PROMPTS.none or prompt,
      width - 5, 132, width - 10, INK_WHITE)
    drawPartySubmenu(self)
    Font.useBattleExtra(wasBattle)
    G.setColor(1, 1, 1, 1)
  end

  local function moveColor(menu, move)
    local def = move and menu.moveDef and menu:moveDef(move.id)
      or (menu.moves and move and menu.moves[move.id])
    return TYPE_COLORS[tostring(def and def.type or "normal"):lower()]
      or TYPE_COLORS.normal, def
  end

  local function moveGridIndex(index, count, direction)
    if count < 1 then return nil end
    index = math.max(1, math.min(tonumber(index) or 1, count))
    local row = math.floor((index - 1) / 2)
    local col = (index - 1) % 2
    if direction == "left" or direction == "right" then
      local other = row * 2 + (1 - col) + 1
      return other <= count and other or index
    end
    local other = (1 - row) * 2 + col + 1
    return other <= count and other or index
  end

  -- The wide presenter lays the native six-slot list out as three rows of two
  -- cards. Remember the active column when entering the full-width CANCEL row
  -- so both axes continue to agree with the visible layout.
  local function partyGridIndex(index, count, direction, allowCancel, column)
    count = math.max(0, tonumber(count) or 0)
    index = math.max(1, tonumber(index) or 1)
    column = tonumber(column)
    if column ~= 0 and column ~= 1 then column = nil end

    local cancel = count + 1
    if count == 0 then return allowCancel and cancel or index, column or 0 end

    if index > count then
      column = column or ((count - 1) % 2)
      if direction == "up" then
        local target = count
        while target > 1 and (target - 1) % 2 ~= column do
          target = target - 1
        end
        return target, column
      elseif direction == "down" then
        local target = column + 1
        return target <= count and target or 1, column
      end
      return allowCancel and cancel or math.min(index, count), column
    end

    column = (index - 1) % 2
    if direction == "left" then
      return column == 1 and index - 1 or index, column == 1 and 0 or column
    elseif direction == "right" then
      local target = index + 1
      if column == 0 and target <= count then return target, 1 end
      return index, column
    elseif direction == "up" then
      local target = index - 2
      if target >= 1 then return target, column end
      return allowCancel and cancel or index, column
    elseif direction == "down" then
      local target = index + 2
      if target <= count then return target, column end
      return allowCancel and cancel or index, column
    end
    return index, column
  end

  local function drawModernBackdrop(self)
    local G = love.graphics
    local width = self and self.modernPartyWideWidth or 160
    setColor(BACKDROP)
    G.rectangle("fill", 0, 0, width, 144)
    setColor({ 0.82, 0.82, 0.90 })
    for x = -144, width, 16 do
      G.line(x, 16, x + 128, 136)
      G.line(x + 128, 16, x, 136)
    end
  end

  local function drawSummaryHeader(self, title)
    local G = love.graphics
    local width = self.modernPartyWideWidth or 160
    setColor(HEADER)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    drawInk(("%d/%d"):format(self.index or 1,
      math.max(1, #(self.party or {}))), 4, 4, 32, INK_WHITE)
    local mon = self.mon or {}
    drawInk(mon.nickname or mon.name or mon.species or "POKéMON",
      34, 4, width - 82, INK_WHITE)
    drawInkRight(title, width - 4, 4, 40, INK_LIGHT)
  end

  local function drawSummaryFooter(self, text)
    local G = love.graphics
    local width = self.modernPartyWideWidth or 160
    setColor(HEADER)
    G.rectangle("fill", 0, 136, width, 8)
    drawInkCentered(text or "L/R PAGE  B BACK", 2, 136, width - 4,
      INK_WHITE)
  end

  local PIC_PAD = { [7] = { 0, 0 }, [6] = { 1, 1 }, [5] = { 1, 2 } }

  local function drawSummaryImage(image, colors, x, y, quad, size)
    if not image then return false end
    local wide = math.floor((size or image:getWidth()) / 8)
    local pad = PIC_PAD[wide] or PIC_PAD[7]
    love.graphics.setColor(1, 1, 1, 1)
    local function body()
      if quad then
        love.graphics.draw(image, quad, x + pad[1] * 8, y + pad[2] * 8)
      else
        love.graphics.draw(image, x + pad[1] * 8, y + pad[2] * 8)
      end
    end
    if colors and GbcPalette.available() then
      GbcPalette.with(colors, body)
    else
      body()
    end
    return true
  end

  local function drawSummarySprite(self, x, y)
    local mon = self.mon
    if not mon then return end
    local colors = self.palettes and Palettes.monColors(self.palettes,
      mon.isEgg and "EGG" or mon.species, mon.shiny)
    if mon.isEgg then
      local gfx = (self.menuGfx or {}).eggHatch
      local image = self.picImage and self:picImage(gfx and gfx.egg)
      if drawSummaryImage(image, colors, x, y) then return end
      local entry = self.icons and self.icons.icons
        and self.icons.icons.ICON_EGG
      image = self.picImage and self:picImage(entry and entry.image)
      if not image then return end
      local w = entry.width or 16
      local h = math.min(entry.height or 16, image:getHeight())
      if (entry.frames or 1) > 1 then h = math.floor(h / entry.frames) end
      local ok, quad = pcall(love.graphics.newQuad, 0, 0, w, h,
        image:getWidth(), image:getHeight())
      if not ok then return end
      local px = x + math.floor((56 - w * 2) / 2)
      local py = y + math.floor((56 - h * 2) / 2)
      love.graphics.setColor(1, 1, 1, 1)
      local function body() love.graphics.draw(image, quad, px, py, 0, 2, 2) end
      if colors and GbcPalette.available() then GbcPalette.with(colors, body)
      else body() end
      return
    end
    local image = self.picFor and self:picFor(mon)
    local sheet, quad, size
    if self.picAnimFrame then sheet, quad, size = self:picAnimFrame() end
    if sheet then drawSummaryImage(sheet, colors, x, y, quad, size)
    else drawSummaryImage(image, colors, x, y) end
  end

  local function summaryLayout(self)
    local width = self.modernPartyWideWidth or 160
    local railW = math.min(88, math.max(58, math.floor(width * 0.31)))
    local mainX = railW + 4
    return {
      width = width, railW = railW, mainX = mainX,
      mainW = width - mainX - 2,
    }
  end

  local function drawSummaryProfile(self)
    local G = love.graphics
    local layout = summaryLayout(self)
    local railW = layout.railW
    local mon = self.mon or {}
    local r, g, b
    if mon.isEgg then
      r, g, b = 0.86, 0.82, 0.68
    else
      r, g, b = cardColor(self, mon)
    end
    setColor({ r, g, b })
    chamfer("fill", 2, 18, railW - 2, 116, 4)
    setColor({ 0.12, 0.13, 0.17 })
    G.setLineWidth(2)
    chamfer("line", 2.5, 18.5, railW - 3, 115, 4)
    local spriteX = 3 + math.max(0, math.floor((railW - 58) / 2))
    drawSummarySprite(self, spriteX, 20)
    setColor({ 0.10, 0.11, 0.15 })
    G.rectangle("fill", 6, 77, railW - 10, 1)
    if mon.isEgg then
      drawInkCentered("EGG", 7, 86, railW - 12, INK_BLACK)
      drawInkCentered("???", 7, 101, railW - 12, INK_BLACK)
      drawInkCentered("HATCH", 7, 119, railW - 12, INK_BLACK)
      return
    end
    local def = self.speciesDef and self:speciesDef()
    drawInk(("No.%03d"):format(def and def.dex or 0), 7, 81,
      railW - 12, INK_BLACK)
    local t1, t2 = self.typeNames and self:typeNames()
    drawInk(tostring(t1 or "---"):upper(), 7, 91, railW - 12, INK_BLACK)
    if t2 then drawInk(tostring(t2):upper(), 7, 101,
      railW - 12, INK_BLACK) end
    drawInk("OT " .. tostring(self.otName and self:otName() or "---"),
      7, 113, railW - 12, INK_BLACK)
    drawInk(("ID %05d"):format(self.otId and self:otId() or 0),
      7, 123, railW - 12, INK_BLACK)
  end

  local function statRows(mon)
    local stats = mon.stats or {}
    return {
      { "ATTACK", stats.attack or 0 },
      { "DEFENSE", stats.defense or 0 },
      { "SP.ATK", stats.specialAttack or 0 },
      { "SP.DEF", stats.specialDefense or 0 },
      { "SPEED", stats.speed or 0 },
    }
  end

  local function drawSummaryStats(self)
    local G = love.graphics
    local layout = summaryLayout(self)
    local x, w = layout.mainX, layout.mainW
    local mon = self.mon or {}
    local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 1
    local row = PartyMenu.rowFor(mon)
    local r, g, b = cardColor(self, mon)
    setColor({ r, g, b })
    chamfer("fill", x, 18, w, 31, 3)
    drawInk("LV" .. tostring(mon.level or 1), x + 6, 23, 46, INK_BLACK)
    drawInkRight(row.status or "OK", x + w - 7, 23, 38, INK_BLACK)
    drawInk("HP", x + 6, 35, 20, INK_BLACK)
    drawInkRight(("%d/%d"):format(mon.hp or 0, maxHp), x + w - 6, 34, 70,
      INK_BLACK)
    drawMeter(x + 24, 45, w - 31, hpFraction(mon), "hp")
    for i, entry in ipairs(statRows(mon)) do
      local y = 51 + (i - 1) * 16
      setColor(i % 2 == 1 and MODAL_DARK or HEADER)
      chamfer("fill", x, y, w, 14, 2)
      drawInk(entry[1], x + 6, y + 3, w - 44, INK_WHITE)
      drawInkRight(tostring(entry[2]), x + w - 7, y + 3, 34, INK_WHITE)
    end
  end

  local function drawSummaryMoves(self)
    local G = love.graphics
    local layout = summaryLayout(self)
    local columns = layout.mainW >= 144 and 2 or 1
    local gap = 3
    local cardW = math.floor((layout.mainW - gap * (columns - 1)) / columns)
    local moves = self.moveList and self:moveList() or (self.mon and self.mon.moves) or {}
    for i = 1, 4 do
      local move = moves[i]
      local color, def = moveColor(self, move)
      local col = (i - 1) % columns
      local row = math.floor((i - 1) / columns)
      local x = layout.mainX + col * (cardW + gap)
      local cardH = columns == 2 and 53 or 25
      local y = 18 + row * (cardH + 3)
      setColor(move and color or { 0.74, 0.76, 0.80 })
      chamfer("fill", x, y, cardW, cardH, 3)
      setColor({ 0.12, 0.13, 0.17 })
      chamfer("line", x + 0.5, y + 0.5, cardW - 1, cardH - 1, 3)
      if move then
        drawInk(def and def.name or (self.moveName and self:moveName(move))
          or move.id, x + 6, y + (columns == 2 and 9 or 4), cardW - 12,
          INK_BLACK)
        local infoY = y + (columns == 2 and 31 or 14)
        drawInk(tostring(def and def.type or "---"):upper(), x + 6, infoY,
          cardW - 48,
          INK_BLACK)
        drawInkRight(("%d/%d"):format(move.pp or 0,
          move.maxPp or move.pp or 0), x + cardW - 6, infoY, 42, INK_BLACK)
      else
        drawInkCentered("EMPTY", x + 4, y + math.floor((cardH - 8) / 2),
          cardW - 8, INK_BLACK)
      end
    end
  end

  local function drawSummaryTrainer(self)
    local G = love.graphics
    local layout = summaryLayout(self)
    local x, w = layout.mainX, layout.mainW
    local mon = self.mon or {}
    setColor(MODAL)
    chamfer("fill", x, 18, w, 39, 3)
    drawInk("TRAINER", x + 6, 23, w - 12, INK_BLACK)
    drawInk("OT " .. tostring(self.otName and self:otName() or "---"),
      x + 6, 35, w - 12, INK_BLACK)
    drawInk(("ID %05d"):format(self.otId and self:otId() or 0),
      x + 6, 46, w - 12, INK_BLACK)
    local rows = statRows(mon)
    for i, entry in ipairs(rows) do
      local y = 59 + (i - 1) * 14
      setColor(i % 2 == 1 and HEADER or MODAL_DARK)
      chamfer("fill", x, y, w, 12, 2)
      drawInk(entry[1], x + 6, y + 2, w - 44, INK_WHITE)
      drawInkRight(tostring(entry[2]), x + w - 7, y + 2, 34, INK_WHITE)
    end
  end

  local function drawSummaryEgg(self)
    local G = love.graphics
    local layout = summaryLayout(self)
    local x, w = layout.mainX, layout.mainW
    setColor(MODAL)
    chamfer("fill", x, 18, w, 39, 3)
    drawInk("EGG INFO", x + 6, 24, w - 12, INK_BLACK)
    drawInk("KIND ???", x + 6, 38, w - 12, INK_BLACK)
    setColor({ 0.08, 0.09, 0.12 })
    chamfer("fill", x, 61, w, 69, 3)
    local lines = {
      "An EGG",
      "from JOHTO.",
      "Walk with it.",
      "May hatch.",
    }
    for i, line in ipairs(lines) do
      drawInk(line, x + 6, 69 + (i - 1) * 13, w - 12,
        i == 1 and INK_LIGHT or INK_WHITE)
    end
  end

  local function drawSummaryMoveDetail(self)
    local G = love.graphics
    local width = self.modernPartyWideWidth or 160
    local wide = width >= 196
    drawModernBackdrop(self)
    drawSummaryHeader(self, "MOVES")
    local moves = self.moveList and self:moveList() or (self.mon and self.mon.moves) or {}
    for i = 1, 4 do
      local move = moves[i]
      local color, def = moveColor(self, move)
      local selected = i == (self.moveIndex or 1)
      local held = i == self.swapFrom
      local columns = wide and 2 or 1
      local col = (i - 1) % columns
      local row = math.floor((i - 1) / columns)
      local gap = 3
      local cardW = math.floor((width - 10 - gap * (columns - 1)) / columns)
      local x = 5 + col * (cardW + gap)
      local cardH = wide and 42 or 19
      local y = 19 + row * (cardH + 3)
      local face = color
      if selected then
        face = { color[1] * 0.52, color[2] * 0.52, color[3] * 0.52 }
      end
      setColor(move and face or { 0.74, 0.76, 0.80 })
      chamfer("fill", x, y, cardW, cardH, 3)
      setColor(selected and INK_WHITE or (held and HEADER or { 0.15, 0.16, 0.20 }))
      G.setLineWidth(selected and 2 or 1)
      chamfer("line", x + 0.5, y + 0.5, cardW - 1, cardH - 1, 3)
      local ink = selected and INK_WHITE or INK_BLACK
      if move then
        drawInk(def and def.name or (self.moveName and self:moveName(move))
          or move.id, x + 7, y + (wide and 7 or 2), cardW - 14, ink)
        local infoY = y + (wide and 25 or 10)
        drawInk(tostring(def and def.type or "---"):upper(), x + 7, infoY,
          cardW - 52,
          ink)
        drawInkRight(("%d/%d"):format(move.pp or 0,
          move.maxPp or move.pp or 0), x + cardW - 7, infoY, 42, ink)
      else
        drawInkCentered("EMPTY", x + 7, y + math.floor((cardH - 8) / 2),
          cardW - 14, ink)
      end
    end
    local selected = moves[self.moveIndex or 1]
    local _, def = moveColor(self, selected)
    setColor({ 0.08, 0.09, 0.12 })
    chamfer("fill", 5, 109, width - 10, 25, 3)
    if self.swapFrom then
      drawInkCentered("WHERE SHOULD IT MOVE?", 10, 117, width - 20,
        INK_WHITE)
    elseif def then
      drawInk(("%s  POWER %s"):format(tostring(def.type or "---"):upper(),
        tostring((def.power or 0) >= 2 and def.power or "---")),
        11, 112, width - 22, INK_LIGHT)
      local description = tostring(def.description or ""):gsub("<NEXT>.*", "")
      drawInk(description, 11, 122, width - 22, INK_WHITE)
    end
    drawSummaryFooter(self, "A MOVE  SEL SWAP  B")
  end

  local function modernSummaryPanel(self)
    local wasBattle = Font.useBattleExtra(true)
    if self.moveDetail then
      drawSummaryMoveDetail(self)
      Font.useBattleExtra(wasBattle)
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    drawModernBackdrop(self)
    local title = self.mon and self.mon.isEgg and "EGG"
      or self.page == SummaryMenu.GREEN_PAGE and "MOVE"
      or self.page == SummaryMenu.BLUE_PAGE and "OT" or "STAT"
    drawSummaryHeader(self, title)
    drawSummaryProfile(self)
    if self.mon and self.mon.isEgg then
      drawSummaryEgg(self)
    elseif self.page == SummaryMenu.GREEN_PAGE then
      drawSummaryMoves(self)
    elseif self.page == SummaryMenu.BLUE_PAGE then
      drawSummaryTrainer(self)
    else
      drawSummaryStats(self)
    end
    drawSummaryFooter(self, "L/R PAGE  B BACK")
    Font.useBattleExtra(wasBattle)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function modernNamingPanel(self)
    local G = love.graphics
    local width = self.modernPartyWideWidth or 160
    setColor(BACKDROP)
    G.rectangle("fill", 0, 0, width, 144)
    setColor(HEADER)
    G.rectangle("fill", 0, 0, width, 16)
    setColor(HEADER_LIGHT)
    G.rectangle("fill", 0, 14, width, 2)
    local title = self.monName and "RENAME?" or tostring(self.prompt or "NAME?")
    drawInkCentered(title, 4, 3, width - 8, INK_WHITE)

    setColor(MODAL)
    chamfer("fill", 4, 19, width - 8, 24, 3)
    setColor(MODAL_DARK)
    chamfer("line", 4.5, 19.5, width - 9, 23, 3)
    local entered = tostring(self.text or "")
    local display = entered
      .. ("-"):rep(math.max(0, (self.maxLength or 7) - #entered))
    local entryX = 10 + math.floor((width - 20 - Font.width(display)) / 2)
    drawInk(display, entryX, 27, width - 20, INK_BLACK)
    if #entered < (self.maxLength or 7) then
      setColor(MODAL_DARK)
      G.rectangle("fill", entryX + Font.width(entered) + 1, 36, 6, 1)
    end

    local rows = self:rows()
    local total = #rows + 1
    local top, areaH = 47, 86
    local rowH = math.max(11, math.floor(areaH / math.max(1, total)))
    local cellW = math.floor((width - 6) / 9)
    for row = 0, #rows - 1 do
      local line = rows[row + 1] or {}
      local y = top + row * rowH
      for col = 0, 8 do
        local x = 3 + col * cellW
        local selected = self.row == row and self.col == col
        setColor(selected and MODAL_DARK or MODAL)
        chamfer("fill", x, y, cellW - 2, rowH - 2, 2)
        local ch = line[col + 1]
        if ch and ch ~= "" and ch ~= " " then
          drawInkCentered(ch, x, y + math.max(1, math.floor((rowH - 10) / 2)),
            cellW - 2, selected and INK_WHITE or INK_BLACK)
        end
      end
    end
    local bottomY = top + #rows * rowH
    local labels = self.lower and { "A-a", "DEL", "END" }
      or { "a-A", "DEL", "END" }
    for i, label in ipairs(labels) do
      local x = 3 + (i - 1) * cellW * 3
      local selected = self.row == self:bottomRow() and self:bottomTarget() == i
      setColor(selected and MODAL_DARK or MODAL)
      chamfer("fill", x, bottomY, cellW * 3 - 2, rowH - 2, 2)
      drawInkCentered(label, x, bottomY + math.max(1, math.floor((rowH - 10) / 2)),
        cellW * 3 - 2, selected and INK_WHITE or INK_BLACK)
    end
    setColor(HEADER)
    G.rectangle("fill", 0, 136, width, 8)
    drawInkCentered("A TYPE B DEL START", 2, 136, width - 4, INK_WHITE)
    G.setColor(1, 1, 1, 1)
  end

  local function install(id, native, decorate)
    local inherited = mod.content.screens:get(id)
    local provider = inherited or native
    local record = { new = function(game, ...)
      return decorate(provider.new(game, ...), game)
    end }
    if inherited then mod.content.screens:override(id, record)
    else mod.content.screens:register(id, record) end
  end

  local function decorateParty(menu)
    if type(menu) ~= "table" or menu.modernPartyGeneration == 2 then return menu end
    menu.modernPartyUI = true
    menu.modernPartyGeneration = 2
    menu.classicGen2PartyPanel = menu.drawPanel
    menu.drawPanel = modernPartyPanel
    local nativeUpdate = menu.update
    if type(nativeUpdate) == "function" then
      menu.classicGen2PartyUpdate = nativeUpdate
      menu.update = function(self, dt)
        local input = self.game and self.game.input
        local renderedWidth = tonumber(self.modernPartyWideWidth)
          or tonumber(self.modernPartyLastWideWidth) or 160

        -- Action submenus and item-result messages keep their native vertical
        -- controls. The two-column roster itself accepts all four directions,
        -- including Switch and Softboiled's second-Pokémon pickers.
        if renderedWidth >= 196 and input and input.wasPressed
            and not self.submenu and not self.itemResult then
          local direction
          for _, key in ipairs({ "left", "right", "up", "down" }) do
            if input:wasPressed(key) then direction = key break end
          end
          if direction then
            local count = #(self.party or {})
            local noCancel = self.switchFrom or self.softboiledFrom
            local nextIndex, nextColumn = partyGridIndex(self.index, count,
              direction, not noCancel, self.modernPartyGridColumn)
            self.index = nextIndex or self.index
            self.modernPartyGridColumn = nextColumn
            if self.index <= count then
              if type(self.storeCursor) == "function" then
                self:storeCursor()
              elseif self.game then
                self.game.partyMenuCursor = self.index
              end
            end

            -- Retain native clocks and A/B handling while preventing the
            -- one-dimensional controller from applying a second movement.
            local originalWasPressed = input.wasPressed
            input.wasPressed = function(source, key)
              if key == "left" or key == "right"
                  or key == "up" or key == "down" then return false end
              return originalWasPressed(source, key)
            end
            local ok, result = pcall(nativeUpdate, self, dt)
            input.wasPressed = originalWasPressed
            if not ok then error(result, 0) end
            return result
          end
        end
        return nativeUpdate(self, dt)
      end
    end
    installWideDraw(menu, menu.drawPanel, BACKDROP)
    return menu
  end

  local function decorateSummary(menu)
    if type(menu) ~= "table" or menu.modernPartyGeneration == 2 then return menu end
    local nativePanel = menu.drawPanel
    menu.modernPartySummary = true
    menu.modernPartyGeneration = 2
    menu.classicGen2SummaryPanel = nativePanel
    menu.drawPanel = modernSummaryPanel
    local nativeUpdateMoveDetail = menu.updateMoveDetail
    if type(nativeUpdateMoveDetail) == "function" then
      menu.classicGen2UpdateMoveDetail = nativeUpdateMoveDetail
      menu.updateMoveDetail = function(self, input)
        -- The expanded move-management page is a 2x2 grid. Keep the native
        -- vertical-list controls at 160px, but make every direction agree
        -- with the cards once the wide presenter has reflowed them.
        local renderedWidth = tonumber(self.modernPartyWideWidth)
          or tonumber(self.modernPartyLastWideWidth) or 160
        if renderedWidth >= 196 then
          for _, direction in ipairs({ "left", "right", "up", "down" }) do
            if input:wasPressed(direction) then
              local moves = self.moveList and self:moveList()
                or (self.mon and self.mon.moves) or {}
              self.moveIndex = moveGridIndex(self.moveIndex, #moves, direction)
                or self.moveIndex
              return
            end
          end
        end
        return nativeUpdateMoveDetail(self, input)
      end
    end
    installWideDraw(menu, menu.drawPanel, BACKDROP)
    return menu
  end

  local function decorateNaming(menu)
    if type(menu) ~= "table" or menu.modernPartyGeneration == 2 then return menu end
    local nativePanel = menu.drawPanel or menu.drawBackdrop
    menu.modernPartyNaming = true
    menu.modernPartyGeneration = 2
    menu.classicGen2NamingPanel = nativePanel
    if type(menu.drawPanel) == "function" then
      menu.drawPanel = modernNamingPanel
      installWideDraw(menu, menu.drawPanel, BACKDROP)
    end
    return menu
  end

  install("Gen2PartyMenu", PartyMenu, decorateParty)
  install("Gen2SummaryMenu", SummaryMenu, decorateSummary)
  install("Gen2NamingScreen", NamingScreen, decorateNaming)
  mod.exports.generation = 2
  mod.log:info("modern Gen 2 party, summary and naming presentation enabled")
end
