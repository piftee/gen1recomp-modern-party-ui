# Changelog

## 0.4.8 - 2026-09-01

- Gen 1 TM/HM target cards now render `ABLE` and `NO` as ordinary card text
  with no badge background. Unselected cards use light text and the selected
  card uses dark text, matching the rest of each card's UI.
- Gen 2 wide party screens now accept
  Left/Right across each visible card row as well as Up/Down between rows.
  Switch and Softboiled target selection use the same two-column controls.

## 0.4.5 - 2026-08-29

- Gen 1 Psychic Pokémon now show `PSY` in the party header instead of `---`;
  the compact label accepts the engine's canonical `PSYCHIC_TYPE` identifier.
- `ICON SOURCE: MENU PACK` now resolves the icon provider that explicitly
  owns party/menu art instead of trusting a live `icons.bySpecies` table that
  a follower mod may have replaced later. Unique Menu Icons therefore remains
  selected alongside Wilds of Kanto, while `FOLLOWER PACK` still selects
  Wilds' exported follower sheets.
- HGSS Visual Overhaul 1.0.2 party sheets are now treated as menu art under
  `MENU PACK`. Their visible alpha bounds are cropped, enlarged and centred in
  the complete 32-pixel card rail rather than falling back to a tiny vanilla
  icon or scaling the padded 32x32 source canvas.

## 0.4.4 - 2026-08-28

- Added a responsive presentation adapter for FAFFO's Moves Manager 1.0.1.
  Its current-move grid, remembered-move list and all three detail pages now
  match Modern Party UI while Moves Manager remains responsible for move
  memory, PP data, HM protection, reordering and replacement callbacks.
- Prevented Gen1 Modern UI from suppressing only the Moves Manager states
  already presented by Modern Party UI. The source adapter remains unchanged
  for undecorated screens and unusual load orders.
- Moves Manager pages clear inherited UI sprite claims before drawing, avoiding
  the grey rectangles seen when menu-icon packs opened a child screen during
  the same frame.

## 0.4.3 - 2026-08-27

- Gen 2's dedicated Modern Party options page now drives its own setting rows
  instead of falling through to the cached parent Options list.

## 0.4.2 - 2026-08-27

- Gen 2's true-wide move-management screen now follows its visible 2x2 card
  grid: Left/Right cross a row and Up/Down cross a column. The native 160x144
  vertical-list controls remain unchanged.

## 0.4.1 - 2026-08-26

- Relearn now clears inherited UI-only true-colour sprite regions before its
  opaque move list is drawn, preventing custom party icons from reappearing as
  grey boxes over move cards while leaving world and voxel rendering intact.

## 0.4.0 - 2026-08-25

- Move cards on the Pokémon summary are now selectable. Press A on a learned
  move to open a responsive detail card showing its type, damage class, power,
  accuracy and current/max PP; B returns to the four-card move list.
- Rename and Relearn actions contributed by compatible QoL mods now open in
  cohesive Modern Party UI presentations while their original callbacks,
  naming rules and move-learning controllers remain in charge.
- Rename now shows the selected Pokémon's active compatible menu sprite. A
  RENAME STYLE setting keeps the faithful Gen 1 keyboard as the default and
  restores the earlier responsive Modern Party UI button grid as an option.
  Both styles keep case, DEL and END together on an arrow-navigable bottom
  command row, with A activating whichever command is selected.
- The selected Rename style now also applies when naming a newly caught,
  received or gifted Pokémon, including Pokémon sent directly to a Box.
  Player and rival naming screens keep their original presentation.
- Added an ICON SOURCE setting with Auto, Original, Menu Pack and Follower Pack
  choices. It composes with the existing ICON ANIMATION switch and gives
  players an explicit fallback when several sprite providers are installed.
- Expanded the compatibility suite to cover source selection, move-detail
  navigation and callback-backed Anytime Rename/QoL Toggles flows.
- Naming screens now clear inherited UI-only true-colour claims before drawing,
  preventing the same grey rectangles previously fixed on summary screens.

## 0.3.21 - 2026-08-24

- Large SGB summary portraits using the pale red, yellow, or brown monster
  ramps now use the stronger equivalent midtones from the bundled Advanced
  palette pack. Other SGB hues, authored true-colour sprites, and non-SGB
  display modes remain unchanged.
- Default type/species summary cards no longer leave an isolated yellow or
  orange vitals slab beside the neutral portrait. Warm SGB surfaces use the
  existing cool summary base, while cool types and explicit Health, Blue, or
  Mono colour choices keep their selected palette.

## 0.3.20 - 2026-08-24

- Summary profiles now composite and protect the complete inner card face
  instead of tracing the source sprite canvas. This removes the faint frame,
  seam, and edge stroke exposed by Android scaling in portrait and landscape
  while retaining each Pokémon's battle-selected artwork and colours.

