-- =====================================================================
-- Moonie - Display.lua
-- Builds TWO visible areas:
--   1) Rotation column (right, "column 5"): shows a SINGLE icon - the
--      highest-priority rule that is currently true (Priority.lua rules),
--      with a glow/halo around it so it stands out from the rest of the
--      addon's icons.
--   2) Status grid (left): ALWAYS shows Moonfire/Insect Swarm/Faerie Fire
--      duration on the target (columns 0-2), Eclipse/Solstice status on
--      me (small icons in columns 3+4, row 3), and Owlkin Frenzy -
--      independent of the rotation column.
--
-- Moving the window: hold left mouse button and drag the right (rotation) window.
-- =====================================================================

local FRAME_SIZE = 40
local FRAME_SPACING = 6
-- Smaller icon size for the Arcane/Nature status icons (columns 3+4, row 3).
local SMALL_SIZE = 28
-- ONE small gap value, used 3x: grid->Arcane, Arcane->Nature, Nature->rotation.
-- Change this single number to make all those gaps bigger/smaller.
local ECLIPSE_GAP = 6

local BAR_HEIGHT = 6
local ICON_BAR_GAP = 2
local ROW_HEIGHT = FRAME_SIZE + ICON_BAR_GAP + BAR_HEIGHT
-- Height of the vertical Eclipse bar above the small Arcane/Nature icons:
-- reaches from the top edge of the small icon (row 3) up to the top edge
-- of the row-1 icons (so it spans 2 rows including their spacing).
local TOP_BAR_HEIGHT = 2 * (ROW_HEIGHT + FRAME_SPACING)
-- Opacity of the vertical Eclipse bar fill (1 = fully solid). Slightly
-- see-through so it doesn't dominate the display visually.
local TOP_BAR_ALPHA = 0.75
local BLUE_COLOR = { 0.15, 0.5, 1 }
local GREEN_COLOR = { 0.2, 0.8, 0.2 }
local PURPLE_COLOR = { 0.6, 0.2, 0.9 }
local ORANGE_COLOR = { 1, 0.6, 0 }
local RED_COLOR = { 1, 0, 0 }
local GREY_COLOR = { 0.35, 0.35, 0.35 }
local GLOW_COLOR = { 1, 0.85, 0.2 }

local mainFrame = CreateFrame("Frame", "MoonieDisplay", UIParent)
mainFrame:SetWidth(FRAME_SIZE)
mainFrame:SetHeight((ROW_HEIGHT + FRAME_SPACING) * 4)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

-- Only iconFrames[1] is ever shown now (only the single highest-priority
-- icon is displayed). Frames 2-4 stay hidden but are kept around in case
-- we want to show more than one icon again later.
local iconFrames = {}
local i
for i = 1, 4 do
    local f = CreateFrame("Frame", "MoonieIcon" .. i, mainFrame)
    f:SetWidth(FRAME_SIZE)
    f:SetHeight(FRAME_SIZE)
    f:SetPoint("TOP", mainFrame, "TOP", 0, -(i - 1) * (ROW_HEIGHT + FRAME_SPACING))

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(f)
    border:SetTexture(0, 0, 0, 0.6)

    -- Glow/halo behind the icon so the rotation icon stands out from the
    -- rest of the addon's icons. Only frame 1 ever gets used, but building
    -- it for every frame keeps this loop simple.
    -- OVERLAY layer = drawn ON TOP of the icon (was BACKGROUND = drawn
    -- BEHIND it, which is why it was invisible before). The texture's
    -- own center is transparent, so the icon still shows through; only
    -- the swirly border shows, sitting around/over the icon's edge.
    local glow = f:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 1, 1, 0.9)
    glow:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
    f.glow = glow

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    f.texture = tex

    f:Hide()
    iconFrames[i] = f
end

