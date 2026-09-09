# Moonie – How the addon works

This file is the central overview. **Update this file after every change to
the addon.** If anything is unclear in the next chat: check here first.

Current version: **0.12**. 7 priority rules (rotation column, far right) -
only the single highest-priority icon is shown, with a glow around it,
a color-coded range number above it (with a "y" suffix and a semi-
transparent grey backdrop for readability), and a red tint on the icon
if the target is out of spell range - + status grid on the left (3x3:
Faerie Fire/Moonfire/Insect Swarm, Owlkin Frenzy) + two small Arcane/
Nature icons right next to it (own area, see below) + minimap button
with dropdown menu, a click-through toggle, and a right-click show/hide
switch for the whole addon (Faerie Fire tracking, click-through, and
hidden state are all saved and survive a relog). The whole addon
disables itself on login if the character isn't a Druid. Not yet tested
in-game.

---

## What does the addon do?

Three areas, left to right:

- **Left (status grid, 3x3 cells, columns 0-2):** ALWAYS shows the current
  state, independent of the rotation. Never disappears (unless turned off
  or not talented, see below), only changes color/number/bar.
  - Row 1, Column 0: **Faerie Fire** status on the target (no matter who
    cast it; bar+timer only if I cast it)
  - Row 1, Column 1: **Moonfire** duration on the target (my DoT)
  - Row 1, Column 2: **Insect Swarm** duration on the target (my DoT)
  - Row 3, Column 2: **Owlkin Frenzy** status (only visible if the talent
    is invested)
- **Middle (small icons, columns 3+4, row 3):** the two Eclipse status
  icons, smaller and with their own bar layout (see the detail section
  below). Column 3 = Arcane, Column 4 = Nature. Positioned close to the
  3x3 grid (`GRID_TO_ECLIPSE_GAP` in `Display.lua`) so the two areas read
  as one connected group.
- **Right (rotation column, "column 5"):** shows a SINGLE icon with a
  glow/halo around it - the next spell to cast, based on the 7 fixed
  rules, re-checked every 0.1 sec. Only the highest-priority rule that is
  currently true gets shown (not a stack of every true rule). The icon row
  is the same height as the status grid on the left, so everything lines
  up. Directly above that icon, a number shows the live distance to your
  target in yards (needs the **UnitXP** DLL/addon - see below), color-coded
  by range. If the target is out of range for the current top-priority
  spell, the icon itself is tinted red.
- **Minimap button** (top-left edge of the minimap, Owlkin Frenzy icon):
  - Left-click: opens the dropdown menu (Faerie Fire tracking on/off,
    click-through windows on/off)
  - Right-click: shows/hides the WHOLE addon (both windows disappear
    completely and stop updating - an on/off switch for the addon).
    Right-click again to bring it back.
  - All settings (Faerie Fire tracking, click-through, hidden state) are
    saved in `MoonieDB` and restored automatically the next time you log in.

## Files and what they do

| File | Job |
|---|---|
| `Moonie.toc` | Tells WoW which files to load (order matters!) |
| `Core.lua` | Icon paths, spell IDs, Nampower check, tooltip duration scanner, saved settings (`MoonieDB`) |
| `EnemyTracking.lua` | Tracks: "did I put Insect Swarm/Moonfire/Faerie Fire on my target?" + "is Faerie Fire on the target at all (no matter who cast it)?" |
| `SelfAuras.lua` | Checks my own buffs/debuffs (Eclipse/Solstice) by icon texture |
| `OwlkinFrenzy.lua` | Determines talent rank, detects the buff, calculates cooldown until the next possible proc |
| `Priority.lua` | The 7 rules + status query functions for the grid + duplicate removal |
| `Display.lua` | Rotation column (single icon + glow) AND status grid (3x3 with bars) |
| `Minimap.lua` | Minimap button, dropdown menu, click-through toggle |

Every global name in the code starts with `Moonie` (e.g. `Moonie`,
`Moonie_EvaluateRules`, `MoonieDisplay`). Important: the folder name, the
.toc file name (`Moonie.toc`), and the `## Title:`/ADDON_LOADED check in
`Core.lua` all have to say "Moonie", or WoW won't load the addon correctly.

## Flow (rough overview)

1. `EnemyTracking.lua` listens for the Nampower event `SPELL_GO_SELF`. If
   I hit with Insect Swarm, Moonfire, or Faerie Fire, the start time +
   duration get saved for that target's GUID. Additionally, its own poll
   frame checks every 0.2s with plain `UnitDebuff("target", ...)` whether
   Faerie Fire is on the target AT ALL (no matter who cast it - normal
   vanilla API, no Nampower needed for that).
