-- Responsive Modern Party UI presentation for Kanto Ribbons 0.18.0.
--
-- Kanto Ribbons remains the data owner: its public catalog and hasRibbon
-- export decide what appears. This screen owns only the same card-based,
-- responsive presentation used by the party and summary screens.
return function(mod, _, compatibility)
  compatibility = compatibility or {}
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local PaletteFX = require("src.render.PaletteFX")
  local PartyMenu = require("src.ui.PartyMenu")
  local Renderer = require("src.render.Renderer")
  local faithfulLoaded, FaithfulRes = pcall(require, "src.core.FaithfulRes")
  if not faithfulLoaded then FaithfulRes = nil end
  local Sprites = require("src.pokemon.Sprites")

  local exports = compatibility and compatibility.kantoRibbonsExports or {}
  local catalog = type(exports.catalog) == "table" and exports.catalog or {}
  local hasRibbon = type(exports.hasRibbon) == "function"
    and exports.hasRibbon or function(mon, id)
      return mon and mon.ribbons and mon.ribbons[id] == true
    end

  local SCREEN_H = 144
  local HEADER_H = 16
  local FOOTER_Y = 136
  local WINDOW_SIZE = 4
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
  local RIBBON_COLORS = {
    "ELECTRIC", "FLYING", "DARK", "PSYCHIC", "WATER", "GRASS",
    "FIGHTING", "GROUND", "FIRE", "ICE", "ROCK", "FAIRY",
    "BUG", "DRAGON", "POISON", "GHOST", "STEEL", "NORMAL",
  }

  local inkShader
  local fittedHgssIcons = {}

  local function setting(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function animationCounter(state)
    local counter = tonumber(state and state.blink) or 0
    if love.timer and love.timer.getTime then
      local ok, seconds = pcall(love.timer.getTime)
      if ok and tonumber(seconds) then
        counter = math.max(counter, math.floor(seconds * 60))
      end
    end
    return counter
  end

  local function isHgssEntry(entry)
    if not compatibility.hgssSprites or type(entry) ~= "table"
        or entry.trueColor ~= true then return false end
    local path = tostring(entry.image or ""):lower()
    return path:find("assets/icons/", 1, true) ~= nil
      and path:find("hgss", 1, true) ~= nil
  end

  local function drawFittedHgssIcon(state, entry, x, y, target)
    if not (love.image and love.image.newImageData
        and love.graphics.newQuad) then return false end
    local path = Sprites.iconPath(state.game.data, state.mon,
      entry.image, {})
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
        -- Keep both animation frames in one shared local envelope. Several
        -- HGSS icons animate through a one-pixel internal bob; independently
        -- centring each frame makes that authored movement disappear.
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

    local counter = animationCounter(state)
    local maxHP = state.mon.stats and state.mon.stats.hp or 1
    local hpPixels = math.floor((state.mon.hp or 0) * 48
      / math.max(1, maxHP))
    local speed = hpPixels >= 27 and 5 or hpPixels >= 10 and 16 or 32
    local animate = setting("animate_icons", true)
    local frame = animate and math.floor(counter / speed) % 2 or 0
    local bounds = cached.frames[frame] or cached.frames[0]
    if not bounds then return false end

    local scale = math.min(target / bounds.w, target / bounds.h)
    local drawW, drawH = bounds.w * scale, bounds.h * scale
    local drawX = math.floor(x + (target - drawW) / 2 + 0.5)
    local drawY = math.floor(y + (target - drawH) / 2 + 0.5)
    local quad = love.graphics.newQuad(bounds.x, bounds.y,
      bounds.w, bounds.h, cached.iw, cached.ih)
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cached.image, quad, drawX, drawY, 0, scale, scale)
    love.graphics.pop()
    for _, run in ipairs(bounds.runs or {}) do
      PaletteFX.markTrueColor(
        drawX + (run.x - bounds.x) * scale,
        drawY + (run.y - (bounds.y % 32)) * scale,
        math.max(1, run.w * scale), math.max(1, scale))
    end
    return true
  end

  local function gray(value)
    love.graphics.setColor(value, value, value, 1)
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
    drawText(text, x + math.floor((maxWidth - width) / 2), y,
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
    local scale = math.max(1, math.floor(math.min(
      width / Renderer.WIDTH, height / SCREEN_H)))
    return math.min(Renderer.MAX_UI_WIDTH or 640,
      math.max(160, math.floor(width / scale)))
  end

  local function layoutFor(state)
    local width = responsiveWidth()
    local renderer = state and state.game and state.game.renderer
    if setting("responsive", true) and not faithfulRatioActive()
        and renderer and renderer.uiSize then
      width = select(1, renderer:uiSize()) or width
    end
    width = math.max(160, math.floor(width))
    return {
      width = width,
      columns = width >= 224 and 2 or 1,
      profileX = 2, profileY = HEADER_H + 2,
      profileW = width - 4, profileH = 24,
      cardsY = HEADER_H + 28,
      cardsH = FOOTER_Y - HEADER_H - 28,
    }
  end

  local function cardGeometry(layout, slot)
    local zero = slot - 1
    local column = zero % layout.columns
    local row = math.floor(zero / layout.columns)
    local rows = math.ceil(WINDOW_SIZE / layout.columns)
    local innerW = layout.width - 4
    local x = 2 + math.floor(column * innerW / layout.columns)
    local x2 = 2 + math.floor((column + 1) * innerW / layout.columns)
    local y = layout.cardsY + math.floor(row * layout.cardsH / rows)
    local y2 = layout.cardsY + math.floor((row + 1) * layout.cardsH / rows)
    return x, y, x2 - x, y2 - y
  end

  local function definition(state)
    local pokemon = state.game and state.game.data and state.game.data.pokemon
    return pokemon and state.mon and pokemon[state.mon.species] or {}
  end

  local function primaryPalette(state)
    local def = definition(state)
    local primary = def.types and def.types[1]
    return TYPE_COLORS[tostring(primary or "NORMAL"):upper()]
      or TYPE_COLORS.NORMAL
  end

  local function basePalette(state)
    local data = state.game and state.game.data
    return PaletteFX.pal(data, "BLUEMON")
      or PaletteFX.pal(data, "MEWMON") or PaletteFX.GRAYS
  end

  local function ribbonPalette(entry)
    local color = RIBBON_COLORS[entry.catalogIndex] or "NORMAL"
    return TYPE_COLORS[color] or TYPE_COLORS.NORMAL
  end

  local function ownedRibbons(mon)
    local owned = {}
    for index, ribbon in ipairs(catalog) do
      local ok, has = pcall(hasRibbon, mon, ribbon.id)
      if ok and has then
        owned[#owned + 1] = {
          id = ribbon.id,
          label = ribbon.short or ribbon.name or ribbon.id,
          name = ribbon.name or ribbon.short or ribbon.id,
          description = ribbon.description or "",
          catalogIndex = index,
        }
      end
    end
    return owned
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

  local function drawHeader(state, layout, owned)
    gray(DARK)
    love.graphics.rectangle("fill", 0, 0, layout.width, HEADER_H)
    gray(LIGHT)
    love.graphics.rectangle("fill", 0, HEADER_H - 2, layout.width, 2)
    drawText(("%d/%d"):format(#owned, #catalog), 4, 4, 32, WHITE)

    local def = definition(state)
    local name = state.mon and (state.mon.nickname or def.name
      or state.mon.species) or "POKéMON"
    local nameLeft, nameRight = 40, layout.width - 64
    local nameW = math.max(24, nameRight - nameLeft)
    local shown = fitText(name, nameW)
    drawText(shown, nameLeft + (nameW - Font.width(shown)) / 2,
      3, nameW, WHITE)
    drawTextRight("RIBBONS", layout.width - 4, 4, 56, WHITE)
  end

  local function drawProfile(state, layout, owned)
    local x, y, w, h = layout.profileX, layout.profileY,
      layout.profileW, layout.profileH
    drawCard(x, y, w, h, true)

    local iconX, iconY = x + 6, y + 3
    local def = definition(state)
    local icons = state.game.data.icons or {}
    local entry = (icons.bySpecies and icons.bySpecies[state.mon.species])
      or def.icon
    local trueColorIcon = false
    local hgssIcon = false
    if type(entry) == "table" then
      local path = tostring(entry.image or ""):lower()
      -- Support both the pre-1.5.0 icons_original folder and 1.5.0's
      -- singular icon_original name.  Both contain palette-aware art.
      local paletteAware = path:find("icons_original", 1, true) ~= nil
        or path:find("icon_original", 1, true) ~= nil
      trueColorIcon = not paletteAware
        or PartyMenu._uniqueMenuIconsTrueColorWrapped == true
      hgssIcon = isHgssEntry(entry)
    end
    if trueColorIcon and not hgssIcon then
      local colors = PaletteFX.effectiveColors(primaryPalette(state))
      local face = colors and colors[2]
      if face then
        love.graphics.setColor(face[1] / 255, face[2] / 255,
          face[3] / 255, 1)
        love.graphics.rectangle("fill", iconX - 1, iconY - 1, 18, 18)
      end
    end
    gray(WHITE)
    local fitted = hgssIcon
      and drawFittedHgssIcon(state, entry, iconX, iconY, 18)
    if not fitted then
      local drawIcon = PartyMenu["draw" .. "Icon"]
      drawIcon(state.game, state.mon, iconX, iconY,
        setting("animate_icons", true), animationCounter(state))
    end
    if trueColorIcon and not hgssIcon then
      PaletteFX.markTrueColor(iconX - 1, iconY - 1, 18, 18)
    end

    local left = math.max(0, #catalog - #owned)
    drawText(("%d EARNED"):format(#owned), x + 29, y + 4,
      math.max(40, w - 90), BLACK)
    drawText(("%d LEFT"):format(left), x + 29, y + 13,
      math.max(40, w - 90), BLACK)
    if #owned > WINDOW_SIZE then
      local first = math.min(#owned, state.scroll + 1)
      local last = math.min(#owned, state.scroll + WINDOW_SIZE)
      drawTextRight(("%d-%d"):format(first, last), x + w - 6,
        y + 8, 48, BLACK)
    else
      drawTextRight("ALL", x + w - 6, y + 8, 32, BLACK)
    end
  end

  local function drawRibbonBadge(x, y)
    gray(BLACK)
    chamfer("fill", x, y, 18, 15, 4)
    gray(LIGHT)
    chamfer("fill", x + 2, y + 2, 14, 11, 3)
    gray(WHITE)
    love.graphics.rectangle("fill", x + 6, y + 4, 6, 5)
    gray(DARK)
    if love.graphics.polygon then
      love.graphics.polygon("fill", {
        x + 4, y + 12, x + 8, y + 12, x + 6, y + 18,
        x + 10, y + 12, x + 14, y + 12, x + 12, y + 18,
      })
    else
      love.graphics.rectangle("fill", x + 5, y + 12, 3, 6)
      love.graphics.rectangle("fill", x + 11, y + 12, 3, 6)
    end
  end

  local function drawRibbonCard(layout, slot, entry)
    local x, y, w, h = cardGeometry(layout, slot)
    drawCard(x, y, w, h, false)
    local badgeY = y + math.max(2, math.floor((h - 18) / 2))
    drawRibbonBadge(x + 5, badgeY)
    local name = (entry.label or entry.name or entry.id):upper()
    local description = tostring(entry.description or ""):upper()
    if h >= 36 then
      -- Wide two-column cards reserve the lower line for the description.
      -- It can then use the full card width instead of being squeezed beside
      -- the medal badge, keeping Kanto Ribbons' descriptions intact.
      drawText(name, x + 28, y + 7, w - 34, WHITE)
      drawText(description, x + 6, y + h - 13, w - 12, WHITE)
    else
      local textX = x + 28
      local textW = w - 34
      local nameY = y + math.max(3, math.floor((h - 17) / 2))
      drawText(name, textX, nameY, textW, WHITE)
      drawText(description, textX, nameY + 9, textW, WHITE)
    end
  end

  local function drawEmpty(layout)
    local x, y = 2, layout.cardsY
    local w, h = layout.width - 4, layout.cardsH
    drawCard(x, y, w, h, false)
    drawTextCentered("NO RIBBONS YET", x + 6,
      y + math.floor(h / 2) - 9, w - 12, WHITE)
    drawTextCentered("KEEP ADVENTURING!", x + 6,
      y + math.floor(h / 2) + 2, w - 12, WHITE)
  end

  local function drawFooter(state, layout, owned)
    gray(DARK)
    love.graphics.rectangle("fill", 0, FOOTER_Y, layout.width, 8)
    local hint = #owned > WINDOW_SIZE and layout.width >= 224
      and "UP/DOWN SCROLL    A/B BACK"
      or #owned > WINDOW_SIZE and "UP/DN    A/B BACK"
      or "A/B BACK"
    drawTextCentered(hint, 4, FOOTER_Y, layout.width - 8, WHITE)
  end

  -- The ribbon collection is a separate opaque UI screen, not a SummaryMenu
  -- page.  Replace inherited party-icon true-colour claims here as well so a
  -- same-frame handoff cannot re-blit their old rectangular pixels over the
  -- profile and ribbon cards.  The world bucket is intentionally untouched.
  local function clearInheritedUiTrueColor()
    local rects = PaletteFX.trueColorRects
      and PaletteFX.trueColorRects("ui") or nil
    if type(rects) ~= "table" then return end
    for i = #rects, 1, -1 do rects[i] = nil end
  end

  local function draw(state)
    clearInheritedUiTrueColor()
    local layout = layoutFor(state)
    local owned = ownedRibbons(state.mon)
    state.scroll = math.max(0, math.min(state.scroll or 0,
      math.max(0, #owned - WINDOW_SIZE)))
    state.modernRibbonRows = owned
    drawBackdrop(layout)
    drawHeader(state, layout, owned)
    drawProfile(state, layout, owned)
    if #owned == 0 then
      drawEmpty(layout)
    else
      for slot = 1, WINDOW_SIZE do
        local entry = owned[state.scroll + slot]
        if entry then drawRibbonCard(layout, slot, entry) end
      end
    end
    drawFooter(state, layout, owned)
    gray(WHITE)
  end

  local function update(state, dt)
    local owned = ownedRibbons(state.mon)
    local maxScroll = math.max(0, #owned - WINDOW_SIZE)
    local input = state.game and state.game.input
    if not input then return end
    if input:wasPressed("up") then
      state.scroll = math.max(0, (state.scroll or 0) - 1)
    elseif input:wasPressed("down") then
      state.scroll = math.min(maxScroll, (state.scroll or 0) + 1)
    elseif input:wasPressed("a") or input:wasPressed("b") then
      state.game.stack:pop()
    end
    state.blink = ((state.blink or 0) + 1) % 320
  end

  local function sgbPalettes(state)
    local layout = layoutFor(state)
    local owned = ownedRibbons(state.mon)
    local zones = { {
      colors = basePalette(state), x = 0, y = 0,
      w = layout.width, h = SCREEN_H,
    }, {
      colors = primaryPalette(state), x = layout.profileX,
      y = layout.profileY, w = layout.profileW, h = layout.profileH,
    } }
    for slot = 1, WINDOW_SIZE do
      local entry = owned[(state.scroll or 0) + slot]
      if entry then
        local x, y, w, h = cardGeometry(layout, slot)
        zones[#zones + 1] = {
          colors = ribbonPalette(entry), x = x, y = y, w = w, h = h,
        }
      end
    end
    return zones
  end

  return {
    new = function(game, mon)
      local state = {
        game = game,
        mon = mon,
        isOpaque = true,
        scroll = 0,
        blink = 0,
        modernPartyRibbons = true,
        modernRibbonRows = ownedRibbons(mon),
        modernRibbonLayout = "responsive_cards",
      }
      state.update = update
      state.draw = draw
      state.sgbPalettes = sgbPalettes
      state.uiSize = function(self)
        return layoutFor(self).width, SCREEN_H
      end
      state.isWideBattleLayout = function()
        return setting("responsive", true)
      end
      return state
    end,
  }
end