-- =====================================================================
-- Status grid on the LEFT of the rotation. Always shows what's currently
-- running - independent of the rotation logic (right side, unchanged).
--
-- Column/row numbering (as used in the code, col 0 = leftmost):
--   Row 1: Column 0 = Faerie Fire (target debuff, no matter who cast it;
--                      bar+timer only if I cast it)
--          Column 1 = Moonfire (my DoT on target)
--          Column 2 = Insect Swarm (my DoT on target)
--   Row 3: Column 2 = Owlkin Frenzy (talent buff, only visible if talented)
--          Column 3 = Arcane status (small icon, own area right of the
--                      normal 3x3 grid, see CreateEclipseCell below)
--          Column 4 = Nature status (small icon, mirrors column 3)
--
-- The bar "empties" from right to left all by itself: a StatusBar always
-- fills from the left, so the visible fill shrinks from the right when
-- the value (=remaining time) gets smaller.
-- =====================================================================

-- Extra space between the normal 3x3 grid and the rotation column, so the
-- two small Arcane/Nature icons (columns 3+4) fit in between.
-- Built from the real pieces (grid->arcane gap, arcane->nature gap,
-- nature->rotation gap) so changing GRID_TO_ECLIPSE_GAP actually changes
-- the visible gap instead of just moving the leftover space around.
local EXTRA_GAP = ECLIPSE_GAP + SMALL_SIZE + ECLIPSE_GAP + SMALL_SIZE + ECLIPSE_GAP

local statusFrame = CreateFrame("Frame", "MoonieStatusFrame", UIParent)
statusFrame:SetWidth(FRAME_SIZE * 3 + FRAME_SPACING * 2)
statusFrame:SetHeight(ROW_HEIGHT * 3 + FRAME_SPACING * 2)
statusFrame:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -EXTRA_GAP, 0)

-- Builds a status cell (icon + bar underneath) at grid position (row, col).
-- col can be 0 (that shifts the cell one step LEFT of column 1).
local function CreateStatusCell(row, col, iconTexture)
    local xOff = (col - 1) * (FRAME_SIZE + FRAME_SPACING)
    local yOff = -(row - 1) * (ROW_HEIGHT + FRAME_SPACING)

    local f = CreateFrame("Frame", "MoonieStatusCell" .. row .. col, statusFrame)
    f:SetWidth(FRAME_SIZE)
    f:SetHeight(FRAME_SIZE)
    f:SetPoint("TOPLEFT", statusFrame, "TOPLEFT", xOff, yOff)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(f)
    border:SetTexture(0, 0, 0, 0.6)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    tex:SetTexture(iconTexture)
    f.texture = tex

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    label:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.label = label

    local bar = CreateFrame("StatusBar", "MoonieStatusBar" .. row .. col, statusFrame)
    bar:SetWidth(FRAME_SIZE)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetPoint("TOP", f, "BOTTOM", 0, -ICON_BAR_GAP)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture(0, 0, 0, 0.6)

    f.bar = bar
    return f
end