2. `SelfAuras.lua` checks my own buffs/debuffs every 0.2s and recognizes
   the 4 special auras (Nature Eclipse, Arcane Eclipse, Natural Solstice,
   Arcane Solstice) by their icon texture.
3. `OwlkinFrenzy.lua`:
   - determines on login and on talent point changes how many points are
     invested in "Owlkin Frenzy" (`Moonie_ScanOwlkinTalent()`).
   - checks every 0.2s whether the buff is active on me (same trick as
     SelfAuras.lua), remembers the start time (= also the starting point
     for the cooldown until the next possible proc).
4. `Priority.lua`:
   - `Moonie_GetDotStatus()` returns remaining time + duration for Insect
     Swarm/Moonfire on the current target (for status grid row 1).
   - `Moonie_GetEclipseStatus()` returns remaining time + duration for all
     4 self auras (for status grid row 3).
   - `Moonie_EvaluateRules()` checks on every update: "which of the 7
     rules are currently true?" and returns the list for the rotation
     column.
5. `Display.lua`:
   - Rotation column: takes the rule list, picks the FIRST (= highest
     priority) rule that is true, and shows only that one icon with a
     glow around it. Everything else is hidden.
   - Status grid: updates every cell directly from the status query
     functions (`Moonie_GetDotStatus()`, `Moonie_GetEclipseStatus()`,
     `Moonie_GetFaerieFireStatus()`, `Moonie_GetOwlkinStatus()`). The
     Faerie Fire cell is hidden completely if disabled in the minimap
     menu. The Owlkin cell is hidden completely if the talent isn't
     invested.
6. `Minimap.lua`: button at the minimap edge, left-click opens the
   dropdown menu (writes to `MoonieDB.trackFaerieFire` and
   `MoonieDB.clickThrough`), right-click shows/hides the whole addon via
   `Moonie_ToggleHidden()` (writes to `MoonieDB.hidden`, so the state
   survives a relog). `Display.lua`'s update loop checks `Moonie.hidden`
   every tick and skips all work while hidden.

## The 7 priority rules (rotation column, top = most important)

1. **Insect Swarm** – if (Swarm not on target AND no Eclipse running)
   OR (Nature Eclipse running with <2s left AND Swarm missing/has <12s left)
2. **Moonfire** – if (Moonfire not on target AND no Eclipse running)
   OR (Arcane Eclipse running with <3.5s left AND Moonfire missing/has <12s left)
3. **Starfire** – if Arcane Eclipse (buff on me) is running
4. **Wrath** – if Nature Eclipse (buff on me) is running
5. **Starfire** – if Natural Solstice (debuff on me) is active
6. **Wrath** – if Arcane Solstice (debuff on me) is active
7. **Wrath (dump spell)** – if NONE of the 4 Eclipse/Solstice auras is
   active. Just spam Wrath to try to proc an Eclipse.

**Duplicates:** Starfire can come from rule 3 OR 5, Wrath from rule 4, 6,
OR 7. If more than one rule in the same group is true, only the one with
the lower number (= higher priority) stays visible. **Only the single
highest-priority true rule overall is ever shown** as the rotation icon -
not a stack of several icons.

## Status grid (left, 3x3 cells) – details

Runs completely independent of the 7 rules above. Every cell has an icon
and a thin bar underneath. The bar always fills from the left, so it looks
like it empties from right to left as the remaining time counts down
(normal StatusBar behavior, no trick needed).

**Countdown numbers (applies to ALL cells in the grid):** normally white
and a whole number (e.g. "12"). Once the remaining time drops below 5
seconds, the number turns **red** and shows one decimal place (e.g. "4.9",
"4.8", ... "0.1"). The font is a bit bigger than the normal default font.

**Row 1, Columns 1+2 (Moonfire / Insect Swarm) – 2 states:**
- Debuff running: icon bright, number = remaining time in the middle, bar
  **blue**, runs from full to empty (duration down to 0).
- Debuff not running: icon grey, no text, bar grey and static (no time to
  show).

**Row 1, Column 0 (Faerie Fire) – 3 states:**

Unlike Moonfire/Insect Swarm: Faerie Fire is also detected if ANOTHER
player cast it (plain vanilla API shows every debuff on the target, no
matter who cast it). Only the remaining-time display (bar+number) needs
it to have been ME (needs Nampower, same as Moonfire/Insect Swarm).
- **I cast it:** icon bright, number = remaining time, bar **purple**.
- **It's on the target, but not from me:** icon bright, but bar grey and
  no text (we don't know the remaining time for sure, since it wasn't my cast).
