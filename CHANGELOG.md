# Changelog

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
