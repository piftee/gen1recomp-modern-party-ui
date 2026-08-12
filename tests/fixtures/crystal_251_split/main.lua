-- Crystal 251 0.10.3's public summary contract. The released mod also wraps
-- SummaryMenu.draw with its classic five-row overlay; Modern Party UI must
-- consume statsFor while retaining sole ownership of the responsive drawing.
return function(mod)
  local SummaryMenu = require("src.ui.SummaryMenu")
  local originalDraw = SummaryMenu.draw
  local calls = { statsFor = 0 }

  SummaryMenu.draw = function(self)
    local result = originalDraw(self)
    self.crystal251ClassicSplitDrawn = true
    return result
  end

  mod.exports.crystalSummary = {
    statsFor = function(menu)
      calls.statsFor = calls.statsFor + 1
      local mon = menu and menu.mon
      if not mon then return nil end
      if mon.crystal251Stats then return mon.crystal251Stats end
      local stats = mon.stats
      if stats and stats.specialAttack and stats.specialDefense then
        return stats
      end
      return nil
    end,
  }
  mod.exports.fixtureCalls = calls
end
