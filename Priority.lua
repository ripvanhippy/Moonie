-- =====================================================================
-- Moonie - Priority.lua
-- The core piece: checks all 7 priority rules and says for each one
-- whether it should currently be true. Display.lua then picks only the
-- single highest-priority rule that is true and shows that one icon.
--
-- Rule order (1 = highest priority):
--   1) Insect Swarm
--   2) Moonfire
--   3) Starfire  (Arcane Eclipse running)
--   4) Wrath     (Nature Eclipse running)
--   5) Starfire  (Natural Solstice debuff on me)
--   6) Wrath     (Arcane Solstice debuff on me)
--   7) Wrath     (dump spell: no Eclipse/Solstice active at all)
-- =====================================================================

-- Returns (remainingTime, isActive, fullDuration) for a stored entry
-- {start=,duration=}. fullDuration is needed for filling in the bars.
local function GetRemaining(entry)
    if not entry then return 0, false, 0 end
    local remaining = entry.duration - (GetTime() - entry.start)
    if remaining <= 0 then return 0, false, entry.duration end
    return remaining, true, entry.duration
end

-- Returns the status of the 2 target debuffs (Insect Swarm, Moonfire),
-- including full duration. Used by Moonie_EvaluateRules AND by
-- Display.lua (status grid).
function Moonie_GetDotStatus()
    local targetGuid = Moonie_GetTargetGUID()
    local enemy = targetGuid and Moonie.enemyDebuffs[targetGuid]

    local isRemaining, isActive, isDuration = 0, false, 0
    local mfRemaining, mfActive, mfDuration = 0, false, 0
    if enemy then
        isRemaining, isActive, isDuration = GetRemaining(enemy.insectSwarm)
        mfRemaining, mfActive, mfDuration = GetRemaining(enemy.moonfire)
    end

    return isRemaining, isActive, mfRemaining, mfActive, isDuration, mfDuration
end

-- Returns the status of the 4 self auras (Nature/Arcane Eclipse,
-- Natural/Arcane Solstice), including full duration. Only used by
-- Display.lua (status grid row 3) - Moonie_EvaluateRules reads the
-- auras itself.
function Moonie_GetEclipseStatus()
    local natEclRemaining, natEclActive, natEclDuration = GetRemaining(Moonie.selfBuffs.natureEclipse)
    local arcEclRemaining, arcEclActive, arcEclDuration = GetRemaining(Moonie.selfBuffs.arcaneEclipse)
    local natSolRemaining, natSolActive, natSolDuration = GetRemaining(Moonie.selfDebuffs.naturalSolstice)
    local arcSolRemaining, arcSolActive, arcSolDuration = GetRemaining(Moonie.selfDebuffs.arcaneSolstice)

    return natEclRemaining, natEclActive, natEclDuration,
           arcEclRemaining, arcEclActive, arcEclDuration,
           natSolRemaining, natSolActive, natSolDuration,
           arcSolRemaining, arcSolActive, arcSolDuration
end

-- Builds the list of all 7 rules with their current visibility status.
function Moonie_EvaluateRules()
    local isRemaining, isActive, mfRemaining, mfActive = Moonie_GetDotStatus()

    local natEclRemaining, natEclActive = GetRemaining(Moonie.selfBuffs.natureEclipse)
    local arcEclRemaining, arcEclActive = GetRemaining(Moonie.selfBuffs.arcaneEclipse)
    local _, natSolActive = GetRemaining(Moonie.selfDebuffs.naturalSolstice)
    local _, arcSolActive = GetRemaining(Moonie.selfDebuffs.arcaneSolstice)

    local rule = {}

    -- ---- Rule 1: Insect Swarm ----
    -- Case A: swarm not on target AND no Eclipse running at all
    -- Case B: nature eclipse running with <2s left AND (swarm not on target OR <12s left)
    local condA1 = (not isActive) and (not natEclActive) and (not arcEclActive)
    local condB1 = natEclActive and (natEclRemaining < 2) and ((not isActive) or (isRemaining < 12))
    rule[1] = { icon = Moonie.ICONS.insectSwarm, visible = (condA1 or condB1), group = nil }

    -- ---- Rule 2: Moonfire ----
    -- Case A: moonfire not on target AND no Eclipse running at all
    -- Case B: arcane eclipse running with <3.5s left AND (moonfire not on target OR <12s left)
    local condA2 = (not mfActive) and (not natEclActive) and (not arcEclActive)
    local condB2 = arcEclActive and (arcEclRemaining < 3.5) and ((not mfActive) or (mfRemaining < 12))
    rule[2] = { icon = Moonie.ICONS.moonfire, visible = (condA2 or condB2), group = nil }

    -- ---- Rule 3: Starfire (Arcane Eclipse active) ----
    rule[3] = { icon = Moonie.ICONS.starfire, visible = arcEclActive, group = "starfire" }

    -- ---- Rule 4: Wrath (Nature Eclipse active) ----
    rule[4] = { icon = Moonie.ICONS.wrath, visible = natEclActive, group = "wrath" }

    -- ---- Rule 5: Starfire (Natural Solstice debuff on me) ----
    rule[5] = { icon = Moonie.ICONS.starfire, visible = natSolActive, group = "starfire" }

    -- ---- Rule 6: Wrath (Arcane Solstice debuff on me) ----
    rule[6] = { icon = Moonie.ICONS.wrath, visible = arcSolActive, group = "wrath" }

    -- ---- Rule 7: Wrath "dump" (no Eclipse/Solstice active at all) ----
    -- If none of the above is running, just spam Wrath to try to proc an Eclipse.
    local condA7 = (not natEclActive) and (not arcEclActive) and (not natSolActive) and (not arcSolActive)
    rule[7] = { icon = Moonie.ICONS.wrath, visible = condA7, group = "wrath" }

    -- ---- Remove duplicates ----
    -- Within the same group (starfire: 3+5, wrath: 4+6+7), only the rule
    -- with the lower number (= higher priority) stays visible.
    local seenGroup = {}
    local i
    for i = 1, 7 do
        if rule[i].visible and rule[i].group then
            if seenGroup[rule[i].group] then
                rule[i].visible = false
            else
                seenGroup[rule[i].group] = true
            end
        end
    end

    return rule
end
