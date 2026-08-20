# Changelog

## 0.3.10 - 2026-08-20

- Fixed a v0.3.9 production crash caused by using Lua's unavailable `debug` library while collecting third-party icon colour regions.
- Added QoL Toggles 1.27.0 as an optional dependency and refreshed cached summary artwork when PARTY SCROLL changes Pokémon in place.
- Corrected responsive integer scaling on tall phone displays so party, summary and ribbon screens use the available width instead of collapsing to 160×144.
- Added production-sandbox, in-place sprite-switch and portrait-width regression coverage.

## 0.3.9 - 2026-08-20

- Fixed two-digit party levels being clipped to `LV1` when a gender marker occupied the compact level row.
- Added compatibility with Wilds of Kanto 2.1.7 and other icon renderers that publish their own true-colour regions.
- Routed third-party icon colour protection around the action popup's live dimensions, preventing tall FOLLOW, field-move and utility menus from developing grey blocks.
- Added automated and visual-preview coverage for five-row companion action menus.

## 0.3.8 - 2026-08-12

- Split the DV page into separate Special Attack and Special Defense cards whenever a compatible Special-split overhaul is active.
- Correctly reuse Crystal's single underlying Special DV for both cards while allowing distinct Special Attack and Special Defense Stat EXP values.
- Made the five-DV layout responsive from compact 160×144 through ultrawide surfaces.
- Removed the expanded safety frame behind Gender Mod markers so their protected colour occupies only the native 8×8 glyph cell.

## 0.3.7 - 2026-08-12

- Added split-Special compatibility for Crystal 251 0.10.3 through its public `crystalSummary.statsFor` interface.
- Replaced the combined Special card with separate Special Attack and Special Defense cards only when both live values are available.
- Added a generic fallback for overhaul mods that publish conventional split-stat fields such as `specialAttack`/`specialDefense` or `spAtk`/`spDef`.
- Made the five-stat layout responsive across compact 160×144, square, widescreen and ultrawide surfaces while leaving ordinary Gen I summaries unchanged.
- Added regression coverage for Crystal's recalculated values, classic-overlay suppression and generic split-stat aliases.

## 0.3.6 - 2026-08-10

- Added direct compatibility with DramaticShape 1.8.2's public shiny predicate and species-palette transform.
- Restored shiny colours to Pokémon profile artwork on the responsive stats screen without recolouring its card or surrounding UI.
- Kept ordinary Pokémon, authored true-colour sprites and Crystal Animated Sprites behavior unchanged.
- Added focused regression coverage for shiny and non-shiny summaries beside DramaticShape.

## 0.3.5 - 2026-08-10

- Added a cohesive Kanto Ribbons 0.18.0 collection screen with the same responsive header, patterned backdrop, chamfered cards and Pokémon icon handling as Modern Party UI.
- Added colourful medal cards, earned/remaining progress, ribbon names and descriptions in two-column wide and stacked compact layouts.
- Extended the public Gen1 Modern UI adapter contract so the responsive ribbon collection remains visible alongside the party and summary renderers.
- Added wide, compact, scrolling, controller and colour-zone regression coverage for the restyled collection.

## 0.3.4 - 2026-08-10

- Added a deterministic final-page handoff driven by Kanto Ribbons' public catalog and earned-state exports.
- Composed Kanto Ribbons after either the standard two summary pages or DV Tracker's third page, with matching footer guidance.
- Preserved downstream summary and Crystal animation updates while preventing duplicate or premature ribbon-screen transitions.
- Added a public Gen1 Modern UI 0.8.4 adapter contract that keeps Modern Party UI's party and summary renderers visible while allowing Gen1 Modern UI to own every other supported screen.
- Added regression coverage for Kanto Ribbons alone and together with DV Tracker, Crystal Animated Sprites, earlier screen replacements and Gen1 Modern UI suppression.

## 0.3.3 - 2026-08-10

- Added a responsive third summary page for DV Tracker 1.0.0, including HP and core-stat DVs plus Stat EXP.
- Preserved DV Tracker's native three-page A/B controller behavior while replacing only its fixed-width drawing.
- Raised presentation load priority and declared optional ordering for DV Tracker, Crystal Animated Sprites, Unique Menu Icons and Pokémon Gold & Silver Sprites.
- Replaced any earlier party or summary screen record safely, preventing duplicate-registration failures that could disable Modern Party UI in larger mod stacks.
- Added regression coverage for DV Tracker together with Crystal Animated Sprites' high-priority summary constructor and animation update wrappers.

