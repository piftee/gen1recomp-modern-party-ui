# Modern Party UI

Modern Party UI rebuilds the POKéMON party screen as a responsive two-column
card grid while keeping Gen 1's own font, animated menu icons and palettes.

**Persona: the nostalgic modernizer.** It is for players who want the clearer
information hierarchy of newer Pokémon games without importing art from a
different generation or making the screen feel detached from Pokémon Red.

## Install

1. Download the `.zip` from the
   [latest release](https://github.com/piftee/gen1recomp-modern-party-ui/releases/latest).
2. Open Gen1Recomp and select **MODS → Import mod .zip**. You can also drag the
   downloaded ZIP onto the launcher window on desktop.
3. Enable **Modern Party UI**, then open your game.

The ZIP contains only the mod. You still need your own legally obtained Pokémon
Red, Blue, or Yellow ROM imported into
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).

## What changes

- the six party positions form two columns of chamfered, palette-tinted cards
- left/right/up/down navigation follows the visible grid
- the focused Pokémon receives a bright inset selection treatment
- empty team slots stay visible, making the six-member structure immediately clear
- aligned HP and labelled blue EXP meters mirror newer party screens
- Pokémon icons are centred within their dedicated card column
- optional HP and EXP values or percentages sit directly on their meters
- the header shows team capacity and the focused Pokémon's types
- action menus use a centered card overlay with a highlighted action
- the UI expands horizontally to use the full available integer-scaled surface;
  wide displays get broader cards rather than a centered 160px strip

The mod replaces presentation only. Field moves, battle switching, item targeting,
TM/HM checks, healing animations, trades, callbacks and cursor persistence are
still handled by the engine's original `PartyMenu` controller.

## Settings

The settings appear directly in the game's ordinary **OPTIONS** screen as the
eight `PARTY` rows. They are also available from
**START → MODS → Modern Party UI → OPTIONS..**. Both locations edit the same
saved values, and changes appear the next time the party screen draws.

| Setting | Choices |
| --- | --- |
| Card Color | Species, health, blue, or monochrome palettes |
| HP Display | Bar only, percentage, or current/max values |
| EXP Display | Bar only, percentage, or progress/level-target values |
| EXP Strip | Show or hide progress toward the next level |
| Empty Slots | Show or hide unused party positions |
| Backdrop | Diagonal grid or plain background |
| Widescreen | Fill the available width or use classic 160×144 |
| Icon Anim | Animate the focused menu icon or hold its resting frame |

## Other sprite mods

The mod never loads a Pokémon icon path itself. Every card calls the engine's
shared party-icon renderer, so these all continue to work:

- `icons.bySpecies` registrations, including newly added species
- a Pokémon record's `icon` override
- runtime `pokemon.icon` hooks for selectable skins
- asset overrides and the original HP-dependent icon animation

Authored replacement images are also protected from the card palette at their
actual responsive positions. This preserves **Unique Menu Icons** in GBC Red
and Unique Colors modes. Its ORIGINAL icon set remains palette-aware, as that
mod intends. Transparent pixels are backed with the card's final display
colour, so true-colour protection does not introduce a gray icon square. The
same protection is clipped beneath the action menu, keeping popup text and
backgrounds intact when they overlap a colour icon.

Mods that replace the entire `PartyMenu` screen conflict by design because two
screen implementations cannot own the same screen id. The manager reports that
conflict instead of silently choosing one.

## Develop it

Clone this repository into the `mods` directory of a Gen1Recomp checkout:

```sh
git clone https://github.com/piftee/gen1recomp-modern-party-ui.git \
  mods/modern_party_ui
```

From the Gen1Recomp repository root, validate and test it with:

```sh
python3 tools/modkit.py validate modern_party_ui --base auto
luajit mods/modern_party_ui/tests/modern_party_ui_test.lua
love . --developer
```

Import a legally obtained canonical US Red, Blue or Yellow ROM on first launch.
Open **POKéMON** from the Start menu. While developing, press **F5** to reload.

## Compatibility

This mod declares `engine_internals` because the public UI kit does not expose the
built-in party controller. It delegates to that controller and overrides only
`draw` and `sgbPalettes`; this keeps the behavior surface deliberately small.

Another mod that also registers the `PartyMenu` screen id will conflict at load
time instead of silently winning.

## Distribution

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py lint modern_party_ui
python3 tools/modkit.py pack modern_party_ui -o Modern-Party-UI.zip
```

The package contains no ROM-derived assets. Source code is available under the
[MIT License](LICENSE). Pokémon and related names and imagery are trademarks of
their respective owners; this is an unofficial fan-made mod.
