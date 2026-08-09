-- Responsive modern presentation for src.ui.SummaryMenu.
--
-- Page changes and closing remain owned by the original controller. This
-- module replaces only drawing, palette zones and the logical UI width so a
-- summary opened from the party, a PC box or another mod behaves identically.
return function(mod)
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")
  local SummaryMenu = require("src.ui.SummaryMenu")
  local TypeChart = require("src.battle.TypeChart")

  local SCREEN_H = 144
  local HEADER_H = 16
  local FOOTER_Y = 136
  local WHITE, LIGHT, DARK, BLACK = 1, 170 / 255, 85 / 255, 0

  local TYPE_BASE_COLORS = {
    NORMAL = { 144, 152, 162 }, FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 }, POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 }, ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 }, GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 }, WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 }, ELECTRIC = { 244, 210, 59 },
    PSYCHIC_TYPE = { 249, 113, 119 }, PSYCHIC = { 249, 113, 119 },
    ICE = { 115, 206, 191 }, DRAGON = { 9, 109, 195 },
    DARK = { 91, 82, 101 }, FAIRY = { 236, 144, 231 },
    STEEL = { 91, 142, 161 },
  }

  local TYPE_SHORT = {
    NORMAL = "NRM", FIGHTING = "FGT", FLYING = "FLY",
    POISON = "PSN", GROUND = "GRD", ROCK = "RCK", BUG = "BUG",
    GHOST = "GHO", FIRE = "FIR", WATER = "WTR", GRASS = "GRS",
    ELECTRIC = "ELC", PSYCHIC_TYPE = "PSY", PSYCHIC = "PSY",
    ICE = "ICE", DRAGON = "DRG", DARK = "DRK", FAIRY = "FRY",
    STEEL = "STL",
  }

  local function typeRamp(base)
    local light = {}
    for i = 1, 3 do
      light[i] = math.floor(base[i] + (255 - base[i]) * 0.30 + 0.5)
    end
    return {
      { 255, 255, 255 }, light,
      { base[1], base[2], base[3] }, { 0, 0, 0 },
    }
  end

  local TYPE_COLORS = {}
  for id, base in pairs(TYPE_BASE_COLORS) do TYPE_COLORS[id] = typeRamp(base) end

  local inkShader -- false when unavailable

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function responsiveWidth()
    if not setting("responsive", true) then return 160 end
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H
    local scale = math.max(1, math.floor(height / SCREEN_H))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale)))
  end

  local function uiSize()
    return responsiveWidth(), SCREEN_H
  end

  local function layoutFor(summary)
    local width = responsiveWidth()
    local renderer = summary and summary.game and summary.game.renderer
    if setting("responsive", true) and renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    width = math.max(160, math.floor(width))
    local railW = math.min(88, math.max(64, math.floor(width * 0.31)))
    local mainX = railW + 4
    local mainW = width - mainX - 2
    return {
      width = width,
      railX = 2, railY = HEADER_H + 2, railW = railW,
      railH = FOOTER_Y - HEADER_H - 4,
      mainX = mainX, mainY = HEADER_H + 2, mainW = mainW,
      mainH = FOOTER_Y - HEADER_H - 4,
      moveColumns = mainW >= 144 and 2 or 1,
    }
  end

  local function shaderForInk()
    if inkShader == nil then
      if not love.graphics.newShader then
        inkShader = false
      else
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        inkShader = ok and shader or false
      end
    end
    return inkShader or nil
  end

  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(tonumber(maxWidth) or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, maxWidth)
    if count < 1 then return "" end
    return text:sub(1, spans[count].to)
  end

  local function drawText(text, x, y, maxWidth, shade)
    text = fitText(text, maxWidth or Font.width(tostring(text or "")))
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.draw(text, math.floor(x), math.floor(y))
    love.graphics.pop()
    return Font.width(text)
  end

  local function drawTextRight(text, right, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, math.floor(right) - width, y, maxWidth, shade)
    return width
  end

  local function drawTextCentered(text, x, y, maxWidth, shade)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, math.floor(x + (maxWidth - width) / 2), y,
      maxWidth, shade)
    return width
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

  local function drawCard(x, y, w, h, raised)
    gray(BLACK)
    chamfer("fill", x + 2, y + 2, w - 2, h - 2, 4)
    gray(raised and BLACK or LIGHT)
    chamfer("fill", x, y, w - 2, h - 2, 4)
    gray(raised and LIGHT or DARK)
    chamfer("fill", x + 2, y + 2, w - 6, h - 6, 3)
    if raised then
      gray(DARK)
      love.graphics.rectangle("fill", x + 1, y + 7, 2,
        math.max(1, h - 14))
    end
  end

  local function drawBackdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, SCREEN_H)
    if setting("pattern", "grid") ~= "grid" then return end
    gray(LIGHT)
    for x = -SCREEN_H, layout.width, 16 do
      love.graphics.line(x, 0, x + SCREEN_H, SCREEN_H)
      love.graphics.line(x + SCREEN_H, 0, x, SCREEN_H)
    end
  end

  local function definition(summary)
    local data = summary.game.data
    return data and data.pokemon and data.pokemon[summary.mon.species] or {}
  end

  local function primaryPalette(summary)
    local data, mon = summary.game.data, summary.mon
    local style = setting("card_color", "species")
    if style == "health" then
      return PaletteFX.pal(data,
        PaletteFX.barPalName(mon.hp or 0, mon.stats and mon.stats.hp or 1))
    elseif style == "blue" then
      return PaletteFX.pal(data, "BLUEMON")
    elseif style == "mono" then
      return PaletteFX.pal(data, "GRAYMON") or PaletteFX.GRAYS
    elseif style == "species_palette" or PaletteFX.mode == "ogred" then
      return PaletteFX.monPal(data, mon.species)
        or PaletteFX.pal(data, "BLUEMON")
    end
    local def = definition(summary)
    local primary = def.types and def.types[1]
    return TYPE_COLORS[tostring(primary or "NORMAL"):upper()]
      or TYPE_COLORS.NORMAL
  end

  local function basePalette(summary)
    local data = summary.game.data
    return PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON")
      or PaletteFX.GRAYS
  end

  local function movePalette(summary, move)
    local def = move and summary.game.data.moves[move.id]
    local id = def and tostring(def.type or "NORMAL"):upper() or "NORMAL"
    return TYPE_COLORS[id] or TYPE_COLORS.NORMAL
  end

  local function drawHeader(summary, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)
    drawText(('%d/2'):format(summary.page or 1), 4, 4, 24, WHITE)
    local def = definition(summary)
    local name = summary.mon.nickname or def.name or summary.mon.species or "?"
    local nameLeft, nameRight = 36, layout.width - 52
    local maxName = math.max(24, nameRight - nameLeft)
    local shown = fitText(name, maxName)
    drawText(shown, nameLeft + (maxName - Font.width(shown)) / 2,
      3, maxName, WHITE)
    drawTextRight(summary.page == 1 and "STATS" or "MOVES",
      layout.width - 4, 4, 48, WHITE)
  end

  local function spriteGeometry(summary, layout)
    if not summary.sprite then return nil end
    local sw, sh = summary.sprite:getDimensions()
    local x = layout.railX + math.floor((layout.railW - sw) / 2)
    local y = layout.railY + 5 + math.max(0, math.floor((56 - sh) / 2))
    return x, y, sw, sh
  end

  local function displayType(id)
    return id and TypeChart.displayName(id) or "---"
  end

  local function paletteKey(colors)
    local values = {}
    for i = 1, 4 do
      local c = colors and colors[i] or {}
      values[#values + 1] = tostring(c[1] or 0)
      values[#values + 1] = tostring(c[2] or 0)
      values[#values + 1] = tostring(c[3] or 0)
    end
    return table.concat(values, ":")
  end

  -- Front sprites are opaque four-shade images. Only the lightest pixels
  -- connected to an outside edge are matte; the same light shade is also
  -- legitimate artwork inside the outline (eyes, bellies and highlights).
  -- Flood-filling the edge matte keeps those internal details while giving
  -- the result real transparency over the profile card.
  local function maskedPaletteSprite(path, colors)
    if not (path and colors and love.image and love.image.newImageData) then
      return nil
    end
    local ok, data = pcall(Assets.imageData, path)
    if not ok or not data then return nil end
    local w, h = data:getDimensions()
    local outside, qx, qy, head = {}, {}, {}, 1

    local function index(x, y) return y * w + x + 1 end
    local function isMatte(x, y)
      local r, g, b, a = data:getPixel(x, y)
      return a <= 0 or (r > 0.83 and g > 0.83 and b > 0.83)
    end
    local function visit(x, y)
      if x < 0 or y < 0 or x >= w or y >= h then return end
      local i = index(x, y)
      if outside[i] or not isMatte(x, y) then return end
      outside[i] = true
      qx[#qx + 1], qy[#qy + 1] = x, y
    end

    for x = 0, w - 1 do visit(x, 0); visit(x, h - 1) end
    for y = 1, h - 2 do visit(0, y); visit(w - 1, y) end
    while head <= #qx do
      local x, y = qx[head], qy[head]
      head = head + 1
      visit(x - 1, y); visit(x + 1, y)
      visit(x, y - 1); visit(x, y + 1)
    end

    data:mapPixel(function(x, y, r, g, b, a)
      if a <= 0 or outside[index(x, y)] then return r, g, b, 0 end
      local c = r > 0.83 and colors[1]
        or r > 0.5 and colors[2]
        or r > 0.17 and colors[3] or colors[4]
      return c[1] / 255, c[2] / 255, c[3] / 255, a
    end)
    local made, image = pcall(love.graphics.newImage, data)
    if not made then return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    return image
  end

  local function profileSprite(summary)
    if summary.spriteTrueColor then return summary.sprite, true end
    local colors = PaletteFX.effectiveColors(
      PaletteFX.monPal(summary.game.data, summary.mon.species)
        or primaryPalette(summary))
    local key = paletteKey(colors)
    if summary.modernSpriteKey ~= key then
      summary.modernSprite = maskedPaletteSprite(summary.modernSpritePath,
        colors)
      summary.modernSpriteKey = key
    end
    return summary.modernSprite or summary.sprite,
      summary.modernSprite ~= nil
  end

  local function drawProfile(summary, layout)
    local mon, def = summary.mon, definition(summary)
    drawCard(layout.railX, layout.railY, layout.railW, layout.railH, true)
    local x, y, sw, sh = spriteGeometry(summary, layout)
    if x then
      -- Paint the sprite cell with the card's final face colour. The masked
      -- sprite has a genuinely transparent exterior but keeps light artwork
      -- enclosed by its outline; the true-colour mark restores this already
      -- composited result after the screen-wide palette pass.
      local faceColors = PaletteFX.effectiveColors(primaryPalette(summary))
        or PaletteFX.GRAYS
      local face = faceColors[2] or { 170, 170, 170 }
      love.graphics.setColor(face[1] / 255, face[2] / 255,
        face[3] / 255, 1)
      love.graphics.rectangle("fill", x, y, sw, sh)

      local image, paletteBaked = profileSprite(summary)
      local shader
      if not summary.spriteTrueColor and not paletteBaked then
        -- Pixel reads are unavailable only in reduced/headless runtimes. Keep
        -- their previous safe keyed draw as a compatibility fallback.
        shader = PaletteFX.keyedShader()
        if shader then
          love.graphics.setShader(shader)
          PaletteFX.sendColors(shader,
            PaletteFX.monPal(summary.game.data, mon.species)
              or primaryPalette(summary))
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
      -- The original status screen mirrors the front sprite. Preserve that
      -- presentation detail and the live sprite supplied by other mods.
      love.graphics.draw(image, x + sw, y, 0, -1, 1)
      if shader then love.graphics.setShader() end
      PaletteFX.markTrueColor(x, y, sw, sh)
    end

    local compact = layout.railW < 72
    local margin = compact and 4 or 5
    local textX = layout.railX + margin
    local textW = layout.railW - margin * 2
    local infoY = layout.railY + 62
    drawText(("No.%03d"):format(def.dex or 0), textX, infoY,
      textW, BLACK)
    local types = def.types or {}
    drawText(displayType(types[1]), textX, infoY + 10, textW, BLACK)
    if types[2] and types[2] ~= types[1] then
      drawText(displayType(types[2]), textX, infoY + 20, textW, BLACK)
    end
    local player = summary.game.save and summary.game.save.player or {}
    local ot = mon.ot or player.name or "RED"
    local id = mon.otId or player.id or 0
    drawText("OT " .. tostring(ot), textX, infoY + 31, textW, BLACK)
    drawText((compact and "ID%05d" or "ID %05d"):format(id),
      textX, infoY + 41, textW, BLACK)
  end

  local function drawMeter(fraction, x, y, w)
    w = math.max(12, w)
    local inner = math.max(1, w - 4)
    local fill = math.floor(inner * math.max(0, math.min(1, fraction)) + 0.5)
    if fraction > 0 then fill = math.max(1, fill) end
    gray(BLACK)
    love.graphics.rectangle("fill", x, y, w, 6)
    gray(DARK)
    love.graphics.rectangle("fill", x + 2, y + 2, fill, 2)
  end

  local function drawVitals(summary, layout)
    local mon = summary.mon
    local x, y, w, h = layout.mainX, layout.mainY, layout.mainW, 42
    drawCard(x, y, w, h, true)
    drawText("LV" .. tostring(mon.level or 1), x + 5, y + 5, 48, BLACK)
    local status = (mon.hp or 0) <= 0 and "FNT" or mon.status or "OK"
    drawTextRight(tostring(status), x + w - 5, y + 5, 40, BLACK)
    local maxHP = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local barX, barY, barW = x + 25, y + 18, w - 30
    drawText("HP", x + 5, barY, 16, BLACK)
    drawMeter((mon.hp or 0) / math.max(1, maxHP), barX, barY + 1, barW)
    drawTextRight(("%d/%d"):format(mon.hp or 0, maxHP),
      x + w - 5, y + 29, w - 10, BLACK)
  end

  local STAT_ITEMS = {
    { "ATTACK", "attack", "ATK" }, { "DEFENSE", "defense", "DEF" },
    { "SPEED", "speed", "SPD" }, { "SPECIAL", "special", "SPC" },
  }

  local function statGeometry(layout, index)
    local areaY = layout.mainY + 44
    local areaH = layout.mainH - 44
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    local x = layout.mainX
      + math.floor(column * layout.mainW / 2)
    local x2 = layout.mainX
      + math.floor((column + 1) * layout.mainW / 2)
    local y = areaY + math.floor(row * areaH / 2)
    local y2 = areaY + math.floor((row + 1) * areaH / 2)
    return x, y, x2 - x, y2 - y
  end

  local function drawStats(summary, layout)
    for i, item in ipairs(STAT_ITEMS) do
      local x, y, w, h = statGeometry(layout, i)
      drawCard(x, y, w, h, false)
      local value = summary.mon.stats and summary.mon.stats[item[2]] or 0
      local valueText = tostring(value)
      local label = item[1]
      local gap = 4
      local groupWidth = Font.width(label) + gap + Font.width(valueText)
      if groupWidth > w - 8 then
        label = item[3]
        groupWidth = Font.width(label) + gap + Font.width(valueText)
      end

      -- Wide cards keep the related label and value together instead of
      -- pinning them to diagonally opposite corners of an otherwise empty
      -- panel. Compact cards retain their readable two-line arrangement.
      if groupWidth <= w - 8 then
        local startX = x + math.floor((w - groupWidth) / 2)
        local textY = y + math.floor((h - 8) / 2)
        local labelWidth = drawText(label, startX, textY,
          w - 8, WHITE)
        drawText(valueText, startX + labelWidth + gap, textY,
          w - 8 - labelWidth - gap, WHITE)
      else
        drawText(label, x + 4, y + 4, w - 8, WHITE)
        drawTextRight(valueText, x + w - 5, y + h - 11,
          w - 10, WHITE)
      end
    end
  end

  local function expProgress(summary)
    local mon, def = summary.mon, definition(summary)
    local cap = summary.game.data.constants
      and summary.game.data.constants.levelCap or 100
    if (mon.level or 1) >= cap then return 1, 0, true end
    local rates = summary.game.data.growth_rates
    local from = Growth.expForLevel(def.growthRate, mon.level, rates)
    local to = Growth.expForLevel(def.growthRate, mon.level + 1, rates)
    local progress = math.max(0, (mon.exp or 0) - from)
    return math.max(0, math.min(1, progress / math.max(1, to - from))),
      math.max(0, to - (mon.exp or 0)), false
  end

  local function drawExp(summary, layout)
    local mon = summary.mon
    local x, y, w, h = layout.mainX, layout.mainY, layout.mainW, 38
    drawCard(x, y, w, h, true)
    local fraction, needed, capped = expProgress(summary)
    drawText("EXP " .. tostring(mon.exp or 0), x + 5, y + 5,
      w - 10, BLACK)
    local target
    if capped then
      target = "MAX"
    elseif w < 120 then
      target = ("%d/L%d"):format(needed, math.min(100, mon.level + 1))
    else
      target = ("NEXT %d TO LV%d"):format(needed, math.min(100, mon.level + 1))
    end
    drawText(target, x + 5, y + 16, w - 10, BLACK)
    drawMeter(fraction, x + 5, y + 28, w - 10)
  end

  local function moveGeometry(layout, index)
    local areaY = layout.mainY + 40
    local areaH = layout.mainH - 40
    local columns = layout.moveColumns
    local rows = math.ceil(4 / columns)
    local zero = index - 1
    local column = zero % columns
    local row = math.floor(zero / columns)
    local x = layout.mainX
      + math.floor(column * layout.mainW / columns)
    local x2 = layout.mainX
      + math.floor((column + 1) * layout.mainW / columns)
    local y = areaY + math.floor(row * areaH / rows)
    local y2 = areaY + math.floor((row + 1) * areaH / rows)
    return x, y, x2 - x, y2 - y
  end

  local function drawMoves(summary, layout)
    local moves = summary.mon.moves or {}
    for i = 1, 4 do
      local x, y, w, h = moveGeometry(layout, i)
      drawCard(x, y, w, h, false)
      local move = moves[i]
      local def = move and summary.game.data.moves[move.id]
      if not (move and def) then
        drawTextCentered("EMPTY", x + 5, y + math.floor((h - 8) / 2),
          w - 10, WHITE)
      else
        local name = fitText(def.name or move.id, w - 10)
        local nameY = y + math.floor((h - 17) / 2)
        drawTextCentered(name, x + 5, nameY, w - 10, WHITE)
        local typeName = TYPE_SHORT[tostring(def.type or "NORMAL"):upper()]
          or "---"
        local maxPP = (def.pp or 0)
          + (move.ppUps or 0) * math.floor((def.pp or 0) / 5)
        local pp = ("%d/%d"):format(move.pp or 0, maxPP)
        local gap = 6
        local detailWidth = Font.width(typeName) + gap + Font.width(pp)
        local detailX = x + math.floor((w - detailWidth) / 2)
        local detailY = nameY + 9
        local typeWidth = drawText(typeName, detailX, detailY,
          Font.width(typeName), WHITE)
        drawText(pp, detailX + typeWidth + gap, detailY,
          Font.width(pp), WHITE)
      end
    end
  end

  local function drawFooter(summary, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 8)
    local hint = summary.page == 1 and "A/B MOVES" or "A/B BACK"
    drawText(hint, (layout.width - Font.width(hint)) / 2,
      FOOTER_Y, layout.width - 8, WHITE)
  end

  local function draw(summary)
    local layout = layoutFor(summary)
    drawBackdrop(layout)
    drawHeader(summary, layout)
    drawProfile(summary, layout)
    if summary.page == 1 then
      drawVitals(summary, layout)
      drawStats(summary, layout)
    else
      drawExp(summary, layout)
      drawMoves(summary, layout)
    end
    drawFooter(summary, layout)
    gray(WHITE)
  end

  local function sgbPalettes(summary, game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(summary)
    local base = basePalette(summary)
    local primary = primaryPalette(summary)
    local zones = { {
      colors = base, x = 0, y = 0, w = layout.width, h = SCREEN_H,
    }, {
      colors = primary, x = layout.railX, y = layout.railY,
      w = layout.railW, h = layout.railH,
    } }

    if summary.page == 1 then
      zones[#zones + 1] = {
        colors = primary, x = layout.mainX, y = layout.mainY,
        w = layout.mainW, h = 42,
      }
      local maxHP = summary.mon.stats and summary.mon.stats.hp or 1
      local hp = PaletteFX.pal(data,
        PaletteFX.barPalName(summary.mon.hp or 0, maxHP))
      if hp then
        zones[#zones + 1] = {
          colors = hp, x = layout.mainX + 25, y = layout.mainY + 19,
          w = layout.mainW - 30, h = 6,
        }
      end
    else
      local exp = PaletteFX.pal(data, "EXP") or base
      zones[#zones + 1] = {
        colors = exp, x = layout.mainX + 5, y = layout.mainY + 28,
        w = layout.mainW - 10, h = 6,
      }
      for i, move in ipairs(summary.mon.moves or {}) do
        if i > 4 then break end
        local x, y, w, h = moveGeometry(layout, i)
        zones[#zones + 1] = {
          colors = movePalette(summary, move), x = x, y = y, w = w, h = h,
        }
      end
    end
    return zones
  end

  return {
    new = function(game, mon)
      local summary = SummaryMenu.new(game, mon)
      -- Resolve through the same live sprite hook used by SummaryMenu so the
      -- matte mask follows asset replacements rather than a private copy.
      summary.modernSpritePath = Sprites.path(game.data, mon.species, "front",
        { mon = mon, kind = "summary" })
      summary.draw = draw
      summary.sgbPalettes = sgbPalettes
      summary.uiSize = uiSize
      summary.isWideBattleLayout = function()
        return setting("responsive", true)
      end
      summary.modernPartySummary = true
      summary.modernSummaryLayout = "responsive_cards"
      return summary
    end,
  }
end
