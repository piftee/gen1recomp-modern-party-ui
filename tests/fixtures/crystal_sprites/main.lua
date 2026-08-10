-- The public Crystal Animated Sprites 1.5 contract relevant to summaries:
-- wrap SummaryMenu.new to install a live true-colour frame and wrap update to
-- advance it. Modern Party UI must call both live class methods even though it
-- owns the responsive instance renderer.
return function(mod)
  local SummaryMenu = require("src.ui.SummaryMenu")
  local originalNew = SummaryMenu.new
  local originalUpdate = SummaryMenu.update

  function SummaryMenu.new(game, mon)
    local summary = originalNew(game, mon)
    summary.crystalAnimatedSprite = true
    summary.spriteTrueColor = true
    return summary
  end

  function SummaryMenu:update(dt)
    self.crystalUpdateCalls = (self.crystalUpdateCalls or 0) + 1
    return originalUpdate(self, dt)
  end

  mod.exports.fixtureLoaded = true
end
