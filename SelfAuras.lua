-- =====================================================================
-- Moonie - SelfAuras.lua
-- Checks my own buffs/debuffs every ~0.2 seconds (UnitBuff/UnitDebuff on
-- "player") and compares the icon texture against the 4 known auras:
--   Buffs:   Nature Eclipse, Arcane Eclipse       (default duration 15 sec)
--   Debuffs: Natural Solstice, Arcane Solstice    (default duration 30 sec)
-- Doesn't need Nampower - plain vanilla API is enough, because you always
-- see your own auras.
-- =====================================================================
if Moonie.disabled then return end

-- Adds an aura to the storage table (if new) or clears it (if gone).
-- storageTable: Moonie.selfBuffs or Moonie.selfDebuffs
-- key: e.g. "natureEclipse"
-- present: is the aura currently visible?
-- isDebuff: true/false, for the tooltip scanner
-- slotIndex: which buff/debuff slot it's currently in (for the tooltip scan)
-- defaultDuration: fallback duration in seconds, if the tooltip scanner finds nothing
local function UpdateAura(storageTable, key, present, isDebuff, slotIndex, defaultDuration)
    if present then
        if not storageTable[key] then
            local dur = Moonie_GetAuraDuration("player", slotIndex, isDebuff) or defaultDuration
            storageTable[key] = { start = GetTime(), duration = dur }
        end
    else
        storageTable[key] = nil
    end
end

local pollFrame = CreateFrame("Frame", "MoonieSelfFrame")
local lastPoll = 0

pollFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - lastPoll < 0.2 then return end
    lastPoll = now

    -- ---- Buffs (Nature Eclipse, Arcane Eclipse) ----
    local sawNatureEclipse, natureIdx = false, nil
    local sawArcaneEclipse, arcaneIdx = false, nil
    local i = 1
    while true do
        local texture = UnitBuff("player", i)
        if not texture then break end
        if texture == Moonie.ICONS.natureEclipse then
            sawNatureEclipse = true
            natureIdx = i
        elseif texture == Moonie.ICONS.arcaneEclipse then
            sawArcaneEclipse = true
            arcaneIdx = i
        end
        i = i + 1
    end
    UpdateAura(Moonie.selfBuffs, "natureEclipse", sawNatureEclipse, false, natureIdx, 15)
    UpdateAura(Moonie.selfBuffs, "arcaneEclipse", sawArcaneEclipse, false, arcaneIdx, 15)

    -- ---- Debuffs (Natural Solstice, Arcane Solstice) ----
    local sawNaturalSolstice, nsIdx = false, nil
    local sawArcaneSolstice, asIdx = false, nil
    i = 1
    while true do
        local texture = UnitDebuff("player", i)
        if not texture then break end
        if texture == Moonie.ICONS.naturalSolstice then
            sawNaturalSolstice = true
            nsIdx = i
        elseif texture == Moonie.ICONS.arcaneSolstice then
            sawArcaneSolstice = true
            asIdx = i
        end
        i = i + 1
    end
    UpdateAura(Moonie.selfDebuffs, "naturalSolstice", sawNaturalSolstice, true, nsIdx, 30)
    UpdateAura(Moonie.selfDebuffs, "arcaneSolstice", sawArcaneSolstice, true, asIdx, 30)
end)
