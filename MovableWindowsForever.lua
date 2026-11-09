local ADDON_NAME, NS = ...
local FUI = NS.ForeverUI   -- this addon's own copy of the Forever Options-window look (ForeverUI.lua)
local VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "0.2.0"

local MWF = CreateFrame("Frame")
local DB
local optionsFrame
local minimapButton
local MWFUpdateBrokerLauncher
local SELF_ICON = "Interface\\AddOns\\MovableWindowsForever\\Media\\MWFIcon.tga"
local OpenSettings
local pendingApply = {}
local combatProtectedWarned = {}
local installed = {}
local runtimeDefaults = {}
local raidManagerAnchor
local raidManagerDragHandle
local raidManagerTopExpandButton
local raidManagerTopCollapseButton
local raidManagerContentHolder
local raidManagerOriginalParent
local raidManagerOriginalPoints
local raidManagerVisualState
local raidManagerHooksInstalled = false
local bagAnchorHookInstalled = false
local minimapMoveHooksInstalled = false
local minimapPositionHookInstalled = false
local minimapManagedFrame
local minimapMoving = false
local ReanchorRaidManager
local UpdateRaidManagerManagedState
local RestoreRaidManagerNativePosition

-- Profiles: MovableWindowsForeverDB is the account-wide layout; each character can
-- opt into its own layout stored in MovableWindowsForeverCharDB. `DB` always points
-- at whichever profile is currently active so the rest of the file is unchanged.
local accountDB
local charDB
local ActiveProfile
local ReapplyEverything
local ApplyScale
local ClampFrameToScreen
local undoSnapshot   -- deep copy of positions/scales captured before a Reset All, for /mwf undo

local VALID_ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local MIN_WINDOW_SCALE, MAX_WINDOW_SCALE = 0.50, 2.00

local SETTINGS_FRAME_LEVEL = 2000
local HEADER_LEVEL_OFFSET = 500

local BAG_FRAME_NAMES = {
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "ContainerFrame6",
}

local BAG_FRAME_SET = {}
for _, frameName in ipairs(BAG_FRAME_NAMES) do
    BAG_FRAME_SET[frameName] = true
end

local function IsBagFrameName(frameName)
    return BAG_FRAME_SET[frameName] and true or false
end

local function OpenForeverCollection()
    local catalogue = (NS and NS.Catalogue)
    if catalogue and catalogue.Open then
        catalogue:Open()
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Movable Windows Forever:|r Forever Collection is not available.")
    end
end

local function ApplyBlizzardPanelBackground(panel)
    if not panel then return end
    -- The Options window's flat charcoal body and veil (Social Filter Forever's look).
    if FUI and FUI.SkinPanel then
        FUI.SkinPanel(panel, { leftTitle = false })
        return
    end
    if panel.Bg then
        panel.Bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
        if panel.Bg.SetHorizTile then panel.Bg:SetHorizTile(true) end
        if panel.Bg.SetVertTile then panel.Bg:SetVertTile(true) end
        panel.Bg:SetVertexColor(1, 1, 1, 1)
        panel.Bg:SetAlpha(1)
    end
end

local WINDOW_DEFS = {
    { frame = "CharacterFrame",   label = "Character" },
    -- Forever's Legacy window (Y) took over the Achievements key. Its frame name is not fixed across builds, so the
    -- known/likely names are listed here and any other Legacy window is discovered when it opens (see below).
    { frame = "AchievementFrame", label = "Achievements / Legacy" },
    { frame = "LegacyFrame",       label = "Achievements / Legacy" },
    { frame = "LegacyJournal",     label = "Achievements / Legacy" },
    { frame = "LegacyJournalFrame", label = "Achievements / Legacy" },
    { frame = "PlayerLegacyFrame", label = "Achievements / Legacy" },
    { frame = "LegacyUIFrame",     label = "Achievements / Legacy" },

    -- Blizzard manages bag anchors separately from normal UIPanels. Keep the
    -- combined bag and the individual player/reagent containers under one
    -- user-facing Bags setting.
    { frame = "ContainerFrameCombinedBags", label = "Bags", specialBags = true },
    { frame = "ContainerFrame1", label = "Bags", specialBags = true },
    { frame = "ContainerFrame2", label = "Bags", specialBags = true },
    { frame = "ContainerFrame3", label = "Bags", specialBags = true },
    { frame = "ContainerFrame4", label = "Bags", specialBags = true },
    { frame = "ContainerFrame5", label = "Bags", specialBags = true },
    { frame = "ContainerFrame6", label = "Bags", specialBags = true },
    { frame = "MerchantFrame",    label = "Merchant" },
    { frame = "CompactRaidFrameManager", label = "Party / Raid Manager", specialRaidManager = true },

    -- PlayerSpellsFrame is the modern shared root for Spellbook and Talents.
    -- Keep the older aliases for Forever/client compatibility.
    { frame = "PlayerSpellsFrame", label = "Spellbook / Talents" },
    { frame = "SpellBookFrame",    label = "Spellbook / Talents" },
    { frame = "TalentFrame",       label = "Spellbook / Talents" },
    { frame = "PlayerTalentFrame", label = "Spellbook / Talents" },

    -- Modern Map & Quest Log is one WorldMapFrame. QuestLogFrame is retained
    -- as a compatibility alias for clients exposing the older standalone log.
    { frame = "WorldMapFrame",     label = "Map & Quest Log" },
    { frame = "QuestLogFrame",     label = "Map & Quest Log" },

    -- Minimap is managed as a special frame. Dragging is handled from the
    -- zone-title area so normal minimap clicks, pings, and addon buttons remain usable.
    { frame = "MinimapCluster",    label = "Minimap", specialMinimap = true },

    { frame = "CommunitiesFrame",  label = "Guild & Communities" },
    { frame = "GuildFrame",        label = "Guild & Communities" },
    -- Forever uses Blizzard_GroupFinder_VanillaStyle and exposes LFGParentFrame.
    -- PVEFrame is retained as a fallback for other Blizzard UI implementations.
    { frame = "LFGParentFrame",    label = "Looking For Group" },
    { frame = "PVEFrame",          label = "Looking For Group" },
    { frame = "CollectionsJournal",label = "Collections / Appearance" },
    { frame = "CalendarFrame",     label = "Calendar" },

    { frame = "QuestFrame",        label = "Quest Dialogue" },
    { frame = "GossipFrame",       label = "Gossip" },
    { frame = "BankFrame",         label = "Bank" },
    { frame = "MailFrame",         label = "Mail" },
    { frame = "ClassTrainerFrame", label = "Trainer" },
    { frame = "TradeSkillFrame",   label = "Professions" },
    { frame = "ProfessionsFrame",  label = "Professions" },
    { frame = "AuctionFrame",      label = "Auction House" },
    { frame = "AuctionHouseFrame", label = "Auction House" },
    { frame = "GuildBankFrame",    label = "Guild Bank" },
    { frame = "FriendsFrame",      label = "Social" },
    { frame = "SocialUIFrame",     label = "Social" },
    { frame = "InspectFrame",      label = "Inspect" },
}

local RAID_MANAGER_TOGGLE_SKINS = {
    "EXPANDCOLLAPSE",
    "CURRENT",
    "ARROW_SPELLBOOK",
    "ARROW_SCROLLBAR",
    "ARROW_MAP",
    "STREAM_GREEN",
}

local RAID_MANAGER_TOGGLE_SKIN_LABELS = {
    EXPANDCOLLAPSE = "Expand / Collapse",
    CURRENT = "Current Raid Arrow",
    ARROW_SPELLBOOK = "Arrow - Spellbook",
    ARROW_SCROLLBAR = "Arrow - Scrollbar",
    ARROW_MAP = "Arrow - Map",
    STREAM_GREEN = "Green Stream Arrow",
}

local RAID_MANAGER_TOGGLE_SKIN_VALID = {}
for _, skin in ipairs(RAID_MANAGER_TOGGLE_SKINS) do
    RAID_MANAGER_TOGGLE_SKIN_VALID[skin] = true
end

local DEFAULTS = {
    locked = false,
    showMinimapButton = true,
    minimapPos = 220,
    raidManagerArrowRotation = 270,
    raidManagerToggleSkin = "EXPANDCOLLAPSE",
    snapToGrid = false,
    gridSize = 8,
    highlightMovable = false,
    enabled = {},
    positions = {},
    scales = {},
}

for _, def in ipairs(WINDOW_DEFS) do
    DEFAULTS.enabled[def.frame] = true
end

local WINDOW_DEF_BY_FRAME = {}
local LEGACY_LABEL = "Achievements / Legacy"
local legacyGroupFrames   -- the options row's frame list, so discovered Legacy windows join it
for _, def in ipairs(WINDOW_DEFS) do
    WINDOW_DEF_BY_FRAME[def.frame] = def
end

