-- Responsive card presentation for src.ui.PartyMenu.
--
-- Construction and actions still delegate to the engine controller. This
-- module adds a card-grid renderer and a thin navigation adapter; item use,
-- TM/HM checks, field moves, switching, healing and callbacks remain native.
return function(mod, genderExports, compatibility)
  compatibility = compatibility or {}
  local PartyMenu = require("src.ui.PartyMenu")
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")
  local Renderer = require("src.render.Renderer")
  local Theme = require("src.ui.Theme")

  local SCREEN_H = 144
  local HEADER_H = 16
  local DEFAULT_CAPACITY = 6
  local PORTRAIT_MIN_H = 224
  local PORTRAIT_MAX_H = 400

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
  local fittedHgssIcons = {}
  local cardPalette -- assigned after the draw helpers

  local function cardFaceColor(menu, mon, selected)
    if type(cardPalette) ~= "function" then return nil end
    local palette = cardPalette(menu, mon)
      or PaletteFX.pal(menu.game.data, "BLUEMON")
    local effective = PaletteFX.effectiveColors(palette)
    return effective and effective[selected and 2 or 3] or nil
  end

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

  local function responsiveWindowSize()
    if not setting("responsive", true) then return 160, SCREEN_H end
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H

    -- Match Modern Bag UI's portrait surface exactly. Both entry points then
    -- choose the same native canvas before either screen draws, eliminating
    -- the black void and the resize when the party picker is pushed or popped.
    local portraitScale = math.max(1, math.floor(width / 160))
    local portraitHeight = math.min(PORTRAIT_MAX_H,
      math.floor(height / portraitScale))
    if height >= width * 1.35 and portraitHeight >= PORTRAIT_MIN_H then
      return 160, portraitHeight
    end

    -- Pick a scale that the complete classic surface can actually fit.
    -- Height-only scaling collapses tall phones back to 160 pixels wide:
    -- e.g. 360x800 selected 5x, although only 2x fits horizontally. QoL
    -- Toggles' party scrolling exposed that bad fallback on every redraw.
    local scale = math.max(1, math.floor(math.min(
      width / Renderer.WIDTH, height / SCREEN_H)))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale))), SCREEN_H
  end

  -- Bag item use pushes PartyMenu above the responsive Bag surface. Keep
  -- that exact surface while the player chooses a target: otherwise the
  -- renderer changes from (for example) 160x330 back to 180x144 on a phone,
  -- making the party screen jump and exposing the previous frame beneath it.
  -- Only inherit from a Bag below this exact menu instance, so ordinary party,
  -- battle and summary screens keep their established responsive dimensions.
  local function parentBagSurface(menu)
    if not (setting("responsive", true) and type(menu) == "table") then
      return nil
    end
    local stack = menu.game and menu.game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return nil end

    local menuIndex
    for index = #states, 1, -1 do
      if states[index] == menu then
        menuIndex = index
        break
      end
    end
    if not menuIndex then return nil end

    for index = menuIndex - 1, 1, -1 do
      local candidate = states[index]
      if candidate and candidate.modernBagUI
          and type(candidate.uiSize) == "function" then
        local ok, width, height = pcall(candidate.uiSize, candidate)
        width, height = tonumber(width), tonumber(height)
        if ok and width and height and width >= 160 and height >= SCREEN_H then
          menu.modernPartyParentSurface = "modern_bag_ui"
          return math.floor(width), math.floor(height)
        end
      end
    end
    return nil
  end

  local function responsiveSize(menu)
    local width, height = parentBagSurface(menu)
    if width then return width, height end
    return responsiveWindowSize()
  end

  local function uiSize(menu)
    return responsiveSize(menu)
  end

  local function layoutFor(menu)
    local width, height = responsiveSize(menu)
    local renderer = menu and menu.game and menu.game.renderer
    if setting("responsive", true) and renderer and renderer.uiSize then
      local rendererW, rendererH = renderer:uiSize()
      width, height = rendererW or width, rendererH or height
    end
    width = math.max(160, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))
    -- Landscape and desktop keep the reference's two-column party. A tall
    -- phone stacks the six cards vertically no matter how the screen opened:
    -- this uses the extra height, gives names and meters the complete readable
    -- width, and keeps the experience stable between menu and Bag entry.
    local portrait = height >= 224 and height >= width * 1.35
    local columns = portrait and 1 or 2
    local capacity = math.min(DEFAULT_CAPACITY, capacityOf(menu))
    local rows = math.max(1, math.ceil(capacity / columns))
    local footerY = height - 8
    return {
      width = width,
      height = height,
      footerY = footerY,
      portrait = portrait,
      columns = columns,
      rows = rows,
      capacity = capacity,
      contentHeight = footerY - HEADER_H,
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

  local function stripGenderSuffix(text)
    text = tostring(text or "")
    if not genderExports then return text end
    -- Gender Mod strips the baked-in NIDORAN symbols while its classic
    -- renderer is active. Its screen wrapper is deliberately replaced here,
    -- so retain that presentation detail locally without mutating the mon.
    local plain = text:gsub("\226\153[\128\130]%s*$", "")
    if plain == text then plain = text:gsub("[♂♀]%s*$", "") end
    return plain
  end

  local function drawGenderGlyph(mon, x, y, background, trueColorRegions)
    if not (genderExports and type(genderExports.genderOf) == "function"
        and type(genderExports.symbol) == "function") then
      return 0
    end
    local okGender, gender = pcall(genderExports.genderOf, mon)
    if not okGender then return 0 end
    local okSymbol, symbol = pcall(genderExports.symbol, gender)
    if not okSymbol or type(symbol) ~= "string" or symbol == "" then return 0 end

    local color = { 0, 0, 0, 1 }
    if type(genderExports.palette) == "function" then
      local okPalette, exported = pcall(genderExports.palette, gender)
      if okPalette and type(exported) == "table" then color = exported end
    end

    x, y = math.floor(x), math.floor(y)
    love.graphics.push("all")
    -- True-colour regions are re-blitted without the card palette. Back only
    -- the glyph's native 8x8 cell: the former one-pixel safety frame read as
    -- a small recessed square on otherwise-flat party cards.
    if background then
      love.graphics.setColor(background[1] / 255, background[2] / 255,
        background[3] / 255, 1)
      love.graphics.rectangle("fill", x, y, 8, 8)
    end
    local shader = shaderForInk()
    if shader then love.graphics.setShader(shader) end
    love.graphics.setColor(color[1] or 0, color[2] or 0, color[3] or 0,
      color[4] or 1)
    Font.draw(symbol, x, y)
    love.graphics.pop()
    trueColorRegions[#trueColorRegions + 1] = {
      x = x, y = y, w = 8, h = 8,
    }
    return 9
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
    love.graphics.rectangle("fill", 0, 0, layout.width, layout.height)
    if setting("pattern", "grid") ~= "grid" then return end

    -- A restrained diagonal grid nods to the reference screen's hex field,
    -- but is still drawn from the Game Boy's four shades.
    gray(LIGHT)
    for x = -layout.height, layout.width, 16 do
      love.graphics.line(x, 0, x + layout.height, layout.height)
      love.graphics.line(x + layout.height, 0, x, layout.height)
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

  local function iconGeometry(x, y, width, height, iconSize)
    iconSize = math.max(1, math.floor(tonumber(iconSize) or 16))
    local hpY = meterGeometry(x, y, width, height)
    local left, top = x + 3, y + 3
    local availableW = contentInset(width) - 3
    local availableH = hpY - top
    return left + math.max(0, math.floor((availableW - iconSize) / 2)),
      top + math.max(0, math.floor((availableH - iconSize) / 2))
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

  -- Some companion mods replace PartyMenu.drawIcon and claim their own
  -- true-colour rectangle from inside that shared renderer. Collect those
  -- claims instead of publishing them immediately: the party action popup
  -- is drawn afterward, and a raw full-colour re-blit over a tall popup would
  -- turn the overlapping menu pixels back into unshaded grey blocks. All
  -- icon claims are published together after the popup's real bounds are
  -- known, through markTrueColorOutside below.
  local function drawIconCollectingTrueColor(menu, mon, x, y, selected,
      counter, regions, background, iconScale, opaqueRuns)
    local scale = tonumber(iconScale) or 1
    local originalMark = PaletteFX.markTrueColor
    PaletteFX.markTrueColor = function(rx, ry, rw, rh)
      rx, ry, rw, rh = tonumber(rx), tonumber(ry), tonumber(rw), tonumber(rh)
      if opaqueRuns then
        for _, run in ipairs(opaqueRuns) do
          regions[#regions + 1] = {
            x = x + run.x * scale, y = y + run.y * scale,
            w = math.max(1, run.w * scale), h = math.max(1, scale),
          }
        end
      elseif rx and ry and rw and rh and rw > 0 and rh > 0 then
        regions[#regions + 1] = {
          x = x + (rx - x) * scale,
          y = y + (ry - y) * scale,
          w = rw * scale,
          h = rh * scale,
        }
        if background then
          love.graphics.setColor(background[1] / 255,
            background[2] / 255, background[3] / 255, 1)
          love.graphics.rectangle("fill", rx, ry, rw, rh)
        end
      end
    end

    local result
    -- The production mod sandbox intentionally does not expose Lua's debug
    -- library. pcall still guarantees that markTrueColor is restored before
    -- we rethrow an icon-mod failure, without depending on debug.traceback.
    love.graphics.push("all")
    if scale ~= 1 then
      love.graphics.translate(x, y)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-x, -y)
    end
    local ok, err = pcall(function()
      result = PartyMenu.drawIcon(menu.game, mon, x, y, selected, counter)
    end)
    love.graphics.pop()
    PaletteFX.markTrueColor = originalMark
    if not ok then error(err, 0) end
    return result
  end

  local function drawFittedHgssIcon(menu, mon, entry, x, y, animate,
      counter, target, regions)
    if not (love.image and love.image.newImageData
        and love.graphics.newQuad) then return false end
    local path = Sprites.iconPath(menu.game.data, mon, entry.image, {})
    if type(path) ~= "string" then return false end
    local cached = fittedHgssIcons[path]
    if cached == nil then
      local okData, data = pcall(Assets.imageData, path)
      local okImage, image = pcall(Assets.image, path)
      if not okData or not data or not okImage or not image then
        fittedHgssIcons[path] = false
      else
        local iw, ih = data:getDimensions()
        local rawFrames = {}
        for frame = 0, math.min(1, math.floor(ih / 32) - 1) do
          local minX, minY, maxX, maxY = 32, 32, -1, -1
          local runs = {}
          for py = 0, math.min(31, ih - frame * 32 - 1) do
            local start
            for px = 0, math.min(31, iw - 1) do
              local _, _, _, alpha = data:getPixel(px, frame * 32 + py)
              local opaque = (alpha or 0) > 0.01
              if opaque then
                minX, minY = math.min(minX, px), math.min(minY, py)
                maxX, maxY = math.max(maxX, px), math.max(maxY, py)
              end
              if opaque and not start then start = px end
              if start and (not opaque or px == math.min(31, iw - 1)) then
                local finish = opaque and px or px - 1
                runs[#runs + 1] = { x = start, y = py,
                  w = finish - start + 1 }
                start = nil
              end
            end
          end
          if maxX >= minX and maxY >= minY then
            rawFrames[frame] = { minX = minX, minY = minY,
              maxX = maxX, maxY = maxY, runs = runs }
          end
        end
        -- HGSS authors animate many icons by shifting the opaque pixels one
        -- row inside an otherwise identical 32x32 frame. Use one crop for
        -- both frames so that fitting/centring does not cancel that motion.
        local unionMinX, unionMinY, unionMaxX, unionMaxY
        for _, raw in pairs(rawFrames) do
          unionMinX = unionMinX and math.min(unionMinX, raw.minX) or raw.minX
          unionMinY = unionMinY and math.min(unionMinY, raw.minY) or raw.minY
          unionMaxX = unionMaxX and math.max(unionMaxX, raw.maxX) or raw.maxX
          unionMaxY = unionMaxY and math.max(unionMaxY, raw.maxY) or raw.maxY
        end
        local frames = {}
        if unionMinX then
          for frame, raw in pairs(rawFrames) do
            frames[frame] = {
              x = unionMinX, y = frame * 32 + unionMinY,
              w = unionMaxX - unionMinX + 1,
              h = unionMaxY - unionMinY + 1,
              runs = raw.runs,
            }
          end
        end
        cached = { image = image, iw = iw, ih = ih, frames = frames }
        fittedHgssIcons[path] = cached
      end
    end
    if not cached then return false end
    local alt = false
    if animate then
      local maxHP = mon.stats and mon.stats.hp or 1
      local hpPixels = math.floor((mon.hp or 0) * 48 / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      alt = math.floor((counter or 0) / speed) % 2 == 1
    end
    local bounds = cached.frames[alt and 1 or 0] or cached.frames[0]
    if not bounds then return false end

    -- Fit the visible creature, not HGSS's transparent 32px source canvas.
    -- The authored art is deliberately compact inside that canvas, which is
    -- why merely drawing the source at 32px still looked tiny.
    local fittedScale = math.min(target / bounds.w, target / bounds.h)
    local drawW, drawH = bounds.w * fittedScale, bounds.h * fittedScale
    local drawX = math.floor(x + (target - drawW) / 2 + 0.5)
    local drawY = math.floor(y + (target - drawH) / 2 + 0.5)
    local quad = love.graphics.newQuad(bounds.x, bounds.y,
      bounds.w, bounds.h, cached.iw, cached.ih)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cached.image, quad, drawX, drawY, 0,
      fittedScale, fittedScale)
    love.graphics.pop()
    for _, run in ipairs(bounds.runs or {}) do
      regions[#regions + 1] = {
        x = drawX + (run.x - bounds.x) * fittedScale,
        y = drawY + (run.y - (bounds.y % 32)) * fittedScale,
        w = math.max(1, run.w * fittedScale),
        h = math.max(1, fittedScale),
      }
    end
    return true
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
    local hgssIcon = false
    if type(entry) == "table" then
      local path = tostring(entry.image or ""):lower()
      -- Unique Menu Icons 1.5.0 renamed these folders from icons_* to
      -- icon_*.  ORIGINAL is deliberately palette-driven in both layouts;
      -- treating the new singular path as authored true colour preserves
      -- its literal grayscale pixels and is what made those icons look gray.
      local paletteAware = path:find("icons_original", 1, true) ~= nil
        or path:find("icon_original", 1, true) ~= nil
      trueColorIcon = not paletteAware
        or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
      hgssIcon = compatibility.hgssSprites and entry.trueColor == true
        and path:find("assets/icons/", 1, true) ~= nil
        and path:find("hgss", 1, true) ~= nil
    end

    -- Fit HGSS's visible creature into this rail. Its 32px source frame has
    -- substantial transparent padding, so scaling the complete frame leaves
    -- the actual sprite much smaller than the available card space.
    local iconSize = hgssIcon and (spacious and 32 or 22) or 16
    local iconScale = hgssIcon and iconSize / 32 or 1
    local iconX, iconY = iconGeometry(x, y, width, height, iconSize)
    local textX = math.max(x + contentInset(width), iconX + iconSize + 2)

    -- A true-colour zone restores the complete icon canvas rectangle, not
    -- just the icon's opaque pixels. Paint the card's final display colour
    -- behind the transparent pixels first, so that restore cannot reveal the
    -- raw gray pre-palette card as a square backplate.
    if trueColorIcon and not hgssIcon then
      local background = cardFaceColor(menu, mon, selected)
      if background then
        love.graphics.setColor(background[1] / 255, background[2] / 255,
          background[3] / 255, 1)
        love.graphics.rectangle("fill", iconX - 1, iconY - 1,
          iconSize + 2, iconSize + 2)
      end
    end

    gray(WHITE)
    -- Keep the roster calm and make focus immediately readable: the shared
    -- animation setting enables movement, while selection decides which one
    -- of the visible cards is allowed to advance beyond its resting frame.
    local regionCount = #trueColorIcons
    local animate = setting("animate_icons", true) and selected
    local fitted = hgssIcon and drawFittedHgssIcon(menu, mon, entry,
      iconX, iconY, animate, menu.blink or 0, iconSize, trueColorIcons)
    if not fitted then
      drawIconCollectingTrueColor(menu, mon, iconX, iconY,
        animate, menu.blink or 0, trueColorIcons,
        hgssIcon and nil or cardFaceColor(menu, mon, selected),
        iconScale)
    end
    -- Renderers such as HGSS publish their exact transformed rectangle from
    -- inside PartyMenu.drawIcon. Only add the generic safety rectangle when
    -- a true-colour renderer did not claim one itself.
    if trueColorIcon and #trueColorIcons == regionCount then
      trueColorIcons[#trueColorIcons + 1] = {
        x = iconX - 1, y = iconY - 1,
        w = iconSize + 2, h = iconSize + 2,
      }
    end

    drawText(stripGenderSuffix(
        mon.nickname or def.name or mon.species or "?"),
      textX, nameY, x + width - 5 - textX, 1, ink)
    local level = tostring(math.max(1, tonumber(mon.level) or 1))
    local levelText = (spacious and "LV" or "L") .. level
    local genderWidth = drawGenderGlyph(mon, textX, detailY,
      cardFaceColor(menu, mon, selected), trueColorIcons)
    -- Gender occupies its own eight-pixel cell. On the smallest wide cards,
    -- the previous percentage allotment was one pixel narrower than "LV12"
    -- after that cell was removed, so fitText displayed every two-digit level
    -- as "LV1". The save data was intact; only the final glyph was clipped.
    -- Always reserve at least the native width of the complete level label.
    local levelWidth = math.max(Font.width(levelText),
      math.floor(math.max(24, width * 0.33) - genderWidth))
    drawText(levelText,
      textX + genderWidth, detailY,
      levelWidth, 1, ink)

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
    love.graphics.rectangle("fill", 0, layout.footerY, layout.width, 8)
    local text = footerText(menu, party)
    local maxWidth = layout.width - 8
    text = fitText(text, maxWidth)
    local width = Font.width(text)
    drawText(text, (layout.width - width) / 2, layout.footerY,
      maxWidth, 1, WHITE)
  end

  local function submenuGeometry(menu, layout)
    local count = math.max(1, #(menu.subItems or {}))
    local height = 16 + count * 12
    local width = math.min(120, layout.width - 16)
    return math.floor((layout.width - width) / 2),
      math.floor((layout.footerY - height) / 16) * 8, width, height
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
      colors = base, x = 0, y = 0, w = layout.width, h = layout.height,
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
      menu.modernPartyLayoutInfo = function() return layoutFor(menu) end
      return menu
    end,
  }
end
