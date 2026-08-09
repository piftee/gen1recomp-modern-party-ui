-- Minimal contract fixture for Gender Mod 0.3.5. The real mod registers
-- complete classic party and summary screens, then publishes these helpers.
-- Modern Party UI must replace those two presentation records while reading
-- gender exclusively through the public exports below.
return function(mod)
  local PartyMenu = require("src.ui.PartyMenu")
  local SummaryMenu = require("src.ui.SummaryMenu")

  mod.content.screens:register("PartyMenu", {
    new = function(game, opts) return PartyMenu.new(game, opts) end,
  })
  mod.content.screens:register("SummaryMenu", {
    new = function(game, mon) return SummaryMenu.new(game, mon) end,
  })

  mod.exports.calls = { gender = 0, symbol = 0, palette = 0 }
  mod.exports.genderOf = function(mon)
    mod.exports.calls.gender = mod.exports.calls.gender + 1
    return mon and mon.gender_mod or nil
  end
  mod.exports.symbol = function(gender)
    mod.exports.calls.symbol = mod.exports.calls.symbol + 1
    return ({ M = "♂", F = "♀" })[gender] or "⚲"
  end
  mod.exports.palette = function(gender)
    mod.exports.calls.palette = mod.exports.calls.palette + 1
    if gender == "M" then return { 32 / 255, 104 / 255, 224 / 255, 1 } end
    if gender == "F" then return { 248 / 255, 72 / 255, 152 / 255, 1 } end
    return { 0, 0, 0, 1 }
  end
end
