# Modern Party UI

Modern Party UI rebuilds the POKéMON party screen and both Pokémon summary
pages with responsive cards while keeping Gen 1's own font, sprites and
animated menu icons. Party and summary cards use a cohesive primary-type
palette shared with Typed Move Colors.

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
- the focused Pokémon receives a larger black frame and raised light face
- empty team slots stay visible, making the six-member structure immediately clear
- aligned HP and labelled blue EXP meters mirror newer party screens
- Pokémon icons are centred within their dedicated card column
- optional HP and EXP values or percentages sit directly on their meters
- the header shows team capacity and the focused Pokémon's types
- action menus use a centered card overlay with a highlighted action
- the UI expands horizontally to use the full available integer-scaled surface;
  wide displays get broader cards rather than a centered 160px strip
- the STATS summary page uses a responsive profile rail, HP/status card and
  four clear stat cards
- the MOVES summary page adds a labelled EXP meter and type-coloured move cards
  with current/max PP
- wide summaries arrange moves two-by-two; compact and portrait summaries stack
  them so names, type abbreviations and PP never overlap

The mod replaces presentation only. Field moves, battle switching, item targeting,
TM/HM checks, healing animations, trades, callbacks and cursor persistence are
still handled by the engine's original `PartyMenu` controller. Summary page
changes and closing remain handled by the original `SummaryMenu` controller.

## Settings

The settings appear directly in the game's ordinary **OPTIONS** screen as the
eight `PARTY` rows. They are also available from
**START → MODS → Modern Party UI → OPTIONS..**. Both locations edit the same
saved values, and changes appear the next time the party screen draws.

| Setting | Choices |
| --- | --- |
| Card Color | Type, species, health, blue, or monochrome palettes |
| HP Display | Bar only, percentage, or current/max values |
| EXP Display | Bar only, percentage, or progress/level-target values |
| EXP Strip | Show or hide progress toward the next level |
| Empty Slots | Show or hide unused party positions |
| Backdrop | Diagonal grid or plain background |
| Widescreen | Fill the available width or use classic 160×144 |
| Icon Anim | Animate the focused menu icon or hold its resting frame |

## Type palette

Type is the default card-colour setting and follows each Pokémon's live primary
type. The bold card faces use the supplied reference palette exactly:

| Type | Colour | Type | Colour | Type | Colour |
| --- | --- | --- | --- | --- | --- |
| Normal | `#9098A2` | Fighting | `#CE3F6B` | Flying | `#8FA8DE` |
| Poison | `#AB6AC8` | Ground | `#D97746` | Rock | `#C9B68B` |
| Bug | `#90C02C` | Ghost | `#5269AD` | Fire | `#FE9C55` |
| Water | `#4D90D6` | Grass | `#65BC5E` | Electric | `#F4D23B` |
| Psychic | `#F97177` | Ice | `#73CEBF` | Dragon | `#096DC3` |
| Dark | `#5B5265` | Fairy | `#EC90E7` | Steel | `#5B8EA1` |

Each colour receives a lighter selected shade while retaining the game's paper
and ink endpoints. OG Red/Blue/Yellow, monochrome, inverted and Classic display
modes still apply. Unknown or typeless custom species use Normal. Choose
**Species** to restore the engine's original per-species palettes, including
palette changes supplied by compatible sprite mods.

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

The **Species** card-colour option continues to use the engine's live Pokémon
palette lookup. The default **Type** option changes only the card surface; icon
pixels still come from the shared renderer and authored true-colour icons stay
untouched.

Mods that replace the entire `PartyMenu` screen conflict by design because two
screen implementations cannot own the same screen id. The manager reports that
conflict instead of silently choosing one.

The summary renderer uses the sprite already resolved by Gen1Recomp, including
`pokemon.sprite` hooks and content-mod sprite paths. Authored true-colour sprites
are protected from palette recolouring at their live responsive position.

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
built-in party and summary controllers. It delegates to those controllers and
overrides only their presentation and responsive surface methods; this keeps the
behavior surface deliberately small.

Another mod that also registers the `PartyMenu` or `SummaryMenu` screen id will
conflict at load time instead of silently winning.

## Distribution

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py lint modern_party_ui
python3 tools/modkit.py pack modern_party_ui -o Modern-Party-UI.zip
```

The package contains no ROM-derived assets. Source code is available under the
[MIT License](LICENSE). Pokémon and related names and imagery are trademarks of
their respective owners; this is an unofficial fan-made mod.
