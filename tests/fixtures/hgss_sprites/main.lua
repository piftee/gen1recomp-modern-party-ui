-- Relevant behavior from HGSS Visual Overhaul 1.0.2: its shared party icon
-- renderer draws native 32x32 artwork and protects that complete rectangle.
return function(mod)
  local PartyMenu = require("src.ui.PartyMenu")
  local PaletteFX = require("src.render.PaletteFX")
  mod.exports.calls = {}
  PartyMenu.drawIcon = function(_, mon, x, y, selected, counter)
    local speed = 5
    local frame = selected and math.floor((counter or 0) / speed) % 2 or 0
    mod.exports.calls[#mod.exports.calls + 1] = {
      species = mon.species,
      x = x,
      y = y,
      selected = selected == true,
      counter = counter or 0,
      frame = frame,
    }
    PaletteFX.markTrueColor(x, y, 32, 32)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x + frame, y, 32, 32)
    return true
  end
end