-- Shows/hides a cell COMPLETELY (icon + bar - they hang off different
-- parent frames, so a single f:Hide() isn't enough).
local function ShowCell(cell)
    cell:Show()
    cell.bar:Show()
end
local function HideCell(cell)
    cell:Hide()
    cell.bar:Hide()
end

-- Sets the countdown text of a cell. Under 5 seconds: red + one decimal
-- place (4.9, 4.8, ...). From 5 seconds up: white, whole number.
local function SetCellTimerText(cell, remaining)
    if remaining < 5 then
        cell.label:SetTextColor(RED_COLOR[1], RED_COLOR[2], RED_COLOR[3])
        cell.label:SetText(string.format("%.1f", remaining))
    else
        cell.label:SetTextColor(1, 1, 1)
        cell.label:SetText(string.format("%d", remaining))
    end
end

local cellFaerieFire = CreateStatusCell(1, 1, Moonie.ICONS.faerieFire)
local cellMoonfire   = CreateStatusCell(1, 2, Moonie.ICONS.moonfire)
local cellSwarm      = CreateStatusCell(1, 3, Moonie.ICONS.insectSwarm)
local cellOwlkin     = CreateStatusCell(3, 3, Moonie.ICONS.owlkinFrenzy)

-- Builds a small Arcane/Nature status cell (column 3 / 4, row 3).
-- Unlike CreateStatusCell, this doesn't start from the grid raster
-- (col*FRAME_SIZE) - it's positioned in raw pixels starting from the
-- right edge of the normal 3x3 grid (statusFrame TOPRIGHT). Besides the
-- normal bar UNDER the icon (f.bar, as before) there's a second, VERTICAL
-- bar ABOVE the icon (f.topBar + f.topBarFill), reaching up to the top
-- edge of row 1.
local function CreateEclipseCell(xOff, yOff, size, iconTexture)
    local f = CreateFrame("Frame", nil, statusFrame)
    f:SetWidth(size)
    f:SetHeight(size)
    f:SetPoint("TOPLEFT", statusFrame, "TOPRIGHT", xOff, yOff)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(f)
    border:SetTexture(0, 0, 0, 0.6)

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    tex:SetTexture(iconTexture)
    f.texture = tex

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.label = label

    -- Bar UNDER the icon: only shows Solstice (red) or "nothing" (grey).
    local bar = CreateFrame("StatusBar", nil, statusFrame)
    bar:SetWidth(size)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetPoint("TOP", f, "BOTTOM", 0, -ICON_BAR_GAP)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture(0, 0, 0, 0.6)

    f.bar = bar

    -- Bar ABOVE the icon: only visible while the Eclipse (buff) itself is
    -- running. Fill shrinks from top toward the icon as remaining time
    -- counts down. Completely invisible when no Eclipse is running.
    -- Slightly see-through (TOP_BAR_ALPHA) rather than fully solid.
    local topBar = CreateFrame("Frame", nil, statusFrame)
    topBar:SetWidth(size)
    topBar:SetHeight(TOP_BAR_HEIGHT)
    topBar:SetPoint("BOTTOM", f, "TOP", 0, 0)

    local topBarBg = topBar:CreateTexture(nil, "BACKGROUND")
    topBarBg:SetAllPoints(topBar)
    topBarBg:SetTexture(0, 0, 0, 0.6)

    local topBarFill = topBar:CreateTexture(nil, "ARTWORK")
    topBarFill:SetPoint("BOTTOMLEFT", topBar, "BOTTOMLEFT", 0, 0)
    topBarFill:SetPoint("BOTTOMRIGHT", topBar, "BOTTOMRIGHT", 0, 0)
    topBarFill:SetHeight(TOP_BAR_HEIGHT)

    f.topBar = topBar
    f.topBarFill = topBarFill
    topBar:Hide()

    return f
end

-- Arcane cell: column 3, row 3 (first small cell right of the 3x3 grid).
local cellArcane = CreateEclipseCell(ECLIPSE_GAP, -2 * (ROW_HEIGHT + FRAME_SPACING), SMALL_SIZE, Moonie.ICONS.arcaneStatus)
-- Nature cell: column 4, row 3 (directly right of the Arcane cell).
local cellNature = CreateEclipseCell(ECLIPSE_GAP + SMALL_SIZE + ECLIPSE_GAP, -2 * (ROW_HEIGHT + FRAME_SPACING), SMALL_SIZE, Moonie.ICONS.natureStatus)

-- Updates a row-1 cell (target DoT: only active/inactive) - Moonfire/Swarm.
-- 'color' picks the bar color while active (Moonfire = blue, Swarm = green).
local function UpdateDotCell(cell, remaining, active, duration, color)
    if active then
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(1, 1, 1)
        SetCellTimerText(cell, remaining)
        cell.bar:SetStatusBarColor(color[1], color[2], color[3])
        cell.bar:SetMinMaxValues(0, duration)
        cell.bar:SetValue(remaining)
    else
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(0.35, 0.35, 0.35)
        cell.label:SetText("")
        cell.bar:SetStatusBarColor(0.35, 0.35, 0.35)
        cell.bar:SetMinMaxValues(0, 1)
        cell.bar:SetValue(1)
    end
end

-- Faerie Fire cell: 3 states.
--   mine=true     -> purple bar + timer (I put it there)
--   present=true (but not mine) -> icon bright, but grey bar, no timer
--   present=false -> icon grey, grey bar (like "not active")
local function UpdateFaerieFireCell(cell, present, remaining, mine, duration)
    if mine then
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(1, 1, 1)
        SetCellTimerText(cell, remaining)
        cell.bar:SetStatusBarColor(PURPLE_COLOR[1], PURPLE_COLOR[2], PURPLE_COLOR[3])
        cell.bar:SetMinMaxValues(0, duration)
        cell.bar:SetValue(remaining)
    elseif present then
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(1, 1, 1)
        cell.label:SetText("")
        cell.bar:SetStatusBarColor(0.5, 0.5, 0.5)
        cell.bar:SetMinMaxValues(0, 1)
        cell.bar:SetValue(1)
    else
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(GREY_COLOR[1], GREY_COLOR[2], GREY_COLOR[3])
        cell.label:SetText("")
        cell.bar:SetStatusBarColor(GREY_COLOR[1], GREY_COLOR[2], GREY_COLOR[3])
        cell.bar:SetMinMaxValues(0, 1)
        cell.bar:SetValue(1)
    end
end

-- Updates an Arcane/Nature cell: THREE separate parts.
-- 1) Icon + number: same 3-state behavior as before (bright during
--    Eclipse, red+translucent during Solstice, grey when nothing running).
local function UpdateEclipseIcon(cell, eclRemaining, eclActive, solRemaining, solActive)
    if eclActive then
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(1, 1, 1)
        SetCellTimerText(cell, eclRemaining)
    elseif solActive then
        cell:SetAlpha(0.6)
        cell.texture:SetVertexColor(1, 0.3, 0.3)
        SetCellTimerText(cell, solRemaining)
    else
        cell:SetAlpha(0.5)
        cell.texture:SetVertexColor(0.5, 0.5, 0.5)
        cell.label:SetText("")
    end
