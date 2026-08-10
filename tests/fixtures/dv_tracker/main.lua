-- Minimal behavioral contract for DV Tracker 1.0.0. The released mod patches
-- the native SummaryMenu controller so A or B advances through a third page,
-- then supplies a classic renderer for that page. Modern Party UI must retain
-- the controller behavior while replacing that third renderer responsively.
return function(mod)
  local SummaryMenu = require("src.ui.SummaryMenu")
  local originalDraw = SummaryMenu.draw

  SummaryMenu.update = function(self)
    local input = self.game.input
    if input:wasPressed("a") or input:wasPressed("b") then
      if self.page == 1 then
        self.page = 2
      elseif self.page == 2 then
        self.page = 3
      else
        self.game.stack:pop()
      end
    end
  end

  SummaryMenu.draw = function(self)
    if self.page < 3 then return originalDraw(self) end
    self.dvTrackerClassicDrawn = true
  end

  mod.exports.fixtureLoaded = true
end