- **Not on the target:** icon grey, bar grey and static.

Can be hidden entirely via the minimap button (left-click → uncheck
"Track Faerie Fire"). Stored in `MoonieDB.trackFaerieFire` (saved setting,
survives a relog).

**Arcane/Nature icons (columns 3+4, row 3) – own layout, 3 parts per cell:**

IMPORTANT: The two Solstice debuffs are CROSS-linked with the Eclipse
buffs (game mechanic) - NOT with the buff of the same name:
- Arcane Eclipse (buff) AND Natural Solstice (debuff) ALWAYS start at the
  same time. While it's active, Natural Solstice prevents Nature Eclipse
  from being able to proc.
- Nature Eclipse (buff) AND Arcane Solstice (debuff) ALWAYS start at the
  same time. While it's active, Arcane Solstice prevents Arcane Eclipse
  from being able to proc.

Each of the two cells (Arcane = column 3, Nature = column 4, mirrored)
consists of 3 parts, each updated separately:

1. **Icon + number in the middle** (28x28px, smaller than the rest of the
   grid):
   - Eclipse (buff) active: icon bright, number = Eclipse remaining time.
   - Eclipse over, but the cross-linked Solstice debuff still active: icon
     slightly translucent + tinted red, number = Solstice remaining time.
   - Neither Eclipse nor Solstice active: icon slightly translucent +
     grey, no text.
2. **Bar UNDER the icon** (thin, like the rest of the grid): shows ONLY the
   Solstice debuff. Red + counts down while the cross-linked Solstice is
   active on me. Otherwise steady grey (also while the Eclipse itself is
   running - no Solstice is active yet at that point, that only comes
   afterward).
3. **Bar ABOVE the icon** (as wide as the icon, reaches up to the top edge
   of row 1): only visible while the Eclipse (buff) itself is active - blue
   for Arcane, green for Nature. Runs empty as the 15 seconds count down.
   The fill is slightly see-through (75% opacity) rather than a fully
   solid block of color. As soon as the Eclipse ends, this bar disappears
   completely (not grey, not red - just gone), regardless of whether a
   Solstice is currently running or not.

The "only appears after the Eclipse ends" timing on the Solstice bar
happens automatically: the remaining time is always calculated from the
debuff's real start time + duration (`GetRemaining()` in `Priority.lua`),
so no extra code was needed - it just had to be wired to the correct
Solstice debuff for the correct cell in `Display.lua` (see change history
below).

**Row 3, Column 2 (Owlkin Frenzy) – 3 states:**

Owlkin Frenzy is a Balance talent (0-3 points). The cell is completely
**hidden** as long as 0 points are invested. Once at least 1 point is
talented, it appears with 3 possible states:
- **Buff active** (the proc is currently running): icon bright, number =
  remaining time, bar **orange**.