end

-- 2) Bar UNDER the icon: only 2 states now - red+counting down while
--    Solstice (debuff) is active, otherwise grey and static (also while
--    Eclipse itself is running, since Solstice and Eclipse are never
--    active at the same time).
local function UpdateEclipseBottomBar(cell, solRemaining, solActive, solDuration)
    if solActive then
        cell.bar:SetStatusBarColor(RED_COLOR[1], RED_COLOR[2], RED_COLOR[3])
        cell.bar:SetMinMaxValues(0, solDuration)
        cell.bar:SetValue(solRemaining)
    else
        cell.bar:SetStatusBarColor(GREY_COLOR[1], GREY_COLOR[2], GREY_COLOR[3])
        cell.bar:SetMinMaxValues(0, 1)
        cell.bar:SetValue(1)
    end
end

-- 3) Bar ABOVE the icon: only visible while Eclipse (buff) is active,
--    otherwise completely hidden (not grey, not red - see CreateEclipseCell).
-- Fill is drawn with TOP_BAR_ALPHA so it's slightly see-through instead
-- of a fully solid block of color.
local function UpdateEclipseTopBar(cell, eclRemaining, eclActive, eclDuration, color)
    if eclActive then
        cell.topBar:Show()
        local ratio = eclRemaining / eclDuration
        if ratio > 1 then ratio = 1 end
        if ratio < 0 then ratio = 0 end
        cell.topBarFill:SetTexture(color[1], color[2], color[3], TOP_BAR_ALPHA)
        cell.topBarFill:SetHeight(TOP_BAR_HEIGHT * ratio)
    else
        cell.topBar:Hide()
    end
end

-- Owlkin Frenzy cell: 3 states (the cell itself is hidden entirely from
-- the outside when rank == 0 - see OnUpdate below).
--   Buff active  -> icon bright, orange bar + timer
--   Cooldown     -> icon red + slightly translucent, red bar + timer
--   Ready        -> icon grey, grey bar, no timer
local function UpdateOwlkinCell(cell, buffActive, buffRemaining, buffDuration, cdActive, cdRemaining, cdDuration)
    if buffActive then
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(1, 1, 1)
        SetCellTimerText(cell, buffRemaining)
        cell.bar:SetStatusBarColor(ORANGE_COLOR[1], ORANGE_COLOR[2], ORANGE_COLOR[3])
        cell.bar:SetMinMaxValues(0, buffDuration)
        cell.bar:SetValue(buffRemaining)
    elseif cdActive then
        cell:SetAlpha(0.6)
        cell.texture:SetVertexColor(1, 0.3, 0.3)
        SetCellTimerText(cell, cdRemaining)
        cell.bar:SetStatusBarColor(RED_COLOR[1], RED_COLOR[2], RED_COLOR[3])
        cell.bar:SetMinMaxValues(0, cdDuration)
        cell.bar:SetValue(cdRemaining)
    else
        cell:SetAlpha(1)
        cell.texture:SetVertexColor(GREY_COLOR[1], GREY_COLOR[2], GREY_COLOR[3])
        cell.label:SetText("")
        cell.bar:SetStatusBarColor(GREY_COLOR[1], GREY_COLOR[2], GREY_COLOR[3])
        cell.bar:SetMinMaxValues(0, 1)
        cell.bar:SetValue(1)
    end