-- One user-facing group per label, shared by the Settings panel, the slash
-- commands (/mwf list, /mwf reset <name>) and Legacy window discovery.
local LABEL_ORDER = {}
local LABEL_GROUPS = {}
for _, def in ipairs(WINDOW_DEFS) do
    local group = LABEL_GROUPS[def.label]
    if not group then
        group = { label = def.label, frames = {} }
        LABEL_GROUPS[def.label] = group
        LABEL_ORDER[#LABEL_ORDER + 1] = def.label
    end
    group.frames[#group.frames + 1] = def.frame
end
-- Windows discovered later (the Legacy window) append to this shared list so they
-- are managed even before the Settings panel has been built.
legacyGroupFrames = LABEL_GROUPS[LEGACY_LABEL] and LABEL_GROUPS[LEGACY_LABEL].frames or nil

-- Fill any fields missing from a stored profile table (in place) so old saved
-- variables and imported layouts always have the complete shape.
local function NormalizeProfile(t)
    if type(t) ~= "table" then t = {} end
    if type(t.enabled) ~= "table" then t.enabled = {} end
    if type(t.positions) ~= "table" then t.positions = {} end
    if type(t.scales) ~= "table" then t.scales = {} end
    if t.locked == nil then t.locked = DEFAULTS.locked end
    if t.showMinimapButton == nil then t.showMinimapButton = DEFAULTS.showMinimapButton end
    if type(t.minimapPos) ~= "number" then t.minimapPos = DEFAULTS.minimapPos end
    if type(t.raidManagerArrowRotation) ~= "number" then
        t.raidManagerArrowRotation = DEFAULTS.raidManagerArrowRotation
    end
    t.raidManagerArrowRotation = (math.floor((t.raidManagerArrowRotation % 360) / 90 + 0.5) % 4) * 90
    t.raidManagerToggleSkin = tostring(t.raidManagerToggleSkin or DEFAULTS.raidManagerToggleSkin):upper()
    if not RAID_MANAGER_TOGGLE_SKIN_VALID[t.raidManagerToggleSkin] then
        t.raidManagerToggleSkin = DEFAULTS.raidManagerToggleSkin
    end
    if t.snapToGrid == nil then t.snapToGrid = DEFAULTS.snapToGrid end
    if type(t.gridSize) ~= "number" or t.gridSize < 1 then t.gridSize = DEFAULTS.gridSize end
    if t.highlightMovable == nil then t.highlightMovable = DEFAULTS.highlightMovable end
    for frameName, enabled in pairs(DEFAULTS.enabled) do
        if t.enabled[frameName] == nil then t.enabled[frameName] = enabled end
    end
    return t
end

ActiveProfile = function()
    if charDB and charDB.useOwn and type(charDB.data) == "table" then
        return charDB.data
    end
    return accountDB
end

local function InitDB()
    if type(MovableWindowsForeverDB) ~= "table" then MovableWindowsForeverDB = {} end
    accountDB = NormalizeProfile(MovableWindowsForeverDB)

    if type(MovableWindowsForeverCharDB) ~= "table" then MovableWindowsForeverCharDB = {} end
    charDB = MovableWindowsForeverCharDB
    if charDB.useOwn == nil then charDB.useOwn = false end
    charDB.data = NormalizeProfile(charDB.data)

    DB = ActiveProfile()
end

local function UpdateMinimapButtonPosition()
    if not minimapButton or not Minimap or not DB then return end
    local angle = math.rad(tonumber(DB.minimapPos) or DEFAULTS.minimapPos)
    local radius = ((Minimap:GetWidth() or 140) / 2) + 7
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateMinimapButtonVisibility()
    if not DB then return end
    if MWFUpdateBrokerLauncher and MWFUpdateBrokerLauncher() then
        if minimapButton then minimapButton:Hide() end
        return
    end
    if not minimapButton then return end
    if DB.showMinimapButton ~= false then minimapButton:Show() else minimapButton:Hide() end
end


-- Standard broker/minimap launcher. Prefer LibDBIcon when another addon provides
-- the library; keep the existing native button only as a fallback.
local MWFLDB, MWFLDBIcon, MWFBroker
local MWFBrokerName = 'Movable Windows Forever'

local function MWFAcquireBrokerLibraries()
    if not LibStub then return false end
    if not MWFLDB then
        local ok, lib = pcall(LibStub, "LibDataBroker-1.1", true)
        if ok then MWFLDB = lib end
    end
    if not MWFLDBIcon then
        local ok, lib = pcall(LibStub, "LibDBIcon-1.0", true)
        if ok then MWFLDBIcon = lib end
    end
    return MWFLDB ~= nil and MWFLDBIcon ~= nil
end

MWFUpdateBrokerLauncher = function()
    if not MWFAcquireBrokerLibraries() then return false end
    local db = DB
    if not db then return false end
    db.minimapLauncher = type(db.minimapLauncher) == "table" and db.minimapLauncher or {}
    local state = db.minimapLauncher
    if type(state.minimapPos) ~= "number" then state.minimapPos = tonumber(DB.minimapPos) or 220 end
    state.hide = not (DB.showMinimapButton ~= false)

    if not MWFBroker then
        local existing = MWFLDB:GetDataObjectByName(MWFBrokerName)
        if existing and existing._mwfForeverLauncher then
            MWFBroker = existing
        else
            MWFBroker = MWFLDB:NewDataObject(MWFBrokerName, {
                type = "launcher",
                text = 'Movable Windows Forever',
                label = 'Movable Windows Forever',
                icon = SELF_ICON,
            })
        end
    end
    if not MWFBroker then return false end
    MWFBroker._mwfForeverLauncher = true
    MWFBroker.type = "launcher"
    MWFBroker.text = 'Movable Windows Forever'
    MWFBroker.label = 'Movable Windows Forever'
    MWFBroker.icon = SELF_ICON
    MWFBroker.OnClick = function(_, button)
        if button == "LeftButton" or button == "RightButton" then
            if optionsFrame and optionsFrame:IsShown() then optionsFrame:Hide() elseif OpenSettings then OpenSettings() end
        end
    end
    MWFBroker.OnTooltipShow = function(tooltip)
        if not tooltip then return end
        tooltip:AddLine('Movable Windows Forever', 1, 0.82, 0)
        tooltip:AddLine("Left-click or right-click: Toggle Settings", 1, 1, 1)
    end

    local registered = false
    if MWFLDBIcon.IsRegistered then
        local ok, result = pcall(MWFLDBIcon.IsRegistered, MWFLDBIcon, MWFBrokerName)
        registered = ok and result and true or false
    end
    if not registered then
        local ok = pcall(function()
            MWFLDBIcon:Register(MWFBrokerName, MWFBroker, state)
        end)
        registered = ok
    end
    if not registered then return false end

    if state.hide then
        pcall(MWFLDBIcon.Hide, MWFLDBIcon, MWFBrokerName)
    else
        pcall(MWFLDBIcon.Show, MWFLDBIcon, MWFBrokerName)
    end
    return true
end

local function CreateMinimapButton()
    if DB and MWFUpdateBrokerLauncher and MWFUpdateBrokerLauncher() then
        if minimapButton then minimapButton:Hide() end
        return minimapButton
    end
    if minimapButton or not Minimap then return minimapButton end

    local button = CreateFrame("Button", "MovableWindowsForeverMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(SELF_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function()
        if optionsFrame and optionsFrame:IsShown() then
            optionsFrame:Hide()
        elseif OpenSettings then
            OpenSettings()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Movable Windows Forever")
        GameTooltip:AddLine("Left-click or right-click: Toggle Settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move this button around the minimap", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function UpdateDragPosition()
        if not DB or not Minimap then return end
        local mx, my = Minimap:GetCenter()
        if not mx or not my then return end
        local scale = Minimap:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        DB.minimapPos = angle
        UpdateMinimapButtonPosition()
    end

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdateDragPosition)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateDragPosition()
    end)

    minimapButton = button
    UpdateMinimapButtonPosition()
    UpdateMinimapButtonVisibility()
    return button
end

local function CanTouchFrame(frame)
    if not frame then return false end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        return false
    end
    return true
end

local function WarnProtectedCombat(frameName)
    if combatProtectedWarned[frameName] then return end
    combatProtectedWarned[frameName] = true

    local def = WINDOW_DEF_BY_FRAME[frameName]
    local label = (def and def.label) or frameName or "This window"
    print("|cffffd100Movable Windows Forever:|r " .. label .. " is protected by Blizzard during combat and cannot be moved until combat ends.")
end

local function CaptureDefaultPoints(frameName, frame)
    if runtimeDefaults[frameName] then return end

    local points = {}
    local n = frame:GetNumPoints() or 0
    for i = 1, n do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        points[#points + 1] = {
            point = point,
            relative = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
            relativeFrame = relativeTo,
            relativePoint = relativePoint,
            x = x or 0,
            y = y or 0,
        }
    end
    runtimeDefaults[frameName] = points
end

local function ResolveRelative(name)
    if name and _G[name] then return _G[name] end
    return UIParent
end

local function IsSpecialFrameName(frameName)
    return frameName == "MinimapCluster" or frameName == "CompactRaidFrameManager"
end

-- Deep copy a saved-position / scales table (one level of nested tables is enough
-- for the shapes MWF stores).
local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DeepCopy(v) end
    return copy
end

-- Nudge a frame back onto the screen if a saved position (often made at a
-- different resolution or UI scale) would leave it partly or fully off-screen.
-- Guarded so it is a no-op for protected frames in combat or unsized frames.
ClampFrameToScreen = function(frame)
    if not frame or type(frame.GetLeft) ~= "function" then return end
    if not CanTouchFrame(frame) then return end

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return end

    local fScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local uiScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if fScale <= 0 or uiScale <= 0 then return end

    -- Work in physical screen pixels so frames at a different scale compare cleanly.
    left, right, top, bottom = left * fScale, right * fScale, top * fScale, bottom * fScale
    local screenW = (GetScreenWidth and GetScreenWidth() or 0) * uiScale
    local screenH = (GetScreenHeight and GetScreenHeight() or 0) * uiScale
    if screenW <= 0 or screenH <= 0 then return end

    local margin = 4 * uiScale
    local dx, dy = 0, 0
    if left < margin then
        dx = margin - left
    elseif right > screenW - margin then
        dx = (screenW - margin) - right
    end
    if bottom < margin then
        dy = margin - bottom
    elseif top > screenH - margin then
        dy = (screenH - margin) - top
    end
    if dx == 0 and dy == 0 then return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, (x or 0) + dx / fScale, (y or 0) + dy / fScale)
end

-- Apply the saved per-window scale. Minimap and Raid Manager are special, secure
-- frames and are intentionally left unscaled.
ApplyScale = function(frameName)
    if not DB or IsSpecialFrameName(frameName) then return end
    local frame = _G[frameName]
    if not frame or type(frame.SetScale) ~= "function" then return end
    local scale = DB.scales and DB.scales[frameName]
    if not scale then return end
    if not CanTouchFrame(frame) then
        pendingApply[frameName] = pendingApply[frameName] or true
        return
    end
    frame:SetScale(scale)
end

-- Round a frame's anchor offsets to the configured grid after a drag.
local function SnapFrameToGrid(frame)
    if not DB or not DB.snapToGrid then return end
    local grid = DB.gridSize or DEFAULTS.gridSize
    if not grid or grid < 1 then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    local sx = math.floor((x or 0) / grid + 0.5) * grid
    local sy = math.floor((y or 0) / grid + 0.5) * grid
    if sx == (x or 0) and sy == (y or 0) then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, sx, sy)
end

local function PositionRaidManagerAnchorAtNativeDefault(anchor)
    if not anchor then return end

    anchor:ClearAllPoints()
    local points = runtimeDefaults.CompactRaidFrameManager
    local p = points and points[1]
    if p then
        anchor:SetPoint(p.point, p.relativeFrame or ResolveRelative(p.relative), p.relativePoint or p.point, p.x or 0, p.y or 0)
    else
        -- Fallback used only if Blizzard's frame was not available early enough
        -- for its original anchor to be captured.
        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -7, -140)
    end
end

-- When MWF takes control of the Raid Manager for the first time, place it at a
-- predictable fully visible mover location instead of inheriting an edge/off-screen
-- native anchor. Once the player drags it, the saved position always wins.
local function PositionRaidManagerAnchorAtMoverDefault(anchor)
    if not anchor then return end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 32, -180)
end

local function GetRaidManagerArrowRotation()
    local degrees = DB and tonumber(DB.raidManagerArrowRotation) or DEFAULTS.raidManagerArrowRotation
    return (math.floor(((degrees or 270) % 360) / 90 + 0.5) % 4) * 90
end

local function GetRaidManagerToggleSkin()
    local skin = DB and tostring(DB.raidManagerToggleSkin or ""):upper() or DEFAULTS.raidManagerToggleSkin
    if not RAID_MANAGER_TOGGLE_SKIN_VALID[skin] then
        skin = DEFAULTS.raidManagerToggleSkin
    end
    return skin
end

local function SetRaidManagerNativeStateAlpha(button, alpha)
    if not button then return end
    local regions = {
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
    }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            region:SetAlpha(alpha)
        end
    end
end

local function EnsureRaidManagerSkinRegions(button)
    if not button then return end

    if not button.MWFSkinBase then
        button.MWFSkinBase = button:CreateTexture(nil, "ARTWORK")
        button.MWFSkinBase:SetPoint("CENTER")
        button.MWFSkinBase:Hide()
    end

    if not button.MWFSkinOverlay then
        button.MWFSkinOverlay = button:CreateTexture(nil, "OVERLAY")
        button.MWFSkinOverlay:SetPoint("CENTER")
        button.MWFSkinOverlay:Hide()
    end
end

local function PrepareRaidManagerSkinRegion(region)
    if not region then return end
    region:ClearAllPoints()
    region:SetPoint("CENTER")
    if region.SetTexCoord then region:SetTexCoord(0, 1, 0, 1) end
    if region.SetVertexColor then region:SetVertexColor(1, 1, 1, 1) end
    if region.SetAlpha then region:SetAlpha(1) end
    if region.SetRotation then region:SetRotation(0) end
end

local function ApplyRaidManagerButtonSkin(button, expanding)
    if not button then return end

    EnsureRaidManagerSkinRegions(button)

    local base = button.MWFSkinBase
    local overlay = button.MWFSkinOverlay
    PrepareRaidManagerSkinRegion(base)
    PrepareRaidManagerSkinRegion(overlay)
    base:Hide()
    overlay:Hide()

    local skin = GetRaidManagerToggleSkin()
    local rotationRadians = math.rad(GetRaidManagerArrowRotation())

    if skin == "CURRENT" then
        -- Blizzard's original Raid Manager toggle does not rotate the whole
        -- tab. The tab stays fixed and only the arrow state changes through
        -- the texture coordinates. Preserve that behavior here.
        if button.MWFApplyCurrentArtwork then
            button.MWFApplyCurrentArtwork(expanding)
        elseif button.MWFRestoreNativeArtwork then
            button.MWFRestoreNativeArtwork()
        end
        SetRaidManagerNativeStateAlpha(button, 1)

        local nativeWidth = tonumber(button.MWFCurrentWidth or button.MWFNativeWidth) or 32
        local nativeHeight = tonumber(button.MWFCurrentHeight or button.MWFNativeHeight) or 32
        button:SetSize(32, 32)

        -- Preserve 0.1.67's native Blizzard open/closed state first, then
        -- rotate the completed native tab into MWF's top-mounted orientation.
        local regions = {
            button.GetNormalTexture and button:GetNormalTexture(),
            button.GetPushedTexture and button:GetPushedTexture(),
            button.GetDisabledTexture and button:GetDisabledTexture(),
            button.GetHighlightTexture and button:GetHighlightTexture(),
        }
        for _, region in ipairs(regions) do
            if region then
                region:ClearAllPoints()
                region:SetPoint("CENTER", button, "CENTER", 0, 0)
                if region.SetSize then region:SetSize(nativeWidth, nativeHeight) end
                if region.SetRotation then region:SetRotation(rotationRadians) end
            end
        end
        return
    end

    -- Keep the secure Button itself unchanged; alternate skins are drawn on
    -- addon-owned texture regions so switching skins never replaces the
    -- captured native Raid Manager artwork.
    SetRaidManagerNativeStateAlpha(button, 0)
    button:SetSize(32, 32)

    if skin == "EXPANDCOLLAPSE" then
        -- Same real Blizzard Button-state implementation used by
        -- Minimap Button Groups Forever. This gives the toggle its native
        -- hover glow, pushed/mouse-down response and disabled state instead
        -- of displaying a static atlas on an addon-owned texture.
        base:Hide()
        overlay:Hide()
        button:SetSize(28, 28)

        -- expanding=true is the button shown while Raid Manager is collapsed.
        -- In that state show the UP artwork; while open show DOWN.
        local expanded = expanding
        local normalAtlas = expanded
            and "common-button-collapseexpand-up"
             or "common-button-collapseexpand-down"
        local pushedAtlas = expanded
            and "common-button-collapseExpand-up-pressed"
             or "common-button-collapseExpand-down-pressed"
        local disabledAtlas = expanded
            and "common-button-collapseExpand-up-disabled"
             or "common-button-collapseExpand-down-disabled"
        local highlightAtlas = "common-button-collapseExpand-hover"

        if button.SetNormalAtlas then
            button:SetNormalAtlas(normalAtlas)
            button:SetPushedAtlas(pushedAtlas)
            button:SetDisabledAtlas(disabledAtlas)
            button:SetHighlightAtlas(highlightAtlas, "ADD")
        else
            button:SetNormalTexture(normalAtlas)
            button:SetPushedTexture(pushedAtlas)
            button:SetDisabledTexture(disabledAtlas)
            button:SetHighlightTexture(highlightAtlas, "ADD")
        end

        local stateTextures = {
            button.GetNormalTexture and button:GetNormalTexture() or nil,
            button.GetPushedTexture and button:GetPushedTexture() or nil,
            button.GetDisabledTexture and button:GetDisabledTexture() or nil,
            button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        }
        for _, tex in ipairs(stateTextures) do
            if tex then
                tex:ClearAllPoints()
                tex:SetAllPoints(button)
                tex:SetAlpha(1)
                if tex.SetRotation then tex:SetRotation(rotationRadians) end
            end
        end

    elseif skin == "ARROW_SPELLBOOK" then
        base:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        base:SetSize(32, 32)
        if base.SetRotation then
            local stateRadians = expanding and (math.pi / 2) or (-math.pi / 2)
            base:SetRotation(stateRadians + rotationRadians)
        end
        base:Show()

    elseif skin == "ARROW_SCROLLBAR" then
        base:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        base:SetSize(32, 32)
        if base.SetRotation then
            local stateRadians = expanding and math.pi or 0
            base:SetRotation(stateRadians + rotationRadians)
        end
        base:Show()

    elseif skin == "ARROW_MAP" then
        -- Use Blizzard's dedicated UP and DOWN map-arrow textures rather than
        -- rotating Arrow-Down-Up. The paired assets keep the visible glyph in
        -- the same place while still changing direction with the toggle state.
        base:SetTexture(
            expanding and "Interface\\Buttons\\Arrow-Up-Up"
                      or "Interface\\Buttons\\Arrow-Down-Up"
        )
        base:SetSize(20, 20)
        if base.SetRotation then base:SetRotation(rotationRadians) end
        base:Show()

    elseif skin == "STREAM_GREEN" then
        base:SetTexture("Interface\\Buttons\\UI-MicroButtonStreamDL-Up")
        base:SetSize(28, 36)
        base:Show()

        overlay:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
        overlay:SetSize(18, 18)
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", button, "CENTER", 0, -1)
        if overlay.SetRotation then
            local stateRadians = expanding and math.pi or 0
            overlay:SetRotation(stateRadians + rotationRadians)
        end
        overlay:Show()
    end