- **Cooldown** (buff is over, but can't proc again yet): icon slightly
  translucent + red, number = remaining time until the next possible
  proc, bar **red**.
- **Ready** (cooldown over, no buff active): icon grey, no text, bar grey
  and static.

The cooldown starts when the buff APPEARS (not when it ends) and depends
on the invested talent points:

| Talent points | Cooldown |
|---|---|
| 0 | Cell hidden |
| 1 | 30 seconds |
| 2 | 25 seconds |
| 3 | 20 seconds |

## Range display (rotation icon) - details

Shown directly above the single rotation icon (needs the **UnitXP**
DLL/addon installed - if it's missing, this number just stays hidden,
nothing else breaks). Updated every 0.1 sec together with the rotation
icon itself. Format: one decimal place plus a "y" suffix for clarity,
e.g. "23.4y". Sits on a small semi-transparent black backdrop (50%
opacity, reads as soft grey) so it stays readable over any background.

Color by distance to target (in yards):

| Range | Color |
|---|---|
| 0 - 10 | light blue (melee) |
| 10.1 - 20 | yellow |
| 20.1 - 30 | green |
| 30.1 - 36 | orange |
| 36.1+ | red |

**Out-of-range icon tint:** instead of assuming a fixed range, this asks
the game itself. On login (and whenever the spellbook changes),
`Moonie_ScanRotationSpellSlots()` (`Core.lua`) finds each rotation
spell's spellbook slot by matching its icon texture. Every update, the
current top-priority spell's slot gets checked with the native
`IsSpellInRange(slot, "spell", "target")` API - if the target is out of
range, the icon turns red. This is always correct no matter how many
points are in **Nature's Reach** (extends range to 33/36 yards) or any
other range talent, including after a respec - nothing needs to be
updated by hand. Doesn't need UnitXP at all (native API), so this part
keeps working even if UnitXP isn't installed.

## Minimap button

Top-left edge of the minimap, shows the Owlkin Frenzy icon. The ring
around the button uses the standard minimap-button positioning values
(31x31 button, 53x53 ring anchored at the button's TOPLEFT with no
offset, icon inset at 7,-5) - the ring texture itself isn't centered
within its own canvas, so any other anchoring makes it look offset from
the icon.

- **Left-click:** opens a dropdown menu with two options:
  - "Track Faerie Fire" (checkbox) - controls `MoonieDB.trackFaerieFire` -
    only affects the Faerie Fire cell (row 1, column 0), nothing else.
  - "Click-through windows" (checkbox) - controls `MoonieDB.clickThrough` -
    both main windows stop reacting to the mouse (no more dragging, but
    also no accidental clicks) when on.
- **Right-click:** toggles `Moonie.hidden` (`Moonie_ToggleHidden()` in
  `Minimap.lua`). When hidden: both main windows (rotation column +
  status grid) disappear completely and the update loop in `Display.lua`
  stops doing any work each tick. Right-click again to bring it back. A
  chat message confirms which state is now active. Saved in
  `MoonieDB.hidden` and restored on the next login - if you hid the
  addon, it stays hidden after a relog too.

## Icons (located in `Interface\Icons\`)

| What | File |
|---|---|
| Insect Swarm | `Spell_Nature_InsectSwarm` |
| Moonfire | `Spell_Nature_StarFall` |
| Wrath | `Spell_Nature_AbolishMagic` |
| Starfire | `Spell_Arcane_Starfire` |
| Nature Eclipse (buff, detection) | `Spell_Nature_AbolishMagic` |
| Arcane Eclipse (buff, detection) | `Spell_Nature_WispSplode` |
| Natural Solstice (debuff, detection) | `Spell_Nature_AbolishMagic` |
| Arcane Solstice (debuff, detection) | `Spell_Arcane_Starfire` |
| Arcane cell (status grid, display only) | `Spell_Arcane_Blast` |
| Nature cell (status grid, display only) | `Spell_Nature_ProtectionFormNature` |
| Faerie Fire | `Spell_Nature_FaerieFire` |
| Owlkin Frenzy (talent + buff + minimap button) | `Ability_Druid_OwlkinFrenzy` |

**Aura durations (fallback values):**
- Nature Eclipse (buff) and Arcane Eclipse (buff): 15 seconds base duration.
- Natural Solstice (debuff) and Arcane Solstice (debuff): 30 seconds base duration.
- Faerie Fire: 40 seconds.
- Owlkin Frenzy (buff): 10 seconds.

These values are only a **fallback**: the tooltip scanner (`Core.lua`,
`Moonie_GetAuraDuration`) always tries first to read the real duration
from the tooltip for the self auras (Eclipse/Solstice, Owlkin Frenzy). The
fallback value is only used if that read fails. For Insect Swarm/Moonfire/
Faerie Fire (my target debuffs), the duration is hardcoded, not scanned
from a tooltip (as before).

## Open items / still to verify in-game

- **`Moonie_ScanRotationSpellSlots()` in `Core.lua`:** finds each
  rotation spell's spellbook slot by matching icon textures - **needs to
  be tested in-game**. If `IsSpellInRange` never returns anything (icon
  texture mismatch, or a rank isn't in the spellbook yet at low level),
  the icon just never turns red (fails safe) - let me know if that
  happens and we'll add a fallback.
- **`Moonie_GetTargetGUID()`** in `EnemyTracking.lua`: currently uses
  `UnitExists("target")` with an assumed 2nd return value (GUID) from
  SuperWoW. **This needs to be tested in-game** - if it doesn't work, I
  need the name of the real SuperWoW GUID function.
- Insect Swarm / Moonfire base duration is hardcoded to 18 seconds
  (`DOT_DURATION` in `EnemyTracking.lua`). Faerie Fire hardcoded to 40
  seconds (`FAERIE_FIRE_DURATION`, same file). If talents change this for
  you, let me know and we'll add the tooltip scanner here too.
- **`Moonie_ScanOwlkinTalent()` in `OwlkinFrenzy.lua`:** uses
  `GetTalentInfo(tab, index)` and reads the 5th return value as "rank".
  **Needs to be tested in-game** - if the return value order differs on
  your client, or the talent name isn't exactly "Owlkin Frenzy" (e.g.
  client language), let me know.
- **Owlkin Frenzy buff duration:** fallback of 10 seconds assumed - please
  check in-game and adjust `BUFF_DURATION_FALLBACK` in `OwlkinFrenzy.lua`
  if the tooltip scan finds nothing.
- **Minimap button position:** currently fixed at the top-left edge of the
  minimap (`Minimap.lua`, `SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 20)`).
  No dragging around the minimap ring built in - let me know if you want that.
- **Show/hide (right-click) not yet tested in-game:** please confirm both
  windows fully disappear/reappear, and that the hidden state is still
  correct after a relog.
- **Faerie Fire spell IDs:** assumed 770/778/9749/9907 (4 ranks, druid
  version "Faerie Fire", NOT the feral version). Please check in-game if
  the "did I cast it" tracking doesn't trigger.
- Status grid not yet tested in-game: please check bar width (40px), bar
  height (6px), and positioning to see if it looks the way you want.
- Arcane/Nature icons (columns 3+4) not yet tested in-game: please check
  whether the size (28px), the gap to the status grid
  (`GRID_TO_ECLIPSE_GAP`), the gap to the rotation column, and the height
  of the vertical bar above the icon look the way you want.
- **Rotation column now shows only 1 icon (not tested in-game yet):**
  please confirm the glow/halo looks right and is easy to spot at a glance
  during combat. If you'd rather have a different glow color/texture/size,
  see `GLOW_COLOR` and the `glow` texture setup in `Display.lua`.
- Window position: currently centered on screen, moveable with the left
  mouse button (only the right-hand rotation window is draggable, the
  status grid follows it automatically). Position is NOT saved (resets on
  every login) - let me know if that should be saved too.
- No "only show in combat" visibility condition built in yet.

## How to change things (for you, without programming background)

- **Different priority rule (right column)?** → `Priority.lua`, the
  section with the matching rule number (e.g. `-- ---- Rule 1: Insect
  Swarm ----`).
- **Different icon?** → `Core.lua`, table `Moonie.ICONS`.
- **Different color in the status grid?** → `Display.lua`, near the top of
  the status grid section: `BLUE_COLOR` / `GREEN_COLOR` / `PURPLE_COLOR` /
  `ORANGE_COLOR` / `RED_COLOR` / `GREY_COLOR` / `GLOW_COLOR`.
- **Bar size in the status grid?** → `Display.lua`, near the top:
  `BAR_HEIGHT`, `ICON_BAR_GAP`.
- **Window size/position (right column)?** → `Display.lua`, near the top:
  `FRAME_SIZE`, `FRAME_SPACING`, and the line with `SetPoint("CENTER", ...)`.
  The status grid on the left follows automatically, no separate move needed.
- **Size of the Arcane/Nature icons?** → `Display.lua`, near the top:
  `SMALL_SIZE`.
- **Gap between the status grid and the Arcane/Nature icons?** →
  `Display.lua`, `GRID_TO_ECLIPSE_GAP` (near the top).
- **Gap between the 3x3 grid area and the rotation column?** →
  `Display.lua`, `EXTRA_GAP` (shortly after `SMALL_SIZE`).
- **How see-through the vertical Eclipse bar is?** → `Display.lua`,
  `TOP_BAR_ALPHA` (1 = fully solid, 0 = fully invisible; currently 0.75).
- **Glow/halo around the rotation icon?** → `Display.lua`, `GLOW_COLOR`
  and the `glow` texture block inside the icon-frame creation loop
  (texture, size via the `-10`/`10` offsets, opacity via
  `SetVertexColor(..., 0.9)`).
- **Different default duration for Solstice/Eclipse/Owlkin Frenzy?** →
  `SelfAuras.lua` (Eclipse/Solstice, the four `UpdateAura(...)` lines near
  the bottom) or `OwlkinFrenzy.lua` (`BUFF_DURATION_FALLBACK` near the
  top). The last number in each `UpdateAura(...)` line is the fallback
  duration in seconds.
- **Change Owlkin Frenzy cooldown times?** → `OwlkinFrenzy.lua`, the table
  `TALENT_CD` near the top (`[1] = 30, [2] = 25, [3] = 20`).
- **Change the minimap button position?** → `Minimap.lua`, the line with
  `minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 20)`.
- **Range number backdrop (size/opacity)?** → `Display.lua`, the `rangeBg`
  block right after `-- Range-to-target display` (width/height for size,
  the `0.5` in `rangeBgTex:SetTexture(0, 0, 0, 0.5)` for opacity).
- **Add another option to the dropdown menu?** → `Minimap.lua`, function
  `InitDropdown()` - add another `info` block + `UIDropDownMenu_AddButton(info)`
  following the same pattern.
- **Range display colors/thresholds (the yard number)?** → `Display.lua`,
  `GetRangeColor()` and `LIGHT_BLUE_COLOR`/`YELLOW_COLOR` near the top
  (Green/Orange/Red already existed). This is purely informational and
  doesn't affect the red icon tint.
- **Out-of-range icon tint logic?** → `Core.lua`,
  `Moonie_IsRotationSpellInRange()` and `Moonie_ScanRotationSpellSlots()`
  - uses the native `IsSpellInRange` API, so it already adapts to
    Nature's Reach/talents automatically; nothing to configure here.
- **Class restriction (Druid-only)?** → `Core.lua`, near the very top,
  the `if engClass ~= "DRUID" then ... end` block.

If you tell me WHAT you want to change, I'll tell you exactly which
line(s) in which file need to be replaced - with a clear start/end marker.

---

## Change history

- **v0.12 - NEW: Minimap right-click now shows/hides the whole addon
  instead of toggling click-through; range number now has a "y" suffix
  and a readable backdrop.**
  - `Minimap.lua`: new `MoonieDB.hidden` setting with matching
    `Moonie_ApplyHidden()` / `Moonie_ToggleHidden()` functions (same
    pattern as the existing click-through functions). Right-click on the
    minimap button now calls `Moonie_ToggleHidden()` instead of
    `Moonie_ToggleClickthrough()` - it fully shows/hides both windows.
    The "Click-through windows" dropdown option is unchanged and still
    works exactly as before, just no longer tied to right-click.
    Tooltip text updated to say "Right-click: show/hide addon".
  - `Core.lua`: added the `MoonieDB.hidden` default (off) next to the
    existing `MoonieDB.clickThrough` default, and calls
    `Moonie_ApplyHidden()` on load (same place `Moonie_ApplyClickthrough()`
    is called), so the hidden state is restored correctly on login/relog.
  - `Display.lua`: the main `OnUpdate` loop now checks `Moonie.hidden`
    first - if true, both windows get `Hide()`'d and the rest of the
    tick (rules, status grid, range check) is skipped entirely, so a
    hidden addon does no work, not just "invisible but still ticking".
  - `Display.lua`: the range number above the rotation icon now shows a
    "y" suffix (e.g. "23.4y" instead of "23.4") and sits on a new small
    backdrop frame (`rangeBg`, 50%-opacity black, reads as soft grey) so
    it stays readable over bright backgrounds. Purely visual - the range
    calculation and out-of-range tint logic are unchanged.
  - Non-Druid lockout (from v0.11) already covered "disable/hide by
    default for non-Druids" - the whole addon returns early in `Core.lua`
    before any frame, button, or event gets created, so nothing needed
    to change there.
  - **NOT yet tested in-game.**

- **v0.11 - NEW: Druid-only lockout, range display + out-of-range tint,
  Owlkin Frenzy respec fix, saved-settings robustness, new title style.**
  - `Core.lua`: on login, checks `UnitClass("player")`'s English class
    token - if it's not `"DRUID"`, sets `Moonie.disabled = true`, prints
    a chat message, and stops loading right there. Every other file now
    starts with `if Moonie.disabled then return end` as its very first
    line, so nothing (frames, events, polling) ever gets created for a
    non-Druid. New function `Moonie_GetTargetRange()` (needs UnitXP,
    same nil-safe pattern as the Nampower check) returns live yards to
    target. `ADDON_LOADED` handler also now checks for UnitXP and warns
    in chat if it's missing (same as the existing Nampower warning).
  - `Core.lua`: the saved-settings block (`MoonieDB` defaults +
    `Moonie_ApplyClickthrough()`) now also re-runs on
    `PLAYER_ENTERING_WORLD`, not just `ADDON_LOADED` - a safety net in
    case the saved Faerie Fire tracking/click-through state wasn't fully
    settled the moment you first entered the world.
  - `Minimap.lua`: the dropdown's two checkmarks are now forced to a
    strict `true`/`false` instead of a possibly-`nil` value, so they
    always show the real saved state instead of defaulting to unchecked.
  - `OwlkinFrenzy.lua`: added a 5-second safety-net re-scan of the talent
    rank (`Moonie_ScanOwlkinTalent()`), independent of the
    `CHARACTER_POINTS_CHANGED` event - fixes the Owlkin Frenzy cell not
    reappearing after respeccing into Balance via a custom respec item
    that doesn't fire that event reliably.
  - `Display.lua`: new range number above the rotation icon (color-coded,
    needs UnitXP, purely informational) and a red tint on the icon
    itself when the target is out of range for the current top-priority
    spell. The tint uses `Moonie_IsRotationSpellInRange()` (`Core.lua`),
    which asks the native `IsSpellInRange` API against the spell's real
    spellbook slot - found once via `Moonie_ScanRotationSpellSlots()` by
    matching each rotation spell's icon texture. This automatically
    accounts for **Nature's Reach** (extends range to 33/36 yards) and
    any other range talent, including respecs, with nothing hardcoded
    and no UnitXP dependency for the tint itself.
  - `Priority.lua`: each of the 7 rules now also carries a `key` field
    (`"wrath"`/`"starfire"`/`"moonfire"`/`"insectSwarm"`) identifying
    which actual spell it is, so `Display.lua` knows which spellbook slot
    to range-check for the current top-priority icon.
  - `Moonie.toc`: new colored title style
    (`|cffff8000<Gaha>|r |cff006400Moonie|r`), added a `## Version:` line.
  - **NOT yet tested in-game.**

- **NEW: Rotation column now shows only the single highest-priority icon,
  with a glow/halo, instead of stacking up to 4 icons (`Display.lua`
  only).**
  - `Priority.lua`'s rule list is unchanged (still 7 rules, same
    conditions and priority order).
  - `Display.lua`'s `OnUpdate` now walks the rule list from 1 to 7 and
    stops at the FIRST visible rule - that one icon gets shown in
    `iconFrames[1]`; frames 2-4 are always hidden now.
  - Every icon frame got a new `glow` texture (additive blend, gold-ish
    color, larger than the icon itself) sitting behind it, so the single
    rotation icon visually stands out from the rest of the addon's icons.
    Color/size/opacity are all adjustable via `GLOW_COLOR` and the `glow`
    block in `Display.lua`.
  - **NOT yet tested in-game.**

