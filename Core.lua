-- =====================================================================
-- Moonie - Core.lua
-- Foundation: global tables, icon paths, spell IDs, Nampower setup,
-- and the tooltip trick used to find out how long a buff/debuff lasts.
-- =====================================================================

Moonie = {}

-- =====================================================================
-- CLASS CHECK
-- Moonie is a Balance Druid rotation helper. If the logged-in character
-- is not a Druid, the WHOLE addon turns itself off right here - no
-- further checks anywhere else. Every other file starts with
-- "if Moonie.disabled then return end" as its very first line, so none
-- of their frames/events/logic are ever created for a non-Druid.
-- =====================================================================
local _, engClass = UnitClass("player")
if engClass ~= "DRUID" then
    Moonie.disabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Moonie:|r disabled (character is not a Druid).")
    return
end

-- This is where we remember what's currently active.
-- enemyDebuffs: per target GUID, whether MY Insect Swarm / Moonfire is on it
-- selfBuffs / selfDebuffs: the 4 "Eclipse"/"Solstice" auras on myself
Moonie.enemyDebuffs = {}
Moonie.selfBuffs = {}
Moonie.selfDebuffs = {}

-- =====================================================================
-- ICON PATHS
-- If you ever want different icons, change them here - nowhere else.
-- =====================================================================
Moonie.ICONS = {
    insectSwarm     = "Interface\\Icons\\Spell_Nature_InsectSwarm",
    moonfire        = "Interface\\Icons\\Spell_Nature_StarFall",
    wrath           = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    starfire        = "Interface\\Icons\\Spell_Arcane_Starfire",
    natureEclipse   = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    arcaneEclipse   = "Interface\\Icons\\Spell_Nature_WispSplode",
    naturalSolstice = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    arcaneSolstice  = "Interface\\Icons\\Spell_Arcane_Starfire",
    -- Only used for the left-hand status display (Row 2), NOT used to
    -- detect the buffs/debuffs (that happens above via natureEclipse/arcaneEclipse).
    arcaneStatus    = "Interface\\Icons\\Spell_Arcane_Blast",
    natureStatus    = "Interface\\Icons\\Spell_Nature_ProtectionFormNature",
    -- Faerie Fire (target debuff, Row 1 Column 0) and Owlkin Frenzy
    -- (self buff, Row 3 Column 2).
    faerieFire      = "Interface\\Icons\\Spell_Nature_FaerieFire",
    owlkinFrenzy    = "Interface\\Icons\\Ability_Druid_OwlkinFrenzy",
}

-- =====================================================================
-- SPELL IDs (all ranks) - for Insect Swarm and Moonfire
-- Used by EnemyTracking.lua to check "was that MY spell?"
-- =====================================================================
Moonie.SPELL_IDS = {
    insectSwarm = {5570, 24974, 24975, 24976, 24977},
    moonfire    = {8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835},
    -- Faerie Fire (druid version, all 4 ranks). Used in EnemyTracking.lua
    -- to check "did I cast this?".
    faerieFire  = {770, 778, 9749, 9907},
}

-- Helper function: is "id" in the list "list"?
function Moonie_ListContains(list, id)
    local i
    for i = 1, table.getn(list) do
        if list[i] == id then
            return true
        end
    end
    return false
end