end

local function ApplyRaidManagerToggleAppearance()
    if InCombatLockdown and InCombatLockdown() then
        pendingApply.CompactRaidFrameManager = pendingApply.CompactRaidFrameManager or "raid-appearance"
        return
    end

    ApplyRaidManagerButtonSkin(raidManagerTopExpandButton, true)
    ApplyRaidManagerButtonSkin(raidManagerTopCollapseButton, false)
end

local function ApplyRaidManagerArrowRotation()
    ApplyRaidManagerToggleAppearance()
end

local function GetMinimapManagedFrame()
    if minimapManagedFrame then return minimapManagedFrame end

    local frame = _G.MinimapCluster
    if not frame or type(frame.SetPoint) ~= "function" then
        frame = _G.Minimap
    end

    minimapManagedFrame = frame
    return frame
end

local function SaveMinimapPosition()
    if not DB then return end
    local frame = GetMinimapManagedFrame()
    if not frame then return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end

    DB.positions.MinimapCluster = {
        point = point,
        relative = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

local function ApplySavedMinimapPosition()
    if not DB or not DB.enabled.MinimapCluster then return end

    local frame = GetMinimapManagedFrame()
    local pos = DB.positions.MinimapCluster
    if not frame or not pos then return end

    if not CanTouchFrame(frame) then
        pendingApply.MinimapCluster = "minimap-position"
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        pos.point or "TOPRIGHT",
        ResolveRelative(pos.relative),
        pos.relativePoint or pos.point or "TOPRIGHT",
        pos.x or 0,
        pos.y or 0
    )
    -- MinimapCluster is repositioned directly with SetPoint. Do not call
    -- SetUserPlaced here: during display-mode / UI-scale rebuilds Forever can
    -- expose MinimapCluster as non-movable, which makes SetUserPlaced error.
    pendingApply.MinimapCluster = nil
end

local function RestoreMinimapNativePosition()
    if not DB then return end
    DB.positions.MinimapCluster = nil

    local frame = GetMinimapManagedFrame()
    if not frame then return end

    if not CanTouchFrame(frame) then
        pendingApply.MinimapCluster = "minimap-reset"
        return
    end

    -- MinimapCluster does not need SetUserPlaced(false); restoring its
    -- captured native points is sufficient and avoids display-mode errors.
    local points = runtimeDefaults.MinimapCluster
    if points and #points > 0 then
        frame:ClearAllPoints()
        for _, p in ipairs(points) do
            frame:SetPoint(
                p.point,
                p.relativeFrame or ResolveRelative(p.relative),
                p.relativePoint or p.point,
                p.x or 0,
                p.y or 0
            )
        end
    elseif UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end

    pendingApply.MinimapCluster = nil
end

local function ScheduleMinimapPositionRefresh()
    if not DB or not DB.enabled.MinimapCluster or not DB.positions.MinimapCluster then return end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplySavedMinimapPosition)
        C_Timer.After(0.20, ApplySavedMinimapPosition)
        C_Timer.After(1.00, ApplySavedMinimapPosition)
    else
        ApplySavedMinimapPosition()
    end
end

local function InstallMinimapPositionHook()
    if minimapPositionHookInstalled or not hooksecurefunc then return end
    if type(_G.UIParent_ManageFramePositions) ~= "function" then return end

    minimapPositionHookInstalled = true
    hooksecurefunc("UIParent_ManageFramePositions", function()
        if not minimapMoving then
            ScheduleMinimapPositionRefresh()
        end
    end)
end

local function StopMinimapMove(savePosition)
    if not minimapMoving then return end
    minimapMoving = false

    local frame = GetMinimapManagedFrame()
    if not frame then return end
    if not CanTouchFrame(frame) then
        pendingApply.MinimapCluster = savePosition and "minimap-save-after-drag" or "minimap-position"
        return
    end

    frame:StopMovingOrSizing()
    -- Do not use SetUserPlaced on MinimapCluster; direct point persistence is
    -- enough, and SetUserPlaced can fail after display-mode changes.
    if savePosition then
        SaveMinimapPosition()
    end
end

local function GetMinimapZoneDragHandle()
    -- Retail has used both the global MinimapZoneTextButton and a zone-text
    -- button owned by MinimapCluster across UI revisions. Prefer the global
    -- Blizzard frame when available, then fall back to cluster-owned variants.
    if _G.MinimapZoneTextButton then
        return _G.MinimapZoneTextButton
    end

    local cluster = _G.MinimapCluster
    if cluster then
        if cluster.ZoneTextButton then
            return cluster.ZoneTextButton
        end
        if cluster.ZoneText and type(cluster.ZoneText.HookScript) == "function" then
            return cluster.ZoneText
        end
    end

    return nil
end

local function InstallMinimapMoveHooks()
    if minimapMoveHooksInstalled then return end

    local source = GetMinimapZoneDragHandle()
    local frame = GetMinimapManagedFrame()
    if not source or not frame or type(source.HookScript) ~= "function" then return end

    minimapMoveHooksInstalled = true

    source:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        if not DB or not DB.enabled.MinimapCluster or DB.locked then return end

        if not CanTouchFrame(frame) then
            WarnProtectedCombat("MinimapCluster")
            return
        end

        frame:SetMovable(true)
        if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
        frame:StartMoving()
        minimapMoving = true
    end)

    source:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and minimapMoving then
            StopMinimapMove(true)
        end
    end)

    source:HookScript("OnHide", function()
        if minimapMoving then
            StopMinimapMove(true)
        end
    end)
end

local function ApplySavedPosition(frameName)
    if not DB or not DB.enabled[frameName] then return end
    local frame = _G[frameName]
    local pos = DB.positions[frameName]
    if not frame or not pos then return end

    if not CanTouchFrame(frame) then
        pendingApply[frameName] = true
        return
    end

    frame:ClearAllPoints()
    if type(pos.points) == "table" and #pos.points > 0 then
        -- Multi-anchor frames restore every saved point.
        for _, p in ipairs(pos.points) do
            frame:SetPoint(p.point or "CENTER", ResolveRelative(p.relative), p.relativePoint or p.point or "CENTER", p.x or 0, p.y or 0)
        end
    else
        frame:SetPoint(pos.point or "CENTER", ResolveRelative(pos.relative), pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
    end
    if frame.SetUserPlaced then frame:SetUserPlaced(true) end

    -- Scale first, then clamp, so the on-screen test uses the final size.
    local scale = DB.scales and DB.scales[frameName]
    if scale and type(frame.SetScale) == "function" then frame:SetScale(scale) end
    ClampFrameToScreen(frame)

    pendingApply[frameName] = nil
end

local function ReapplySavedBagPositions()
    if not DB then return end
    for _, frameName in ipairs(BAG_FRAME_NAMES) do
        local frame = _G[frameName]
        local handle = frame and frame.MWFDragHandle
        if frame and DB.enabled[frameName] and DB.positions[frameName] and not (handle and handle.MWFMoving) then
            ApplySavedPosition(frameName)
        end
    end
end

local function ScheduleBagPositionRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ReapplySavedBagPositions)
    else
        ReapplySavedBagPositions()
    end
end

local function InstallBagAnchorHook()
    if bagAnchorHookInstalled or not hooksecurefunc or type(_G.UpdateContainerFrameAnchors) ~= "function" then
        return
    end
    bagAnchorHookInstalled = true
    hooksecurefunc("UpdateContainerFrameAnchors", function()
        ScheduleBagPositionRefresh()
    end)
end