- **NEW: Visual tuning pass based on first impressions - gap, bar
  transparency, minimap ring, click-through option, full English
  translation (`Display.lua`, `Minimap.lua`, `Core.lua`, all comments and
  in-game chat text).**
  - `Display.lua`: gap between the 3x3 status grid and the small
    Arcane/Nature icons shrunk from `FRAME_SPACING` (6px) to a new,
    smaller `GRID_TO_ECLIPSE_GAP` (2px), so the two areas read as one
    group instead of looking spaced apart. The vertical Eclipse bar above
    the Arcane/Nature icons is now slightly see-through (`TOP_BAR_ALPHA =
    0.75`) instead of a fully solid block of color.
  - `Minimap.lua`: fixed the tracking-border ring so it sits directly
    around the icon instead of floating above-left of it (button resized
    to 31x31, icon inset to 7,-5, ring anchored at the button's TOPLEFT
    with no offset - matches the layout most other minimap-button addons
    use, since the ring texture itself isn't centered in its own canvas).
    Added a second dropdown option "Click-through windows" next to
    "Track Faerie Fire", so click-through can be toggled from the menu
    too (not just via right-click). New function `Moonie_ApplyClickthrough()`
    restores the saved click-through state on login.
  - `Core.lua`: added `MoonieDB.clickThrough` (default off, same
    save/restore pattern as `MoonieDB.trackFaerieFire`), calls
    `Moonie_ApplyClickthrough()` once after load so the setting is
    restored automatically. (`MoonieDB.trackFaerieFire` already persisted
    correctly before this change - it uses the same `## SavedVariables:
    MoonieDB` mechanism declared in `Moonie.toc`.)
  - All chat messages, comments, and this README translated from German
    to English - the German text was left over from earlier sessions and
    was never intentional; everything user-facing and all code comments
    are English going forward.

- **Arcane/Nature icons shrunk and relocated, rotation column moved right
  (`Display.lua` only, NO logic changed - only positions/sizes/display).**
  - The two icons are now smaller (28px instead of 40px) and no longer
    sit in row 2 of the 3x3 grid, but in their own area to the right of it
    (row 3, "column 3" = Arcane, "column 4" = Nature), between the 3x3
    grid and the rotation column.
  - Each cell now has TWO bars instead of one: a thin bar UNDER the icon
    (shows only the Solstice debuff: red+counting down or grey+static)
    and a wide VERTICAL bar ABOVE the icon (reaches up to the top edge of
    row 1, shows only the Eclipse itself: blue or green while it's
    running, completely invisible otherwise).
  - The old `UpdateEclipseCell(...)` function was replaced by three new
    functions: `UpdateEclipseIcon(...)` (icon+number),
    `UpdateEclipseBottomBar(...)` (bottom bar, Solstice only),
    `UpdateEclipseTopBar(...)` (top bar, Eclipse only). New builder
    function `CreateEclipseCell(...)` (instead of `CreateStatusCell(...)`)
    for these 2 cells, because they need a different size and positioning
    than the rest of the grid.
  - The rotation column (right) moved further right to make room between
    it and the 3x3 grid for the 2 new icons (`EXTRA_GAP` in `Display.lua`).
    The rotation column's icon rows now use `ROW_HEIGHT` (including bar
    space) instead of just `FRAME_SIZE` as spacing, so the rows line up
    with the status grid on the left.

