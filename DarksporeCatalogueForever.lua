local HOST_ADDON, NS = ...
NS = NS or {}

--[[
DarksporeCatalogueForever

Static reference catalogue. This file is the master copy maintained in
Darkspore Suite Forever and may be copied verbatim into another Forever addon.
Each addon gets its own private Catalogue table through WoW's per-addon namespace.

There is deliberately NO shared global catalogue, revision arbitration, provider
registration, metadata override, merging, or cross-addon synchronization. The UI
shows only the entries physically embedded in BASE_ENTRIES below.
]]

local Catalogue = {}
NS.Catalogue = Catalogue

local CATALOGUE_VERSION = "0.2.40"

Catalogue.currentFilter = "All"
Catalogue.currentPage = 1
Catalogue.expanded = true
Catalogue.frame = nil

local SKIN = {
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    pageLeft = "spellbook-Page-Left-C60",
    pageRight = "spellbook-Page-Right-C60",
}

-- Every catalogue entry's icon is bundled with the catalogue itself in
-- Media\Catalogue\<AddonId>.tga inside whichever addon carries this copy, so
-- all cards show their real artwork whether or not that addon is installed.
-- Copy the whole Media\Catalogue folder together with this file.
local ICON_DIR = "Interface\\AddOns\\" .. tostring(HOST_ADDON) .. "\\Media\\Catalogue\\"
local BUNDLED_ICONS = {
    AddonSpellbookForever = true,
    BackdropsMakerForever = true,
    DontTouchMyRAMForever = true,
    HideBagBarForever = true,
    MacroManagerForever = true,
    MicroMenuForever = true,
    MinimapButtonCreatorForever = true,
    MinimapButtonGroupsForever = true,
    MovableWindowsForever = true,
    NoteBagForever = true,
    PartyBuffTrackerForever = true,
    PartyMapDrawForever = true,
    RXPPartySyncForever = true,
    SocialFilterForever = true,
    TalentCalculatorForever = true,
}

local BASE_ENTRIES = {
    {
        id = "AddonSpellbookForever",
        title = "Addon Spellbook Forever",
        category = "Tools",
        description = "Browse, launch and manage installed addons from the WoW: Forever Spellbook.",
    },
    {
        id = "BackdropsMakerForever",
        title = "Backdrops Maker Forever",
        category = "Interface",
        description = "Create lightweight Blizzard-style backdrop panels for your UI.",
    },
    {
        id = "DontTouchMyRAMForever",
        title = "Don't Touch My RAM Forever",
        category = "Tools",
        description = "Track addon memory use, peaks and live changes without guesswork.",
    },
    {
        id = "HideBagBarForever",
        title = "Hide Bag Bar Forever",
        category = "Interface",
        description = "Automatically hide Blizzard's BagsBar while keeping it easy to configure.",
    },
    {
        id = "MacroManagerForever",
        title = "Macro Manager Forever",
        category = "Tools",
        description = "Create, edit, organize and search macros with a Blizzard-style browser.",
    },
    {
        id = "MinimapButtonCreatorForever",
        title = "Minimap Button Creator Forever",
        category = "Interface",
        description = "Create minimap launchers for commands, spells, items and addon controls.",
    },
    {
        id = "MinimapButtonGroupsForever",
        title = "Minimap Button Groups Forever",
        category = "Interface",
        description = "Group detected minimap buttons into sortable, expandable minimap button groups.",
    },
    {
        id = "MicroMenuForever",
        title = "Micro Menu Forever",
        category = "Interface",
        description = "Replace Blizzard's fixed Micro Menu with a movable, customizable expandable launcher.",
    },
    {
        id = "MovableWindowsForever",
        title = "Movable Windows Forever",
        category = "Interface",
        description = "Move Blizzard windows that Edit Mode cannot move and remember their positions.",
    },
    {
        id = "NoteBagForever",
        title = "Note Bag Forever",
        category = "Tools",
        description = "Store personal notes as WoW-style bag items with rarity, mail-like reading and floating shortcuts.",
    },
    {
        id = "PartyBuffTrackerForever",
        title = "Party Buff Tracker Forever",
        category = "Group",
        description = "Track party and raid buffs, consumables and remaining durations at a glance.",
    },
    {
        id = "PartyMapDrawForever",
        title = "Party Map Draw Forever",
        category = "Group",
        description = "Draw locally or share map markings live with your party or raid.",
    },
    {
        id = "RXPPartySyncForever",
        title = "RXP Party Sync Forever",
        category = "Group",
        description = "Compare RestedXP party progress, XP and steps with desync warnings.",
    },
    {
        id = "TalentCalculatorForever",
        title = "Talent Calculator Forever",
        category = "Tools",
        description = "Plan talents for any WoW: Forever class and level directly inside Blizzard's Talent window.",
    },
    {
        id = "SocialFilterForever",
        title = "Social Filter Forever",
        category = "Tools",
        description = "Filter unwanted chat, spam and social interactions with smart rules for messages, players and guilds.",
    },
}