## 0.3.19 - 2026-08-24

- Removed magnified horizontal backdrop bands between party cards on narrow
  portrait screens by keeping all six card rows on a shared native-pixel grid
  and covering their joins before the chamfered frames are drawn.
- Faithful Ratio now retains the exact classic 160x144 viewport throughout the
  party, summary and Kanto Ribbons screens instead of being replaced by the
  responsive tall-phone or widescreen canvas.
- Added regression coverage for a 360x800 portrait display, equal-height card
  joins and stale responsive renderer sizes while Faithful Ratio is locked.

## 0.3.18 - 2026-08-23

- Summary profiles now resolve the same `battle` front-sprite selection used
  in combat, removing visual mismatches caused by context-specific art mods.
- Kept responsive palette masking, shiny transforms, animated replacements,
  and in-place PARTY SCROLL refreshes on the battle-selected source artwork.
- Party icons now preserve authored colour only on opaque sprite pixels, so
  transparent canvases cannot appear as white or grey boxes with or without
  Gender Mod. Missing third-party icon assets fall back to the normal game
  icon instead of leaving an empty square.
- Wilds of Kanto party art now resolves through its exported follower-sprite
  API, so a later mod replacing the shared party-icon hook cannot make every
  card sprite disappear. Wilds' authored idle/walk frames and transparent
  padding remain intact.
- Added regression coverage for the shared battle-sprite context and for a
  late party-icon hook replacing Wilds of Kanto's renderer.

## 0.3.17 - 2026-08-23

- Added compatibility with Unique Menu Icons 1.5.0's renamed asset folders.
- ORIGINAL mode now follows the active party-card palette, while GBC RED and
  UNIQUE COLORS retain their authored colours on party and Kanto Ribbons screens.
- Added regression coverage for the new 1.5.0 asset paths and palette modes.

## 0.3.16 - 2026-08-22

- ICON ANIMATION now follows party focus: only the highlighted Pokémon moves,
  while every other visible card remains on its resting frame.
- HGSS animation follows the cursor immediately when the highlighted party
  card changes, without altering its fitted alignment or colour protection.

## 0.3.15 - 2026-08-22

- Consolidated all eight in-game settings behind one MODERN PARTY UI entry in
  Options. ICON ANIMATION is now the second row, remains ON by default and can
  be changed without opening the external mod manager.
- Added compatibility with HGSS Visual Overhaul party icons. Modern Party UI
  now measures both animation frames' visible pixels, fits their shared
  envelope into the card rail and preserves the sheet's authored internal bob.
- ICON ANIMATION now moves every visible party icon, making the enabled state
  immediately apparent; turning it off holds every icon on its resting frame.
- HGSS true-colour protection now follows opaque sprite-pixel runs, leaving
  the surrounding type-coloured card untouched instead of restoring a darker
  rectangular cell.
- Corrected the animated HGSS icon geometry: visible creatures fill a 32px
  rail on roomy cards and a 22px rail on compact cards, while remaining centred
  and clear of names, gender markers, HP labels and meters.
- Applied the same shared-frame visible-pixel fit to Kanto Ribbons profiles,
  fixing the low sprite, preserving its animation and removing the large grey
  restored rectangles.
- Unified direct and Bag-opened party screens on portrait displays. Both now
  use the same full-height, one-column phone layout with no resize or black void.

## 0.3.14 - 2026-08-22

- Fixed the party target picker jumping back to a short 144-pixel surface when
  an item was used from Modern Bag UI on a portrait phone.
- Made the party backdrop, cards, footer and colour regions fill the Bag's
  inherited responsive surface until item targeting finishes.
- Stacked the six target cards vertically on that portrait surface so names,
  HP and EXP remain readable at phone width.
- Kept battle and summary screen sizing unchanged.

## 0.3.13 - 2026-08-21

- Fixed QoL Toggles' RENAME flow freezing when Gen1 Modern UI 0.9.2's Menu UI
  presenter was enabled by leaving the child NamingScreen source-owned.
- Updated the Gen1 Modern UI compatibility fixture from 0.8.4 to 0.9.2 and
  added the real QoL Toggles 1.27.0 RENAME transition as regression coverage.

## 0.3.12 - 2026-08-20

- Fixed inherited true-colour party-icon rectangles leaking onto the Kanto
  Ribbons collection during the final summary-page handoff.

## 0.3.11 - 2026-08-20

- Fixed grey true-colour rectangles leaking from Unique Menu Icons onto the
  responsive stats and moves pages during same-frame screen transitions.
- Added verified Anytime Rename 1.2.1 ordering and naming-screen flow coverage.

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
