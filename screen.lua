-- Modern two-column presentation for src.ui.PartyMenu.
--
-- Construction and actions still delegate to the engine controller. This
-- module adds a card-grid renderer and a thin navigation adapter; item use,
-- TM/HM checks, field moves, switching, healing and callbacks remain native.
return function(mod)
  local PartyMenu = require("src.ui.PartyMenu")
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local Theme = require("src.ui.Theme")

  local SCREEN_H = 144
  local HEADER_H = 16
  local FOOTER_Y = 136
  local DEFAULT_CAPACITY = 6

  local WHITE = 1
  local LIGHT = 170 / 255
  local DARK = 85 / 255
  local BLACK = 0

  -- Exact flat fills sampled from the supplied type-colour reference. Dark,
  -- Fairy and Steel are included for party species registered by content
  -- mods, even though the original Gen 1 roster does not use them.
  local TYPE_BASE_COLORS = {
    NORMAL = { 144, 152, 162 },
    FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 },
    POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 },
    ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 },
    GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 },
    WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 },
    ELECTRIC = { 244, 210, 59 },
    PSYCHIC_TYPE = { 249, 113, 119 },
    PSYCHIC = { 249, 113, 119 },
    ICE = { 115, 206, 191 },
    DRAGON = { 9, 109, 195 },
    DARK = { 91, 82, 101 },
    FAIRY = { 236, 144, 231 },
    STEEL = { 91, 142, 161 },
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
  for id, base in pairs(TYPE_BASE_COLORS) do
    TYPE_COLORS[id] = typeRamp(base)
  end

  local inkShader -- false when unavailable
  local cardPalette -- assigned after the draw helpers

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
  end

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function partyOf(menu)
    return menu.party or (menu.game.save and menu.game.save.party) or {}
  end

  local function definition(menu, mon)
    local pokemon = menu.game.data and menu.game.data.pokemon or {}
    return mon and pokemon[mon.species] or nil
  end

  local function capacityOf(menu)
    local constants = menu.game.data and menu.game.data.constants or nil
    return (constants and constants.partyMax) or DEFAULT_CAPACITY
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

  local function layoutFor(menu)
    local width = responsiveWidth()
    local renderer = menu and menu.game and menu.game.renderer
    if setting("responsive", true) and renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    width = math.max(160, math.floor(width))
    -- The reference layout is always a two-column party: wider displays make
    -- those cards broader instead of shrinking the Gen 1 font into a third
    -- column. This keeps the hierarchy readable at every aspect ratio.
    local columns = 2
    local capacity = math.min(DEFAULT_CAPACITY, capacityOf(menu))
    local rows = math.max(1, math.ceil(capacity / columns))
    return {
      width = width,
      columns = columns,
      rows = rows,
      capacity = capacity,
      contentHeight = FOOTER_Y - HEADER_H,
    }
  end

  local function slotGeometry(layout, index)
    local zero = index - 1
    local column = zero % layout.columns
    local row = math.floor(zero / layout.columns)
    local x = math.floor(column * layout.width / layout.columns)
    local x2 = math.floor((column + 1) * layout.width / layout.columns)
    local y = HEADER_H
      + math.floor(row * layout.contentHeight / layout.rows)
    local y2 = HEADER_H
      + math.floor((row + 1) * layout.contentHeight / layout.rows)
    return x, y, x2 - x, y2 - y, column, row
  end

  local function shownMon(menu, mon)
    if menu.heal and menu.heal.mon == mon then
      return { hp = math.floor(menu.heal.shown), stats = mon.stats }
    end
    return mon
  end

  local function canLearn(menu, def)
    if not (menu.tmhm and def) then return false end
    for _, moveId in ipairs(def.tmhm or {}) do
      if moveId == menu.tmhm.move then return true end
    end
    return false
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

  -- The ROM font is an 8x8 tile font. Scaling it by fractions makes strokes
  -- land between pixels, which produces broken letters once the whole UI is
  -- integer-scaled to the window. Keep every glyph at its native size and
  -- trim only on complete glyph boundaries when a compact card runs out of
  -- room. Font.split also keeps multi-byte glyphs such as é intact.
  local function fitText(text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(0, math.floor(tonumber(maxWidth) or Font.width(text)))
    if Font.width(text) <= maxWidth then return text end
    local spans = Font.split(text)
    local count = Font.spansFitting(spans, maxWidth)
    if count < 1 then return "" end
    return text:sub(1, spans[count].to)
  end

  -- The extracted tile font is black-on-transparent. A tiny shader treats it
  -- as an alpha mask, allowing the dark cards to use paper-colored text while
  -- retaining the exact Gen 1 letterforms. Headless tests fall back to black.
  local function drawText(text, x, y, maxWidth, _preferred, shade)
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

  local function drawTextRight(text, right, y, maxWidth, preferred, shade)
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, math.floor(right) - width, y, maxWidth, preferred, shade)
    return width
  end

  local function drawCode(code, x, y, shade)
    love.graphics.push("all")
    local shader = shaderForInk()
    if shader then
      love.graphics.setShader(shader)
      gray(shade == nil and WHITE or shade)
    else
      gray(BLACK)
    end
    Font.drawCode(code, x, y)
    love.graphics.pop()
  end

  -- The extracted Red/Blue font has no percent tile. Draw the small symbol
  -- from whole 1px blocks so percentage modes remain crisp and do not fall
  -- back to a blank glyph.
  local PERCENT_PIXELS = {
    { 0, 1 }, { 1, 1 }, { 5, 1 },
    { 0, 2 }, { 1, 2 }, { 4, 2 },
    { 3, 3 }, { 2, 4 }, { 1, 5 },
    { 0, 6 }, { 4, 5 }, { 5, 5 },
    { 4, 6 }, { 5, 6 },
  }

  local function drawPercent(x, y, shade)
    gray(shade == nil and WHITE or shade)
    for _, pixel in ipairs(PERCENT_PIXELS) do
      love.graphics.rectangle("fill", math.floor(x) + pixel[1],
        math.floor(y) + pixel[2], 1, 1)
    end
  end

  local function chamfer(mode, x, y, w, h, cut)
    cut = cut or 3
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

  local function drawBackdrop(layout)
    gray(WHITE)
    love.graphics.rectangle("fill", 0, 0, layout.width, SCREEN_H)
    if setting("pattern", "grid") ~= "grid" then return end

    -- A restrained diagonal grid nods to the reference screen's hex field,
    -- but is still drawn from the Game Boy's four shades.
    gray(LIGHT)
    for x = -SCREEN_H, layout.width, 16 do
      love.graphics.line(x, 0, x + SCREEN_H, SCREEN_H)
      love.graphics.line(x + SCREEN_H, 0, x, SCREEN_H)
    end
  end

  local function drawHeader(menu, party, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)

    drawText(('%d/%d'):format(#party, capacityOf(menu)), 4, 4, 32, 1, WHITE)
    drawText("POKéMON", (layout.width - 56) / 2, 3, 56, 1, WHITE)

    local mon = party[menu.index]
    local def = definition(menu, mon)
    local types = def and def.types or {}
    local short = {
      NORMAL = "NRM", FIGHTING = "FGT", FLYING = "FLY",
      POISON = "PSN", GROUND = "GRD", ROCK = "RCK", BUG = "BUG",
      GHOST = "GHO", FIRE = "FIR", WATER = "WTR", GRASS = "GRS",
      ELECTRIC = "ELC", PSYCHIC = "PSY", ICE = "ICE", DRAGON = "DRG",
    }
    local typeWidth = math.max(24, math.floor(layout.width / 2) - 36)
    local first = short[tostring(types[1] or ""):upper()] or "---"
    local second = short[tostring(types[2] or ""):upper()]
    local label = second and typeWidth >= 56 and (first .. "/" .. second)
      or first
    drawTextRight(label, layout.width - 4, 4, typeWidth, 1, WHITE)
  end

  local function drawCardFrame(x, y, width, height, selected)
    -- Match Typed Move Colors' focus hierarchy. The selected card grows by a
    -- pixel on each side, uses a black outer frame, and raises its lighter
    -- face inside that frame. Its contents keep their original grid anchors,
    -- so the emphasis cannot crowd the icon or meter labels.
    if selected then
      x, y, width, height = x - 1, y - 1, width + 2, height + 2
    end

    gray(BLACK)
    chamfer("fill", x + 2, y + 2, width - 3, height - 3, 4)

    gray(selected and BLACK or LIGHT)
    chamfer("fill", x + 1, y + 1, width - 3, height - 3, 4)

    gray(selected and LIGHT or DARK)
    chamfer("fill", x + 3, y + 3, width - 7, height - 7, 3)

    if selected then
      gray(DARK)
      love.graphics.rectangle("fill", x + 1, y + 8, 2, height - 16)
    end
  end

  local function expProgress(menu, mon, def)
    if not (mon and def and mon.exp and mon.level) then return 0, 1, false end
    local cap = (menu.game.data.constants and menu.game.data.constants.levelCap) or 100
    if mon.level >= cap then return 1, 1, true end
    local rates = menu.game.data.growth_rates
    local from = Growth.expForLevel(def.growthRate, mon.level, rates)
    local to = Growth.expForLevel(def.growthRate, mon.level + 1, rates)
    if to <= from then return 0, 1, false end
    return math.max(0, mon.exp - from), to - from, false
  end

  local function expFraction(menu, mon, def)
    local current, needed, capped = expProgress(menu, mon, def)
    if capped then return 1 end
    return math.max(0, math.min(1, current / math.max(1, needed)))
  end

  local function contentInset(width)
    -- Full "EXP" needs a 24px label column. Compact 80px cards use the
    -- equally familiar "XP" and retain one extra glyph of nickname room.
    return width >= 110 and 31 or 23
  end

  local function meterGeometry(x, y, width, height)
    local barX = x + contentInset(width)
    local barW = math.max(16, x + width - 5 - barX)
    return y + height - 17, y + height - 9, barX, barW
  end

  local function iconGeometry(x, y, width, height)
    local hpY = meterGeometry(x, y, width, height)
    local left, top = x + 3, y + 3
    local availableW = contentInset(width) - 3
    local availableH = hpY - top
    return left + math.max(0, math.floor((availableW - 16) / 2)),
      top + math.max(0, math.floor((availableH - 16) / 2))
  end

  local function drawMeter(fraction, rowY, barX, barW, nonzero)
    local inner = math.max(1, barW - 4)
    local fill = math.floor(inner * math.max(0, math.min(1, fraction)) + 0.5)
    if nonzero then fill = math.max(1, fill) end

    gray(BLACK)
    love.graphics.rectangle("fill", barX, rowY + 1, barW, 6)
    gray(DARK)
    love.graphics.rectangle("fill", barX + 2, rowY + 3, fill, 2)
  end

  local function drawExpBar(menu, mon, def, x, y, width, height)
    if not setting("exp_strip", true) then return end
    local _, expY, barX, barW = meterGeometry(x, y, width, height)
    drawMeter(expFraction(menu, mon, def), expY, barX, barW, false)
  end

  local function statusLabel(mon)
    if (mon.hp or 0) <= 0 then return "FNT" end
    if mon.status and mon.status ~= "" then return tostring(mon.status) end
    return nil
  end

  local function hpDetail(mon)
    local maxHP = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local mode = setting("hp_text", "bar")
    if mode == "percent" then
      return ("%d%%"):format(math.floor((mon.hp or 0) * 100 / math.max(1, maxHP)))
    elseif mode == "bar" then
      return nil
    end
    return ("%d/%d"):format(mon.hp or 0, maxHP)
  end

  local function compactAmount(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value >= 1000000 then
      return tostring(math.floor(value / 100000) / 10) .. "M"
    elseif value >= 10000 then
      return tostring(math.floor(value / 100) / 10) .. "K"
    end
    return tostring(value)
  end

  local function expDetail(menu, mon, def, maxWidth)
    local mode = setting("exp_text", "percent")
    if mode == "bar" then return nil end
    local current, needed, capped = expProgress(menu, mon, def)
    if capped then return "MAX" end
    if mode == "percent" then
      return ("%d%%"):format(math.floor(current * 100
        / math.max(1, needed)))
    end
    local exact = ("%d/%d"):format(current, needed)
    if Font.width(exact) <= maxWidth then return exact end
    return compactAmount(current) .. "/" .. compactAmount(needed)
  end

  local function drawMeterDetail(text, rowY, barX, barW)
    if not text then return end
    text = tostring(text)
    if text:sub(-1) == "%" then
      local digits = fitText(text:sub(1, -2), barW - 10)
      local width = Font.width(digits) + 6
      local x = barX + barW - 2 - width
      drawText(digits, x, rowY, barW - 10, 1, WHITE)
      drawPercent(x + Font.width(digits), rowY, WHITE)
    else
      drawTextRight(text, barX + barW - 2, rowY, barW - 4, 1, WHITE)
    end
  end

  local function drawBadge(text, right, y, selected, spacious)
    if not text then return end
    text = fitText(text, spacious and 40 or 24)
    local padding = spacious and 4 or 0
    local width = math.max(16, Font.width(text) + padding)
    gray(selected and DARK or WHITE)
    love.graphics.rectangle("fill", right - width, y, width, 8)
    drawText(text, right - width + math.floor(padding / 2), y,
      width - padding, 1,
      selected and WHITE or BLACK)
  end

  local function drawHealthBar(mon, x, y, width, height)
    local maxHP = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local fraction = math.max(0, math.min(1, (mon.hp or 0) / math.max(1, maxHP)))
    local hpY, _, barX, barW = meterGeometry(x, y, width, height)
    drawMeter(fraction, hpY, barX, barW, (mon.hp or 0) > 0)
  end

  local function drawEmptyCard(layout, index)
    local x, y, width, height = slotGeometry(layout, index)
    drawCardFrame(x, y, width, height, false)
    drawText("EMPTY", x + 23, y + (height - 8) / 2,
      width - 30, 1, WHITE)
    gray(LIGHT)
    love.graphics.rectangle("line", x + 5, y + (height - 14) / 2, 13, 13)
  end

  local function drawPartyCard(menu, layout, mon, index, trueColorIcons)
    local x, y, width, height = slotGeometry(layout, index)
    local selected = index == menu.index
    local def = definition(menu, mon) or { name = mon.species or "?" }
    local shown = shownMon(menu, mon)
    shown.stats = shown.stats or { hp = math.max(1, shown.hp or 1) }
    shown.hp = math.max(0, shown.hp or 0)
    local ink = selected and BLACK or WHITE
    local spacious = width >= 110
    local iconX, iconY = iconGeometry(x, y, width, height)
    local textX = x + contentInset(width)
    local nameY = y + 6
    local detailY = nameY + 10
    local hpY, expY = meterGeometry(x, y, width, height)

    drawCardFrame(x, y, width, height, selected)

    -- This is intentionally the engine helper rather than a direct image
    -- load. It resolves icons.bySpecies, pokemon.icon hooks, asset overrides,
    -- animation frames and per-species art supplied by other mods.
    local icons = menu.game.data.icons or {}
    local entry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    local trueColorIcon = false
    if type(entry) == "table" then
      local path = tostring(entry.image or ""):lower()
      local paletteAware = path:find("icons_original", 1, true) ~= nil
      trueColorIcon = not paletteAware
        or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
    end

    -- A true-colour zone restores the complete 16x16 canvas rectangle, not
    -- just the icon's opaque pixels. Paint the card's final display colour
    -- behind the transparent pixels first, so that restore cannot reveal the
    -- raw gray pre-palette card as a square backplate.
    if trueColorIcon then
      local palette = cardPalette(menu, mon)
        or PaletteFX.pal(menu.game.data, "BLUEMON")
      local effective = PaletteFX.effectiveColors(palette)
      local background = effective and effective[selected and 2 or 3]
      if background then
        love.graphics.setColor(background[1] / 255, background[2] / 255,
          background[3] / 255, 1)
        love.graphics.rectangle("fill", iconX, iconY, 16, 16)
      end
    end

    gray(WHITE)
    PartyMenu.drawIcon(menu.game, mon, iconX, iconY,
      selected and setting("animate_icons", true), menu.blink or 0)
    if trueColorIcon then
      trueColorIcons[#trueColorIcons + 1] = {
        x = iconX, y = iconY, w = 16, h = 16,
      }
    end

    drawText(mon.nickname or def.name or mon.species or "?",
      textX, nameY, x + width - 5 - textX, 1, ink)
    local level = tostring(math.max(1, tonumber(mon.level) or 1))
    drawText((spacious and "LV" or "L") .. level,
      textX, detailY, math.max(24, width * 0.33), 1, ink)

    local badge
    if menu.tmhm then
      badge = canLearn(menu, def) and "ABLE" or "NO"
    else
      badge = statusLabel(shown)
    end
    if badge then
      drawBadge(badge, x + width - 5, detailY, selected, spacious)
    end

    if menu.tmhm then
      drawText(menu.tmhm.kind or "TM/HM", x + 4, hpY,
        width - 8, 1, ink)
    else
      drawHealthBar(shown, x, y, width, height)
      drawText("HP", x + 2, hpY, 16, 1, ink)
      local _, _, barX, barW = meterGeometry(x, y, width, height)
      drawMeterDetail(hpDetail(shown), hpY, barX, barW)
      if setting("exp_strip", true) then
        drawExpBar(menu, mon, def, x, y, width, height)
        drawText(spacious and "EXP" or "XP", x + 2, expY,
          spacious and 24 or 16, 1, ink)
        drawMeterDetail(expDetail(menu, mon, def, barW - 4),
          expY, barX, barW)
      end
    end

    if (index == menu.swapFrom or index == menu.softboiledFrom)
        and not selected then
      drawCode(Theme.cursorHollow, x + 1, hpY + 2, WHITE)
    end
  end

  local function footerText(menu, party)
    if #party == 0 then return "NO POKéMON" end
    if menu.swapFrom or menu.softboiledFrom or menu.pickOnly
        or menu.tmhm or menu.battle then
      return tostring(menu:bottomMessage() or ""):gsub("\n", " ")
    end
    return "A SELECT    B BACK"
  end

  local function drawFooter(menu, party, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 8)
    local text = footerText(menu, party)
    local maxWidth = layout.width - 8
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, (layout.width - width) / 2, FOOTER_Y,
      maxWidth, 1, WHITE)
  end

  local function submenuGeometry(menu, layout)
    local count = math.max(1, #(menu.subItems or {}))
    local height = 16 + count * 12
    local width = math.min(120, layout.width - 16)
    return math.floor((layout.width - width) / 2),
      math.floor((FOOTER_Y - height) / 16) * 8, width, height
  end

  local function drawSubmenu(menu, layout)
    if not menu.submenu then return end
    local x, y, w, h = submenuGeometry(menu, layout)
    gray(BLACK)
    chamfer("fill", x + 2, y + 2, w, h, 5)
    gray(WHITE)
    chamfer("fill", x, y, w, h, 5)
    gray(DARK)
    chamfer("fill", x + 2, y + 2, w - 4, h - 4, 4)

    drawText("ACTIONS", x + 8, y + 4, w - 16, 1, WHITE)
    for i, entry in ipairs(menu.subItems or {}) do
      local rowY = y + 14 + (i - 1) * 12
      local selected = i == menu.subIndex
      if selected then
        gray(LIGHT)
        love.graphics.rectangle("fill", x + 5, rowY - 1, w - 10, 11)
      end
      drawText(entry.label, x + 17, rowY, w - 25, 1,
        selected and BLACK or WHITE)
      if selected then drawCode(Theme.cursor, x + 7, rowY, BLACK) end
    end
  end

  -- True-colour regions are restored from the finished canvas after palette
  -- processing. Split each icon region around the action modal so an icon
  -- hidden beneath it cannot restore a square of the underlying card over
  -- the popup.
  local function markTrueColorOutside(rect, cutout)
    if not cutout then
      PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
      return
    end

    local x1, y1 = rect.x, rect.y
    local x2, y2 = x1 + rect.w, y1 + rect.h
    local cx1, cy1 = cutout.x, cutout.y
    local cx2, cy2 = cx1 + cutout.w, cy1 + cutout.h
    local ix1, iy1 = math.max(x1, cx1), math.max(y1, cy1)
    local ix2, iy2 = math.min(x2, cx2), math.min(y2, cy2)

    if ix1 >= ix2 or iy1 >= iy2 then
      PaletteFX.markTrueColor(x1, y1, rect.w, rect.h)
      return
    end

    if y1 < iy1 then
      PaletteFX.markTrueColor(x1, y1, rect.w, iy1 - y1)
    end
    if iy2 < y2 then
      PaletteFX.markTrueColor(x1, iy2, rect.w, y2 - iy2)
    end
    if x1 < ix1 then
      PaletteFX.markTrueColor(x1, iy1, ix1 - x1, iy2 - iy1)
    end
    if ix2 < x2 then
      PaletteFX.markTrueColor(ix2, iy1, x2 - ix2, iy2 - iy1)
    end
  end

  local function draw(menu)
    local layout = layoutFor(menu)
    local trueColorIcons = {}
    drawBackdrop(layout)
    local party = partyOf(menu)
    drawHeader(menu, party, layout)

    for i = 1, layout.capacity do
      if party[i] then
        drawPartyCard(menu, layout, party[i], i, trueColorIcons)
      elseif setting("empty_slots", true) then
        drawEmptyCard(layout, i)
      end
    end

    drawFooter(menu, party, layout)
    drawSubmenu(menu, layout)

    local modalCutout
    if menu.submenu then
      local x, y, w, h = submenuGeometry(menu, layout)
      -- Include the two-pixel drop shadow as part of the protected popup.
      modalCutout = { x = x, y = y, w = w + 2, h = h + 2 }
    end
    for _, rect in ipairs(trueColorIcons) do
      markTrueColorOutside(rect, modalCutout)
    end
    gray(WHITE)
  end

  cardPalette = function(menu, mon)
    local data = menu.game.data
    local style = setting("card_color", "species")
    if style == "health" then
      local hp = mon.hp or 0
      if menu.heal and menu.heal.mon == mon then hp = menu.heal.from end
      local maxHP = mon.stats and mon.stats.hp or math.max(1, hp)
      return PaletteFX.pal(data, PaletteFX.barPalName(hp, maxHP))
    elseif style == "blue" then
      return PaletteFX.pal(data, "BLUEMON")
    elseif style == "mono" then
      return PaletteFX.pal(data, "GRAYMON") or PaletteFX.GRAYS
    elseif style == "species_palette" or PaletteFX.mode == "ogred" then
      return PaletteFX.monPal(data, mon.species)
        or PaletteFX.pal(data, "BLUEMON")
    end
    local def = definition(menu, mon)
    local primary = def and def.types and def.types[1]
    return TYPE_COLORS[tostring(primary or "NORMAL"):upper()]
      or TYPE_COLORS.NORMAL
  end

  local function sgbPalettes(menu, game)
    local data = game and game.data
    if not data then return nil end
    local layout = layoutFor(menu)
    local base = PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON")
    if not base then return nil end

    local zones = { {
      colors = base, x = 0, y = 0, w = layout.width, h = SCREEN_H,
    } }
    local party = partyOf(menu)
    for i, mon in ipairs(party) do
      if i > DEFAULT_CAPACITY then break end
      local x, y, width, height = slotGeometry(layout, i)
      local palette = cardPalette(menu, mon)
      if palette then
        zones[#zones + 1] = {
          colors = palette, x = x, y = y, w = width, h = height,
        }
      end

      if not menu.tmhm then
        local hp = mon.hp or 0
        if menu.heal and menu.heal.mon == mon then hp = menu.heal.from end
        local maxHP = mon.stats and mon.stats.hp or math.max(1, hp)
        local bar = PaletteFX.pal(data, PaletteFX.barPalName(hp, maxHP))
        if bar then
          local hpY, _, barX, barW = meterGeometry(x, y, width, height)
          zones[#zones + 1] = {
            colors = bar, x = barX, y = hpY + 1,
            w = barW, h = 6,
          }
        end

        if setting("exp_strip", true) then
          local exp = PaletteFX.pal(data, "EXP")
            or PaletteFX.pal(data, "BLUEMON")
          if exp then
            local _, expY, barX, barW = meterGeometry(x, y, width, height)
            zones[#zones + 1] = {
              colors = exp, x = barX, y = expY + 1,
              w = barW, h = 6,
            }
          end
        end
      end
    end

    if menu.submenu then
      local x, y, w, h = submenuGeometry(menu, layout)
      zones[#zones + 1] = {
        colors = base,
        x = x, y = y, w = w, h = h,
      }
    end
    return zones
  end

  local function verticalTarget(index, direction, count, columns)
    local column = (index - 1) % columns
    local target = index + direction * columns
    if target >= 1 and target <= count then return target end
    if direction > 0 then
      target = column + 1
      return target <= count and target or index
    end
    target = count
    while target >= 1 and (target - 1) % columns ~= column do
      target = target - 1
    end
    return target >= 1 and target or index
  end

  local function gridTarget(index, direction, count, columns)
    if count <= 1 then return math.max(1, count) end
    local column = (index - 1) % columns
    if direction == "left" then
      return column > 0 and index - 1 or index
    elseif direction == "right" then
      return column < columns - 1 and index + 1 <= count and index + 1 or index
    elseif direction == "up" then
      return verticalTarget(index, -1, count, columns)
    elseif direction == "down" then
      return verticalTarget(index, 1, count, columns)
    end
    return index
  end

  local function update(menu, dt)
    local input = menu.game.input
    if menu.submenu or menu.heal or not (input and input.wasPressed) then
      return PartyMenu.update(menu, dt)
    end

    local direction
    for _, key in ipairs({ "left", "right", "up", "down" }) do
      if input:wasPressed(key) then direction = key break end
    end
    if not direction then return PartyMenu.update(menu, dt) end

    local party = partyOf(menu)
    if #party > 0 then
      menu.index = gridTarget(menu.index, direction, #party,
        layoutFor(menu).columns)
      menu.game.partyMenuSavedIndex = menu.index
    end

    -- The native controller still owns A/B, submenu actions and every picker
    -- mode. Mask only this frame's directional edge so it does not also apply
    -- the original one-dimensional movement after the grid has handled it.
    local original = input.wasPressed
    input.wasPressed = function(self, key)
      if key == "left" or key == "right" or key == "up" or key == "down" then
        return false
      end
      return original(self, key)
    end
    local ok, err = pcall(PartyMenu.update, menu, dt)
    input.wasPressed = original
    if not ok then error(err, 0) end
  end

  return {
    new = function(game, opts)
      local menu = PartyMenu.new(game, opts)
      menu.draw = draw
      menu.update = update
      menu.sgbPalettes = sgbPalettes
      menu.uiSize = uiSize
      menu.isWideBattleLayout = function()
        return setting("responsive", true)
      end
      menu.modernPartyUI = true
      menu.modernPartyLayout = "cards"
      return menu
    end,
  }
end
