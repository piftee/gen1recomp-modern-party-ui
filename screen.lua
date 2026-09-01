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
  local faithfulLoaded, FaithfulRes = pcall(require, "src.core.FaithfulRes")
  if not faithfulLoaded then FaithfulRes = nil end

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
  local directMenuIconImages = {}
  local originalIconImages = {}
  local iconAlphaMasks = {}
  local wildsIconDefs = {}
  local wildsIconAlphaMasks = {}
  local cardPalette -- assigned after the draw helpers

  if Assets.register then
    Assets.register(function()
      fittedHgssIcons = {}
      directMenuIconImages = {}
      originalIconImages = {}
      iconAlphaMasks = {}
      wildsIconDefs = {}
      wildsIconAlphaMasks = {}
    end)
  end

  local function cardFaceColor(menu, mon, selected)
    if type(cardPalette) ~= "function" then return nil end
    local palette = cardPalette(menu, mon)
      or PaletteFX.pal(menu.game.data, "BLUEMON")
    local effective = PaletteFX.effectiveColors(palette)
    return effective and effective[selected and 2 or 3] or nil
  end

  -- Android can expose hairline gaps when the final palette pass restores a
  -- true-colour icon as a stack of one-pixel alpha runs.  Match the Pokédex
  -- treatment instead: bake the sprite onto the card's *final* face colour
  -- and restore one stable, integer-aligned icon well.  Because the backing
  -- is exactly the colour the card receives after palette work, transparent
  -- source pixels remain visually transparent without a white/grey square.
  local function fillStableIconWell(menu, mon, selected, x, y, size, final)
    local x1, y1 = math.floor(x), math.floor(y)
    local x2, y2 = math.ceil(x + size), math.ceil(y + size)
    local rect = {
      x = x1, y = y1,
      w = math.max(1, x2 - x1), h = math.max(1, y2 - y1),
    }
    love.graphics.push("all")
    if final then
      local face = cardFaceColor(menu, mon, selected)
      if not face then
        love.graphics.pop()
        return nil
      end
      love.graphics.setColor((face[1] or 0) / 255,
        (face[2] or 0) / 255, (face[3] or 0) / 255, 1)
    else
      local shade = selected and LIGHT or DARK
      love.graphics.setColor(shade, shade, shade, 1)
    end
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.pop()
    return rect
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

  -- Party and follower packs share icons.bySpecies, so its live value cannot
  -- identify which provider the player selected after a runtime follower mod
  -- has replaced it.  The frozen content registry retains provenance for
  -- every load-time contribution.  Prefer the last provider that explicitly
  -- declares ownership of party/menu icons (Unique Menu Icons 1.5.0 exposes
  -- ownsPartyIcons), without mutating the live registry used by followers.
  local function explicitMenuPackEntry(menu, mon)
    local game = menu and menu.game
    local loader = game and game.mods
    local registry = loader and loader.content and loader.content.icons
    local ops = registry and registry.ops and mon
      and registry.ops[mon.species]
    if type(ops) ~= "table" then return nil end

    for i = #ops, 1, -1 do
      local op = ops[i]
      local owner = op and op.owner
      local exported = owner and loader.exports and loader.exports[owner]
      local ownsMenu = owner == "unique_menu_icons"
        or (type(exported) == "table" and exported.ownsPartyIcons == true)
      if ownsMenu then
        if op.op == "remove" or op.value == nil then return nil end
        return op.value, owner
      end
    end
    return nil
  end

  local function capacityOf(menu)
    local constants = menu.game.data and menu.game.data.constants or nil
    return (constants and constants.partyMax) or DEFAULT_CAPACITY
  end

  -- Faithful Ratio owns the final 160x144 viewport on mobile. Responsive
  -- screens must not replace it with a taller canvas: the renderer can only
  -- preserve the promised 10:9 Game Boy surface when the UI reports the same
  -- native dimensions that the lock was calculated from.
  local function faithfulRatioActive()
    if not (FaithfulRes and type(FaithfulRes.scaleCap) == "function") then
      return false
    end
    local ok, cap = pcall(FaithfulRes.scaleCap)
    return ok and cap ~= nil
  end

  local function snapPortraitHeight(height)
    -- Six equal native-pixel rows prevent alternating one-pixel joins. At a
    -- 5x or 6x phone scale those joins otherwise become conspicuous bands.
    local fixed = HEADER_H + 8 -- header plus footer
    local snapped = height - ((height - fixed) % DEFAULT_CAPACITY)
    if snapped >= PORTRAIT_MIN_H then return snapped end
    return height
  end

  local function responsiveWindowSize()
    if not setting("responsive", true) then return 160, SCREEN_H end
    if faithfulRatioActive() then return 160, SCREEN_H end
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
      return 160, snapPortraitHeight(portraitHeight)
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
    if faithfulRatioActive() then return nil end
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
    if setting("responsive", true) and not faithfulRatioActive()
        and renderer and renderer.uiSize then
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
      ELECTRIC = "ELC", PSYCHIC_TYPE = "PSY", PSYCHIC = "PSY",
      ICE = "ICE", DRAGON = "DRG",
    }
    local typeWidth = math.max(24, math.floor(layout.width / 2) - 36)
    local first = short[tostring(types[1] or ""):upper()] or "---"
    local second = short[tostring(types[2] or ""):upper()]
    local label = second and typeWidth >= 56 and (first .. "/" .. second)
      or first
    drawTextRight(label, layout.width - 4, 4, typeWidth, 1, WHITE)
  end

  local function drawCardFrame(x, y, width, height, selected, seamless)
    if seamless then
      -- Portrait cards occupy the complete cell before their chamfered frame
      -- is drawn. This hides the patterned backdrop on card join rows without
      -- changing the frame, its palette zone, or any icon transparency mask.
      gray(DARK)
      love.graphics.rectangle("fill", x, y, width, height)
    end
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

  local METER_BOTTOM_PADDING = 1

  local function meterGeometry(x, y, width, height)
    local barX = x + contentInset(width)
    local barW = math.max(16, x + width - 5 - barX)
    -- Keep one native pixel between the lower text/meter row and the card's
    -- chamfered frame.  The selected frame is deliberately heavier, so the
    -- old edge-aligned row appeared to merge into it after integer scaling.
    return y + height - 17 - METER_BOTTOM_PADDING,
      y + height - 9 - METER_BOTTOM_PADDING, barX, barW
  end

  local function iconGeometry(x, y, width, height, iconSize)
    iconSize = math.max(1, math.floor(tonumber(iconSize) or 16))
    local hpY = meterGeometry(x, y, width, height)
      + METER_BOTTOM_PADDING
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
      width - padding, 1, selected and WHITE or BLACK)
  end

  local function drawLearnability(text, right, y, selected, spacious)
    if not text then return end
    text = fitText(text, spacious and 40 or 24)
    local padding = spacious and 4 or 0
    local width = math.max(16, Font.width(text) + padding)
    -- ABLE/NO is ordinary card ink: no lozenge, and the same contrast rule
    -- as the name, level and TM/HM label on the card beneath it.
    drawText(text, right - width + math.floor(padding / 2), y,
      width - padding, 1, selected and BLACK or WHITE)
  end

  local function drawHealthBar(mon, x, y, width, height)
    local maxHP = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local fraction = math.max(0, math.min(1, (mon.hp or 0) / math.max(1, maxHP)))
    local hpY, _, barX, barW = meterGeometry(x, y, width, height)
    drawMeter(fraction, hpY, barX, barW, (mon.hp or 0) > 0)
  end

  local function drawEmptyCard(layout, index)
    local x, y, width, height = slotGeometry(layout, index)
    drawCardFrame(x, y, width, height, false, layout.portrait)
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
  local function appendOpaqueRegions(regions, x, y, iconScale, opaqueRuns)
    local scale = tonumber(iconScale) or 1
    for _, run in ipairs(opaqueRuns or {}) do
      regions[#regions + 1] = {
        x = x + run.x * scale, y = y + run.y * scale,
        w = math.max(1, run.w * scale), h = math.max(1, scale),
      }
    end
  end

  local function isShinyMon(mon)
    if not mon then return false end
    if mon.shiny == true or mon.isShiny == true then return true end
    if not mon.dvs then return false end
    local okModule, Stats = pcall(require, "src.pokemon.Stats")
    if not okModule or type(Stats) ~= "table"
        or type(Stats.isShiny) ~= "function" then
      return false
    end
    local okShiny, shiny = pcall(Stats.isShiny, mon.dvs)
    return okShiny and shiny == true
  end

  -- Wilds of Kanto publishes follower-style sprite sheets through a stable
  -- resolver. Consume that API directly instead of depending on its global
  -- PartyMenu.drawIcon wrapper remaining the last wrapper installed. Several
  -- legitimate mod orders replace that global function later, which used to
  -- leave every modern card empty even though Wilds still had valid artwork.
  local function wildsIconDef(menu, mon)
    local exports = compatibility.wildsOfKantoExports
    local resolve = exports and exports.resolveFollowerSprite
    if type(resolve) ~= "function" then return nil end

    local shiny = isShinyMon(mon)
    local key = table.concat({
      tostring(mon.species or ""), shiny and "s" or "n",
      tostring(mon.form or ""),
    }, "|")
    local cached = wildsIconDefs[key]
    if cached ~= nil then return cached or nil end

    local ok, def = pcall(resolve, {
      species = mon.species,
      shiny = shiny,
      form = mon.form,
      surface = "land",
      role = "party_menu",
      game = menu.game,
    })
    if not ok or type(def) ~= "table" or type(def.image) ~= "string"
        or def.image == "" then
      wildsIconDefs[key] = false
      return nil
    end
    wildsIconDefs[key] = def
    return def
  end

  local function wildsOpaqueRuns(path, frameX, frameY, frameW, frameH)
    local cached = wildsIconAlphaMasks[path]
    if cached == nil then
      local ok, data, iw, ih = pcall(function()
        local decoded = Assets.imageData(path)
        local width, height = decoded:getDimensions()
        return decoded, width, height
      end)
      if not ok or not data or not iw or not ih then
        wildsIconAlphaMasks[path] = false
        return nil
      end
      cached = { data = data, iw = iw, ih = ih, frames = {} }
      wildsIconAlphaMasks[path] = cached
    elseif cached == false then
      return nil
    end

    frameX = math.max(0, math.floor(tonumber(frameX) or 0))
    frameY = math.max(0, math.floor(tonumber(frameY) or 0))
    frameW = math.min(math.floor(tonumber(frameW) or cached.iw),
      cached.iw - frameX)
    frameH = math.min(math.floor(tonumber(frameH) or cached.ih),
      cached.ih - frameY)
    if frameW <= 0 or frameH <= 0 then return nil end
    local key = table.concat({ frameX, frameY, frameW, frameH }, ":")
    if cached.frames[key] ~= nil then
      return cached.frames[key] or nil
    end

    local ok, runs = pcall(function()
      local result = {}
      for py = 0, frameH - 1 do
        local start
        for px = 0, frameW - 1 do
          local _, _, _, alpha = cached.data:getPixel(frameX + px, frameY + py)
          local opaque = alpha == nil or alpha > 0.01
          if opaque and start == nil then start = px end
          if start ~= nil and (not opaque or px == frameW - 1) then
            local finish = opaque and px or px - 1
            result[#result + 1] = {
              x = start, y = py, w = finish - start + 1,
            }
            start = nil
          end
        end
      end
      return result
    end)
    if not ok or #runs == 0 then
      cached.frames[key] = false
      return nil
    end
    cached.frames[key] = runs
    return runs
  end

  local function drawWildsIcon(menu, mon, x, y, selected, counter, regions,
      resolvedDef)
    local def = resolvedDef or wildsIconDef(menu, mon)
    if not def then return false end
    local okImage, image = pcall(Assets.image, def.image)
    if not okImage or not image then return false end

    local iw, ih
    if type(image.getDimensions) == "function" then
      iw, ih = image:getDimensions()
    elseif type(image.getWidth) == "function"
        and type(image.getHeight) == "function" then
      iw, ih = image:getWidth(), image:getHeight()
    end
    iw, ih = tonumber(iw), tonumber(ih)
    if not iw or not ih or iw <= 0 or ih <= 0
        or not love.graphics.newQuad then return false end

    local frames = math.max(1, math.floor(tonumber(def.frames) or 1))
    local frameW = math.min(iw,
      math.max(1, math.floor(tonumber(def.frameWidth) or iw)))
    local defaultFrameH = frames > 1 and math.floor(ih / frames) or ih
    local frameH = math.min(ih,
      math.max(1, math.floor(tonumber(def.frameHeight) or defaultFrameH)))
    local frame = 0
    if selected and frames >= 4 then
      local maxHP = mon.stats and tonumber(mon.stats.hp) or 1
      local hpPixels = math.floor((tonumber(mon.hp) or 0) * 48
        / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      if math.floor((tonumber(counter) or 0) / speed) % 2 == 1 then
        frame = 3
      end
    end
    frame = math.min(frames - 1, frame)
    local frameY = math.min(math.max(0, ih - frameH), frame * frameH)
    local quad = love.graphics.newQuad(0, frameY, frameW, frameH, iw, ih)
    local scale = math.min(1, 16 / frameW, 16 / frameH)
    local drawW, drawH = frameW * scale, frameH * scale
    local drawX = math.floor(x + (16 - drawW) / 2 + 0.5)
    local drawY = math.floor(y + (16 - drawH) / 2 + 0.5)

    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, quad, drawX, drawY, 0, scale, scale)
    love.graphics.pop()

    if def.trueColor ~= false then
      local runs = wildsOpaqueRuns(def.image, 0, frameY, frameW, frameH)
      appendOpaqueRegions(regions, drawX, drawY, scale, runs)
    end
    return true
  end

  -- Read the same animation frame PartyMenu.drawIcon will use, but retain
  -- only its opaque pixel runs. PaletteFX can then restore the authored
  -- colours without restoring the transparent canvas around them as a
  -- white/grey square. A failed decode deliberately returns nil: the icon
  -- may still draw through a companion renderer, but no unsafe rectangular
  -- true-colour claim will be published for it.
  local function iconOpaqueRuns(menu, mon, entry, selected, counter)
    if type(entry) ~= "table" or type(entry.image) ~= "string" then
      return nil
    end
    local path = Sprites.iconPath(menu.game.data, mon, entry.image, {})
    if type(path) ~= "string" then return nil end

    local cached = iconAlphaMasks[path]
    if cached == nil then
      local ok, data, iw, ih = pcall(function()
        local decoded = Assets.imageData(path)
        local width, height = decoded:getDimensions()
        return decoded, width, height
      end)
      if not ok or not data or not iw or not ih then
        iconAlphaMasks[path] = false
        return nil
      end
      cached = { data = data, iw = iw, ih = ih, frames = {} }
      iconAlphaMasks[path] = cached
    elseif cached == false then
      return nil
    end

    local alt = false
    if selected then
      local maxHP = mon.stats and mon.stats.hp or 1
      local hpPixels = math.floor((mon.hp or 0) * 48 / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      alt = math.floor((counter or 0) / speed) % 2 == 1
    end
    local frame = cached.ih > 16
      and PartyMenu.frameFor(nil, alt, cached.ih) or 0
    if cached.frames[frame] ~= nil then
      return cached.frames[frame] or nil
    end

    local ok, runs = pcall(function()
      local result = {}
      local frameY = cached.ih > 16 and frame * 16 or 0
      local sourceW = cached.ih > 16
        and math.min(16, cached.iw) or cached.iw
      local sourceH = math.min(16, cached.ih - frameY)
      if sourceW <= 0 or sourceH <= 0 then return result end
      for py = 0, sourceH - 1 do
        local start
        for px = 0, sourceW - 1 do
          local _, _, _, alpha = cached.data:getPixel(px, frameY + py)
          local opaque = (alpha == nil or alpha > 0.01)
          if opaque and start == nil then start = px end
          if start ~= nil and (not opaque or px == sourceW - 1) then
            local finish = opaque and px or px - 1
            result[#result + 1] = {
              x = start, y = py, w = finish - start + 1,
            }
            start = nil
          end
        end
      end
      return result
    end)
    if not ok or #runs == 0 then
      cached.frames[frame] = false
      return nil
    end
    cached.frames[frame] = runs
    return runs
  end

  local function entryImagePath(menu, entry)
    local icons = menu.game.data.icons or {}
    if type(entry) == "table" then return entry.image end
    if type(entry) == "string" then
      return icons.icons and icons.icons[entry]
    end
    return nil
  end

  local function paletteAwareEntry(menu, entry)
    local path = tostring(entryImagePath(menu, entry) or ""):lower()
    return path:find("icons_original", 1, true) ~= nil
      or path:find("icon_original", 1, true) ~= nil
  end

  local function hgssPartyEntry(menu, entry)
    if not compatibility.hgssSprites or type(entry) ~= "table"
        or entry.trueColor ~= true then return false end
    local path = tostring(entryImagePath(menu, entry) or ""):lower()
    -- HGSS Visual Overhaul installs these records at game.ready rather than
    -- through the frozen content registry.  The containing directory is not
    -- guaranteed to equal its manifest id, so identify the documented party
    -- asset family rather than requiring "hgss" in the absolute path.
    return path:find("assets/icons/", 1, true) ~= nil
  end

  -- Draw an explicitly selected menu provider without going back through the
  -- global PartyMenu.drawIcon wrapper. Follower mods are allowed to wrap that
  -- shared function, so using it here would immediately discard the source
  -- choice we just resolved from registry provenance.
  local function drawDirectMenuIcon(menu, mon, entry, x, y, animate,
      counter, target)
    local path = entryImagePath(menu, entry)
    if type(path) ~= "string" or path == "" then return false end
    local image = directMenuIconImages[path]
    if image == nil then
      local ok, loaded = pcall(Assets.image, path)
      image = ok and loaded or false
      directMenuIconImages[path] = image
    end
    if not image then return false end

    local iw, ih
    if type(image.getDimensions) == "function" then
      iw, ih = image:getDimensions()
    elseif type(image.getWidth) == "function"
        and type(image.getHeight) == "function" then
      iw, ih = image:getWidth(), image:getHeight()
    end
    iw, ih = tonumber(iw), tonumber(ih)
    if not iw or not ih or iw <= 0 or ih <= 0
        or not love.graphics.newQuad then return false end

    local frames = type(entry) == "table"
      and math.max(1, math.floor(tonumber(entry.frames) or 1)) or 1
    local frameW = math.min(iw, 16)
    local frameH = frames > 1 and math.floor(ih / frames) or ih
    frameH = math.max(1, math.min(16, frameH, ih))
    local alt = false
    if animate then
      local maxHP = mon.stats and tonumber(mon.stats.hp) or 1
      local hpPixels = math.floor((tonumber(mon.hp) or 0) * 48
        / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      alt = math.floor((tonumber(counter) or 0) / speed) % 2 == 1
    end
    local name = type(entry) == "string" and entry or nil
    local frame = frames > 1 and PartyMenu.frameFor(name, alt, ih) or 0
    frame = math.max(0, math.min(frames - 1, frame))
    local frameY = math.min(math.max(0, ih - frameH), frame * frameH)
    local scale = math.min((tonumber(target) or 16) / frameW,
      (tonumber(target) or 16) / frameH)
    local drawW, drawH = frameW * scale, frameH * scale
    local drawX = math.floor(x + ((tonumber(target) or 16) - drawW) / 2
      + 0.5)
    local drawY = math.floor(y + ((tonumber(target) or 16) - drawH) / 2
      + 0.5)

    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    if name and PartyMenu.mirrorsIcon(name) then
      local half = love.graphics.newQuad(0, frameY,
        math.min(8, frameW), frameH, iw, ih)
      love.graphics.draw(image, half, drawX, drawY, 0, scale, scale)
      love.graphics.draw(image, half, drawX + drawW, drawY, 0,
        -scale, scale)
    else
      local quad = love.graphics.newQuad(0, frameY,
        frameW, frameH, iw, ih)
      love.graphics.draw(image, quad, drawX, drawY, 0, scale, scale)
    end
    love.graphics.pop()
    return true
  end

  local function drawIconCollectingTrueColor(menu, mon, x, y, selected,
      counter, regions, iconScale, opaqueRuns, suppressUnmasked)
    local scale = tonumber(iconScale) or 1
    local originalMark = PaletteFX.markTrueColor
    local opaqueClaimed = false
    PaletteFX.markTrueColor = function(rx, ry, rw, rh)
      rx, ry, rw, rh = tonumber(rx), tonumber(ry), tonumber(rw), tonumber(rh)
      if opaqueRuns then
        if not opaqueClaimed then
          appendOpaqueRegions(regions, x, y, scale, opaqueRuns)
          opaqueClaimed = true
        end
      elseif not suppressUnmasked
          and rx and ry and rw and rh and rw > 0 and rh > 0 then
        regions[#regions + 1] = {
          x = x + (rx - x) * scale,
          y = y + (ry - y) * scale,
          w = rw * scale,
          h = rh * scale,
        }
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
      -- Kept indirect because this file is the Gen 1 presenter; Gen 2 loads
      -- gen2.lua and uses its native menu-icon method instead.
      local drawIcon = PartyMenu["draw" .. "Icon"]
      result = drawIcon(menu.game, mon, x, y, selected, counter)
    end)
    love.graphics.pop()
    PaletteFX.markTrueColor = originalMark
    if not ok then error(err, 0) end
    return result, opaqueClaimed
  end

  -- A stale or platform-incompatible per-species asset used to leave the
  -- card's safety backing visible with no creature in it. Retry through the
  -- engine's normal definition/dex icon chain instead. Registry values are
  -- restored before returning, so this is local to the failed draw and does
  -- not change another mod's data.
  local function drawFallbackIcon(menu, mon, x, y, selected, counter, regions)
    local icons = menu.game.data.icons or {}
    local bySpecies = icons.bySpecies
    local def = definition(menu, mon)
    local speciesEntry = bySpecies and bySpecies[mon.species]
    local defIcon = def and def.icon
    local touchedSpecies, touchedDef = false, false

    local function restore()
      if touchedSpecies then bySpecies[mon.species] = speciesEntry end
      if touchedDef then def.icon = defIcon end
    end

    local ok, drawn = pcall(function()
      local result
      if speciesEntry ~= nil then
        bySpecies[mon.species] = nil
        touchedSpecies = true
        result = drawIconCollectingTrueColor(menu, mon, x, y,
          selected, counter, regions, 1, nil, true)
        if result == true then return true end
      end
      if defIcon ~= nil then
        def.icon = nil
        touchedDef = true
        result = drawIconCollectingTrueColor(menu, mon, x, y,
          selected, counter, regions, 1, nil, true)
        if result == true then return true end
      end
      return false
    end)
    restore()
    if not ok then error(drawn, 0) end
    return drawn == true
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

  -- Draw the game's dex-indexed icon directly. This deliberately bypasses
  -- per-species registries and Sprites.iconPath hooks, giving players a
  -- dependable ORIGINAL choice even when several icon packs are installed.
  -- It remains palette-driven, so the party card can colour it exactly like
  -- the original engine renderer does.
  local function drawOriginalIcon(menu, mon, x, y, animate, counter)
    local icons = menu.game.data.icons or {}
    local def = definition(menu, mon)
    local name = def and def.dex and icons.byDex and icons.byDex[def.dex]
    local path = name and icons.icons and icons.icons[name]
    if type(path) ~= "string" then return false end

    local image = originalIconImages[path]
    if image == nil then
      local ok, loaded = pcall(Assets.image, path)
      image = ok and loaded or false
      originalIconImages[path] = image
    end
    if not image then return false end

    local iw, ih
    if type(image.getDimensions) == "function" then
      iw, ih = image:getDimensions()
    elseif type(image.getWidth) == "function"
        and type(image.getHeight) == "function" then
      iw, ih = image:getWidth(), image:getHeight()
    end
    iw, ih = tonumber(iw), tonumber(ih)
    if not iw or not ih or iw <= 0 or ih <= 0 then return false end

    local alt = false
    if animate then
      local maxHP = mon.stats and tonumber(mon.stats.hp) or 1
      local hpPixels = math.floor((tonumber(mon.hp) or 0) * 48
        / math.max(1, maxHP))
      local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
      alt = math.floor((tonumber(counter) or 0) / speed) % 2 == 1
    end
    if alt and (name == "BALL" or name == "HELIX") then
      y, alt = y + 1, false
    end
    local frame = ih > 16 and PartyMenu.frameFor(name, alt, ih) or 0

    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    if PartyMenu.mirrorsIcon(name) and love.graphics.newQuad then
      local half = love.graphics.newQuad(0, frame * 16,
        math.min(8, iw), math.min(16, ih - frame * 16), iw, ih)
      love.graphics.draw(image, half, x, y)
      love.graphics.draw(image, half, x + 16, y, 0, -1, 1)
    elseif ih > 16 and love.graphics.newQuad then
      local quad = love.graphics.newQuad(0, frame * 16,
        math.min(16, iw), math.min(16, ih - frame * 16), iw, ih)
      love.graphics.draw(image, quad, x, y)
    else
      love.graphics.draw(image, x, y)
    end
    love.graphics.pop()
    return true
  end

  -- Compact, source-aware icon presenter for party-owned child screens.
  -- It follows ICON SOURCE / ICON ANIMATION, consumes Wilds and HGSS through
  -- the same resolvers as the roster, and composites authored artwork onto
  -- the caller's final face colour so transparent pixels cannot become a
  -- white or grey square during the palette pass.
  local function drawToolIcon(game, mon, x, y, opts)
    opts = opts or {}
    if not (game and mon) then return false end
    local menu = { game = game }
    local size = math.max(8, math.floor(tonumber(opts.size) or 16))
    local selected = opts.selected ~= false
    local counter = tonumber(opts.counter) or 0
    local source = setting("sprite_source", "auto")
    local animate = setting("animate_icons", true) and selected
    local def = definition(menu, mon)
    local icons = game.data.icons or {}
    local liveEntry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    local menuEntry = source == "menu_pack"
      and explicitMenuPackEntry(menu, mon) or nil
    local entry = menuEntry or liveEntry
    local paletteAware = paletteAwareEntry(menu, entry)
    local authored = type(entry) == "table" and not paletteAware
    local hgss = authored and hgssPartyEntry(menu, entry)
    local allowFollower = source == "auto" or source == "follower_pack"
    local wildsDef = allowFollower and compatibility.wildsOfKanto
      and wildsIconDef(menu, mon) or nil
    local protected = authored or hgss
      or (wildsDef and wildsDef.trueColor ~= false)
    local background = opts.background
    local stableRect

    if protected and type(background) == "table" then
      stableRect = {
        x = math.floor(x), y = math.floor(y), w = size, h = size,
      }
      love.graphics.push("all")
      love.graphics.setColor((background[1] or 255) / 255,
        (background[2] or 255) / 255,
        (background[3] or 255) / 255, 1)
      love.graphics.rectangle("fill", stableRect.x, stableRect.y,
        stableRect.w, stableRect.h)
      love.graphics.pop()
    end

    local regions = {}
    local drawn = false
    if source == "original" then
      drawn = drawOriginalIcon(menu, mon, x, y, animate, counter) == true
      protected = false
      stableRect = nil
    elseif menuEntry then
      drawn = drawDirectMenuIcon(menu, mon, menuEntry, x, y,
        animate, counter, size) == true
    elseif wildsDef then
      drawn = drawWildsIcon(menu, mon, x, y, animate, counter,
        regions, wildsDef) == true
    elseif hgss then
      drawn = drawFittedHgssIcon(menu, mon, entry, x, y,
        animate, counter, size, regions) == true
    end

    if not drawn and menuEntry then
      -- A missing menu-pack file must never fall back through a follower
      -- wrapper and silently violate ICON SOURCE. The dex-indexed original
      -- remains a dependable last resort for this explicit choice.
      drawn = drawOriginalIcon(menu, mon, x, y, animate, counter) == true
      protected = false
      stableRect = nil
    elseif not drawn then
      local scale = size / 16
      local runs = source ~= "original" and not hgss
        and iconOpaqueRuns(menu, mon, entry, animate, counter) or nil
      drawn = drawIconCollectingTrueColor(menu, mon, x, y,
        animate, counter, regions, scale, runs,
        type(entry) == "table" and runs == nil) == true
    end
    if not drawn and not menuEntry then
      drawn = drawFallbackIcon(menu, mon, x, y,
        animate, counter, regions) == true
    end

    if drawn and protected and stableRect then
      PaletteFX.markTrueColor(stableRect.x, stableRect.y,
        stableRect.w, stableRect.h)
    elseif drawn and protected then
      -- Only authored/full-colour artwork may publish literal-colour claims.
      -- Palette-aware ORIGINAL packs sometimes report source-sheet
      -- coordinates here; replaying those coordinates onto a responsive
      -- child screen creates the scattered grey rectangles seen on naming.
      for _, rect in ipairs(regions) do
        PaletteFX.markTrueColor(rect.x, rect.y, rect.w, rect.h)
      end
    end
    gray(WHITE)
    return drawn
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

    drawCardFrame(x, y, width, height, selected, layout.portrait)

    -- AUTO/FOLLOWER keep the engine's live helper seam. MENU PACK may instead
    -- draw the explicitly owning content contribution, because the live
    -- icons.bySpecies table can be replaced later by a follower provider.
    local icons = menu.game.data.icons or {}
    local liveEntry = (icons.bySpecies and icons.bySpecies[mon.species])
      or (def and def.icon)
    local source = setting("sprite_source", "auto")
    local menuEntry = source == "menu_pack"
      and explicitMenuPackEntry(menu, mon) or nil
    local entry = menuEntry or liveEntry
    local trueColorIcon = false
    local hgssIcon = hgssPartyEntry(menu, entry)
    if type(entry) == "table" then
      -- Unique Menu Icons 1.5.0 renamed these folders from icons_* to
      -- icon_*.  ORIGINAL is deliberately palette-driven in both layouts;
      -- treating the new singular path as authored true colour preserves
      -- its literal grayscale pixels and is what made those icons look gray.
      trueColorIcon = not paletteAwareEntry(menu, entry)
        or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
    end

    -- Fit HGSS's visible creature into this rail. Its 32px source frame has
    -- substantial transparent padding, so scaling the complete frame leaves
    -- the actual sprite much smaller than the available card space.
    local iconSize = hgssIcon and (spacious and 32 or 22) or 16
    local iconScale = hgssIcon and iconSize / 32 or 1
    local iconX, iconY = iconGeometry(x, y, width, height, iconSize)
    local textX = math.max(x + contentInset(width), iconX + iconSize + 2)

    gray(WHITE)
    -- Keep the roster calm and make focus immediately readable: the shared
    -- animation setting enables movement, while selection decides which one
    -- of the visible cards is allowed to advance beyond its resting frame.
    local regionCount = #trueColorIcons
    local animate = setting("animate_icons", true) and selected
    local opaqueRuns = source ~= "original" and not hgssIcon
      and iconOpaqueRuns(menu, mon, entry, animate, menu.blink or 0) or nil
    local allowFollower = source == "auto" or source == "follower_pack"
    local wildsDef = allowFollower and compatibility.wildsOfKanto
      and wildsIconDef(menu, mon) or nil
    local stableRect
    local protectedDrawn = false

    local function prepareStableWell()
      if not stableRect then
        stableRect = fillStableIconWell(menu, mon, selected,
          iconX, iconY, iconSize, true)
      end
      return stableRect ~= nil
    end

    local function discardStableWell()
      while #trueColorIcons > regionCount do
        table.remove(trueColorIcons)
      end
      if stableRect then
        fillStableIconWell(menu, mon, selected,
          iconX, iconY, iconSize, false)
        stableRect = nil
      end
    end

    local drawn = false
    if source == "original" then
      drawn = drawOriginalIcon(menu, mon, iconX, iconY,
        animate, menu.blink or 0) == true
    end

    if not drawn and menuEntry then
      if trueColorIcon then prepareStableWell() end
      drawn = drawDirectMenuIcon(menu, mon, menuEntry, iconX, iconY,
        animate, menu.blink or 0, iconSize) == true
      protectedDrawn = drawn and trueColorIcon
      if not drawn then
        discardStableWell()
        -- Do not re-enter the globally wrapped menu renderer when an explicit
        -- provider fails: a follower wrapper would defeat MENU PACK again.
        drawn = drawOriginalIcon(menu, mon, iconX, iconY,
          animate, menu.blink or 0) == true
      end
    end

    if not drawn and wildsDef then
      local protectWilds = wildsDef.trueColor ~= false
      if protectWilds then prepareStableWell() end
      drawn = drawWildsIcon(menu, mon, iconX, iconY,
        animate, menu.blink or 0, trueColorIcons, wildsDef) == true
      protectedDrawn = drawn and protectWilds
      if not drawn then discardStableWell() end
    end

    local fitted = false
    if not drawn and hgssIcon then
      prepareStableWell()
      fitted = drawFittedHgssIcon(menu, mon, entry,
        iconX, iconY, animate, menu.blink or 0,
        iconSize, trueColorIcons) == true
      drawn = fitted
      protectedDrawn = fitted
      if not fitted then discardStableWell() end
    end

    if not drawn and not menuEntry then
      if trueColorIcon then prepareStableWell() end
      local sharedDrawn = drawIconCollectingTrueColor(menu, mon, iconX, iconY,
        animate, menu.blink or 0, trueColorIcons, iconScale, opaqueRuns,
        type(entry) == "table" and opaqueRuns == nil)
      drawn = sharedDrawn == true
      protectedDrawn = drawn and trueColorIcon
      if not drawn then
        -- A renderer may have claimed colour before discovering that its
        -- image could not be loaded. Remove those claims before falling back
        -- or the empty source canvas would still be restored as a square.
        discardStableWell()
        drawn = drawFallbackIcon(menu, mon, iconX, iconY,
          animate, menu.blink or 0, trueColorIcons)
      elseif trueColorIcon and opaqueRuns
          and #trueColorIcons == regionCount then
        appendOpaqueRegions(trueColorIcons, iconX, iconY,
          iconScale, opaqueRuns)
      end
    end

    if protectedDrawn and stableRect then
      -- Replace the renderer's per-row claims with one Android-safe
      -- composite.  markTrueColorOutside still clips this rectangle around
      -- the party action popup, so modal menus retain their own pixels.
      while #trueColorIcons > regionCount do
        table.remove(trueColorIcons)
      end
      trueColorIcons[#trueColorIcons + 1] = stableRect
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
      if menu.tmhm then
        drawLearnability(badge, x + width - 5, detailY, selected, spacious)
      else
        drawBadge(badge, x + width - 5, detailY, selected, spacious)
      end
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
    drawToolIcon = drawToolIcon,
  }
end
