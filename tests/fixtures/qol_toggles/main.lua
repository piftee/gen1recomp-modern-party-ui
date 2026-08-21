-- Relevant public behavior from QoL Toggles 1.27.0: append RENAME to the
-- party submenu and push the engine's standard NamingScreen from its callback.
return function(mod)
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    out[#out + 1] = {
      id = "RENAME",
      label = "RENAME",
      onSelect = function(selected, selectedGame)
        local target = selected or mon
        local activeGame = selectedGame or game
        mod.ui.push(activeGame, "NamingScreen", {
          title = "NICKNAME?",
          maxLen = 10,
          default = target.nickname,
          onDone = function(name) target.nickname = name end,
        })
      end,
    }
    return out
  end)
end
