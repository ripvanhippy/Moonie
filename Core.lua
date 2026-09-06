-- =====================================================================
-- Moonie - Core.lua
-- Foundation: global tables, icon paths, spell IDs, Nampower setup,
-- and the tooltip trick used to find out how long a buff/debuff lasts.
-- =====================================================================

Moonie = {}

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
-- ADDON LOAD / NAMPOWER CHECK
-- =====================================================================
local coreFrame = CreateFrame("Frame", "MoonieCoreFrame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Moonie" then
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

        if not GetNampowerVersion then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Moonie:|r Nampower not found! Enemy debuff tracking will not work.")
        else
            SetCVar("NP_EnableSpellGoEvents", 1)
            SetCVar("NP_EnableSpellStartEvents", 1)
            SetCVar("NP_EnableUnitEventsGuid", 1)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Moonie:|r loaded, Nampower OK.")
        end

        -- Apply the saved click-through state now that the display frames
        -- (Display.lua) and the toggle function (Minimap.lua) both exist,
        -- since ADDON_LOADED only fires after every file has run.
        if Moonie_ApplyClickthrough then
            Moonie_ApplyClickthrough()
        end
    end
end)
