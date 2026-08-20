-- Relevant public behavior from Anytime Rename 1.2.1: add a party action
-- whose callback pushes the native Gen 1 naming screen.
return function(mod)
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    out[#out + 1] = {
      label = "NICKNAME",
      onSelect = function(selected, selectedGame)
        local target = selected or mon
        local activeGame = selectedGame or game
        mod.ui.push(activeGame, "NamingScreen", {
          title = "NICKNAME?",
          maxLen = 10,
          default = target.nickname or target.species,
          onDone = function(name) target.nickname = name end,
        })
      end,
    }
    return out
  end)
end
