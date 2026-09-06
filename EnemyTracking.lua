-- =====================================================================
-- Moonie - EnemyTracking.lua
-- Remembers: "did I put Insect Swarm / Moonfire on my current target,
-- and when does it run out?" Needs Nampower (SPELL_GO_SELF event).
--
-- We do NOT listen for a "fades" chat event (unlike Cursive) - instead we
-- simply calculate: "is start+duration already over?" That's simpler and
-- less error-prone. See Priority.lua (GetRemaining function).
-- =====================================================================

-- Default duration of Insect Swarm / Moonfire (base value, can vary with
-- talents - if that becomes an issue, we can use the tooltip scanner here too).
local DOT_DURATION = 18

-- Fallback duration for Faerie Fire in seconds. Has to be defined HERE
-- (above) because the SPELL_GO_SELF handler below already uses it.
local FAERIE_FIRE_DURATION = 40

-- Gets the GUID of my current target.
-- IMPORTANT: this needs to be tested in-game! SuperWoW normally patches
-- UnitExists() so it returns a second value (the GUID). If this does NOT
-- work for you, let me know which SuperWoW function provides GUIDs on
-- your client (e.g. UnitExists might return the GUID as a string, or
-- there might be a separate function like UnitXP("target","guid")).
function Moonie_GetTargetGUID()
    if not UnitExists("target") then
        return nil
    end
    local exists, guid = UnitExists("target")
    return guid
end

local trackFrame = CreateFrame("Frame", "MoonieEnemyFrame")
trackFrame:RegisterEvent("SPELL_GO_SELF")

trackFrame:SetScript("OnEvent", function()
    if event == "SPELL_GO_SELF" then
        -- Argument order per the tracking notes:
        -- itemId, spellID, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed
        local spellID = arg2
        local targetGuid = arg4
        local numTargetsHit = arg6

        if numTargetsHit and numTargetsHit > 0 and targetGuid then
            if not Moonie.enemyDebuffs[targetGuid] then
                Moonie.enemyDebuffs[targetGuid] = {}
            end

            if Moonie_ListContains(Moonie.SPELL_IDS.insectSwarm, spellID) then
                Moonie.enemyDebuffs[targetGuid].insectSwarm = { start = GetTime(), duration = DOT_DURATION }
            elseif Moonie_ListContains(Moonie.SPELL_IDS.moonfire, spellID) then
                Moonie.enemyDebuffs[targetGuid].moonfire = { start = GetTime(), duration = DOT_DURATION }
            elseif Moonie_ListContains(Moonie.SPELL_IDS.faerieFire, spellID) then
                Moonie.enemyDebuffs[targetGuid].faerieFire = { start = GetTime(), duration = FAERIE_FIRE_DURATION }
            end
        end
    end
end)

-- =====================================================================
-- FAERIE FIRE
-- Unlike Moonfire/Insect Swarm above, we need TWO separate things here:
--   1) "Is Faerie Fire on the target AT ALL?" (no matter who cast it) -
--      plain vanilla API (UnitDebuff) is enough for this, everyone can see it.
--   2) "Did I put it there?" - handled by the SPELL_GO_SELF branch above
--      (the elseif line), same as Moonfire/Insect Swarm.
-- Only when BOTH are true do we show the bar+timer in purple.
-- =====================================================================
local ffPresent = false
local ffPollFrame = CreateFrame("Frame", "MoonieFaerieFirePollFrame")
local ffLastPoll = 0
ffPollFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - ffLastPoll < 0.2 then return end
    ffLastPoll = now

    ffPresent = false
    if UnitExists("target") then
        local i = 1
        while true do
            local texture = UnitDebuff("target", i)
            if not texture then break end
            if texture == Moonie.ICONS.faerieFire then
                ffPresent = true
                break
            end
            i = i + 1
        end
    end
end)

-- Returns everything Display.lua needs for the Faerie Fire cell:
--   present   = is it on the target AT ALL (no matter who cast it)?
--   remaining/mine/duration = only valid if I put it there
function Moonie_GetFaerieFireStatus()
    local targetGuid = Moonie_GetTargetGUID()
    local entry = targetGuid and Moonie.enemyDebuffs[targetGuid] and Moonie.enemyDebuffs[targetGuid].faerieFire

    local remaining, mine, duration = 0, false, 0
    if entry and ffPresent then
        local rem = entry.duration - (GetTime() - entry.start)
        if rem > 0 then
            remaining = rem
            duration = entry.duration
            mine = true
        end
    end

    return ffPresent, remaining, mine, duration
end
