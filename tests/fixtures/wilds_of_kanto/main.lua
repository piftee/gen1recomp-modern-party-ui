-- Models Wilds of Kanto 2.2.0's stable follower-sprite export. Deliberately
-- does not own PartyMenu.drawIcon: the compatibility regression is the load
-- order where another mod replaces that shared renderer after Wilds loads.
return function(mod)
  mod.exports.calls = {}
  mod.exports.resolveFollowerSprite = function(opts)
    opts = opts or {}
    mod.exports.calls[#mod.exports.calls + 1] = opts
    if not opts.species then return nil end
    return {
      image = "mods/overworld_wild_spawns/assets/runtime/test/"
        .. tostring(opts.species):lower() .. ".png",
      frames = 6,
      frameWidth = 16,
      frameHeight = 16,
      trueColor = true,
      role = opts.role,
      surface = opts.surface,
    }
  end
end
