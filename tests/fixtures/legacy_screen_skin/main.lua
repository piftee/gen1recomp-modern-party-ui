-- An unrecognized presentation mod that claims both complete screen records.
-- Modern Party UI should replace these records safely instead of failing its
-- own load with a duplicate-registration error.
return function(mod)
  local PartyMenu = require("src.ui.PartyMenu")
  local SummaryMenu = require("src.ui.SummaryMenu")
  mod.content.screens:register("PartyMenu", {
    new = function(game, opts) return PartyMenu.new(game, opts) end,
  })
  mod.content.screens:register("SummaryMenu", {
    new = function(game, mon) return SummaryMenu.new(game, mon) end,
  })
end