- **NEW: Faerie Fire, Owlkin Frenzy, minimap button, bigger/red countdown
  numbers under 5 sec.**
  - `Core.lua`: added icons `faerieFire`/`owlkinFrenzy`, spell IDs
    `SPELL_IDS.faerieFire`, saved setting `MoonieDB` (init in the
    ADDON_LOADED handler, field `trackFaerieFire`, default = on).
  - `EnemyTracking.lua`: added a SPELL_GO_SELF branch for Faerie Fire (did
    I cast it), new poll frame checks via `UnitDebuff("target")` whether
    Faerie Fire is on the target at all (no matter who cast it). New
    function `Moonie_GetFaerieFireStatus()`.
  - `OwlkinFrenzy.lua` (new file): talent rank scan (`GetTalentInfo`),
    buff detection like the Eclipse auras, cooldown calculation depending
    on talent rank. New function `Moonie_GetOwlkinStatus()`.
  - `Display.lua`: status grid expanded from 2x2 to 3x3 (new cells Faerie
    Fire at row 1/column 0 and Owlkin Frenzy at row 3/column 2). New
    helper function `SetCellTimerText()` (now used everywhere instead of
    a direct `string.format("%d", ...)`) - makes the number bigger, and
    red with one decimal place under 5 seconds. New helper functions
    `ShowCell()`/`HideCell()` to fully show/hide a cell (icon and bar hang
    off different parent frames, so a single `Hide()` isn't enough).
    `mainFrame`/`statusFrame` exported at the end of the file as
    `Moonie.mainFrame`/`Moonie.statusFrame`, so `Minimap.lua` can reach
    them for the click-through toggle.
  - `Minimap.lua` (new file): button at the minimap edge, left-click opens
    a dropdown menu (`UIDropDownMenuTemplate`) with the "Track Faerie
    Fire" option, right-click toggles `EnableMouse` on both main windows.
  - `Moonie.toc`: added `## SavedVariables: MoonieDB`, added
    `OwlkinFrenzy.lua` and `Minimap.lua` to the load list (order: Core,
    EnemyTracking, SelfAuras, OwlkinFrenzy, Priority, Display, Minimap).

- **Bugfix (status grid row 3, Arcane/Nature swapped):** the two Solstice
  debuffs were wired to the wrong cell in `Display.lua`. The Arcane cell
  incorrectly got the Arcane Solstice debuff as state 2, and the Nature
  cell got the Natural Solstice debuff - but they're cross-linked: Arcane
  Eclipse (buff) always starts together with Natural Solstice (debuff),
  Nature Eclipse (buff) always together with Arcane Solstice (debuff). Now
  correct: the Arcane cell uses Natural Solstice as state 2, the Nature
  cell uses Arcane Solstice as state 2. Only affects the wiring in
  `Display.lua` (the `UpdateEclipseCell(...)` calls at the time) - the
  remaining-time calculation itself was always correct, since it comes
  from each debuff's real start/duration time.

- **Bugfix:** Insect Swarm / Moonfire were stored with 12 seconds duration
  instead of the correct 18 seconds (`DOT_DURATION` in
  `EnemyTracking.lua`). This made the status grid on the left show the
  DoTs as "expired" too early. The separate "< 12 seconds remaining" check
  in priority rules 1 and 2 (`Priority.lua`) is NOT affected by this and
  intentionally stays at 12.

- **Renamed:** addon renamed from "MoonkinPrio" to "Moonie" (folder, .toc
  file, all global names in the code, ADDON_LOADED check).
- **Bugfix:** Natural Solstice / Arcane Solstice (the 2 debuffs on
  myself) incorrectly had a 15-second fallback duration instead of the
  correct 30 seconds. Fixed in `SelfAuras.lua`.
- **Added rule 7:** Wrath as a "dump spell" when no Eclipse/Solstice is
  active at all (`Priority.lua`, `Display.lua`).
- **Added status grid on the left (2x2):** Moonfire/Insect Swarm duration
  on target (row 1) and Arcane/Nature Eclipse-Solstice status (row 2),
  with bar display. `GetRemaining()` in `Priority.lua` now also returns
  the full duration, new functions `Moonie_GetDotStatus()` (extended) and
  `Moonie_GetEclipseStatus()` (new) supply `Display.lua` with the values
  for the bars.