local CATEGORY_ICONS = {
    Interface = "Interface\\Icons\\INV_Gizmo_02",
    Group = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    Tools = "Interface\\Icons\\INV_Misc_Note_01",
}

local COLLAPSED_WIDTH = 650
local EXPANDED_WIDTH = 1180
local BOOK_HEIGHT = 680
local PAGE_MARGIN_X = 48
local PAGE_TOP = -122
local PAGE_BOTTOM = 46
local ENTRY_HEIGHT = 92
local ENTRIES_PER_PAGE = 5

-- Mouse wheel turns catalogue pages anywhere over the book/page content.
-- WoW sends a positive delta for wheel-up and a negative delta for wheel-down.
local function OnCatalogueMouseWheel(_, delta)
    if not delta or delta == 0 then return end

    local entries = Catalogue:GetFilteredEntries()
    local perView = Catalogue.expanded and (ENTRIES_PER_PAGE * 2) or ENTRIES_PER_PAGE
    local totalPages = math.max(1, math.ceil(#entries / perView))
    local page = tonumber(Catalogue.currentPage) or 1

    if delta > 0 then
        page = math.max(1, page - 1)
    else
        page = math.min(totalPages, page + 1)
    end

    if page ~= Catalogue.currentPage then
        Catalogue.currentPage = page
        Catalogue:Refresh()
    end
end

local function AddonExists(name)
    if not name then return false end
    local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()
        or (GetNumAddOns and GetNumAddOns()) or 0
    for index = 1, count do
        local addonName
        if C_AddOns and C_AddOns.GetAddOnInfo then
            addonName = C_AddOns.GetAddOnInfo(index)
        elseif GetAddOnInfo then
            addonName = GetAddOnInfo(index)
        end
        if addonName == name then return true end
    end
    return false
end

local function IsAddonLoaded(name)
    if not name then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local a, b = C_AddOns.IsAddOnLoaded(name)
        return not not (b or a)
    end
    if IsAddOnLoaded then return not not IsAddOnLoaded(name) end
    return false
end

local function IsAddonEnabled(name)
    if not name then return false end
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local character = UnitGUID and UnitGUID("player") or nil
        if not character and UnitName then
            character = UnitName("player")
        end

        local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, character)
        if ok and type(state) == "number" then
            return state == 2
        end
    end
    return true
end

local function Meta(name, key)
    if not name then return nil end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, name, key)
        if ok then return value end
    end
    if GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, name, key)
        if ok then return value end
    end
    return nil
end

local function EntryIcon(entry)
    if AddonExists(entry.id) then
        local icon = Meta(entry.id, "IconTexture")
        if icon and icon ~= "" then
            return tonumber(icon) or icon
        end
    end
    if BUNDLED_ICONS[entry.id] then
        return ICON_DIR .. entry.id
    end
    return CATEGORY_ICONS[entry.category] or SKIN.icon
end

local function EntryStatus(entry)
    if not AddonExists(entry.id) then
        return "Not Installed", nil, false, false
    end

    local version = Meta(entry.id, "Version")
    local enabled = IsAddonEnabled(entry.id)
    local loaded = IsAddonLoaded(entry.id)

    if not enabled then return "Installed · Disabled", version, true, false end
    if loaded then return "Installed · Loaded", version, true, true end
    return "Installed", version, true, true
end

local function SetAtlasSafe(texture, atlas)
    if texture and texture.SetAtlas then
        local ok = pcall(texture.SetAtlas, texture, atlas)
        if ok then return true end
    end
    return false