## 0.3.2 - 2026-08-09

- Removed grey squares behind Gender Mod markers by backing their transparent pixels with the card's final type colour.
- Added matching one-pixel guards around protected gender markers, menu icons and summary artwork so outward-rounded rendering cannot reveal grey seams.
- Kept the Pokémon and gender artwork itself unchanged.

## 0.3.1 - 2026-08-09

- Added explicit compatibility with Gender Mod 0.3.5 so both mods load without competing for `PartyMenu` or `SummaryMenu`.
- Kept Modern Party UI as the responsive presentation while resolving gender, symbols and colours through Gender Mod's public exports.
- Added gender markers directly before the level on modern party cards and the stats summary.
- Preserved Gender Mod's gender locking, GENDER-OOZE, battle HUD markers, nickname screen and PC labels.
- Continued replacing baked-in Nidoran gender suffixes with the dedicated marker when both mods are enabled.

## 0.3.0 - 2026-08-09

- Rebuilt both Pokémon summary pages with the party screen's chamfered card styling, type colours, pixel backdrop and clear information hierarchy.
- Added a responsive profile rail with the live front sprite, Pokédex number, typing, original trainer and trainer ID.
- Added modern HP, status and four-stat cards to the first summary page.
- Added a labelled blue EXP meter and type-coloured move cards with PP to the second summary page.
- Made moves use a two-by-two grid on wide displays and a readable stacked layout on narrow or portrait displays.
- Grouped stat labels, values and move details around each card's visual centre on wide displays.
- Removed the coloured rectangle behind summary artwork while retaining light-coloured details enclosed inside each Pokémon's outline.
- Preserved the original A/B page flow, PC-box summaries, cry, live stats, PP Ups, custom move records, sprite replacements and true-colour sprite handling.

## 0.2.5 - 2026-08-08

- Added reference-matched primary-type colours as the default party-card style.
- Kept the original per-species palette as a separate compatibility option.
- Added matching Dark, Fairy and Steel colours for content mods.
- Strengthened the selected Pokémon with a black frame and subtly raised card face.
- Preserved OG Red/Blue/Yellow, monochrome, inverted and Classic display modes.

## 0.2.4 - 2026-08-08

- Clipped true-colour icon restoration around the action menu and its shadow.
- Removed the gray square that appeared when a colour icon overlapped the popup.

## 0.2.3 - 2026-08-08

- Centered each 16×16 Pokémon icon within its available card column.
- Moved configured HP values or percentages directly onto the HP meter.
- Added an independent EXP Display setting: values, percentage, or bar only.
- Added a native pixel-art percent sign missing from the original ROM font.
- Exposed the new EXP Display setting in the main Options menu.

## 0.2.2 - 2026-08-08

- Moved the EXP meter beneath HP and labelled it EXP (XP on compact cards).
- Gave every EXP meter the dedicated blue EXP palette.
- Aligned HP and EXP meters with the card's main text column.
- Removed gray backplates behind transparent full-colour menu icons.
- Added all seven Modern Party UI settings directly to the main Options menu.

## 0.2.1 - 2026-08-08

- Kept every Gen 1 font glyph at its native 8×8 size to prevent broken text.
- Added glyph-safe truncation for compact cards instead of fractional scaling.
- Preserved authored colour icon pixels at their responsive card positions.
- Added compatibility for Unique Menu Icons' GBC Red and Unique Colors modes.

## 0.2.0 - 2026-08-08

- Rebuilt the roster as a reference-inspired two-column card grid.
- Added responsive full-width rendering, including wide battle party screens.
- Added grid navigation and seven user-facing presentation settings.
- Routed every card through the shared menu-icon resolver for mod compatibility.
- Added EXP strips, adaptive card sizing and a modern action overlay.

## 0.1.0 - 2026-08-08

### Added

- Modern-inspired party roster drawn with the game's existing visual language.
- Selected-card highlighting, empty slots, compact HP layout and type footer.
- Compatibility coverage for standard, battle, item and TM/HM party modes.