-- =====================================================================
-- TOOLTIP DURATION SCANNER
-- Vanilla 1.12 doesn't directly tell you "how long is this buff/debuff
-- left". Trick: an invisible tooltip gets pointed at the buff/debuff
-- slot, and we read out the text "18 sec" etc. Same trick as Cursive.
-- =====================================================================
local scanTip = CreateFrame("GameTooltip", "MoonieScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- unit: "player" or "target"
-- index: the buff/debuff slot number (1,2,3...)
-- isDebuff: true = read a debuff slot, false = read a buff slot
-- Returns the duration in seconds, or nil if nothing was found.
function Moonie_GetAuraDuration(unit, index, isDebuff)
    if not index then return nil end
    scanTip:ClearLines()
    if isDebuff then
        scanTip:SetUnitDebuff(unit, index)
    else
        scanTip:SetUnitBuff(unit, index)
    end
    local textObj = getglobal("MoonieScanTipTextLeft2")
    if not textObj then return nil end
    local text = textObj:GetText()
    if not text then return nil end
    local _, _, sec = string.find(text, "(%d+) sec")
    if sec then
        return tonumber(sec)
    end
    return nil
end

-- =====================================================================
-- UNITXP RANGE HELPER
-- Requires the UnitXP SP3 DLL/addon. Returns the distance to the
-- current target in yards, or nil if UnitXP isn't installed or there's
-- no target right now. Used by Display.lua for the plain range NUMBER
-- shown above the rotation icon (informational only).
-- =====================================================================
function Moonie_GetTargetRange()
    if not UnitXP then return nil end
    if not UnitExists("target") then return nil end
    return UnitXP("distanceBetween", "player", "target")
end

-- =====================================================================
-- NATURE'S REACH TALENT SCAN (for the out-of-range red icon tint)
-- Nature's Reach increases the range of Wrath/Starfire/Moonfire/Insect
-- Swarm: 0 points = 30 yd, 1 point = 33 yd, 2 points = 36 yd. We already
-- have the live UnitXP distance to the target (Moonie_GetTargetRange
-- above) - all that's missing is the current max range, so we compare
-- the two directly instead of asking the spellbook/IsSpellInRange (that
-- API turned out unreliable on this server for the range check).
-- Same talent-scan trick as Moonie_ScanOwlkinTalent() in OwlkinFrenzy.lua:
-- walk every talent tab/index and match by name.
-- =====================================================================
Moonie.natureReachRank = 0

function Moonie_ScanNatureReachTalent()
    local tab
    for tab = 1, 3 do
        local numTalents = GetNumTalents(tab)
        local idx
        for idx = 1, numTalents do
            local name, _, _, _, rank = GetTalentInfo(tab, idx)
            if name == "Nature's Reach" then
                Moonie.natureReachRank = rank
                return
            end
        end
    end
    Moonie.natureReachRank = 0
end

local natureReachFrame = CreateFrame("Frame", "MoonieNatureReachFrame")
natureReachFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
natureReachFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
natureReachFrame:SetScript("OnEvent", function()
    Moonie_ScanNatureReachTalent()
end)

-- Safety net, same reasoning as OwlkinFrenzy.lua's talent poll: some
-- custom respec items don't fire CHARACTER_POINTS_CHANGED reliably.
local natureReachPollFrame = CreateFrame("Frame", "MoonieNatureReachPollFrame")
local natureReachLastPoll = 0
natureReachPollFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - natureReachLastPoll < 5 then return end
    natureReachLastPoll = now
    Moonie_ScanNatureReachTalent()
end)

-- Returns true/false for "is the target in range for the rotation spells
-- right now?", based on the live UnitXP distance and the current
-- Nature's Reach rank. Returns nil if this can't be determined (UnitXP
-- missing, or no target) - callers should treat nil like "don't know",
-- i.e. don't tint red. 'key' is accepted for future use (all 4 rotation
-- spells currently share the same 30/33/36 yd range).
function Moonie_IsRotationSpellInRange(key)
    if not key then return nil end
    local range = Moonie_GetTargetRange()
    if not range then return nil end
    local maxRange = 30 + (Moonie.natureReachRank * 3)
    return range <= maxRange
end

-- =====================================================================
-- ADDON LOAD / NAMPOWER CHECK / UNITXP CHECK
-- Re-applies the MoonieDB defaults and the saved click-through state on
-- BOTH events (not just ADDON_LOADED) as a safety net, in case anything
-- about the saved settings isn't fully ready the very first time you
-- enter the world after logging in.
-- =====================================================================
local coreFrame = CreateFrame("Frame", "MoonieCoreFrame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
coreFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 ~= "Moonie" then
        return
    end

    -- Saved settings (persist across logins/relogs).
    -- MoonieDB.trackFaerieFire - on/off via the minimap dropdown menu.
    -- MoonieDB.clickThrough - on/off via the minimap dropdown menu or right-click.
    MoonieDB = MoonieDB or {}
    if MoonieDB.trackFaerieFire == nil then
        MoonieDB.trackFaerieFire = true
    end
    if MoonieDB.clickThrough == nil then
        MoonieDB.clickThrough = false
    end
    -- MoonieDB.hidden - addon fully hidden/disabled via minimap right-click.
    -- Non-Druids never reach this point at all (see the class check at the
    -- very top of this file), so this only ever applies to Druids who
    -- chose to hide the addon themselves.
    if MoonieDB.hidden == nil then
        MoonieDB.hidden = false
    end

    if event == "ADDON_LOADED" then
        if not GetNampowerVersion then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Moonie:|r Nampower not found! Enemy debuff tracking will not work.")
        else
            SetCVar("NP_EnableSpellGoEvents", 1)
            SetCVar("NP_EnableSpellStartEvents", 1)
            SetCVar("NP_EnableUnitEventsGuid", 1)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Moonie:|r loaded, Nampower OK.")
        end

        if not UnitXP then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Moonie:|r UnitXP not found! Range display will not work.")
        end
    end

    -- Apply the saved click-through state now that the display frames
    -- (Display.lua) and the toggle function (Minimap.lua) both exist,
    -- since ADDON_LOADED only fires after every file has run. Re-run on
    -- PLAYER_ENTERING_WORLD too, so a slow/late SavedVariables load can't
    -- leave Faerie Fire tracking or click-through in the wrong state.
    if Moonie_ApplyClickthrough then
        Moonie_ApplyClickthrough()
    end
    if Moonie_ApplyHidden then
        Moonie_ApplyHidden()
    end
end)