end

local function ApplyResponsiveScale(frame)
    if not frame or not UIParent then return end
    local width = Catalogue.expanded and EXPANDED_WIDTH or COLLAPSED_WIDTH
    local parentWidth = math.max(1, UIParent:GetWidth() or 1)
    local parentHeight = math.max(1, UIParent:GetHeight() or 1)
    local scale = math.min(1, (parentWidth - 36) / width, (parentHeight - 36) / BOOK_HEIGHT)
    frame:SetScale(math.max(0.72, scale))
end

local function SetPortrait(frame)
    local portrait = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait
    if portrait then
        portrait:SetTexture(SKIN.icon)
        portrait:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    end
end

local function SetMorpheusFont(fontString, size)
    if not fontString then return false end
    local ok, applied = pcall(fontString.SetFont, fontString, "Fonts\\MORPHEUS.TTF", size, "")
    if ok and applied then return true end
    fontString:SetFontObject(GameFontNormalLarge)
    return false
end

local function CreatePageArt(parent)
    local art = CreateFrame("Frame", nil, parent)
    art:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -82)
    art:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
    art:SetFrameLevel(parent:GetFrameLevel())
    art:SetClipsChildren(true)

    art.backing = art:CreateTexture(nil, "BACKGROUND", nil, -8)
    art.backing:SetAllPoints(art)
    art.backing:SetColorTexture(0.10, 0.07, 0.035, 1)

    art.whole = art:CreateTexture(nil, "BACKGROUND", nil, -7)
    art.whole:SetAllPoints(art)
    if not SetAtlasSafe(art.whole, SKIN.pageRight) then
        art.whole:SetColorTexture(0.72, 0.61, 0.40, 1)
    end

    art.left = art:CreateTexture(nil, "BACKGROUND", nil, -7)
    art.left:SetPoint("TOPLEFT", art, "TOPLEFT")
    art.left:SetPoint("BOTTOMRIGHT", art, "BOTTOM", 0, 0)
    if not SetAtlasSafe(art.left, SKIN.pageLeft) then
        art.left:SetColorTexture(0.72, 0.61, 0.40, 1)
    end

    art.right = art:CreateTexture(nil, "BACKGROUND", nil, -7)
    art.right:SetPoint("TOPLEFT", art, "TOP")
    art.right:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT")
    if not SetAtlasSafe(art.right, SKIN.pageRight) then
        art.right:SetColorTexture(0.72, 0.61, 0.40, 1)
    end

    return art
end

local function CreateFilterTab(parent, text, filter, x)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(104, 28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -44)
    button.filterName = filter

    button.text = button:CreateFontString(nil, "OVERLAY")
    local fontPath, _, fontFlags = GameFontNormal:GetFont()
    button.text:SetFont(fontPath or STANDARD_TEXT_FONT, 15, fontFlags)
    button.text:SetPoint("CENTER")
    button.text:SetText(text)
    button.text:SetTextColor(0.34, 0.20, 0.07)
    button.text:SetShadowColor(0, 0, 0, 0.25)
    button.text:SetShadowOffset(1, -1)

    button.underline = button:CreateTexture(nil, "ARTWORK")
    button.underline:SetHeight(2)
    button.underline:SetPoint("BOTTOMLEFT", 12, 2)
    button.underline:SetPoint("BOTTOMRIGHT", -12, 2)
    button.underline:SetColorTexture(0.72, 0.48, 0.14, 0.75)
    button.underline:Hide()

    button:SetScript("OnClick", function(self)
        Catalogue.currentFilter = self.filterName
        Catalogue.currentPage = 1
        Catalogue:Refresh()
    end)
    button:SetScript("OnEnter", function(self)
        if Catalogue.currentFilter ~= self.filterName then
            self.text:SetTextColor(0.75, 0.48, 0.10)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if Catalogue.currentFilter ~= self.filterName then
            self.text:SetTextColor(0.34, 0.20, 0.07)
        end
    end)
    return button
end

local function UpdateFilterTabs(frame)
    for _, button in ipairs(frame.filterButtons or {}) do
        local active = button.filterName == (Catalogue.currentFilter or "All")
        button.underline:SetShown(active)
        button.text:SetTextColor(active and 0.76 or 0.34, active and 0.48 or 0.20, active and 0.10 or 0.07)
    end