end

local updateFrame = CreateFrame("Frame")
local lastUpdate = 0
updateFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - lastUpdate < 0.1 then return end
    lastUpdate = now

    local rules = Moonie_EvaluateRules()

    -- ---- Update the left-hand status grid ----
    local isRemaining, isActive, mfRemaining, mfActive, isDuration, mfDuration = Moonie_GetDotStatus()
    UpdateDotCell(cellMoonfire, mfRemaining, mfActive, mfDuration, BLUE_COLOR)
    UpdateDotCell(cellSwarm, isRemaining, isActive, isDuration, GREEN_COLOR)

    -- Faerie Fire: only show it if enabled in the minimap menu.
    if MoonieDB and MoonieDB.trackFaerieFire then
        local ffPresent, ffRemaining, ffMine, ffDuration = Moonie_GetFaerieFireStatus()
        ShowCell(cellFaerieFire)
        UpdateFaerieFireCell(cellFaerieFire, ffPresent, ffRemaining, ffMine, ffDuration)
    else
        HideCell(cellFaerieFire)
    end

    local natEclRemaining, natEclActive, natEclDuration,
          arcEclRemaining, arcEclActive, arcEclDuration,
          natSolRemaining, natSolActive, natSolDuration,
          arcSolRemaining, arcSolActive, arcSolDuration = Moonie_GetEclipseStatus()

    -- IMPORTANT: Arcane Eclipse (buff) and Natural Solstice (debuff) ALWAYS
    -- start at the same time - likewise Nature Eclipse (buff) and Arcane
    -- Solstice (debuff). That's why the Arcane cell gets the Natural
    -- Solstice status as state 2, and the Nature cell gets the Arcane
    -- Solstice status. Each cell is updated in 3 parts now: icon, bottom
    -- bar (Solstice), top bar (Eclipse).
    UpdateEclipseIcon(cellArcane, arcEclRemaining, arcEclActive, natSolRemaining, natSolActive)
    UpdateEclipseBottomBar(cellArcane, natSolRemaining, natSolActive, natSolDuration)
    UpdateEclipseTopBar(cellArcane, arcEclRemaining, arcEclActive, arcEclDuration, BLUE_COLOR)

    UpdateEclipseIcon(cellNature, natEclRemaining, natEclActive, arcSolRemaining, arcSolActive)
    UpdateEclipseBottomBar(cellNature, arcSolRemaining, arcSolActive, arcSolDuration)
    UpdateEclipseTopBar(cellNature, natEclRemaining, natEclActive, natEclDuration, GREEN_COLOR)

    -- Owlkin Frenzy: only show the cell if the talent is invested (rank > 0).
    local owlRank, owlBuffActive, owlBuffRemaining, owlBuffDuration, owlCdActive, owlCdRemaining, owlCdDuration = Moonie_GetOwlkinStatus()
    if owlRank > 0 then
        ShowCell(cellOwlkin)
        UpdateOwlkinCell(cellOwlkin, owlBuffActive, owlBuffRemaining, owlBuffDuration, owlCdActive, owlCdRemaining, owlCdDuration)
    else
        HideCell(cellOwlkin)
    end

    -- ---- Update the rotation column (right side) ----
    -- Only the single highest-priority TRUE rule gets shown, not every
    -- true rule stacked underneath each other. Rules are already ordered
    -- 1 (highest) to 7 (lowest), so the first visible one wins.
    local topIcon = nil
    for i = 1, 7 do
        if rules[i].visible then
            topIcon = rules[i].icon
            break
        end
    end

    if topIcon then
        iconFrames[1].texture:SetTexture(topIcon)
        iconFrames[1]:Show()
    else
        iconFrames[1]:Hide()
    end

    for i = 2, 4 do
        iconFrames[i]:Hide()
    end
end)

-- Made accessible to Minimap.lua (right-click = toggle click-through).
Moonie.mainFrame = mainFrame
Moonie.statusFrame = statusFrame
