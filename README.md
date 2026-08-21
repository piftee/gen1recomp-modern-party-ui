# Modern Party UI

Modern Party UI rebuilds the POKéMON party screen and the built-in Pokémon
summary pages with responsive cards while keeping Gen 1's own font, sprites
and animated menu icons. Compatible information mods can add another modern
summary page. Party and summary cards use a cohesive primary-type palette
shared with Typed Move Colors.

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
  four clear stat cards—or five when a compatible mod splits Special Attack
  and Special Defense
- the MOVES summary page adds a labelled EXP meter and type-coloured move cards
  with current/max PP
- when DV Tracker is installed, a third responsive DVS page shows HP and core
  stat DVs together with their Stat EXP
- when Kanto Ribbons is installed, the final summary page leads into a fully
  responsive ribbon collection with colourful medal cards, earned progress,
  Pokémon icon, names and descriptions
- wide summaries arrange moves two-by-two; compact and portrait summaries stack
  them so names, type abbreviations and PP never overlap

The mod replaces presentation only. Field moves, battle switching, item targeting,
TM/HM checks, healing animations, trades, callbacks and cursor persistence are
still handled by the engine's original `PartyMenu` controller. Summary page
changes remain handled by the composed `SummaryMenu` controller; the final
Kanto Ribbons handoff is added without replacing its ribbon screen.

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
backgrounds intact when they overlap a colour icon. Third-party colour claims
made inside the shared icon renderer follow the same popup-aware path. This
keeps the taller FOLLOW and utility menus supplied by **Wilds of Kanto 2.1.7**
free of unshaded grey blocks.

The **Species** card-colour option continues to use the engine's live Pokémon
palette lookup. The default **Type** option changes only the card surface; icon
pixels still come from the shared renderer and authored true-colour icons stay
untouched.

Gender Mod 0.3.5 is an explicit exception to full-screen conflicts. When both
mods are enabled, Modern Party UI owns the responsive party and summary
presentation and reads each Pokémon's gender, marker and marker colour through
Gender Mod's public exports. Gender locking, GENDER-OOZE, battle markers,
nickname handling and PC labels remain owned by Gender Mod.

DV Tracker 1.0.0 is also composed explicitly. Its native three-page controller
remains responsible for advancing and closing the summary, while Modern Party
UI renders its DV and Stat EXP data as responsive cards on page three.

Kanto Ribbons 0.18.0 composes after the final available summary page. Without
DV Tracker the flow is **STATS → MOVES → RIBBONS**; with it the flow is
**STATS → MOVES → DVS → RIBBONS**. Kanto Ribbons remains authoritative for
the catalog, earned state and selected Pokémon, while Modern Party UI presents
those public exports as the same patterned, chamfered card interface as the
party and summary screens. Four ribbon cards remain visible at once, scrolling
one ribbon at a time; wide surfaces use two columns and compact surfaces stack the
cards. A small controller bridge makes the page order reliable even if another
mod replaced the update method Kanto Ribbons originally wrapped.

Gen1 Modern UI 0.9.2 is supported through its public `gen1ModernUi` adapter
contract. It explicitly leaves Modern Party UI's custom party and summary
renderers visible—including submenus, DV data and the responsive ribbon
collection—while it continues presenting every other supported menu. Naming
opened from a party action also remains native so QoL Toggles' **RENAME** flow
stays interactive. Its **HIDE ORIGINAL UI** setting can remain enabled.

Modern Party UI loads after the known menu and sprite presentation mods and
safely replaces an existing `PartyMenu` or `SummaryMenu` record instead of
failing on a duplicate registration. Menu-icon, sprite and data-only Pokémon
mods continue to compose through the shared engine helpers. An unknown mod
whose entire behavior exists only inside its own replacement screen still
needs a dedicated adapter before that behavior can appear in the modern UI.

The summary renderer uses the live sprite already resolved by Gen1Recomp,
including `pokemon.sprite` hooks, content-mod sprite paths and the frame swaps
performed by Crystal Animated Sprites with Shiny Visuals 1.5. Authored
true-colour sprites are protected from palette recolouring at their live
responsive position.

DramaticShape 1.8.2 shinies are supported through that mod's public
`exports.lib` interface. Modern Party UI asks DramaticShape whether the
selected Pokémon is shiny and applies its species-specific shiny transform to
the profile artwork only. The responsive card, type colour and surrounding
text keep their Modern Party UI palette, and ordinary Pokémon are unchanged.

Crystal 251 0.10.3's Special split is supported through its public
`exports.crystalSummary.statsFor` interface. Its recalculated Special Attack
and Special Defense values appear as separate modern stat cards, with the
fifth card reflowing for compact, square and wide screens. When DV Tracker is
also installed, its DV page likewise shows separate Special Attack and Special
Defense cards. Crystal correctly supplies the same underlying Special DV to
both derived stats, while distinct Special Stat EXP values are shown when
available. Other overhaul mods
receive the same presentation when they expose both conventional split-stat
fields (`specialAttack`/`specialDefense`, `spAtk`/`spDef`, and common naming
variants). If both values are not available, the normal combined Gen I Special
card remains unchanged.

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

Gender Mod 0.3.5, DV Tracker 1.0.0, Kanto Ribbons 0.18.0, Gen1 Modern UI
0.9.2, Crystal 251 0.10.3, QoL Toggles 1.27.0, DramaticShape, Crystal Animated
Sprites with Shiny Visuals, Unique Menu Icons, Anytime Rename 1.2.1, Wilds of
Kanto and Pokémon Gold & Silver Sprites are listed as optional dependencies so
their controller, adapter, stat, art, submenu and icon contributions initialize
first. Modern
Party UI then takes presentation ownership of only its own screens while
continuing to use their live controller methods, exports, sprite frames and
icon records.

The reported Gen1Recomp 0.1.75 stack on Windows 10 was also audited. Dramatic
Shape Voxel, Battle EXP Bar, FireRed/LeafGreen Music, cry replacements and
Running Shoes do not register the party or summary screens; their battle,
audio and movement hooks remain outside this mod's presentation surface.

## Distribution

From the Gen1Recomp repository root:

```sh
python3 tools/modkit.py lint modern_party_ui
python3 tools/modkit.py pack modern_party_ui -o Modern-Party-UI.zip
```

The package contains no ROM-derived assets. Source code is available under the
[MIT License](LICENSE). Pokémon and related names and imagery are trademarks of
their respective owners; this is an unofficial fan-made mod.