local function SavePosition(frameName)
    local frame = _G[frameName]
    if not frame then return end

    local numPoints = (frame.GetNumPoints and frame:GetNumPoints()) or 1
    if numPoints < 1 then return end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end

    -- Keep the first point as flat fields for backward/export compatibility, and
    -- additionally store every anchor point so multi-anchor frames restore exactly.
    local saved = {
        point = point,
        relative = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
    if numPoints > 1 then
        local points = {}
        for i = 1, numPoints do
            local p, rel, rp, px, py = frame:GetPoint(i)
            if p then
                points[#points + 1] = {
                    point = p,
                    relative = rel and rel.GetName and rel:GetName() or "UIParent",
                    relativePoint = rp or p,
                    x = px or 0,
                    y = py or 0,
                }
            end
        end
        saved.points = points
    end
    DB.positions[frameName] = saved
end

local function RestoreRuntimeDefault(frameName)
    local frame = _G[frameName]
    if not frame then return end

    if not CanTouchFrame(frame) then
        pendingApply[frameName] = "reset"
        return
    end

    DB.positions[frameName] = nil
    if DB.scales then DB.scales[frameName] = nil end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if type(frame.SetScale) == "function" and not IsSpecialFrameName(frameName) then
        frame:SetScale(1)
    end

    local points = runtimeDefaults[frameName]
    if points and #points > 0 then
        frame:ClearAllPoints()
        for _, p in ipairs(points) do
            frame:SetPoint(p.point, p.relativeFrame or ResolveRelative(p.relative), p.relativePoint or p.point, p.x or 0, p.y or 0)
        end
    elseif UpdateUIPanelPositions then
        UpdateUIPanelPositions(frame)
    elseif UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end

    pendingApply[frameName] = nil
end

local function ResetWindow(frameName)
    DB.positions[frameName] = nil
    if DB.scales then DB.scales[frameName] = nil end

    if frameName == "MinimapCluster" then
        RestoreMinimapNativePosition()
        return
    end

    if frameName == "CompactRaidFrameManager" then
        local frame = _G[frameName]
        if raidManagerAnchor then
            PositionRaidManagerAnchorAtNativeDefault(raidManagerAnchor)
        end
        if frame then
            if DB.enabled[frameName] then
                if not CanTouchFrame(frame) then
                    pendingApply[frameName] = "raid-reset"
                else
                    ReanchorRaidManager(frame)
                    UpdateRaidManagerManagedState(frame)
                end
            else
                RestoreRaidManagerNativePosition(frame)
            end
        end
        return
    end
    RestoreRuntimeDefault(frameName)
end

local function GetRaidManagerNativeToggles(frame)
    local out, seen = {}, {}
    local function Add(button)
        if button and not seen[button] then
            seen[button] = true
            out[#out + 1] = button
        end
    end
    Add(frame and frame.toggleButtonBack)
    Add(frame and frame.toggleButtonForward)
    Add(frame and frame.toggleButton)
    Add(_G.CompactRaidFrameManagerToggleButtonBack)
    Add(_G.CompactRaidFrameManagerToggleButtonForward)
    Add(_G.CompactRaidFrameManagerToggleButton)
    return out
end

local function NativeRaidManagerCollapsed(frame)
    if not frame then return false end
    if frame.collapsed ~= nil then return frame.collapsed and true or false end
    if frame.displayFrame and frame.displayFrame.IsShown then
        return not frame.displayFrame:IsShown()
    end
    return false
end

local function RaidManagerCollapsed(frame)
    if DB and DB.enabled and DB.enabled.CompactRaidFrameManager then
        if raidManagerContentHolder and raidManagerContentHolder.IsShown then
            return not raidManagerContentHolder:IsShown()
        end
        if DB.raidManagerCollapsed ~= nil then
            return DB.raidManagerCollapsed and true or false
        end
    end
    return NativeRaidManagerCollapsed(frame)
end

local function CaptureRaidManagerVisuals(frame)
    -- Kept as a compatibility shim for older saved sessions. 0.1.17 no longer
    -- hides individual Blizzard regions because doing so can permanently record
    -- them as hidden when the addon first sees the manager in its collapsed state.
    if raidManagerVisualState or not frame then return end
    raidManagerVisualState = {
        frameAlpha = frame.GetAlpha and frame:GetAlpha() or 1,
        hints = {},
    }
    for _, key in ipairs({"LeftJumpHint", "RightJumpHint", "FocusJumpHint", "GamepadInputIcon"}) do
        local hint = frame[key]
        if hint and hint.IsShown then
            raidManagerVisualState.hints[key] = hint:IsShown() and true or false
        end
    end
end

local function HideRaidManagerShell(frame)
    if not frame then return end
    CaptureRaidManagerVisuals(frame)

    -- Do not Hide() Blizzard's regions or children. The native Expand function
    -- expects to restore those itself. Making the whole manager transparent
    -- removes the detached empty shell while preserving every native shown state.
    if frame.SetAlpha then frame:SetAlpha(0) end
end

local function RestoreRaidManagerShell(frame)
    if not frame then return end
    CaptureRaidManagerVisuals(frame)

    -- Restoring the parent alpha makes whatever Blizzard's native Expand path
    -- chose to show visible again, instead of trying to reconstruct child states.
    if frame.SetAlpha then
        local alpha = raidManagerVisualState and raidManagerVisualState.frameAlpha or 1
        if not alpha or alpha <= 0 then alpha = 1 end
        frame:SetAlpha(alpha)
    end
end

local function CaptureFramePoints(frame)
    local points = {}
    if not frame or not frame.GetNumPoints then return points end
    for i = 1, (frame:GetNumPoints() or 0) do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        points[#points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    return points
end

local function RestoreFramePoints(frame, points)
    if not frame or not points or #points == 0 then return end
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

local function EnsureRaidManagerContentHolder(frame)
    if not frame then return nil end
    if InCombatLockdown and InCombatLockdown() then return raidManagerContentHolder end

    -- Hide/show the complete Blizzard manager as one secure unit. Parenting only
    -- displayFrame strips artwork/regions that live on CompactRaidFrameManager
    -- itself, which is why 0.1.28 could open with missing native visuals.
    if raidManagerContentHolder then
        if frame:GetParent() ~= raidManagerContentHolder then
            frame:SetParent(raidManagerContentHolder)
        end
        return raidManagerContentHolder
    end

    raidManagerOriginalParent = frame:GetParent()
    raidManagerOriginalPoints = CaptureFramePoints(frame)

    raidManagerContentHolder = CreateFrame("Frame", "MovableWindowsForeverRaidManagerContentHolder", UIParent, "SecureHandlerBaseTemplate")
    raidManagerContentHolder:SetSize(1, 1)
    raidManagerContentHolder:Show()

    -- The holder and the buttons are MWF-owned secure frames. Once the protected
    -- manager is parented here, a genuine secure click can hide/show the holder in
    -- combat without importing Blizzard frame handles into RestrictedExecution.
    frame:SetParent(raidManagerContentHolder)
    return raidManagerContentHolder
end

local function RestoreRaidManagerFrameParent(frame)
    if not frame or not raidManagerContentHolder then return end
    frame:SetParent(raidManagerOriginalParent or UIParent)
    RestoreFramePoints(frame, raidManagerOriginalPoints)
    raidManagerContentHolder:Hide()
end

local function EnsureRaidManagerAnchor(frame)
    if raidManagerAnchor then return raidManagerAnchor end
    raidManagerAnchor = CreateFrame("Frame", "MovableWindowsForeverRaidManagerAnchor", UIParent)
    raidManagerAnchor:SetSize(math.max(1, frame:GetWidth() or 260), math.max(1, frame:GetHeight() or 380))
    raidManagerAnchor:SetMovable(true)
    raidManagerAnchor:SetClampedToScreen(true)

    local pos = DB and DB.positions and DB.positions.CompactRaidFrameManager
    if pos then
        raidManagerAnchor:SetPoint(pos.point or "TOPLEFT", ResolveRelative(pos.relative), pos.relativePoint or pos.point or "TOPLEFT", pos.x or 0, pos.y or 0)
    else
        PositionRaidManagerAnchorAtMoverDefault(raidManagerAnchor)
    end
    return raidManagerAnchor
end

local function SaveRaidManagerAnchor()
    if not raidManagerAnchor or not DB then return end
    local point, relativeTo, relativePoint, x, y = raidManagerAnchor:GetPoint(1)
    if not point then return end
    DB.positions.CompactRaidFrameManager = {
        point = point,
        relative = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
    }
end

RestoreRaidManagerNativePosition = function(frame)
    if not frame then return end
    if not CanTouchFrame(frame) then
        pendingApply.CompactRaidFrameManager = "raid-native"
        return
    end

    local points = runtimeDefaults.CompactRaidFrameManager
    if points and #points > 0 then
        frame:ClearAllPoints()
        for _, p in ipairs(points) do
            frame:SetPoint(p.point, p.relativeFrame or ResolveRelative(p.relative), p.relativePoint or p.point, p.x or 0, p.y or 0)
        end
    elseif UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end

    pendingApply.CompactRaidFrameManager = nil
end

ReanchorRaidManager = function(frame)
    if not frame or not DB or not DB.enabled.CompactRaidFrameManager then return end
    if not CanTouchFrame(frame) then
        pendingApply.CompactRaidFrameManager = "raid-reanchor"
        return
    end
    local anchorFrame = EnsureRaidManagerAnchor(frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
    -- CompactRaidFrameManager is not a movable/resizable Blizzard frame.
    -- Calling SetUserPlaced on it raises an error/taint on Forever.
    pendingApply.CompactRaidFrameManager = nil
end

local function SetRaidManagerTopVisual(collapsed)
    if InCombatLockdown and InCombatLockdown() then return end
    if raidManagerTopExpandButton then raidManagerTopExpandButton:SetShown(collapsed and true or false) end
    if raidManagerTopCollapseButton then raidManagerTopCollapseButton:SetShown(not collapsed) end
end

local function SyncRaidManagerSecureButtons(frame, collapsed)
    if not frame or not raidManagerTopExpandButton or not raidManagerTopCollapseButton then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local holder = EnsureRaidManagerContentHolder(frame)
    if not holder then return end

    raidManagerTopExpandButton:SetFrameRef("mwfHolder", holder)
    raidManagerTopCollapseButton:SetFrameRef("mwfHolder", holder)
    raidManagerTopExpandButton:SetFrameRef("mwfOther", raidManagerTopCollapseButton)
    raidManagerTopCollapseButton:SetFrameRef("mwfOther", raidManagerTopExpandButton)

    holder:SetShown(not collapsed)
    SetRaidManagerTopVisual(collapsed)
end

UpdateRaidManagerManagedState = function(frame)
    if not frame or not DB or not DB.enabled.CompactRaidFrameManager then return end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    ReanchorRaidManager(frame)
    CaptureRaidManagerVisuals(frame)
    if frame.SetAlpha then frame:SetAlpha(1) end

    local holder = EnsureRaidManagerContentHolder(frame)
    -- Keep Blizzard's native manager logically expanded. MWF collapses the entire
    -- secure holder instead, preserving every native texture/region/child together.
    if frame.Show then frame:Show() end
    if frame.displayFrame and frame.displayFrame.Show then frame.displayFrame:Show() end
    if frame.collapsed ~= nil then frame.collapsed = false end

    for _, toggle in ipairs(GetRaidManagerNativeToggles(frame)) do
        if toggle.SetAlpha then toggle:SetAlpha(0) end
        if toggle.EnableMouse then toggle:EnableMouse(false) end
    end

    for _, key in ipairs({"LeftJumpHint", "RightJumpHint", "FocusJumpHint", "GamepadInputIcon"}) do
        local hint = frame[key]
        if hint and hint.Hide then hint:Hide() end
    end

    local collapsed = DB.raidManagerCollapsed
    if collapsed == nil then
        collapsed = false
        DB.raidManagerCollapsed = false
    end
    if holder then holder:SetShown(not collapsed) end

    if raidManagerDragHandle then
        raidManagerDragHandle:SetShown(not collapsed)
        raidManagerDragHandle:EnableMouse(not DB.locked and not collapsed)
    end
    if raidManagerTopExpandButton and raidManagerTopCollapseButton then
        ApplyRaidManagerArrowRotation()
        SyncRaidManagerSecureButtons(frame, collapsed)
    end
end

local function EnsureRaidManagerControls(frame)
    -- Secure frame references/attributes cannot be configured by insecure code
    -- during combat lockdown. Existing secure controls keep working; if this
    -- manager first appears in combat, finish setup on PLAYER_REGEN_ENABLED.
    if InCombatLockdown and InCombatLockdown() then
        pendingApply.CompactRaidFrameManager = pendingApply.CompactRaidFrameManager or "raid-controls"
        return
    end

    local anchorFrame = EnsureRaidManagerAnchor(frame)

    local function StartRaidManagerDrag()
        if not DB or DB.locked or not DB.enabled.CompactRaidFrameManager then return end
        if InCombatLockdown and InCombatLockdown() then
            WarnProtectedCombat("CompactRaidFrameManager")
            anchorFrame.MWFMoving = false
            return
        end
        anchorFrame:StartMoving()
        anchorFrame.MWFMoving = true
    end

    local function StopRaidManagerDrag()
        if not anchorFrame.MWFMoving then return end
        anchorFrame.MWFMoving = false
        anchorFrame:StopMovingOrSizing()
        SaveRaidManagerAnchor()
        ReanchorRaidManager(frame)
    end

    if not raidManagerDragHandle then
        raidManagerDragHandle = CreateFrame("Frame", "MovableWindowsForeverRaidManagerDragHandle", UIParent, "SecureHandlerBaseTemplate")
        raidManagerDragHandle:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 8, 0)
        raidManagerDragHandle:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", -8, 0)
        raidManagerDragHandle:SetHeight(16)
        raidManagerDragHandle:SetFrameStrata("HIGH")
        raidManagerDragHandle:SetFrameLevel(100)
        raidManagerDragHandle:RegisterForDrag("LeftButton")
        raidManagerDragHandle:EnableMouse(true)
        raidManagerDragHandle:SetScript("OnDragStart", StartRaidManagerDrag)
        raidManagerDragHandle:SetScript("OnDragStop", StopRaidManagerDrag)
    end

    if not raidManagerTopExpandButton or not raidManagerTopCollapseButton then
        local holder = EnsureRaidManagerContentHolder(frame)
        if not holder then return end

        local function GetNativeRaidToggleSource(expanding)
            local candidates
            if expanding then
                candidates = {
                    frame.toggleButtonForward,
                    _G.CompactRaidFrameManagerToggleButtonForward,
                    frame.toggleButton,
                    _G.CompactRaidFrameManagerToggleButton,
                    frame.toggleButtonBack,
                    _G.CompactRaidFrameManagerToggleButtonBack,
                }
            else
                candidates = {
                    frame.toggleButtonBack,
                    _G.CompactRaidFrameManagerToggleButtonBack,
                    frame.toggleButton,
                    _G.CompactRaidFrameManagerToggleButton,
                    frame.toggleButtonForward,
                    _G.CompactRaidFrameManagerToggleButtonForward,
                }
            end
            for _, candidate in ipairs(candidates) do
                if candidate and candidate.GetNormalTexture and candidate:GetNormalTexture() then
                    return candidate
                end
            end
        end

        local function SnapshotTextureRegion(region)
            if not region then return nil end
            local snap = {}
            if region.GetAtlas then snap.atlas = region:GetAtlas() end
            if region.GetTexture then snap.texture = region:GetTexture() end
            if region.GetTexCoord then snap.texCoord = { region:GetTexCoord() } end
            if region.GetVertexColor then snap.vertexColor = { region:GetVertexColor() } end
            if region.GetBlendMode then snap.blendMode = region:GetBlendMode() end
            return snap
        end

        local function SnapshotButtonArtwork(source)
            if not source then return nil end
            local w, h = source:GetSize()
            return {
                width = w,
                height = h,
                normal = SnapshotTextureRegion(source.GetNormalTexture and source:GetNormalTexture()),
                pushed = SnapshotTextureRegion(source.GetPushedTexture and source:GetPushedTexture()),
                highlight = SnapshotTextureRegion(source.GetHighlightTexture and source:GetHighlightTexture()),
            }
        end

        local function CaptureNativeToggleArtwork(expanding)
            local source = GetNativeRaidToggleSource(expanding)
            if not source then return nil end

            -- Some Forever/Classic clients expose separate forward/back buttons.
            -- When they do, their texture regions already contain the exact atlas
            -- coordinates we need. Never guess how Blizzard packed the sprite.
            if source ~= frame.toggleButton or frame.toggleButtonForward or frame.toggleButtonBack then
                return SnapshotButtonArtwork(source)
            end

            -- Older clients expose one toggle button whose texture coordinates are
            -- changed by Blizzard's Collapse/Expand functions. Capture the actual
            -- live state from the client instead of assuming horizontal halves.
            local wasCollapsed = NativeRaidManagerCollapsed(frame) and true or false
            if expanding then
                if type(CompactRaidFrameManager_Collapse) == "function" then
                    CompactRaidFrameManager_Collapse(frame)
                end
            else
                if type(CompactRaidFrameManager_Expand) == "function" then
                    CompactRaidFrameManager_Expand(frame)
                end
            end
            local snap = SnapshotButtonArtwork(source)
            if wasCollapsed then
                if type(CompactRaidFrameManager_Collapse) == "function" then
                    CompactRaidFrameManager_Collapse(frame)
                end
            else
                if type(CompactRaidFrameManager_Expand) == "function" then
                    CompactRaidFrameManager_Expand(frame)
                end
            end
            return snap
        end

        local function ApplyTextureSnapshot(region, snap)
            if not region or not snap then return end
            if snap.atlas and region.SetAtlas then
                region:SetAtlas(snap.atlas, false)
            elseif snap.texture and region.SetTexture then
                region:SetTexture(snap.texture)
            end
            if snap.texCoord and #snap.texCoord > 0 and region.SetTexCoord then
                region:SetTexCoord(unpack(snap.texCoord))
            end
            if snap.vertexColor and #snap.vertexColor >= 3 and region.SetVertexColor then
                region:SetVertexColor(unpack(snap.vertexColor))
            end
            if snap.blendMode and region.SetBlendMode then
                region:SetBlendMode(snap.blendMode)
            end
        end

        local expandArtwork = CaptureNativeToggleArtwork(true)
        local collapseArtwork = CaptureNativeToggleArtwork(false)

        -- Current Raid Arrow uses one fixed geometry reference so both
        -- states share the same dimensions/center. Each state still applies
        -- its actual Blizzard texture/atlas so the arrow really flips.
        local currentArrowArtwork = collapseArtwork or expandArtwork

        local function ApplyNativeRaidToggleArtwork(button, expanding)
            local artwork = expanding and expandArtwork or collapseArtwork
            if not artwork then return end

            if type(artwork.width) == "number" and type(artwork.height) == "number"
                and artwork.width > 0 and artwork.height > 0 then
                button:SetSize(artwork.width, artwork.height)
            end

            if artwork.normal then
                button:SetNormalTexture(artwork.normal.texture or "")
                local normal = button:GetNormalTexture()
                if normal then
                    normal:SetAllPoints(button)
                    ApplyTextureSnapshot(normal, artwork.normal)
                end
            end

            if artwork.pushed then
                button:SetPushedTexture(artwork.pushed.texture or "")
                local pushed = button:GetPushedTexture()
                if pushed then
                    pushed:SetAllPoints(button)
                    ApplyTextureSnapshot(pushed, artwork.pushed)
                end
            end

            if artwork.highlight then
                button:SetHighlightTexture(artwork.highlight.texture or "")
                local highlight = button:GetHighlightTexture()
                if highlight then
                    highlight:SetAllPoints(button)
                    ApplyTextureSnapshot(highlight, artwork.highlight)
                end
            end
        end

        local function ApplyCurrentRaidArrowArtwork(button, expanding)
            local geometryArtwork = currentArrowArtwork
            local stateArtwork = expanding and expandArtwork or collapseArtwork
            if not button or not geometryArtwork then return end
            stateArtwork = stateArtwork or geometryArtwork

            local function ApplyCurrentState(region, geometrySnap, stateSnap)
                if not region or not geometrySnap then return end

                -- Keep one common geometry/size for both states, but apply
                -- Blizzard's FULL native state snapshot. On Forever the
                -- forward/back arrows can use different texture/atlas assets,
                -- not merely different texture coordinates.
                ApplyTextureSnapshot(region, stateSnap or geometrySnap)
                if region.SetRotation then region:SetRotation(0) end
            end

            local normalSnap = (stateArtwork and stateArtwork.normal) or geometryArtwork.normal
            if normalSnap then
                button:SetNormalTexture(normalSnap.texture or "")
                local normal = button:GetNormalTexture()
                if normal then
                    normal:SetAllPoints(button)
                    ApplyCurrentState(normal, geometryArtwork.normal or normalSnap, normalSnap)
                end
            end

            local pushedSnap = (stateArtwork and stateArtwork.pushed) or geometryArtwork.pushed
            if pushedSnap then
                button:SetPushedTexture(pushedSnap.texture or "")
                local pushed = button:GetPushedTexture()
                if pushed then
                    pushed:SetAllPoints(button)
                    ApplyCurrentState(pushed, geometryArtwork.pushed or pushedSnap, pushedSnap)
                end
            end

            local highlightSnap = (stateArtwork and stateArtwork.highlight) or geometryArtwork.highlight
            if highlightSnap then
                button:SetHighlightTexture(highlightSnap.texture or "")
                local highlight = button:GetHighlightTexture()
                if highlight then
                    highlight:SetAllPoints(button)
                    ApplyCurrentState(highlight, geometryArtwork.highlight or highlightSnap, highlightSnap)
                end
            end
        end

        local function CreateRaidTopButton(name, expanding)
            local button = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
            button:SetSize(32, 32)
            button:SetPoint("BOTTOM", anchorFrame, "TOP", 0, -2)
            button:SetFrameStrata("HIGH")
            button:SetFrameLevel(110)
            button:RegisterForClicks("LeftButtonUp")
            ApplyNativeRaidToggleArtwork(button, expanding)
            button.MWFNativeWidth, button.MWFNativeHeight = button:GetSize()
            button.MWFCurrentWidth = currentArrowArtwork and currentArrowArtwork.width or button.MWFNativeWidth
            button.MWFCurrentHeight = currentArrowArtwork and currentArrowArtwork.height or button.MWFNativeHeight
            button.MWFRestoreNativeArtwork = function()
                ApplyNativeRaidToggleArtwork(button, expanding)
            end
            button.MWFApplyCurrentArtwork = function(expandingState)
                ApplyCurrentRaidArrowArtwork(button, expandingState)
            end
            return button
        end

        raidManagerTopExpandButton = raidManagerTopExpandButton or CreateRaidTopButton("MovableWindowsForeverRaidManagerTopExpand", true)
        raidManagerTopCollapseButton = raidManagerTopCollapseButton or CreateRaidTopButton("MovableWindowsForeverRaidManagerTopCollapse", false)
        ApplyRaidManagerArrowRotation()

        raidManagerTopExpandButton:SetFrameRef("mwfHolder", holder)
        raidManagerTopCollapseButton:SetFrameRef("mwfHolder", holder)
        raidManagerTopExpandButton:SetFrameRef("mwfOther", raidManagerTopCollapseButton)
        raidManagerTopCollapseButton:SetFrameRef("mwfOther", raidManagerTopExpandButton)

        raidManagerTopExpandButton:SetAttribute("_onclick", [=[
            local holder = self:GetFrameRef("mwfHolder")
            local other = self:GetFrameRef("mwfOther")
            if holder then holder:Show() end
            self:Hide()
            if other then other:Show() end
        ]=])
        raidManagerTopCollapseButton:SetAttribute("_onclick", [=[
            local holder = self:GetFrameRef("mwfHolder")
            local other = self:GetFrameRef("mwfOther")
            if holder then holder:Hide() end
            self:Hide()
            if other then other:Show() end
        ]=])

        local function ConfigureTopButton(button, actionText)
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", StartRaidManagerDrag)
            button:SetScript("OnDragStop", StopRaidManagerDrag)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(actionText)
                if InCombatLockdown and InCombatLockdown() then
                    GameTooltip:AddLine("Combat-safe MWF secure toggle", 1, 1, 1)
                else
                    GameTooltip:AddLine("Drag to move", 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:HookScript("PostClick", function()
                if InCombatLockdown and InCombatLockdown() then return end
                if not DB or not DB.enabled.CompactRaidFrameManager then return end
                DB.raidManagerCollapsed = raidManagerContentHolder and (not raidManagerContentHolder:IsShown()) or false
                UpdateRaidManagerManagedState(frame)
            end)
        end

        ConfigureTopButton(raidManagerTopExpandButton, "Expand Party / Raid Manager")
        ConfigureTopButton(raidManagerTopCollapseButton, "Collapse Party / Raid Manager")
    end

    if DB.raidManagerCollapsed == nil then
        DB.raidManagerCollapsed = NativeRaidManagerCollapsed(frame) and true or false
    end
    SyncRaidManagerSecureButtons(frame, DB.raidManagerCollapsed)

    if hooksecurefunc and not raidManagerHooksInstalled then
        raidManagerHooksInstalled = true
        if type(CompactRaidFrameManager_Collapse) == "function" then
            hooksecurefunc("CompactRaidFrameManager_Collapse", function(manager)
                if manager == frame and DB and DB.enabled.CompactRaidFrameManager then
                    if C_Timer and C_Timer.After then C_Timer.After(0, function() UpdateRaidManagerManagedState(frame) end) end
                end
            end)
        end
        if type(CompactRaidFrameManager_Expand) == "function" then
            hooksecurefunc("CompactRaidFrameManager_Expand", function(manager)
                if manager == frame and DB and DB.enabled.CompactRaidFrameManager then
                    if C_Timer and C_Timer.After then C_Timer.After(0, function() UpdateRaidManagerManagedState(frame) end) end
                end
            end)
        end
    end

    UpdateRaidManagerManagedState(frame)
end

local function DisableRaidManagerSpecial(frame)
    if not frame then return end

    if InCombatLockdown and InCombatLockdown() then
        pendingApply.CompactRaidFrameManager = "raid-native"
        return
    end

    local collapsed = RaidManagerCollapsed(frame)
    if DB then DB.raidManagerCollapsed = collapsed end

    if raidManagerDragHandle then raidManagerDragHandle:Hide() end
    if raidManagerTopExpandButton then raidManagerTopExpandButton:Hide() end
    if raidManagerTopCollapseButton then raidManagerTopCollapseButton:Hide() end

    RestoreRaidManagerFrameParent(frame)
    RestoreRaidManagerShell(frame)

    for _, toggle in ipairs(GetRaidManagerNativeToggles(frame)) do
        if toggle.SetAlpha then toggle:SetAlpha(1) end
        if toggle.EnableMouse then toggle:EnableMouse(true) end
    end

    local hintStates = raidManagerVisualState and raidManagerVisualState.hints
    if hintStates then
        for key, wasShown in pairs(hintStates) do
            local hint = frame[key]
            if hint then
                if wasShown and hint.Show then hint:Show()
                elseif (not wasShown) and hint.Hide then hint:Hide() end
            end
        end
    end

    if collapsed then
        if type(CompactRaidFrameManager_Collapse) == "function" then
            CompactRaidFrameManager_Collapse(frame)
        elseif frame.displayFrame then
            frame.displayFrame:Hide()
            if frame.collapsed ~= nil then frame.collapsed = true end
        end
    else
        if type(CompactRaidFrameManager_Expand) == "function" then
            CompactRaidFrameManager_Expand(frame)
        elseif frame.displayFrame then
            frame.displayFrame:Show()
            if frame.collapsed ~= nil then frame.collapsed = false end
        end
    end

    RestoreRaidManagerNativePosition(frame)
end

local function SetFrameEnabled(frameName, enabled)
    DB.enabled[frameName] = enabled and true or false

    if frameName == "MinimapCluster" then
        if DB.enabled.MinimapCluster then
            InstallMinimapMoveHooks()
            ApplySavedMinimapPosition()
        else
            StopMinimapMove(false)
            RestoreMinimapNativePosition()
        end
        return
    end

    local frame = _G[frameName]

    if frameName == "CompactRaidFrameManager" and frame then
        if DB.enabled[frameName] then
            local anchor = EnsureRaidManagerAnchor(frame)
            if not DB.positions.CompactRaidFrameManager then
                PositionRaidManagerAnchorAtMoverDefault(anchor)
            end
            EnsureRaidManagerControls(frame)
            ReanchorRaidManager(frame)
            UpdateRaidManagerManagedState(frame)
        else
            DB.positions[frameName] = nil
            DisableRaidManagerSpecial(frame)
        end
        return
    end

    if frame and frame.MWFDragHandle then
        frame.MWFDragHandle:EnableMouse(DB.enabled[frameName] and not DB.locked)
    end

    if not DB.enabled[frameName] then
        ResetWindow(frameName)
    else
        ApplySavedPosition(frameName)
    end
end

local function UpdateDragHandles()
    for frameName in pairs(installed) do
        local frame = _G[frameName]
        if frameName == "CompactRaidFrameManager" then
            if raidManagerDragHandle and frame then
                local collapsed = RaidManagerCollapsed(frame)
                raidManagerDragHandle:SetShown(not collapsed)
                raidManagerDragHandle:EnableMouse(DB.enabled[frameName] and not DB.locked and not collapsed)
            end
        elseif frame and frame.MWFDragHandle then
            local handle = frame.MWFDragHandle
            local movable = DB.enabled[frameName] and not DB.locked
            handle:EnableMouse(movable)
            local show = movable and DB.highlightMovable and true or false
            if handle.MWFHighlight then
                handle.MWFHighlight:SetColorTexture(1, 0.82, 0, 0.16)
                handle.MWFHighlight:SetShown(show)
            end
            if handle.MWFHighlightLabel then handle.MWFHighlightLabel:SetShown(show) end
        end
    end
end

local function InstallFrame(frameName)
    if installed[frameName] then return end

    if frameName == "MinimapCluster" then
        local frame = GetMinimapManagedFrame()
        if not frame or type(frame.SetMovable) ~= "function" then return end

        CaptureDefaultPoints(frameName, frame)
        installed[frameName] = true
        frame:SetMovable(true)
        if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end

        InstallMinimapMoveHooks()
        InstallMinimapPositionHook()

        if DB.enabled.MinimapCluster and DB.positions.MinimapCluster then
            ScheduleMinimapPositionRefresh()
        end
        return
    end

    local frame = _G[frameName]
    if not frame or type(frame.SetMovable) ~= "function" then return end

    CaptureDefaultPoints(frameName, frame)
    installed[frameName] = true

    if frameName == "CompactRaidFrameManager" then
        frame:SetMovable(false)
        frame:HookScript("OnShow", function()
            if DB.enabled[frameName] and C_Timer and C_Timer.After then
                C_Timer.After(0, function() UpdateRaidManagerManagedState(frame) end)
            end
        end)
        if DB.enabled[frameName] then
            EnsureRaidManagerControls(frame)
            UpdateRaidManagerManagedState(frame)
        end
        return
    end

    frame:SetMovable(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end

    local handle = CreateFrame("Frame", nil, frame)
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 44, -2)
    if frameName == "ContainerFrameCombinedBags" then
        -- Leave the combined-bag search/utility controls on the right clickable.
        handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -180, -2)
    else
        handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -2)
    end
    handle:SetHeight(24)
    handle:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    handle:EnableMouse(DB.enabled[frameName] and not DB.locked)
    handle:RegisterForDrag("LeftButton")
    if handle.EnableMouseWheel then handle:EnableMouseWheel(true) end
    if handle.SetPropagateKeyboardInput then handle:SetPropagateKeyboardInput(true) end
    frame.MWFDragHandle = handle

    -- "Highlight movable windows" overlay: a faint band plus the window's label so
    -- users can see what is grabbable (several windows are dragged by an invisible
    -- strip over the title). Hidden unless the option is on.
    local highlight = handle:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(handle)
    highlight:SetColorTexture(1, 0.82, 0, 0.16)
    highlight:Hide()
    handle.MWFHighlight = highlight

    local highlightLabel = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    highlightLabel:SetPoint("CENTER", handle, "CENTER", 0, 0)
    highlightLabel:SetText((WINDOW_DEF_BY_FRAME[frameName] and WINDOW_DEF_BY_FRAME[frameName].label) or frameName)
    highlightLabel:Hide()
    handle.MWFHighlightLabel = highlightLabel

    local initialHighlight = DB.highlightMovable and DB.enabled[frameName] and not DB.locked and true or false
    highlight:SetShown(initialHighlight)
    highlightLabel:SetShown(initialHighlight)

    local function MovableNow()
        return DB and DB.enabled[frameName] and not DB.locked
    end

    handle:SetScript("OnEnter", function(self)
        if not MovableNow() then return end
        if self.MWFHighlight and DB.highlightMovable then self.MWFHighlight:SetColorTexture(1, 0.82, 0, 0.30) end
        if self.EnableKeyboard then self:EnableKeyboard(true) end
        FUI.ShowTip(self, "ANCHOR_TOP", (WINDOW_DEF_BY_FRAME[frameName] and WINDOW_DEF_BY_FRAME[frameName].label) or frameName,
            "Drag to move. Arrow keys nudge (Shift = 10px). Ctrl + mouse-wheel scales.")
    end)

    handle:SetScript("OnLeave", function(self)
        if self.MWFHighlight and DB and DB.highlightMovable then self.MWFHighlight:SetColorTexture(1, 0.82, 0, 0.16) end
        if self.EnableKeyboard then self:EnableKeyboard(false) end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        FUI.HideTip()
    end)

    -- Ctrl + mouse-wheel over the title scales the window (0.50–2.00).
    handle:SetScript("OnMouseWheel", function(self, delta)
        if not IsControlKeyDown() or not MovableNow() then return end
        if not CanTouchFrame(frame) then WarnProtectedCombat(frameName); return end
        local current = (DB.scales and DB.scales[frameName]) or (frame.GetScale and frame:GetScale()) or 1
        current = current + (delta > 0 and 0.05 or -0.05)
        current = math.max(MIN_WINDOW_SCALE, math.min(MAX_WINDOW_SCALE, math.floor(current * 100 + 0.5) / 100))
        DB.scales = DB.scales or {}
        DB.scales[frameName] = current
        if frame.SetScale then frame:SetScale(current) end
        ClampFrameToScreen(frame)
        local label = (WINDOW_DEF_BY_FRAME[frameName] and WINDOW_DEF_BY_FRAME[frameName].label) or frameName
        print(string.format("|cffffd100Movable Windows Forever:|r %s scale %d%%.", label, math.floor(current * 100 + 0.5)))
    end)

    -- Arrow keys nudge the window pixel-by-pixel while the title is hovered.
    handle:SetScript("OnKeyDown", function(self, key)
        local dx, dy = 0, 0
        local step = IsShiftKeyDown() and 10 or 1
        if key == "UP" then dy = step
        elseif key == "DOWN" then dy = -step
        elseif key == "LEFT" then dx = -step
        elseif key == "RIGHT" then dx = step
        else
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end
        -- It is an arrow key: only consume it when a nudge can actually happen,
        -- otherwise let it propagate so normal movement/keybinds still work.
        if not MovableNow() or not CanTouchFrame(frame) then
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            return
        end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if not point then return end
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, (x or 0) + dx, (y or 0) + dy)
        if frame.SetUserPlaced then frame:SetUserPlaced(true) end
        ClampFrameToScreen(frame)
        SavePosition(frameName)
    end)

    handle:SetScript("OnDragStart", function()
        if DB.locked or not DB.enabled[frameName] then return end
        -- Unprotected Blizzard panels may still move during combat. Protected
        -- panels (notably Spellbook / Talents on Forever) are left untouched
        -- until combat ends to avoid blocked actions and taint.
        if not CanTouchFrame(frame) then
            WarnProtectedCombat(frameName)
            handle.MWFMoving = false
            return
        end
        frame:StartMoving()
        handle.MWFMoving = true
    end)

    handle:SetScript("OnDragStop", function()
        -- OnDragStop can fire even when OnDragStart was rejected. Only stop and
        -- save frames that MWF actually started moving.
        if not handle.MWFMoving then return end
        handle.MWFMoving = false

        if not CanTouchFrame(frame) then
            -- PLAYER_REGEN_DISABLED normally finalizes active drags before
            -- lockdown; keep this fallback for an unexpected protection change.
            pendingApply[frameName] = pendingApply[frameName] or "save-after-drag"
            return
        end

        frame:StopMovingOrSizing()
        SnapFrameToGrid(frame)
        if frame.SetUserPlaced then frame:SetUserPlaced(true) end
        SavePosition(frameName)
        if IsBagFrameName(frameName) then
            ScheduleBagPositionRefresh()
        end
    end)

    frame:HookScript("OnShow", function()
        if not DB.enabled[frameName] then return end
        local function apply()
            if DB.positions[frameName] then ApplySavedPosition(frameName) end
            ApplyScale(frameName)
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, apply)
        else
            apply()
        end
    end)

    if DB.enabled[frameName] then
        if DB.positions[frameName] then ApplySavedPosition(frameName) end
        ApplyScale(frameName)
    end
