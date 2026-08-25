-- Responsive modern presentation for src.ui.SummaryMenu.
--
-- Page changes and closing remain owned by the original controller. This
-- module replaces only drawing, palette zones and the logical UI width so a
-- summary opened from the party, a PC box or another mod behaves identically.
return function(mod, genderExports, compatibility)
  local Font = require("src.render.Font")
  local Growth = require("src.pokemon.Growth")
  local PaletteFX = require("src.render.PaletteFX")
  local Renderer = require("src.render.Renderer")
  local Assets = require("src.render.Assets")
  local Sprites = require("src.pokemon.Sprites")
  local SummaryMenu = require("src.ui.SummaryMenu")
  local TypeChart = require("src.battle.TypeChart")
  local faithfulLoaded, FaithfulRes = pcall(require, "src.core.FaithfulRes")
  if not faithfulLoaded then FaithfulRes = nil end

  local SCREEN_H = 144
  local HEADER_H = 16
  local FOOTER_Y = 136
  local WHITE, LIGHT, DARK, BLACK = 1, 170 / 255, 85 / 255, 0
  local dvTracker = compatibility and compatibility.dvTracker == true
  local kantoRibbons = compatibility and compatibility.kantoRibbons == true
  local summaryPageCount = dvTracker and 3 or 2

  -- DramaticShape 1.8.x exposes its shiny predicate and palette transform
  -- through mod.exports.lib. Its native SummaryMenu wrapper cannot see this
  -- screen's instance-owned responsive palette method, so consume that public
  -- interface directly for the artwork while leaving the surrounding type
  -- cards under Modern Party UI's palette ownership.
  local dramaticExports = compatibility
    and compatibility.dramaticShapeExports or nil
  local dramaticLib = dramaticExports and dramaticExports.lib or nil
  local function dramaticModule(name)
    if not (dramaticLib and type(dramaticLib.require) == "function") then
      return nil
    end
    local ok, value = pcall(dramaticLib.require, name)
    return ok and type(value) == "table" and value or nil
  end
  local dramaticShiny = dramaticModule("Shiny")
  local dramaticShinyPalette = dramaticModule("ShinyPalette")
  local crystal251Summary = compatibility
    and compatibility.crystal251Summary or nil

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

  local function faithfulRatioActive()
    if not (FaithfulRes and type(FaithfulRes.scaleCap) == "function") then
      return false
    end
    local ok, cap = pcall(FaithfulRes.scaleCap)
    return ok and cap ~= nil
  end

  local function responsiveWidth()
    if not setting("responsive", true) then return 160 end
    if faithfulRatioActive() then return 160 end
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    width, height = tonumber(width) or 160, tonumber(height) or SCREEN_H
    -- Base the integer scale on both axes. A height-only scale makes a tall
    -- phone request the minimum 160px canvas after an Up/Down party swap,
    -- leaving the responsive summary as a tiny centred Game Boy viewport.
    local scale = math.max(1, math.floor(math.min(
      width / Renderer.WIDTH, height / SCREEN_H)))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale)))
  end

  local function uiSize()
    return responsiveWidth(), SCREEN_H
  end

  local function layoutFor(summary)
    local width = responsiveWidth()
    local renderer = summary and summary.game and summary.game.renderer
    if setting("responsive", true) and not faithfulRatioActive()
        and renderer and renderer.uiSize then
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

  local function stripGenderSuffix(text)
    text = tostring(text or "")
    if not genderExports then return text end
    local plain = text:gsub("\226\153[\128\130]%s*$", "")
    if plain == text then plain = text:gsub("[♂♀]%s*$", "") end
    return plain
  end

  local function drawGenderGlyph(mon, x, y, background)
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
    PaletteFX.markTrueColor(x, y, 8, 8)
    return 9
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

  local function dramaticShinyTransform(summary)
    if not (dramaticShiny and type(dramaticShiny.isShiny) == "function"
        and dramaticShinyPalette) then
      return nil
    end
    local okShiny, shiny = pcall(dramaticShiny.isShiny, summary.mon)
    if not okShiny or shiny ~= true then return nil end

    local dex = definition(summary).dex
    if not dex then return nil end
    if type(dramaticShinyPalette.paletteTransform) == "function" then
      local ok, transform = pcall(
        dramaticShinyPalette.paletteTransform, dex)
      if ok and type(transform) == "function" then return transform end
    end

    -- Early DramaticShape shiny builds exposed the lower-level pair instead
    -- of paletteTransform. Supporting it costs nothing and prevents a silent
    -- normal-colour fallback for players upgrading from those builds.
    if type(dramaticShinyPalette.forDex) == "function"
        and type(dramaticShinyPalette.transform) == "function" then
      local okSpec, spec = pcall(dramaticShinyPalette.forDex, dex)
      if okSpec then
        local ok, transform = pcall(dramaticShinyPalette.transform, spec)
        if ok and type(transform) == "function" then return transform end
      end
    end
    return nil
  end

  local function transformedArtPalette(summary, colors)
    local transform = dramaticShinyTransform(summary)
    if not transform then return colors, false end
    local out = {}
    for i, color in ipairs(colors or {}) do
      if type(color) == "table" and color[1] ~= nil then
        local ok, r, g, b = pcall(transform,
          color[1], color[2], color[3])
        out[i] = ok and { r, g, b } or color
      else
        out[i] = color
      end
    end
    return out, true
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

  -- SGB's pale yellow/orange card ramps are much harsher at the enlarged
  -- summary scale than its cool and green ramps. The portrait composite is
  -- already neutral on these pages, so leaving the vitals card warm creates
  -- one isolated yellow slab. Keep semantic HEALTH colours and explicit
  -- BLUE/MONO choices intact; only default type/species surfaces borrow the
  -- summary's existing cool base palette when their light shade is warm.
  local function summarySurfacePalette(summary, primary, base)
    local mode = PaletteFX.mode
    if mode ~= "gbc" and mode ~= "gbc_inv" then return primary end
    local style = setting("card_color", "species")
    if style == "health" or style == "blue" or style == "mono" then
      return primary
    end
    local colors = PaletteFX.effectiveColors(primary) or primary
    local light = colors and colors[2]
    if not light then return primary end
    local r, g, b = light[1] or 0, light[2] or 0, light[3] or 0
    local warm = r >= 200 and g >= 120 and b <= 160 and g >= b + 8
    return warm and base or primary
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
    drawText(('%d/%d'):format(summary.page or 1, summaryPageCount),
      4, 4, 24, WHITE)
    local def = definition(summary)
    local name = stripGenderSuffix(
      summary.mon.nickname or def.name or summary.mon.species or "?")
    local nameLeft, nameRight = 36, layout.width - 52
    local maxName = math.max(24, nameRight - nameLeft)
    local shown = fitText(name, maxName)
    drawText(shown, nameLeft + (maxName - Font.width(shown)) / 2,
      3, maxName, WHITE)
    local pageTitle = summary.page == 1 and "STATS"
      or summary.page == 2 and "MOVES" or "DVS"
    drawTextRight(pageTitle,
      layout.width - 4, 4, 48, WHITE)
  end

  -- Resolve the same front-sprite context BattleState uses. A visual pack may
  -- intentionally return different art for `battle` and `summary`; using the
  -- latter made the status card disagree with the Pokémon actually fighting.
  local function refreshBattleSprite(summary)
    local mon = summary.mon
    local species = mon and mon.species
    if not species then return nil, false end
    local path, trueColor = Sprites.path(summary.game.data, species, "front",
      { mon = mon, kind = "battle" })
    if summary.modernBattleSpriteSpecies ~= species
        or summary.modernBattleSpritePath ~= path
        or summary.modernBattleSpriteTrueColor ~= (trueColor and true or false) then
      local image
      if path then
        local ok, loaded = pcall(Assets.image, path)
        image = ok and loaded or nil
      end
      summary.modernBattleSpritePath = path
      summary.modernBattleSpriteSpecies = species
      summary.modernBattleSpriteTrueColor = trueColor and true or false
      summary.modernBattleSprite = image
      summary.modernSpritePath = path
      summary.modernSpriteSpecies = species
      summary.modernSprite = nil
      summary.modernSpriteKey = nil
    end
    return summary.modernBattleSprite, summary.modernBattleSpriteTrueColor
  end

  local function spriteGeometry(summary, layout)
    local source = refreshBattleSprite(summary)
      or summary.modernBattleSprite or summary.sprite
    if not source then return nil end
    local sw, sh = source:getDimensions()
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

  local WARM_SGB_PORTRAITS = {
    REDMON = true, YELLOWMON = true, BROWNMON = true,
  }

  -- Preserve SGB's palette across the interface while preventing its pale
  -- orange/yellow monster ramps from washing out when battle art is enlarged
  -- into a standalone profile. The Advanced pack contains stronger versions
  -- of the same Gen 1 REDMON/YELLOWMON/BROWNMON assignments, so only those
  -- grayscale portraits borrow that contrast. Other hues, true-colour art,
  -- and non-SGB display modes are untouched.
  local function portraitArtPalette(data, species)
    local palette = PaletteFX.monPal(data, species)
    local mode = PaletteFX.mode
    if mode ~= "gbc" and mode ~= "gbc_inv" then return palette end
    local name = PaletteFX.monPalName(data, species)
    if not WARM_SGB_PORTRAITS[name] then return palette end
    local pack = PaletteFX.gbcPack and PaletteFX.gbcPack() or nil
    return pack and pack.palettes and pack.palettes[name] or palette
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
    local battleSprite, battleTrueColor = refreshBattleSprite(summary)
    if battleTrueColor and battleSprite then return battleSprite, true end
    -- QoL Toggles' PARTY SCROLL updates `self.mon` and the native sprite in
    -- place instead of constructing a new SummaryMenu. Refresh our separate
    -- matte/palette source as well; otherwise Pokémon sharing a palette key
    -- keep drawing the previously selected species from modernSprite.
    local species = summary.mon and summary.mon.species
    if summary.modernSpriteSpecies ~= species then
      refreshBattleSprite(summary)
    end
    local artPalette, shiny = transformedArtPalette(summary,
      portraitArtPalette(summary.game.data, summary.mon.species)
        or primaryPalette(summary))
    summary.modernDramaticShapeShiny = shiny
    local colors = PaletteFX.effectiveColors(artPalette)
    local key = paletteKey(colors)
    if summary.modernSpriteKey ~= key then
      summary.modernSprite = maskedPaletteSprite(summary.modernSpritePath,
        colors)
      summary.modernSpriteKey = key
    end
    return summary.modernSprite or battleSprite or summary.sprite,
      summary.modernSprite ~= nil
  end

  local function drawProfile(summary, layout)
    local mon, def = summary.mon, definition(summary)
    drawCard(layout.railX, layout.railY, layout.railW, layout.railH, true)
    local x, y, sw, sh = spriteGeometry(summary, layout)
    local protectedFace
    if x then
      -- Composite the card's complete inner face instead of drawing a tight
      -- sprite-sized guard. Android can reveal any true-colour protection
      -- boundary that ends over a flat palette surface, even when both sides
      -- nominally use the same colour. Extending the borderless composite to
      -- the card's structural edge leaves no free-standing frame or stroke.
      protectedFace = {
        x = layout.railX + 2,
        y = layout.railY + 2,
        w = math.max(1, layout.railW - 6),
        h = math.max(1, layout.railH - 6),
      }
      local faceColors = PaletteFX.effectiveColors(primaryPalette(summary))
        or PaletteFX.GRAYS
      local edge = faceColors[4] or { 0, 0, 0 }
      love.graphics.setColor(edge[1] / 255, edge[2] / 255,
        edge[3] / 255, 1)
      love.graphics.rectangle("fill", protectedFace.x, protectedFace.y,
        protectedFace.w, protectedFace.h)
      local face = faceColors[2] or { 170, 170, 170 }
      love.graphics.setColor(face[1] / 255, face[2] / 255,
        face[3] / 255, 1)
      chamfer("fill", protectedFace.x, protectedFace.y,
        protectedFace.w, protectedFace.h, 3)

      local image, paletteBaked = profileSprite(summary)
      local shader
      if not summary.spriteTrueColor and not paletteBaked then
        -- Pixel reads are unavailable only in reduced/headless runtimes. Keep
        -- their previous safe keyed draw as a compatibility fallback.
        shader = PaletteFX.keyedShader()
        if shader then
          love.graphics.setShader(shader)
          local artPalette = transformedArtPalette(summary,
            portraitArtPalette(summary.game.data, mon.species)
              or primaryPalette(summary))
          PaletteFX.sendColors(shader, artPalette)
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
      -- The original status screen mirrors the front sprite. Preserve that
      -- presentation detail and the live sprite supplied by other mods.
      love.graphics.draw(image, x + sw, y, 0, -1, 1)
      if shader then love.graphics.setShader() end
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
    if protectedFace then
      -- Register this after drawing the text so the complete finished card
      -- face is restored as one stable region. There is deliberately no
      -- source-canvas-sized inset and no edge stroke.
      PaletteFX.markTrueColor(protectedFace.x, protectedFace.y,
        protectedFace.w, protectedFace.h)
    end
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
    local faceColors = PaletteFX.effectiveColors(primaryPalette(summary))
    local genderWidth = drawGenderGlyph(mon, x + 5, y + 5,
      faceColors and faceColors[2] or nil)
    drawText("LV" .. tostring(mon.level or 1),
      x + 5 + genderWidth, y + 5, 48 - genderWidth, BLACK)
    local status = (mon.hp or 0) <= 0 and "FNT" or mon.status or "OK"
    drawTextRight(tostring(status), x + w - 5, y + 5, 40, BLACK)
    local maxHP = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local barX, barY, barW = x + 25, y + 18, w - 30
    drawText("HP", x + 5, barY, 16, BLACK)
    drawMeter((mon.hp or 0) / math.max(1, maxHP), barX, barY + 1, barW)
    drawTextRight(("%d/%d"):format(mon.hp or 0, maxHP),
      x + w - 5, y + 29, w - 10, BLACK)
  end

  local COMBINED_STAT_ITEMS = {
    { "ATTACK", "attack", "ATK" }, { "DEFENSE", "defense", "DEF" },
    { "SPEED", "speed", "SPD" }, { "SPECIAL", "special", "SPC" },
  }

  local SPLIT_STAT_ITEMS = {
    { "ATTACK", "attack", "ATK" },
    { "DEFENSE", "defense", "DEF" },
    { "SP.ATK", "specialAttack", "SP.A" },
    { "SP.DEF", "specialDefense", "SP.D" },
    { "SPEED", "speed", "SPD" },
  }

  local SPLIT_STAT_ITEMS_WIDE = {
    { "ATTACK", "attack", "ATK" },
    { "DEFENSE", "defense", "DEF" },
    { "SPEED", "speed", "SPD" },
    { "SP.ATK", "specialAttack", "SP.A" },
    { "SP.DEF", "specialDefense", "SP.D" },
  }

  local SPLIT_ALIASES = {
    specialAttack = {
      "specialAttack", "special_attack", "specialAtk", "spAttack",
      "spAtk", "spatk", "sp_atk",
    },
    specialDefense = {
      "specialDefense", "special_defense", "specialDef", "spDefense",
      "spDef", "spdef", "sp_def",
    },
  }

  local function firstStat(stats, aliases)
    for _, key in ipairs(aliases) do
      local value = stats and tonumber(stats[key])
      if value ~= nil then return value end
    end
    return nil
  end

  local function displayStats(summary)
    local stats
    if crystal251Summary
        and type(crystal251Summary.statsFor) == "function" then
      local ok, resolved = pcall(crystal251Summary.statsFor, summary)
      if ok and type(resolved) == "table" then stats = resolved end
    end
    stats = stats or (summary.mon and summary.mon.stats) or {}

    local specialAttack = firstStat(stats, SPLIT_ALIASES.specialAttack)
    local specialDefense = firstStat(stats, SPLIT_ALIASES.specialDefense)
    if specialAttack ~= nil and specialDefense ~= nil then
      return {
        attack = tonumber(stats.attack) or 0,
        defense = tonumber(stats.defense) or 0,
        speed = tonumber(stats.speed) or 0,
        specialAttack = specialAttack,
        specialDefense = specialDefense,
      }, SPLIT_STAT_ITEMS, true
    end
    return stats, COMBINED_STAT_ITEMS, false
  end

  local function statGrid(layout, count)
    if count <= 4 then return 2, 2 end
    -- Standard widescreen still has room for readable paired stat cards.
    -- Only genuinely expansive surfaces switch to three columns; otherwise
    -- the Special pair stays together and SPEED is centred beneath it.
    if layout.mainW >= 240 then return 3, 2 end
    return 2, 3
  end

  local function statGeometry(layout, index, count)
    local areaY = layout.mainY + 44
    local areaH = layout.mainH - 44
    local columns, rows = statGrid(layout, count)
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns
    local rowCount = math.min(columns, count - row * columns)
    local rowWidth = math.floor(layout.mainW * rowCount / columns)
    local rowX = layout.mainX
      + math.floor((layout.mainW - rowWidth) / 2)
    local x = rowX + math.floor(column * rowWidth / rowCount)
    local x2 = rowX + math.floor((column + 1) * rowWidth / rowCount)
    local y = areaY + math.floor(row * areaH / rows)
    local y2 = areaY + math.floor((row + 1) * areaH / rows)
    return x, y, x2 - x, y2 - y
  end

  local function drawStats(summary, layout)
    local stats, items, split = displayStats(summary)
    local columns = select(1, statGrid(layout, #items))
    if split and columns >= 3 then items = SPLIT_STAT_ITEMS_WIDE end
    summary.modernSplitSpecial = split
    for i, item in ipairs(items) do
      local x, y, w, h = statGeometry(layout, i, #items)
      drawCard(x, y, w, h, false)
      local valueText = tostring(math.floor(tonumber(stats[item[2]]) or 0))
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

  local function selectedMove(summary)
    local index = math.max(1, math.min(4,
      tonumber(summary.modernMoveIndex) or 1))
    local move = (summary.mon.moves or {})[index]
    local def = move and summary.game.data.moves[move.id]
    return move, def, index
  end

  local function moveCategory(def)
    if not def then return "---" end
    if tonumber(def.power) == 0 then return "STATUS" end
    local category = def.category or TypeChart.category(def.type)
    category = tostring(category or "---"):upper()
    if category == "PHYSICAL" then return "PHYSICAL" end
    if category == "SPECIAL" then return "SPECIAL" end
    return category
  end

  local function drawMoveDetail(summary, layout)
    local move, def = selectedMove(summary)
    local x, y = layout.mainX, layout.mainY + 40
    local w, h = layout.mainW, layout.mainH - 40
    drawCard(x, y, w, h, false)
    if not (move and def) then
      drawTextCentered("EMPTY MOVE SLOT", x + 5,
        y + math.floor((h - 8) / 2), w - 10, WHITE)
      return
    end

    local maxPP = (def.pp or 0)
      + (move.ppUps or 0) * math.floor((def.pp or 0) / 5)
    local typeName = TypeChart.displayName(def.type or "NORMAL") or "---"
    local accuracy = tonumber(def.accuracy)
    local rows = {
      { "TYPE", tostring(typeName):upper() },
      { "CLASS", moveCategory(def) },
      { "POWER", tonumber(def.power) == 0 and "---"
          or tostring(math.floor(tonumber(def.power) or 0)) },
      { "ACCURACY", accuracy and (tostring(math.floor(accuracy)) .. "%")
          or "---" },
      { "PP", ("%d/%d"):format(move.pp or 0, maxPP) },
    }
    drawTextCentered(def.name or move.id, x + 5, y + 5, w - 10, WHITE)
    local firstY = y + 20
    local rowH = math.max(10, math.floor((h - 24) / #rows))
    for i, row in ipairs(rows) do
      local rowY = firstY + (i - 1) * rowH
      drawText(row[1], x + 7, rowY, math.floor(w * 0.48), WHITE)
      drawTextRight(row[2], x + w - 7, rowY,
        math.floor(w * 0.48), WHITE)
    end
  end

  local function drawMoves(summary, layout)
    if summary.modernMoveDetail then
      drawMoveDetail(summary, layout)
      return
    end
    local moves = summary.mon.moves or {}
    local selectedIndex = math.max(1, math.min(4,
      tonumber(summary.modernMoveIndex) or 1))
    for i = 1, 4 do
      local x, y, w, h = moveGeometry(layout, i)
      local selected = i == selectedIndex
      drawCard(x, y, w, h, selected)
      local move = moves[i]
      local def = move and summary.game.data.moves[move.id]
      if not (move and def) then
        drawTextCentered("EMPTY", x + 5, y + math.floor((h - 8) / 2),
          w - 10, selected and BLACK or WHITE)
      else
        local name = fitText(def.name or move.id, w - 10)
        local nameY = y + math.floor((h - 17) / 2)
        drawTextCentered(name, x + 5, nameY, w - 10,
          selected and BLACK or WHITE)
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
          Font.width(typeName), selected and BLACK or WHITE)
        drawText(pp, detailX + typeWidth + gap, detailY,
          Font.width(pp), selected and BLACK or WHITE)
      end
    end
  end

  -- DV Tracker 1.0.0 patches the native SummaryMenu controller to add page
  -- three. Modern Party UI owns the instance draw method, so render that
  -- controller page in the same responsive card language rather than
  -- accidentally showing the moves page a second time.
  local DV_ITEMS = {
    { "ATTACK", "attack", "ATK" }, { "DEFENSE", "defense", "DEF" },
    { "SPEED", "speed", "SPD" }, { "SPECIAL", "special", "SPC" },
  }

  local SPLIT_DV_ITEMS = {
    { "ATTACK", "attack", "ATK" },
    { "DEFENSE", "defense", "DEF" },
    { "SP.ATK", "specialAttack", "SP.A" },
    { "SP.DEF", "specialDefense", "SP.D" },
    { "SPEED", "speed", "SPD" },
  }

  local SPLIT_DV_ITEMS_WIDE = {
    { "ATTACK", "attack", "ATK" },
    { "DEFENSE", "defense", "DEF" },
    { "SPEED", "speed", "SPD" },
    { "SP.ATK", "specialAttack", "SP.A" },
    { "SP.DEF", "specialDefense", "SP.D" },
  }

  local function dvData(summary)
    local mon = summary and summary.mon
    local stats = mon and mon.stats or {}
    local dvs = (mon and (mon.dvs or mon.ivs))
      or stats.dvs or stats.ivs or {}
    local statExp = mon and mon.statExp or {}
    local specialAttack = firstStat(dvs, SPLIT_ALIASES.specialAttack)
    local specialDefense = firstStat(dvs, SPLIT_ALIASES.specialDefense)
    local _, _, splitStats = displayStats(summary)
    local split = splitStats
      or (specialAttack ~= nil and specialDefense ~= nil)
    if split then
      local sharedDV = tonumber(dvs.special)
      specialAttack = specialAttack or sharedDV or 0
      specialDefense = specialDefense or sharedDV or 0
      dvs = {
        hp = dvs.hp,
        attack = tonumber(dvs.attack) or 0,
        defense = tonumber(dvs.defense) or 0,
        speed = tonumber(dvs.speed) or 0,
        special = sharedDV,
        specialAttack = specialAttack,
        specialDefense = specialDefense,
      }
      statExp = {
        hp = statExp.hp,
        attack = statExp.attack,
        defense = statExp.defense,
        speed = statExp.speed,
        special = statExp.special,
        specialAttack = firstStat(statExp, SPLIT_ALIASES.specialAttack)
          or statExp.special or 0,
        specialDefense = firstStat(statExp, SPLIT_ALIASES.specialDefense)
          or statExp.special or 0,
      }
    end
    local hp = dvs.hp
    if hp == nil then
      hp = ((dvs.attack or 0) % 2) * 8
        + ((dvs.defense or 0) % 2) * 4
        + ((dvs.speed or 0) % 2) * 2
        + ((dvs.special or specialAttack or specialDefense or 0) % 2)
    end
    return dvs, statExp, hp, split
  end

  local function dvGrid(layout, count)
    if count <= 4 then
      local columns = layout.mainW >= 144 and 2 or 1
      return columns, math.ceil(count / columns)
    end
    if layout.mainW >= 240 then return 3, 2 end
    if layout.mainW >= 120 then return 2, 3 end
    return 1, count
  end

  local function dvGeometry(layout, index, count)
    local areaY = layout.mainY + 34
    local areaH = layout.mainH - 34
    local columns, rows = dvGrid(layout, count)
    local zero = index - 1
    local column = zero % columns
    local row = math.floor(zero / columns)
    local rowCount = math.min(columns, count - row * columns)
    local rowWidth = math.floor(layout.mainW * rowCount / columns)
    local rowX = layout.mainX
      + math.floor((layout.mainW - rowWidth) / 2)
    local x = rowX + math.floor(column * rowWidth / rowCount)
    local x2 = rowX + math.floor((column + 1) * rowWidth / rowCount)
    local y = areaY + math.floor(row * areaH / rows)
    local y2 = areaY + math.floor((row + 1) * areaH / rows)
    return x, y, x2 - x, y2 - y
  end

  local function compactStatExp(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value >= 1000 then return tostring(math.floor(value / 1000)) .. "K" end
    return tostring(value)
  end

  local function drawDVs(summary, layout)
    local dvs, statExp, hpDv, split = dvData(summary)
    local x, y, w, h = layout.mainX, layout.mainY, layout.mainW, 32
    drawCard(x, y, w, h, true)
    local hpText = "HP DV " .. tostring(hpDv or 0)
    local expText = "EXP " .. tostring(statExp.hp or 0)
    local joinedWidth = Font.width(hpText) + 8 + Font.width(expText)
    if joinedWidth <= w - 10 then
      local startX = x + math.floor((w - joinedWidth) / 2)
      local labelW = drawText(hpText, startX, y + 12,
        w - 10, BLACK)
      drawText(expText, startX + labelW + 8, y + 12,
        w - 10 - labelW - 8, BLACK)
    else
      drawTextCentered(hpText, x + 5, y + 5, w - 10, BLACK)
      drawTextCentered(expText, x + 5, y + 16, w - 10, BLACK)
    end

    local items = split and SPLIT_DV_ITEMS or DV_ITEMS
    local columns = select(1, dvGrid(layout, #items))
    if split and columns >= 3 then items = SPLIT_DV_ITEMS_WIDE end
    summary.modernSplitSpecialDVs = split
    for i, item in ipairs(items) do
      local cx, cy, cw, ch = dvGeometry(layout, i, #items)
      drawCard(cx, cy, cw, ch, false)
      local dv = tostring(dvs[item[2]] or 0)
      local stat = tostring(statExp[item[2]] or 0)
      local label = item[1]
      if columns == 1 and split then
        local joined = item[3] .. dv .. "/" .. compactStatExp(stat)
        drawTextCentered(joined, cx + 4,
          cy + math.floor((ch - 8) / 2), cw - 8, WHITE)
      else
        if Font.width(label .. " DV" .. dv) > cw - 8 then label = item[3] end
        local first = label .. " DV" .. dv
        local second = "EXP " .. stat
        local firstY = cy + math.max(2, math.floor((ch - 17) / 2))
        drawTextCentered(first, cx + 4, firstY, cw - 8, WHITE)
        drawTextCentered(second, cx + 4, firstY + 9, cw - 8, WHITE)
      end
    end
  end

  local function drawFooter(summary, layout)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 8)
    local hint
    if summary.page == 1 then
      hint = "A/B MOVES"
    elseif summary.page == 2 and summary.modernMoveDetail then
      hint = "A/B BACK"
    elseif summary.page == 2 and kantoRibbons then
      hint = "ARROWS  A INFO  B RIBBONS"
    elseif summary.page == 2 and dvTracker then
      hint = "ARROWS  A INFO  B DVS"
    elseif summary.page == 2 then
      hint = "ARROWS  A INFO  B BACK"
    elseif kantoRibbons then
      hint = "A/B RIBBONS"
    else
      hint = "A/B BACK"
    end
    drawText(hint, (layout.width - Font.width(hint)) / 2,
      FOOTER_Y, layout.width - 8, WHITE)
  end

  -- Party-icon packs publish true-colour rectangles after drawing each icon.
  -- When a submenu action replaces PartyMenu with SummaryMenu in the same
  -- rendered frame, those party-space rectangles can otherwise be re-blitted
  -- over this screen as grey squares.  The summary is an opaque UI owner, so
  -- discard only the UI pass's inherited claims and then let drawProfile add
  -- the one claim that belongs to the current Pokemon artwork.  Preserve the
  -- world pass so voxel/battle presentation mods remain untouched.
  local function clearInheritedUiTrueColor()
    local rects = PaletteFX.trueColorRects
      and PaletteFX.trueColorRects("ui") or nil
    if type(rects) ~= "table" then return end
    for i = #rects, 1, -1 do rects[i] = nil end
  end

  local function draw(summary)
    clearInheritedUiTrueColor()
    local layout = layoutFor(summary)
    drawBackdrop(layout)
    drawHeader(summary, layout)
    drawProfile(summary, layout)
    if summary.page == 1 then
      drawVitals(summary, layout)
      drawStats(summary, layout)
    elseif summary.page == 2 then
      drawExp(summary, layout)
      drawMoves(summary, layout)
    else
      drawDVs(summary, layout)
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
        colors = summarySurfacePalette(summary, primary, base),
        x = layout.mainX, y = layout.mainY,
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
    elseif summary.page == 2 then
      local exp = PaletteFX.pal(data, "EXP") or base
      zones[#zones + 1] = {
        colors = exp, x = layout.mainX + 5, y = layout.mainY + 28,
        w = layout.mainW - 10, h = 6,
      }
      if summary.modernMoveDetail then
        local move = selectedMove(summary)
        zones[#zones + 1] = {
          colors = movePalette(summary, move),
          x = layout.mainX, y = layout.mainY + 40,
          w = layout.mainW, h = layout.mainH - 40,
        }
      else
        for i, move in ipairs(summary.mon.moves or {}) do
          if i > 4 then break end
          local x, y, w, h = moveGeometry(layout, i)
          zones[#zones + 1] = {
            colors = movePalette(summary, move), x = x, y = y, w = w, h = h,
          }
        end
      end
    else
      zones[#zones + 1] = {
        colors = primary, x = layout.mainX, y = layout.mainY,
        w = layout.mainW, h = 32,
      }
    end
    return zones
  end

  return {
    new = function(game, mon)
      local summary = SummaryMenu.new(game, mon)
      local downstreamUpdate = summary.update
      -- Resolve through the same live sprite hook used by SummaryMenu so the
      -- matte mask follows asset replacements rather than a private copy.
      summary.modernSpritePath = Sprites.path(game.data, mon.species, "front",
        { mon = mon, kind = "battle" })
      summary.modernBattleSpritePath = summary.modernSpritePath
      summary.modernSpriteSpecies = mon.species
      summary.modernMoveIndex = 1
      summary.modernMoveDetail = false
      summary.update = function(self, dt)
        local input = self.game and self.game.input
        if self.page ~= 2 then
          self.modernMoveDetail = false
          return downstreamUpdate(self, dt)
        end
        if not (input and type(input.wasPressed) == "function") then
          return downstreamUpdate(self, dt)
        end
        if self.modernMoveDetail then
          if input:wasPressed("a") or input:wasPressed("b") then
            self.modernMoveDetail = false
          end
          return
        end

        local columns = layoutFor(self).moveColumns
        local index = math.max(1, math.min(4,
          tonumber(self.modernMoveIndex) or 1))
        if input:wasPressed("left") then
          index = columns == 1 and index
            or (index % columns == 1 and index + columns - 1 or index - 1)
        elseif input:wasPressed("right") then
          index = columns == 1 and index
            or (index % columns == 0 and index - columns + 1 or index + 1)
        elseif input:wasPressed("up") then
          index = index - columns
          if index < 1 then index = index + 4 end
        elseif input:wasPressed("down") then
          index = index + columns
          if index > 4 then index = index - 4 end
        elseif input:wasPressed("a") then
          local move = (self.mon.moves or {})[index]
          if move and self.game.data.moves[move.id] then
            self.modernMoveDetail = true
          end
          return
        else
          -- B still belongs to the original controller: it closes the
          -- summary or advances into DV/Ribbons pages supplied by other mods.
          return downstreamUpdate(self, dt)
        end
        self.modernMoveIndex = math.max(1, math.min(4, index))
      end
      summary.draw = draw
      summary.sgbPalettes = sgbPalettes
      summary.uiSize = uiSize
      summary.isWideBattleLayout = function()
        return setting("responsive", true)
      end
      summary.modernPartySummary = true
      summary.modernSummaryLayout = "responsive_cards"
      summary.modernSummaryPages = summaryPageCount
      -- Kanto Ribbons reads pageCount to locate the last controller page.
      -- Publish the composed total even when DV Tracker itself does not.
      summary.pageCount = math.max(tonumber(summary.pageCount) or 2,
        summaryPageCount)
      summary.dvTrackerCompatible = dvTracker
      summary.kantoRibbonsCompatible = kantoRibbons
      summary.dramaticShapeShinyCompatible = dramaticShiny ~= nil
        and dramaticShinyPalette ~= nil
      summary.splitSpecialCompatible = crystal251Summary ~= nil
      return summary
    end,
  }
end
