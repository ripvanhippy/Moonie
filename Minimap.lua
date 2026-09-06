-- =====================================================================
-- Moonie - Minimap.lua
-- Small button at the top-left edge of the minimap.
--   Left-click  -> dropdown menu with options (Faerie Fire tracking on/off,
--                  click-through windows on/off)
--   Right-click -> toggle "click-through": the Moonie windows then stop
--                  reacting to mouse clicks (e.g. so you don't accidentally
--                  drag them during combat)
-- Both settings are saved in MoonieDB and restored on the next login.
-- =====================================================================

Moonie.clickThrough = false

-- Applies the saved click-through state to the two main windows. Called
-- once from Core.lua's ADDON_LOADED handler (after MoonieDB and the
-- display frames both exist), and also whenever the state is toggled.
function Moonie_ApplyClickthrough()
    Moonie.clickThrough = MoonieDB and MoonieDB.clickThrough or false
    if Moonie.mainFrame then
        Moonie.mainFrame:EnableMouse(not Moonie.clickThrough)
    end
    if Moonie.statusFrame then
        Moonie.statusFrame:EnableMouse(not Moonie.clickThrough)
    end
end

function Moonie_ToggleClickthrough()
    Moonie.clickThrough = not Moonie.clickThrough
    if MoonieDB then
        MoonieDB.clickThrough = Moonie.clickThrough
    end
    if Moonie.mainFrame then
        Moonie.mainFrame:EnableMouse(not Moonie.clickThrough)
    end
    if Moonie.statusFrame then
        Moonie.statusFrame:EnableMouse(not Moonie.clickThrough)
    end

    if Moonie.clickThrough then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Moonie:|r Windows are now click-through.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Moonie:|r Windows react to the mouse again.")
    end
end

-- =====================================================================
-- DROPDOWN MENU (left-click)
-- =====================================================================
local dropDown = CreateFrame("Frame", "MoonieDropDown", UIParent, "UIDropDownMenuTemplate")

local function InitDropdown()
    local info = {}
    info.text = "Track Faerie Fire"
    info.checked = MoonieDB and MoonieDB.trackFaerieFire
    info.func = function()
        MoonieDB.trackFaerieFire = not MoonieDB.trackFaerieFire
    end
    UIDropDownMenu_AddButton(info)

    info = {}
    info.text = "Click-through windows"
    info.checked = MoonieDB and MoonieDB.clickThrough
    info.func = function()
        Moonie_ToggleClickthrough()
    end
    UIDropDownMenu_AddButton(info)
end

UIDropDownMenu_Initialize(dropDown, InitDropdown, "MENU")

function Moonie_ToggleDropdown()
    -- Re-run InitDropdown right before opening, so the checkmarks are
    -- rebuilt from the current MoonieDB values instead of showing
    -- whatever state existed when the menu frame was first created.
    UIDropDownMenu_Initialize(dropDown, InitDropdown, "MENU")
    ToggleDropDownMenu(1, nil, dropDown, "MoonieMinimapButton", 0, 0)
end

-- =====================================================================
-- THE BUTTON ITSELF
-- Size/position values (31x31 button, 53x53 border, icon inset at 7,-5)
-- match the standard minimap-button layout used by most addons, since
-- the "MiniMap-TrackingBorder" ring texture is not centered within its
-- own canvas - anchoring it any other way makes the ring look offset.
-- =====================================================================
local minimapButton = CreateFrame("Button", "MoonieMinimapButton", Minimap)
minimapButton:SetWidth(31)
minimapButton:SetHeight(31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 20)

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture(Moonie.ICONS.owlkinFrenzy)
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -5)
minimapButton.icon = icon

local btnBorder = minimapButton:CreateTexture(nil, "OVERLAY")
btnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btnBorder:SetWidth(53)
btnBorder:SetHeight(53)
btnBorder:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetScript("OnClick", function()
    if arg1 == "RightButton" then
        Moonie_ToggleClickthrough()
    else
        Moonie_ToggleDropdown()
    end
end)

minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Moonie")
    GameTooltip:AddLine("Left-click: menu", 1, 1, 1)
    GameTooltip:AddLine("Right-click: toggle click-through", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