end

local function InstallAvailableFrames()
    for _, def in ipairs(WINDOW_DEFS) do
        InstallFrame(def.frame)
    end
    InstallBagAnchorHook()
end

-- Legacy window discovery ---------------------------------------------------------------------------------------------
-- Forever's Legacy window (Y) is not one of the stock frame names on every build. When it opens, look for a newly shown,
-- named, window-sized child of UIParent and manage it under the "Achievements / Legacy" row.
local function IsWindowCandidate(child)
    if not child or type(child.GetName) ~= "function" or type(child.SetMovable) ~= "function" then return false end
    if child.IsForbidden and child:IsForbidden() then return false end
    local name = child:GetName()
    if not name or WINDOW_DEF_BY_FRAME[name] or _G[name] ~= child then return false end
    if not (child.IsShown and child:IsShown()) then return false end
    if child.GetObjectType and child:GetObjectType() ~= "Frame" then return false end
    local w, h = child:GetWidth() or 0, child:GetHeight() or 0
    return w >= 250 and h >= 200
end

local function RegisterLegacyWindow(frame)
    local name = frame:GetName()
    if WINDOW_DEF_BY_FRAME[name] then return end
    local def = { frame = name, label = LEGACY_LABEL }
    WINDOW_DEFS[#WINDOW_DEFS + 1] = def
    WINDOW_DEF_BY_FRAME[name] = def
    if legacyGroupFrames then legacyGroupFrames[#legacyGroupFrames + 1] = name end
    if DB and DB.enabled[name] == nil then
        DB.enabled[name] = DB.enabled.AchievementFrame ~= false
    end
    InstallFrame(name)
    UpdateDragHandles()
end

local function ShownUIParentChildren()
    local set = {}
    if not UIParent or not UIParent.GetChildren then return set end
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if child.IsShown and child:IsShown() then set[child] = true end
    end
    return set
end

-- before: the children shown before the Legacy key/button was used (nil = only accept "Legacy" names).
local function DiscoverLegacyWindow(before)
    if not DB or not UIParent or not UIParent.GetChildren then return end
    local best, bestArea
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if IsWindowCandidate(child) then
            local name = child:GetName()
            local namedLegacy = name:lower():find("legacy", 1, true) ~= nil
            if namedLegacy or (before and not before[child]) then
                local area = (child:GetWidth() or 0) * (child:GetHeight() or 0) + (namedLegacy and 1e9 or 0)
                if not best or area > bestArea then best, bestArea = child, area end
            end
        end
    end
    if best then RegisterLegacyWindow(best) end
end

local legacyHooksInstalled = {}
local function InstallLegacyDiscoveryHooks()
    if not C_Timer or not C_Timer.After then return end
    for _, buttonName in ipairs({ "LegacyMicroButton", "AchievementMicroButton" }) do
        local button = _G[buttonName]
        if button and not legacyHooksInstalled[buttonName] and button.HookScript then
            legacyHooksInstalled[buttonName] = true
            local before
            button:HookScript("PreClick", function() before = ShownUIParentChildren() end)
            button:HookScript("OnClick", function()
                local snapshot = before
                before = nil
                C_Timer.After(0, function() DiscoverLegacyWindow(snapshot) end)
                C_Timer.After(0.3, function() DiscoverLegacyWindow(snapshot) end)
            end)
        end
    end
    if hooksecurefunc then
        for _, fnName in ipairs({ "ToggleAchievementFrame", "ToggleLegacyFrame", "ToggleLegacyUI", "ToggleLegacyJournal", "Legacy_Toggle", "LegacyFrame_Toggle" }) do
            if type(_G[fnName]) == "function" and not legacyHooksInstalled[fnName] then
                legacyHooksInstalled[fnName] = true
                hooksecurefunc(fnName, function()
                    C_Timer.After(0, function() DiscoverLegacyWindow(nil) end)
                end)
            end
        end
    end
end

-- Re-sync every managed window to the currently active profile. Used after a
-- profile switch or a layout import so on-screen windows match the data at once.
ReapplyEverything = function()
    if not DB then return end
    for _, def in ipairs(WINDOW_DEFS) do
        local frameName = def.frame
        if DB.enabled[frameName] then
            -- Make sure the frame is managed, then match the active profile exactly:
            -- apply a saved position, or restore the Blizzard default when the profile
            -- has none (so a switch/import never leaves a window at a stale spot).
            SetFrameEnabled(frameName, true)
            if DB.positions[frameName] then
                ApplySavedPosition(frameName)
            elseif not IsSpecialFrameName(frameName) then
                RestoreRuntimeDefault(frameName)
            end
        else
            SetFrameEnabled(frameName, false)
        end
    end
    for frameName in pairs(installed) do
        if DB.enabled[frameName] then ApplyScale(frameName) end
    end
    UpdateDragHandles()
    UpdateMinimapButtonVisibility()
    -- Refresh the open Settings window's controls to the new values.
    if optionsFrame and optionsFrame:IsShown() then
        local onShow = optionsFrame:GetScript("OnShow")
        if onShow then onShow(optionsFrame) end
    end
end

local function SetProfileMode(useOwnProfile)
    if not charDB then return end
    charDB.useOwn = useOwnProfile and true or false
    DB = ActiveProfile()
    ReapplyEverything()
    print("|cffffd100Movable Windows Forever:|r now using the "
        .. (charDB.useOwn and "per-character" or "account-wide") .. " layout.")
end

local function DoResetAllWindows()
    -- Snapshot the current layout so /mwf undo can bring it back.
    undoSnapshot = { positions = DeepCopy(DB.positions), scales = DeepCopy(DB.scales) }
    for _, def in ipairs(WINDOW_DEFS) do
        ResetWindow(def.frame)
    end
    UpdateDragHandles()
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["MWF_RESET_ALL"] = {
    text = "Movable Windows Forever: reset ALL saved window positions and scales to Blizzard defaults?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
        DoResetAllWindows()
        print("|cffffd100Movable Windows Forever:|r all saved positions reset. Use /mwf undo to restore.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ConfirmResetAll()
    if StaticPopup_Show then
        StaticPopup_Show("MWF_RESET_ALL")
    else
        DoResetAllWindows()
    end
end

local function UndoLastReset()
    if not undoSnapshot then
        print("|cffffd100Movable Windows Forever:|r nothing to undo.")
        return
    end
    DB.positions = undoSnapshot.positions or {}
    DB.scales = undoSnapshot.scales or {}
    undoSnapshot = nil
    ReapplyEverything()
    print("|cffffd100Movable Windows Forever:|r last reset undone.")
end

-- Bring any currently shown managed window that is off-screen back into view.
-- Hidden windows self-correct when next opened (ApplySavedPosition clamps on show).
local function RescueWindows()
    local fixed = 0
    for frameName in pairs(installed) do
        if not IsSpecialFrameName(frameName) then
            local frame = _G[frameName]
            if frame and frame:IsShown() and DB.enabled[frameName] and CanTouchFrame(frame) then
                local beforeX = select(4, frame:GetPoint(1))
                ClampFrameToScreen(frame)
                local afterX = select(4, frame:GetPoint(1))
                if beforeX ~= afterX then
                    SavePosition(frameName)
                    fixed = fixed + 1
                end
            end
        end
    end
    print(string.format("|cffffd100Movable Windows Forever:|r rescued %d on-screen window%s. Off-screen windows are corrected automatically when reopened.",
        fixed, fixed == 1 and "" or "s"))
end

-- Re-clamp managed windows after a resolution or UI-scale change (deferred so
-- UIParent has already resized), and persist the corrected positions.
local function ReclampAllWindows()
    if not DB then return end
    for frameName in pairs(installed) do
        if not IsSpecialFrameName(frameName) then
            local frame = _G[frameName]
            if frame and frame:IsShown() and DB.enabled[frameName] and DB.positions[frameName] and CanTouchFrame(frame) then
                ClampFrameToScreen(frame)
                SavePosition(frameName)
            end
        end
    end
end

-- Layout export / import -------------------------------------------------------------------------------------------
-- A plain, line-based text format (no loadstring) so layouts can be shared or
-- backed up. Lines: "MWF1" header, "S|..." settings, one "W|..." per window.
local function ExportLayout()
    local lines = { "MWF1" }
    lines[#lines + 1] = table.concat({
        "S",
        DB.locked and 1 or 0,
        DB.snapToGrid and 1 or 0,
        DB.gridSize or DEFAULTS.gridSize,
        DB.highlightMovable and 1 or 0,
    }, "|")
    for _, def in ipairs(WINDOW_DEFS) do
        local f = def.frame
        local pos = DB.positions[f]
        local scale = DB.scales and DB.scales[f]
        local enabled = DB.enabled[f]
        if pos or scale or enabled == false then
            local p = pos or {}
            lines[#lines + 1] = table.concat({
                "W", f, enabled and 1 or 0, scale or 1,
                p.point or "", p.relative or "", p.relativePoint or "",
                p.x or 0, p.y or 0,
            }, "|")
        end
    end
    return table.concat(lines, "\n")
end

local function ImportLayout(str)
    if type(str) ~= "string" or str == "" then return false, "No data provided." end
    if not str:match("^%s*MWF1") then return false, "Unrecognized format (expected an MWF1 layout string)." end

    local settings
    local newPositions, newScales, newEnabled = {}, {}, {}
    local count = 0
    for line in str:gmatch("[^\r\n]+") do
        if line:sub(1, 2) == "S|" then
            local a, b, c, d = line:match("^S|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
            settings = {
                locked = a == "1",
                snapToGrid = b == "1",
                gridSize = tonumber(c) or DEFAULTS.gridSize,
                highlightMovable = d == "1",
            }
        elseif line:sub(1, 2) == "W|" then
            local parts = {}
            for field in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = field end
            local f = parts[2]
            if f and (WINDOW_DEF_BY_FRAME[f] or f == "MinimapCluster") then
                newEnabled[f] = parts[3] == "1"
                local sc = tonumber(parts[4])
                if sc then newScales[f] = math.max(MIN_WINDOW_SCALE, math.min(MAX_WINDOW_SCALE, sc)) end
                local point = parts[5]
                if VALID_ANCHOR_POINTS[point] then
                    newPositions[f] = {
                        point = point,
                        relative = (parts[6] ~= "" and _G[parts[6]] and parts[6]) or "UIParent",
                        relativePoint = VALID_ANCHOR_POINTS[parts[7]] and parts[7] or point,
                        x = tonumber(parts[8]) or 0,
                        y = tonumber(parts[9]) or 0,
                    }
                end
                count = count + 1
            end
        end
    end

    if count == 0 and not settings then return false, "No windows found in the layout string." end

    if settings then
        DB.locked = settings.locked
        DB.snapToGrid = settings.snapToGrid
        DB.gridSize = (settings.gridSize >= 1) and settings.gridSize or DEFAULTS.gridSize
        DB.highlightMovable = settings.highlightMovable
    end
    for f, v in pairs(newEnabled) do DB.enabled[f] = v end
    DB.positions = newPositions
    DB.scales = newScales
    ReapplyEverything()
    return true, string.format("Imported %d window%s.", count, count == 1 and "" or "s")
end

-- Shared multi-line text dialog used for Export (read-only) and Import (editable).
local ioDialog
local function ShowTextDialog(titleText, bodyText, readOnly, onAccept)
    if not ioDialog then
        local dlg = CreateFrame("Frame", "MovableWindowsForeverIODialog", UIParent, "DefaultPanelTemplate")
        dlg:SetSize(440, 340)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("FULLSCREEN_DIALOG")
        dlg:SetToplevel(true)
        dlg:SetMovable(true)
        dlg:EnableMouse(true)
        dlg:RegisterForDrag("LeftButton")
        dlg:SetScript("OnDragStart", function(self) self:StartMoving() end)
        dlg:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        ApplyBlizzardPanelBackground(dlg)

        dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dlg.title:SetPoint("TOPLEFT", 16, -10)

        local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() dlg:Hide() end)

        local scroll = CreateFrame("ScrollFrame", "$parentScroll", dlg, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -40)
        scroll:SetPoint("BOTTOMRIGHT", -34, 48)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal or GameFontHighlight)
        edit:SetWidth(380)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        dlg.edit = edit

        local accept = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        accept:SetSize(120, 22)
        accept:SetPoint("BOTTOMLEFT", 16, 16)
        dlg.accept = accept

        local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        cancel:SetSize(120, 22)
        cancel:SetPoint("BOTTOMRIGHT", -16, 16)
        cancel:SetText(CANCEL or "Cancel")
        cancel:SetScript("OnClick", function() dlg:Hide() end)

        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = dlg:GetName() end
        ioDialog = dlg
    end

    local dlg = ioDialog
    ApplyBlizzardPanelBackground(dlg)
    dlg.title:SetText(titleText or "")
    dlg.edit:SetText(bodyText or "")
    dlg.edit:SetCursorPosition(0)

    dlg.edit:SetScript("OnTextChanged", nil)
    if readOnly then
        -- Export: select the whole string so the player can copy it with Ctrl+C.
        -- The box stays editable (it is only a throwaway copy to read out).
        dlg.accept:SetText("Select All")
        dlg.accept:SetScript("OnClick", function()
            dlg.edit:SetFocus()
            dlg.edit:HighlightText()
        end)
        dlg.edit:SetFocus()
        dlg.edit:HighlightText()
    else
        dlg.accept:SetText(ACCEPT or "Import")
        dlg.accept:SetScript("OnClick", function()
            local text = dlg.edit:GetText()
            dlg:Hide()
            if onAccept then onAccept(text) end
        end)
        dlg.edit:SetFocus()
    end

    dlg:Show()
    dlg:Raise()
end

-- Reset every frame grouped under a user-facing label (used by /mwf reset <name>).
local function ResetGroupByLabel(labelLower)
    for label, group in pairs(LABEL_GROUPS) do
        if label:lower() == labelLower then
            for _, frameName in ipairs(group.frames) do
                ResetWindow(frameName)
            end
            UpdateDragHandles()
            print("|cffffd100Movable Windows Forever:|r reset '" .. label .. "'.")
            return true
        end
    end
    return false
end

local function ListWindows()
    print("|cffffd100Movable Windows Forever|r — managed windows ("
        .. (charDB and charDB.useOwn and "per-character" or "account-wide") .. " layout):")
    for _, label in ipairs(LABEL_ORDER) do
        local group = LABEL_GROUPS[label]
        local enabled, hasPos, scaled = false, false, nil
        for _, frameName in ipairs(group.frames) do
            if DB.enabled[frameName] then enabled = true end
            if DB.positions[frameName] then hasPos = true end
            if DB.scales[frameName] then scaled = DB.scales[frameName] end
        end
        local bits = {}
        bits[#bits + 1] = enabled and "|cff40ff40on|r" or "|cffff4040off|r"
        if hasPos then bits[#bits + 1] = "moved" end
        if scaled then bits[#bits + 1] = string.format("%d%%", math.floor(scaled * 100 + 0.5)) end
        print("  " .. label .. " — " .. table.concat(bits, ", "))
    end
end

local function MakeCheckbox(parent, x, y, label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)

    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb.MWFText = text
    FUI.SkinCheckButton(cb, text)   -- the Options window's minimal check box, gold label and hover band

    cb:SetScript("OnShow", function(self) self:SetChecked(getter() and true or false) end)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb:SetChecked(getter() and true or false)
    return cb
end

local function MakeButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(text)
    return b
end

local function BuildOptions()
    if optionsFrame then return optionsFrame end

    local panel = CreateFrame("Frame", "MovableWindowsForeverOptions", UIParent, "DefaultPanelTemplate")
    panel:SetSize(650, 724)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(SETTINGS_FRAME_LEVEL)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetToplevel(true)
    panel:Hide()
    panel.name = "Movable Windows Forever"
    optionsFrame = panel

    ApplyBlizzardPanelBackground(panel)

    local title
    if panel.TitleContainer and panel.TitleContainer.TitleText then
        title = panel.TitleContainer.TitleText
        panel.TitleContainer:ClearAllPoints()
        panel.TitleContainer:SetPoint("TOPLEFT", 24, -1)
        panel.TitleContainer:SetPoint("TOPRIGHT", -135, -1)
        title:ClearAllPoints()
        title:SetPoint("LEFT", panel.TitleContainer, "LEFT", 0, 0)
        title:SetPoint("RIGHT", panel.TitleContainer, "RIGHT", 0, 0)
        title:SetJustifyH("LEFT")
    else
        title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 24, -8)
    end
    title:SetText("Movable Windows Forever — Settings")
    panel.titleText = title

    local dragBar = CreateFrame("Frame", nil, panel)
    dragBar:SetPoint("TOPLEFT", 8, -5)
    dragBar:SetPoint("TOPRIGHT", -78, -5)
    dragBar:SetHeight(32)
    dragBar:SetFrameLevel(SETTINGS_FRAME_LEVEL + 1)
    dragBar:EnableMouse(true)
    dragBar:RegisterForDrag("LeftButton")
    dragBar:SetScript("OnDragStart", function() panel:StartMoving() end)
    dragBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    panel.dragBar = dragBar

    local headerOverlay = CreateFrame("Frame", nil, panel)
    headerOverlay:SetAllPoints(panel)
    headerOverlay:SetFrameStrata("LOW")
    headerOverlay:SetFrameLevel(SETTINGS_FRAME_LEVEL + HEADER_LEVEL_OFFSET)
    panel.headerOverlay = headerOverlay

    local close = CreateFrame("Button", nil, headerOverlay, "UIPanelCloseButton")
    close:SetFrameStrata("LOW")
    close:SetFrameLevel(SETTINGS_FRAME_LEVEL + HEADER_LEVEL_OFFSET + 1)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() panel:Hide() end)
    panel.closeButton = close

    local collectionButton = CreateFrame("Button", nil, headerOverlay, "UIPanelButtonTemplate")
    collectionButton:SetFrameStrata("LOW")
    collectionButton:SetFrameLevel(SETTINGS_FRAME_LEVEL + HEADER_LEVEL_OFFSET + 1)
    collectionButton:SetSize(24, 22)
    collectionButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -31, -4)
    collectionButton:SetText("!")
    collectionButton:SetScript("OnClick", OpenForeverCollection)
    collectionButton:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Forever Collection", "Browse the Darkspore Forever addon collection.")
    end)
    collectionButton:SetScript("OnLeave", function() FUI.HideTip() end)
    panel.collectionButton = collectionButton

    local version = headerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("RIGHT", collectionButton, "LEFT", -6, 0)
    version:SetText("v" .. VERSION)
    panel.versionText = version

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 24, -48)
    desc:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Drag supported Blizzard windows by their title area or movable anchor. Drag the Minimap by its zone title. Positions are remembered automatically. Ctrl + mouse-wheel a title to scale a window; hover a title and use arrow keys to nudge it.")
    FUI.Font(desc, "desc")

    local function MakeSectionHeader(parent, x, y, width, label)
        -- An Options section header (white) with the Options divider beside it.
        local section = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        section:SetPoint("TOPLEFT", x, y + 2)
        section:SetText(label)

        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.45, 0.38, 0.24, 0.75)
        line:SetPoint("LEFT", section, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", parent, "TOPLEFT", x + width, 0)
        line:SetHeight(1)
        FUI.SkinDivider(line)
        return section
    end

    MakeSectionHeader(panel, 24, -104, 602, "General")

    local lock = MakeCheckbox(panel, 24, -124, "Lock all window positions", function()
        return DB and DB.locked
    end, function(v)
        DB.locked = v
        UpdateDragHandles()
    end)
    panel.lockCheck = lock

    local showMinimap = MakeCheckbox(panel, 338, -124, "Show minimap button", function()
        return DB and DB.showMinimapButton ~= false
    end, function(v)
        DB.showMinimapButton = v and true or false
        CreateMinimapButton()
        UpdateMinimapButtonVisibility()
    end)
    panel.minimapCheck = showMinimap

    MakeSectionHeader(panel, 24, -166, 602, "Supported Blizzard windows")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 24, -186)
    sub:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("Unchecking a window restores its default position and stops managing it. Windows are grouped by function for easier scanning.")
    FUI.Font(sub, "desc")

    panel.rows = {}

    -- Reuse the shared label groups (also used by the slash commands and Legacy
    -- discovery) so alternate Blizzard frame names stay under one user-facing row.
    local groupByLabel = LABEL_GROUPS

    -- Explicit section order keeps the UI stable and human-readable instead of
    -- exposing the internal WINDOW_DEFS/API order.
    local sections = {
        {
            title = "Character & Social",
            x = 24,
            y = -226,
            width = 286,
            labels = {
                "Achievements / Legacy",
                "Bags",
                "Calendar",
                "Character",
                "Collections / Appearance",
                "Guild & Communities",
                "Inspect",
                "Social",
                "Spellbook / Talents",
            },
        },
        {
            title = "Group & Navigation",
            x = 24,
            y = -466,
            width = 286,
            labels = {
                "Looking For Group",
                "Map & Quest Log",
                "Minimap",
                "Party / Raid Manager",
            },
        },
        {
            title = "NPC & Services",
            x = 338,
            y = -226,
            width = 288,
            labels = {
                "Auction House",
                "Bank",
                "Gossip",
                "Guild Bank",
                "Mail",
                "Merchant",
                "Professions",
                "Quest Dialogue",
                "Trainer",
            },
        },
    }

    local usedLabels = {}

    local function AddWindowRow(group, x, y, width)
        if not group then return end
        local frameNames = group.frames
        local label = group.label

        local cb = MakeCheckbox(panel, x, y, label, function()
            if not DB then return false end
            for _, frameName in ipairs(frameNames) do
                if DB.enabled[frameName] then return true end
            end
            return false
        end, function(v)
            for _, frameName in ipairs(frameNames) do
                SetFrameEnabled(frameName, v)
            end
        end)

        if cb.MWFText then
            cb.MWFText:SetWidth(width - 104)
            cb.MWFText:SetJustifyH("LEFT")
            cb.MWFText:SetWordWrap(false)
        end

        local reset = MakeButton(panel, "Reset", 58, 20)
        reset:SetPoint("TOPLEFT", panel, "TOPLEFT", x + width - 58, y + 2)
        reset:SetScript("OnClick", function()
            for _, frameName in ipairs(frameNames) do
                ResetWindow(frameName)
            end
        end)

        panel.rows[#panel.rows + 1] = { check = cb, reset = reset, frames = frameNames }
    end

    for _, section in ipairs(sections) do
        MakeSectionHeader(panel, section.x, section.y, section.width, section.title)
        local rowY = section.y - 22
        for _, label in ipairs(section.labels) do
            local group = groupByLabel[label]
            if group then
                usedLabels[label] = true
                AddWindowRow(group, section.x, rowY, section.width)
                rowY = rowY - 23
            end
        end
    end

    local raidRotationLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    raidRotationLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 338, -466)
    raidRotationLabel:SetText("Raid Manager Arrow Rotation")

    local rotationSlider = CreateFrame("Slider", "MovableWindowsForeverRaidArrowRotationSlider", panel, "OptionsSliderTemplate")
    rotationSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 338, -486)
    rotationSlider:SetSize(210, 17)
    rotationSlider:SetMinMaxValues(0, 3)
    rotationSlider:SetValueStep(1)
    if rotationSlider.SetObeyStepOnDrag then rotationSlider:SetObeyStepOnDrag(true) end

    local sliderName = rotationSlider:GetName()
    if sliderName then
        local low = _G[sliderName .. "Low"]
        local high = _G[sliderName .. "High"]
        local sliderText = _G[sliderName .. "Text"]
        if low then low:SetText("") end
        if high then high:SetText("") end
        if sliderText then sliderText:SetText("") end
    end
    FUI.SkinSlider(rotationSlider)

    local rotationValue = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rotationValue:SetPoint("LEFT", rotationSlider, "RIGHT", 22, 0)
    rotationValue:SetWidth(48)
    rotationValue:SetJustifyH("LEFT")

    local raidRotations = { 0, 90, 180, 270 }
    local syncingRotationSlider = false

    local function SyncRaidRotationSlider()
        if not DB then return end
        local degrees = GetRaidManagerArrowRotation()
        local index = 0
        for i, value in ipairs(raidRotations) do
            if value == degrees then
                index = i - 1
                break
            end
        end
        syncingRotationSlider = true
        rotationSlider:SetValue(index)
        syncingRotationSlider = false
        rotationValue:SetText(degrees .. "°")
    end

    rotationSlider:SetScript("OnValueChanged", function(self, value)
        local index = math.max(0, math.min(3, math.floor((tonumber(value) or 0) + 0.5)))
        local degrees = raidRotations[index + 1]
        rotationValue:SetText(degrees .. "°")
        if syncingRotationSlider or not DB then return end
        DB.raidManagerArrowRotation = degrees
        ApplyRaidManagerArrowRotation()
    end)

    rotationSlider:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetValue() or 0
        self:SetValue(math.max(0, math.min(3, value + (delta > 0 and 1 or -1))))
    end)
    if rotationSlider.EnableMouseWheel then rotationSlider:EnableMouseWheel(true) end

    rotationSlider:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Raid Manager Arrow Rotation", "Four saved positions: 0°, 90°, 180°, 270°.")
    end)
    rotationSlider:SetScript("OnLeave", function() FUI.HideTip() end)

    panel.raidRotationSlider = rotationSlider
    panel.raidRotationValue = rotationValue
    panel.SyncRaidRotationSlider = SyncRaidRotationSlider
    SyncRaidRotationSlider()

    local raidSkinLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    raidSkinLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 338, -520)
    raidSkinLabel:SetText("Raid Manager Toggle Button Skin")

    -- The Options window's dropdown (WowStyle2); its box lines up with the right-side controls at x = 338.
    local raidSkinOptions = {}
    for _, skin in ipairs(RAID_MANAGER_TOGGLE_SKINS) do
        raidSkinOptions[#raidSkinOptions + 1] = { value = skin, text = RAID_MANAGER_TOGGLE_SKIN_LABELS[skin] or skin }
    end
    local raidSkinDropdown = FUI.MakeDropdown(panel, 322, -534, 210, raidSkinOptions,
        function() return DB and GetRaidManagerToggleSkin() or DEFAULTS.raidManagerToggleSkin end,
        function(skinKey)
            if not DB then return end
            DB.raidManagerToggleSkin = skinKey
            ApplyRaidManagerArrowRotation()
        end, {
            steppers = false,
            tipTitle = "Raid Manager Toggle Button Skin",
            tipBody = "Choose the artwork used by the movable Raid Manager expand/collapse button. Expand / Collapse uses the same interactive Blizzard button states as Minimap Button Groups Forever. Current Raid Arrow preserves MWF's previous artwork.",
        })

    local function SyncRaidToggleSkinDropdown()
        if not DB then return end
        raidSkinDropdown:Refresh()
    end

    panel.raidSkinDropdown = raidSkinDropdown
    panel.SyncRaidToggleSkinDropdown = SyncRaidToggleSkinDropdown
    SyncRaidToggleSkinDropdown()

    -- Future supported frames that have not yet been assigned to a section are
    -- still shown rather than silently disappearing from Settings.
    local otherGroups = {}
    for label, group in pairs(groupByLabel) do
        if not usedLabels[label] then otherGroups[#otherGroups + 1] = group end
    end
    table.sort(otherGroups, function(a, b) return a.label < b.label end)
    if #otherGroups > 0 then
        local otherY = -466
        MakeSectionHeader(panel, 24, otherY, 286, "Other")
        otherY = otherY - 22
        for _, group in ipairs(otherGroups) do
            AddWindowRow(group, 24, otherY, 286)
            otherY = otherY - 23
        end
    end

    -- Layout Tools -------------------------------------------------------------
    MakeSectionHeader(panel, 24, -584, 602, "Layout Tools")

    local profileCheck = MakeCheckbox(panel, 24, -606, "Separate layout for this character", function()
        return charDB and charDB.useOwn
    end, function(v)
        SetProfileMode(v)
    end)
    profileCheck:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Per-character layout",
            "On: this character keeps its own window layout. Off: share the account-wide layout.")
    end)
    profileCheck:SetScript("OnLeave", function() FUI.HideTip() end)
    panel.profileCheck = profileCheck

    local snapCheck = MakeCheckbox(panel, 338, -606, "Snap to grid while dragging", function()
        return DB and DB.snapToGrid
    end, function(v)
        DB.snapToGrid = v and true or false
    end)
    snapCheck:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Snap to grid",
            "Rounds a window to an " .. (DB and DB.gridSize or DEFAULTS.gridSize) .. "px grid when you finish dragging it.")
    end)
    snapCheck:SetScript("OnLeave", function() FUI.HideTip() end)
    panel.snapCheck = snapCheck

    local highlightCheck = MakeCheckbox(panel, 24, -630, "Highlight movable windows", function()
        return DB and DB.highlightMovable
    end, function(v)
        DB.highlightMovable = v and true or false
        UpdateDragHandles()
    end)
    highlightCheck:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Highlight movable windows",
            "Marks each window's draggable title strip with a faint band and label.")
    end)
    highlightCheck:SetScript("OnLeave", function() FUI.HideTip() end)
    panel.highlightCheck = highlightCheck

    local exportBtn = MakeButton(panel, "Export", 90, 22)
    exportBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 338, -632)
    exportBtn:SetScript("OnClick", function()
        ShowTextDialog("Export Layout", ExportLayout(), true)
    end)
    exportBtn:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Export Layout", "Copy a shareable string of the current layout.")
    end)
    exportBtn:SetScript("OnLeave", function() FUI.HideTip() end)

    local importBtn = MakeButton(panel, "Import", 90, 22)
    importBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 436, -632)
    importBtn:SetScript("OnClick", function()
        ShowTextDialog("Import Layout", "", false, function(text)
            local ok, info = ImportLayout(text)
            print("|cffffd100Movable Windows Forever:|r " .. (ok and ("layout imported. " .. (info or "")) or ("import failed — " .. (info or "unknown error."))))
        end)
    end)
    importBtn:SetScript("OnEnter", function(self)
        FUI.ShowTip(self, "ANCHOR_TOP", "Import Layout", "Paste a layout string to replace the current layout.")
    end)
    importBtn:SetScript("OnLeave", function() FUI.HideTip() end)

    local bottomLine = panel:CreateTexture(nil, "ARTWORK")
    bottomLine:SetColorTexture(0.45, 0.38, 0.24, 0.75)
    bottomLine:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 52)
    bottomLine:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 52)
    bottomLine:SetHeight(1)
    FUI.SkinDivider(bottomLine)

    local resetAll = MakeButton(panel, "Reset All Positions", 150, 24)
    resetAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 18)
    resetAll:SetScript("OnClick", ConfirmResetAll)

    local footer = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("LEFT", resetAll, "RIGHT", 12, 0)
    footer:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    footer:SetJustifyH("LEFT")
    footer:SetText("Protected Blizzard windows may need to be moved after combat ends.")
    FUI.Font(footer, "desc")

    panel:SetScript("OnShow", function(self)
        ApplyBlizzardPanelBackground(self)
        if self.lockCheck then self.lockCheck:SetChecked(DB.locked and true or false) end
        if self.minimapCheck then self.minimapCheck:SetChecked(DB.showMinimapButton ~= false) end
        if self.profileCheck then self.profileCheck:SetChecked(charDB and charDB.useOwn and true or false) end
        if self.snapCheck then self.snapCheck:SetChecked(DB.snapToGrid and true or false) end
        if self.highlightCheck then self.highlightCheck:SetChecked(DB.highlightMovable and true or false) end
        if self.SyncRaidRotationSlider then self.SyncRaidRotationSlider() end
        if self.SyncRaidToggleSkinDropdown then self.SyncRaidToggleSkinDropdown() end
        for _, row in ipairs(self.rows or {}) do
            local enabled = false
            for _, frameName in ipairs(row.frames or {}) do
                if DB.enabled[frameName] then
                    enabled = true
                    break
                end
            end
            row.check:SetChecked(enabled)
        end
    end)

    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = panel:GetName()
    end

    return panel
