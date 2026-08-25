-- Relevant public behavior from QoL Toggles: append utility actions to the
-- party submenu while keeping the actual naming and relearn callbacks owned
-- by the source mod.
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
    out[#out + 1] = {
      id = "RELEARN",
      label = "RELEARN",
      onSelect = function(selected, selectedGame)
        local target = selected or mon
        local activeGame = selectedGame or game
        local Menu = require("src.ui.Menu")
        activeGame.stack:push(Menu.new(activeGame, {
          { label = "GUST", onSelect = function()
              target.relearnedMove = "GUST"
            end },
          { label = "WATERFALL", onSelect = function()
              target.relearnedMove = "WATERFALL"
            end },
        }, { cancelable = true }))
      end,
    }
    return out
  end)
end
