-- =====================================================================
-- Moonie - OwlkinFrenzy.lua
-- Owlkin Frenzy: a Balance-tree talent, 0-3 points. Once talented, the
-- "Owlkin Frenzy" buff can proc when you're hit in melee.
-- The buff effectively has a built-in cooldown: it can't reappear until
-- a certain amount of time has passed since the LAST time it appeared
-- (not since it ended - since it STARTED). How long that cooldown is
-- depends on how many talent points are invested.
-- =====================================================================

-- Cooldown in seconds, depending on invested talent points.
-- 1 point = 30s, 2 points = 25s, 3 points = 20s (0 = not talented).
local TALENT_CD = { [0] = nil, [1] = 30, [2] = 25, [3] = 20 }
local BUFF_DURATION_FALLBACK = 10

Moonie.owlkinRank = 0          -- how many talent points are currently invested
Moonie.owlkinLastStart = nil   -- GetTime() of the last time the buff appeared

-- =====================================================================
-- DETERMINE TALENT RANK
-- Scans all 3 talent trees for "Owlkin Frenzy" and remembers the rank.
-- Called on login and whenever talent points change.
-- =====================================================================
function Moonie_ScanOwlkinTalent()
    local tab
    for tab = 1, 3 do
        local numTalents = GetNumTalents(tab)
        local idx
        for idx = 1, numTalents do
            local name, _, _, _, rank = GetTalentInfo(tab, idx)
            if name == "Owlkin Frenzy" then
                Moonie.owlkinRank = rank
                return
            end
        end
    end
    Moonie.owlkinRank = 0
end

local talentFrame = CreateFrame("Frame", "MoonieOwlkinTalentFrame")
talentFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
talentFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
talentFrame:SetScript("OnEvent", function()
    Moonie_ScanOwlkinTalent()
end)

-- =====================================================================
-- BUFF DETECTION
-- Same trick as Nature/Arcane Eclipse in SelfAuras.lua: you always see
-- your own buffs, no Nampower needed. Checked every 0.2 sec.
-- =====================================================================
local owlkinPollFrame = CreateFrame("Frame", "MoonieOwlkinPollFrame")
local owlkinLastPoll = 0
owlkinPollFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - owlkinLastPoll < 0.2 then return end
    owlkinLastPoll = now

    local present, idx = false, nil
    local i = 1
    while true do
        local texture = UnitBuff("player", i)
        if not texture then break end
        if texture == Moonie.ICONS.owlkinFrenzy then
            present = true
            idx = i
        end
        i = i + 1
    end

    if present then
        if not Moonie.selfBuffs.owlkinFrenzy then
            -- Newly appeared: remember the start time (this is also the
            -- starting point for the cooldown until the next possible proc).
            local dur = Moonie_GetAuraDuration("player", idx, false) or BUFF_DURATION_FALLBACK
            Moonie.selfBuffs.owlkinFrenzy = { start = GetTime(), duration = dur }
            Moonie.owlkinLastStart = GetTime()
        end
    else
        Moonie.selfBuffs.owlkinFrenzy = nil
    end
end)

-- =====================================================================
-- STATUS QUERY for Display.lua
-- Returns:
--   rank                                   = invested talent points (0 = icon off)
--   buffActive, buffRemaining, buffDuration = is the buff running RIGHT NOW?
--   cdActive, cdRemaining, cdDuration       = is the next proc still locked?
-- =====================================================================
function Moonie_GetOwlkinStatus()
    local rank = Moonie.owlkinRank
    local buffActive, buffRemaining, buffDuration = false, 0, 0
    local cdActive, cdRemaining, cdDuration = false, 0, 0

    local buff = Moonie.selfBuffs.owlkinFrenzy
    if buff then
        local rem = buff.duration - (GetTime() - buff.start)
        if rem > 0 then
            buffActive = true
            buffRemaining = rem
            buffDuration = buff.duration
        end
    end

    if rank > 0 and Moonie.owlkinLastStart then
        cdDuration = TALENT_CD[rank]
        local rem = cdDuration - (GetTime() - Moonie.owlkinLastStart)
        if rem > 0 and not buffActive then
            cdActive = true
            cdRemaining = rem
        end
    end

    return rank, buffActive, buffRemaining, buffDuration, cdActive, cdRemaining, cdDuration
end