end

OpenSettings = function()
    local panel = BuildOptions()
    ApplyBlizzardPanelBackground(panel)
    panel:Show()
    panel:Raise()
end

SLASH_MOVABLEWINDOWSFOREVER1 = "/mwf"
SLASH_MOVABLEWINDOWSFOREVER2 = "/movablewindows"
local function PrintSlashHelp()
    print("|cffffd100Movable Windows Forever|r commands:")
    print("  |cffffff00/mwf|r — open Settings")
    print("  |cffffff00/mwf reset|r — reset all positions (asks to confirm)")
    print("  |cffffff00/mwf reset <window>|r — reset one window (see /mwf list for names)")
    print("  |cffffff00/mwf undo|r — restore the layout from before the last reset")
    print("  |cffffff00/mwf lock|r / |cffffff00unlock|r — lock or unlock all windows")
    print("  |cffffff00/mwf rescue|r — bring off-screen windows back into view")
    print("  |cffffff00/mwf snap|r — toggle snap-to-grid while dragging")
    print("  |cffffff00/mwf list|r — list managed windows and their state")
    print("  Tip: Ctrl + mouse-wheel a window's title to scale it; hover a title and use arrow keys to nudge.")
end

SlashCmdList.MOVABLEWINDOWSFOREVER = function(msg)
    msg = (msg or ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")

    if cmd == "" then
        OpenSettings()
    elseif cmd == "reset" or cmd == "resetall" then
        if rest and rest ~= "" then
            if not ResetGroupByLabel(rest) then
                print("|cffffd100Movable Windows Forever:|r no window called '" .. rest .. "'. Try /mwf list.")
            end
        else
            ConfirmResetAll()
        end
    elseif cmd == "undo" then
        UndoLastReset()
    elseif cmd == "lock" then
        DB.locked = true
        UpdateDragHandles()
        print("|cffffd100Movable Windows Forever:|r windows locked.")
    elseif cmd == "unlock" then
        DB.locked = false
        UpdateDragHandles()
        print("|cffffd100Movable Windows Forever:|r windows unlocked.")
    elseif cmd == "rescue" then
        RescueWindows()
    elseif cmd == "snap" then
        DB.snapToGrid = not DB.snapToGrid
        print("|cffffd100Movable Windows Forever:|r snap-to-grid " .. (DB.snapToGrid and "on" or "off") .. ".")
    elseif cmd == "list" then
        ListWindows()
    elseif cmd == "help" then
        PrintSlashHelp()
    else
        OpenSettings()
    end
end

MWF:RegisterEvent("ADDON_LOADED")
MWF:RegisterEvent("PLAYER_LOGIN")
MWF:RegisterEvent("PLAYER_ENTERING_WORLD")
MWF:RegisterEvent("DISPLAY_SIZE_CHANGED")
MWF:RegisterEvent("UI_SCALE_CHANGED")
MWF:RegisterEvent("PLAYER_REGEN_DISABLED")
MWF:RegisterEvent("PLAYER_REGEN_ENABLED")
MWF:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            BuildOptions()
            CreateMinimapButton()
            InstallAvailableFrames()
            InstallLegacyDiscoveryHooks()
        elseif DB then
            -- Blizzard windows such as Auction House, Mail, Trainer, etc. may load lazily.
            InstallAvailableFrames()
            InstallLegacyDiscoveryHooks()
        end
    elseif event == "PLAYER_LOGIN" then
        CreateMinimapButton()
        UpdateMinimapButtonPosition()
        UpdateMinimapButtonVisibility()
        InstallAvailableFrames()
        InstallLegacyDiscoveryHooks()
        ScheduleMinimapPositionRefresh()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        InstallAvailableFrames()
        ScheduleMinimapPositionRefresh()
        if event ~= "PLAYER_ENTERING_WORLD" then
            -- A resolution or UI-scale change can push saved positions off-screen.
            -- Re-clamp shown windows once UIParent has finished resizing.
            if C_Timer and C_Timer.After then
                C_Timer.After(0.1, ReclampAllWindows)
            else
                ReclampAllWindows()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Blizzard fires this immediately before combat lockdown takes effect.
        -- Finish any drag already in progress while protected frame methods are
        -- still legal, preventing a mid-drag combat transition from leaving a
        -- window in an unsaved or stuck moving state.
        for frameName in pairs(installed) do
            local frame = _G[frameName]
            local handle = frame and frame.MWFDragHandle
            if frame and handle and handle.MWFMoving then
                handle.MWFMoving = false
                frame:StopMovingOrSizing()
                if frame.SetUserPlaced then frame:SetUserPlaced(true) end
                SavePosition(frameName)
            end
        end
        if raidManagerAnchor and raidManagerAnchor.MWFMoving then
            raidManagerAnchor.MWFMoving = false
            raidManagerAnchor:StopMovingOrSizing()
            SaveRaidManagerAnchor()
            local raidFrame = _G.CompactRaidFrameManager
            if raidFrame then ReanchorRaidManager(raidFrame) end
        end

        if minimapMoving then
            StopMinimapMove(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatProtectedWarned = {}

        -- The secure MWF holder can change visibility during combat. Once
        -- lockdown ends, persist that state and resync the normal mover visuals.
        local raidFrame = _G.CompactRaidFrameManager
        if raidFrame and DB and DB.enabled.CompactRaidFrameManager then
            if raidManagerContentHolder then
                DB.raidManagerCollapsed = not raidManagerContentHolder:IsShown()
            end
            EnsureRaidManagerControls(raidFrame)
            UpdateRaidManagerManagedState(raidFrame)
        end

        for frameName, action in pairs(pendingApply) do
            if frameName == "MinimapCluster" then
                if action == "minimap-reset" then
                    RestoreMinimapNativePosition()
                elseif action == "minimap-save-after-drag" then
                    local frame = GetMinimapManagedFrame()
                    if frame then
                        frame:StopMovingOrSizing()
                        SaveMinimapPosition()
                    end
                    pendingApply.MinimapCluster = nil
                else
                    ApplySavedMinimapPosition()
                end
            elseif frameName == "CompactRaidFrameManager" then
                local frame = _G[frameName]
                if frame then
                    if DB.enabled[frameName] then
                        EnsureRaidManagerControls(frame)
                        if action == "raid-reset" and raidManagerAnchor then
                            PositionRaidManagerAnchorAtNativeDefault(raidManagerAnchor)
                        end
                        ReanchorRaidManager(frame)
                        UpdateRaidManagerManagedState(frame)
                    else
                        DisableRaidManagerSpecial(frame)
                    end
                else
                    pendingApply[frameName] = nil
                end
            elseif action == "reset" then
                RestoreRuntimeDefault(frameName)
            elseif action == "save-after-drag" then
                local frame = _G[frameName]
                if frame then
                    frame:StopMovingOrSizing()
                    if frame.SetUserPlaced then frame:SetUserPlaced(true) end
                    SavePosition(frameName)
                    pendingApply[frameName] = nil
                end
            else
                ApplySavedPosition(frameName)
                ApplyScale(frameName)
            end
        end
    end
end)

if hooksecurefunc then
    hooksecurefunc("ShowUIPanel", function(frame)
        if not frame or not frame.GetName or not DB then return end
        local frameName = frame:GetName()
        if frameName and not WINDOW_DEF_BY_FRAME[frameName] and frameName:lower():find("legacy", 1, true)
            and frame.GetParent and frame:GetParent() == UIParent then
            RegisterLegacyWindow(frame)
        end
        if frameName == "CompactRaidFrameManager" and DB.enabled[frameName] then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    EnsureRaidManagerControls(frame)
                    UpdateRaidManagerManagedState(frame)
                end)
            else
                EnsureRaidManagerControls(frame)
                UpdateRaidManagerManagedState(frame)
            end
            return
        end
        if frameName and DB.enabled[frameName] and DB.positions[frameName] then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() ApplySavedPosition(frameName) end)
            else
                ApplySavedPosition(frameName)
            end
        end
    end)
end