end

local function ClearContainer(container)
    if not container then return end
    for _, child in ipairs({container:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({container:GetRegions()}) do
        region:Hide()
    end
end

local function CreateCatalogueCard(parent, entry, y)
    local card = CreateFrame("Frame", nil, parent)
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", OnCatalogueMouseWheel)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    card:SetHeight(ENTRY_HEIGHT - 4)

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.bg:SetColorTexture(0.32, 0.22, 0.12, 0.035)

    -- Match Addon Spellbook Forever's icon geometry exactly. The spell-background
    -- texture has asymmetric transparent padding, so the visible art must not be
    -- used as the icon's centering reference.
    card.iconBG = card:CreateTexture(nil, "BACKGROUND")
    card.iconBG:SetTexture("Interface\\Spellbook\\UI-Spellbook-SpellBackground")
    card.iconBG:SetSize(64, 64)
    card.iconBG:SetPoint("LEFT", card, "LEFT", -2, 0)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(37, 37)
    card.icon:SetPoint("LEFT", card, "LEFT", 1, 10)
    card.icon:SetTexture(EntryIcon(entry))
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    card.border = card:CreateTexture(nil, "OVERLAY")
    card.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    card.border:SetSize(62, 62)
    card.border:SetPoint("CENTER", card.icon, "CENTER")

    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -5)
    card.name:SetPoint("TOPRIGHT", card, "TOPRIGHT", -132, -5)
    card.name:SetJustifyH("LEFT")
    card.name:SetText(entry.title or entry.id or "Unknown")
    card.name:SetTextColor(0.28, 0.13, 0.035)

    card.category = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.category:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -1)
    card.category:SetText(entry.category or "")
    card.category:SetTextColor(0.49, 0.34, 0.20)

    local status, version, installed, actionable = EntryStatus(entry)
    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -6)
    card.status:SetJustifyH("RIGHT")
    card.status:SetText(version and (status .. " · v" .. tostring(version)) or status)
    if not installed then
        card.status:SetTextColor(0.46, 0.42, 0.36)
    elseif not actionable then
        card.status:SetTextColor(0.68, 0.36, 0.13)
    else
        card.status:SetTextColor(0.20, 0.48, 0.20)
    end

    card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", 54, -39)
    card.desc:SetPoint("RIGHT", card, "RIGHT", -118, 0)
    card.desc:SetHeight(38)
    card.desc:SetJustifyH("LEFT")
    card.desc:SetJustifyV("TOP")
    card.desc:SetWordWrap(true)
    card.desc:SetText(entry.description or "")
    card.desc:SetTextColor(0.34, 0.24, 0.15)


    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.32, 0.22, 0.12, 0.075)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.title or entry.id or "Addon")
        if entry.description and entry.description ~= "" then
            GameTooltip:AddLine(entry.description, 1, 1, 1, true)
        end
        GameTooltip:AddLine(status .. (version and (" · v" .. tostring(version)) or ""), 0.75, 0.62, 0.36, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.32, 0.22, 0.12, 0.035)
        GameTooltip:Hide()
    end)

    return card
end

local function CreatePageTurnButton(parent, direction, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)
    local prefix = direction == "PREV" and "PrevPage" or "NextPage"
    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnClick", onClick)
    return button
end

function Catalogue:GetEntries()
    local result = {}
    for index, base in ipairs(BASE_ENTRIES) do
        result[index] = base
    end
    return result
end

function Catalogue:GetFilteredEntries()
    local list = {}
    local filter = self.currentFilter or "All"
    for _, entry in ipairs(self:GetEntries()) do
        if filter == "All" or entry.category == filter then
            list[#list + 1] = entry
        end
    end
    return list
end

local function UpdateCollectionTitleLayout(frame)
    if not frame or not frame.collectionTitle then return end

    -- Keep the same visual size in both layouts. One-page mode has enough
    -- room; the title only needs a wider text box so it stays on one line.
    SetMorpheusFont(frame.collectionTitle, 24)

    frame.collectionTitle:ClearAllPoints()
    if Catalogue.expanded then
        frame.collectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 42, -99)
        frame.collectionTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -99)
    else
        -- Let the single-page title use almost the full header width.
        frame.collectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -99)
        frame.collectionTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -99)
    end

    frame.collectionTitle:SetJustifyH("CENTER")
    if frame.collectionTitle.SetWordWrap then
        frame.collectionTitle:SetWordWrap(false)
    end
    if frame.collectionTitle.SetMaxLines then
        frame.collectionTitle:SetMaxLines(1)
    end
