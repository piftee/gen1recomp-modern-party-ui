-- Relevant public contract from Unique Menu Icons 1.5.0: the mod owns party
-- icon contributions while follower packs remain free to own overworld art.
return function(mod)
  mod.exports.ownsPartyIcons = true
  for _, species in ipairs({ "FIXMON_A", "FIXMON_B", "FIXMON_C" }) do
    mod.content.icons:override(species, {
      image = "mods/unique_menu_icons/assets/icon_color/"
        .. species .. ".png",
      frames = 2,
    })
  end
end
