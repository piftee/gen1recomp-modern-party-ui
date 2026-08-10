-- Relevant public behavior from Kanto Ribbons 0.18.0: the mod owns an
-- icon-rich standalone detail screen and wraps SummaryMenu.update so A/B on
-- the last page closes the summary and opens that screen.
return function(mod)
  local catalog = {
    { id = "STARTER", name = "Starter Ribbon", short = "Starter",
      description = "First partner." },
    { id = "HALL_OF_FAME", name = "Hall of Fame Ribbon",
      short = "Hall of Fame", description = "Champion team." },
    { id = "RARE", name = "Rare Ribbon", short = "Rare",
      description = "Flawless DVs." },
    { id = "EFFORT", name = "Effort Ribbon", short = "Effort",
      description = "Stat Exp maxed." },
    { id = "EARTH", name = "Earth Ribbon", short = "Earth",
      description = "100 solo wins." },
    { id = "COOL", name = "Cool Ribbon", short = "Cool",
      description = "A COOL contest." },
  }
  local function hasRibbon(mon, id)
    return mon and mon.ribbons and mon.ribbons[id] == true
  end

  mod.content.screens:register("KantoRibbonsDetail", {
    new = function(game, mon)
      return {
        game = game,
        mon = mon,
        isOpaque = true,
        kantoRibbonsDetail = true,
        update = function() end,
        draw = function() end,
      }
    end,
  })

  local SummaryMenu = require("src.ui.SummaryMenu")
  local vanillaSummaryUpdate = SummaryMenu.update
  SummaryMenu.update = function(self, dt)
    local input = self.game and self.game.input
    local last = self.pageCount or 2
    if input and (self.page or 1) >= last
        and (input:wasPressed("a") or input:wasPressed("b")) then
      local game, mon = self.game, self.mon
      game.stack:pop()
      mod.ui.push(game, "KantoRibbonsDetail", mon)
      return
    end
    return vanillaSummaryUpdate(self, dt)
  end

  mod.exports.version = "0.18.0"
  mod.exports.catalog = catalog
  mod.exports.hasRibbon = hasRibbon
end