end

function Catalogue:SetExpanded(expanded)
    self.expanded = not not expanded
    local frame = self:EnsureUI()
    frame:SetWidth(self.expanded and EXPANDED_WIDTH or COLLAPSED_WIDTH)
    frame.pageArt.whole:SetShown(not self.expanded)
    frame.pageArt.left:SetShown(self.expanded)
    frame.pageArt.right:SetShown(self.expanded)
    frame.rightContent:SetShown(self.expanded)
    UpdateCollectionTitleLayout(frame)

    local prefix = self.expanded and "PrevPage" or "NextPage"
    frame.expandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Up")
    frame.expandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Down")
    frame.expandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Disabled")

    self.currentPage = 1
    ApplyResponsiveScale(frame)
    self:Refresh()
end

local function RenderCataloguePage(container, entries, firstIndex)
    ClearContainer(container)

    -- Reserve the same header gap on both parchment pages so entries remain
    -- aligned under the shared collection title.
    local y = -82
    for slot = 0, ENTRIES_PER_PAGE - 1 do
        local entry = entries[firstIndex + slot]
        if not entry then break end
        CreateCatalogueCard(container, entry, y)
        y = y - ENTRY_HEIGHT
    end
end

function Catalogue:EnsureUI()
    if self.frame then
        return self.frame
    end

    local safeHost = tostring(HOST_ADDON or "DarksporeSuiteForever"):gsub("[^%w_]", "")
    local frameName = safeHost .. "CatalogueFrame"
    local frame = CreateFrame("Frame", frameName, UIParent, "PortraitFrameTemplate")
    self.frame = frame

    frame:SetSize(self.expanded and EXPANDED_WIDTH or COLLAPSED_WIDTH, BOOK_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", OnCatalogueMouseWheel)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnShow", function(self)
        ApplyResponsiveScale(self)
        Catalogue:Refresh()
    end)

    if frame.Bg then frame.Bg:Hide() end
    if frame.TopTileStreaks then frame.TopTileStreaks:Hide() end
    SetPortrait(frame)

    if frame.TitleText then
        frame.TitleText:Hide()
    end

    frame.headerBacking = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.headerBacking:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    frame.headerBacking:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -3, -82)
    frame.headerBacking:SetColorTexture(0.075, 0.060, 0.045, 0.98)

    frame.pageArt = CreatePageArt(frame)
    frame.pageArt.whole:SetShown(not self.expanded)
    frame.pageArt.left:SetShown(self.expanded)
    frame.pageArt.right:SetShown(self.expanded)

    -- Keep close/expand controls on their own high-level overlay. PortraitFrame
    -- template regions can otherwise draw over normal child buttons.
    frame.chrome = CreateFrame("Frame", nil, frame)
    frame.chrome:SetAllPoints(frame)
    frame.chrome:SetFrameLevel(frame:GetFrameLevel() + 100)

    -- PortraitFrameTemplate's top border can draw above normal child regions.
    -- Give the window title its own high-strata overlay, just like the close
    -- button, so the title remains visible at both book widths.
    frame.titleOverlay = CreateFrame("Frame", nil, frame)
    frame.titleOverlay:SetPoint("TOPLEFT", frame, "TOPLEFT", 82, -1)
    frame.titleOverlay:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -1)
    frame.titleOverlay:SetHeight(28)
    frame.titleOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.titleOverlay:SetFrameLevel(999)
    frame.titleOverlay:EnableMouse(false)

    frame.chromeTitle = frame.titleOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.chromeTitle:SetPoint("CENTER", frame.titleOverlay, "CENTER", 0, 4)
    frame.chromeTitle:SetText("Forever Collection")
    frame.chromeTitle:SetTextColor(1.0, 0.82, 0.18)
    frame.chromeTitle:SetShadowColor(0, 0, 0, 1)
    frame.chromeTitle:SetShadowOffset(1, -1)

    -- One shared catalogue heading for the entire book.  This replaces the
    -- old left-page-only "Forever Addons" heading and keeps the title centred
    -- across both parchment pages when expanded.
    frame.collectionTitle = frame.chrome:CreateFontString(nil, "OVERLAY")
    SetMorpheusFont(frame.collectionTitle, 24)
    -- Span the actual inner book width rather than centering on a single point.
    -- This keeps the heading visually centred between the parchment borders in
    -- both the single-page and expanded two-page layouts.
    frame.collectionTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 42, -99)
    frame.collectionTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -99)
    frame.collectionTitle:SetJustifyH("CENTER")
    frame.collectionTitle:SetText("Darkspore Forever Addons — Available on CurseForge")
    frame.collectionTitle:SetTextColor(0.78, 0.48, 0.16)
    frame.collectionTitle:SetShadowColor(0, 0, 0, 0.85)
    frame.collectionTitle:SetShadowOffset(1, -1)

    if frame.CloseButton then frame.CloseButton:Hide() end


    -- Use Blizzard's actual close-button template, but put it on a higher
    -- strata than the PortraitFrame NineSlice.  At very wide spellbook sizes
    -- the NineSlice top-right piece can otherwise cover the button even when
    -- its frame level is high.  The slightly inset anchor mirrors the native
    -- PlayerSpellsFrame close-button placement.
    frame.catalogueCloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.catalogueCloseButton:SetSize(32, 32)
    frame.catalogueCloseButton:ClearAllPoints()
    frame.catalogueCloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.catalogueCloseButton:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.catalogueCloseButton:SetFrameLevel(1000)

    -- Embedded catalogue snapshot version.  This is display-only so each
    -- addon makes it obvious which Darkspore Suite catalogue copy it carries.
    frame.catalogueVersionText = frame.titleOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.catalogueVersionText:SetPoint("RIGHT", frame.titleOverlay, "RIGHT", -2, 4)
    frame.catalogueVersionText:SetText("Catalogue v." .. CATALOGUE_VERSION)
    frame.catalogueVersionText:SetTextColor(1.0, 0.82, 0.18)
    frame.catalogueVersionText:SetShadowColor(0, 0, 0, 1)
    frame.catalogueVersionText:SetShadowOffset(1, -1)

    frame.catalogueCloseButton:SetScript("OnClick", function() Catalogue:Close() end)
    frame.catalogueCloseButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(CLOSE or "Close")
        GameTooltip:Show()
    end)
    frame.catalogueCloseButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.expandButton = CreateFrame("Button", nil, frame.chrome)
    frame.expandButton:SetSize(32, 32)
    frame.expandButton:SetPoint("BOTTOMRIGHT", frame.chrome, "BOTTOMRIGHT", -18, 18)
    frame.expandButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    frame.expandButton:SetFrameLevel(frame.chrome:GetFrameLevel() + 5)
    frame.expandButton:SetScript("OnClick", function() Catalogue:SetExpanded(not Catalogue.expanded) end)
    frame.expandButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Catalogue.expanded and "Close second page" or "Open second page")
        GameTooltip:Show()
    end)
    frame.expandButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local prefix = self.expanded and "PrevPage" or "NextPage"
    frame.expandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Up")
    frame.expandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Down")
    frame.expandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. prefix .. "-Disabled")

    frame.filterButtons = {
        CreateFilterTab(frame, "All", "All", 92),
        CreateFilterTab(frame, "Interface", "Interface", 194),
        CreateFilterTab(frame, "Group", "Group", 306),
        CreateFilterTab(frame, "Tools", "Tools", 408),
    }

    frame.leftContent = CreateFrame("Frame", nil, frame)
    frame.leftContent:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_MARGIN_X + 8, PAGE_TOP)
    frame.leftContent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAGE_MARGIN_X + 8, PAGE_BOTTOM)
    frame.leftContent:SetWidth(520)
    frame.leftContent:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.leftContent:EnableMouseWheel(true)
    frame.leftContent:SetScript("OnMouseWheel", OnCatalogueMouseWheel)

    frame.rightContent = CreateFrame("Frame", nil, frame)
    frame.rightContent:SetPoint("TOPLEFT", frame, "TOP", 36, PAGE_TOP)
    frame.rightContent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAGE_MARGIN_X + 8), PAGE_BOTTOM)
    frame.rightContent:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.rightContent:EnableMouseWheel(true)
    frame.rightContent:SetScript("OnMouseWheel", OnCatalogueMouseWheel)
    frame.rightContent:SetShown(self.expanded)


    frame.prev = CreatePageTurnButton(frame.chrome, "PREV", function()
        Catalogue.currentPage = math.max(1, Catalogue.currentPage - 1)
        Catalogue:Refresh()
    end)
    frame.prev:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -52, 18)

    frame.next = CreatePageTurnButton(frame.chrome, "NEXT", function()
        Catalogue.currentPage = Catalogue.currentPage + 1
        Catalogue:Refresh()
    end)
    frame.next:SetPoint("LEFT", frame.prev, "RIGHT", 72, 0)

    frame.pageText = frame.chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.pageText:SetPoint("CENTER", frame.prev, "CENTER", 52, 0)
    frame.pageText:SetTextColor(0.34, 0.20, 0.07)

    if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == frameName then found = true break end
        end
        if not found then UISpecialFrames[#UISpecialFrames + 1] = frameName end
    end

    return frame
end

function Catalogue:Refresh()
    local frame = self:EnsureUI()
    UpdateFilterTabs(frame)

    local entries = self:GetFilteredEntries()
    local perView = self.expanded and (ENTRIES_PER_PAGE * 2) or ENTRIES_PER_PAGE
    local totalPages = math.max(1, math.ceil(#entries / perView))
    self.currentPage = math.max(1, math.min(tonumber(self.currentPage) or 1, totalPages))
    local first = ((self.currentPage - 1) * perView) + 1

    RenderCataloguePage(frame.leftContent, entries, first)

    if self.expanded then
        RenderCataloguePage(
            frame.rightContent,
            entries,
            first + ENTRIES_PER_PAGE
        )
    end

    frame.pageText:SetText(("Page %d / %d"):format(self.currentPage, totalPages))
    frame.prev:SetEnabled(self.currentPage > 1)
    frame.next:SetEnabled(self.currentPage < totalPages)
    frame.prev:SetShown(totalPages > 1)
    frame.next:SetShown(totalPages > 1)
    frame.pageText:SetShown(totalPages > 1)
end

function Catalogue:Open()
    local frame = self:EnsureUI()
    self:Refresh()
    frame:Show()
    frame:Raise()
end

function Catalogue:Close()
    if self.frame then
        self.frame:Hide()
    end
end

function Catalogue:Toggle()
    local frame = self:EnsureUI()
    if frame:IsShown() then self:Close() else self:Open() end
end

function Catalogue:CreateLauncher(parent, options)
    if not parent or (type(parent) ~= "table" and type(parent) ~= "userdata") then
        return nil
    end

    options = options or {}
    local propertyName = options.propertyName or "DarksporeCatalogueButton"
    if parent[propertyName] then return parent[propertyName] end

    local size = tonumber(options.size) or 20
    local button = CreateFrame("Button", nil, parent)
    parent[propertyName] = button

    button:SetSize(size, size)
    local parentLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 0
    button:SetFrameLevel(parentLevel + (tonumber(options.levelOffset) or 25))

    local relativeTo = options.relativeTo
    if relativeTo then
        button:SetPoint(options.point or "RIGHT", relativeTo, options.relativePoint or "LEFT", options.x or -3, options.y or 0)
    elseif parent.CloseButton then
        button:SetPoint(options.point or "RIGHT", parent.CloseButton, options.relativePoint or "LEFT", options.x or -3, options.y or 0)
    else
        button:SetPoint(options.point or "TOPRIGHT", parent, options.relativePoint or "TOPRIGHT", options.x or -31, options.y or -7)
    end

    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon:SetTexture(SKIN.icon)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button.icon)
    button.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function()
        Catalogue:Toggle()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, options.tooltipAnchor or "ANCHOR_RIGHT")
        GameTooltip:SetText("Darkspore Forever Catalogue")
        GameTooltip:AddLine("Browse the full Forever addon collection.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return button
end

Catalogue.OpenCatalogue = Catalogue.Open
Catalogue.ToggleCatalogue = Catalogue.Toggle
Catalogue.CreateCollectionButton = Catalogue.CreateLauncher
