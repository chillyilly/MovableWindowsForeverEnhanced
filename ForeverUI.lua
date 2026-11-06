-- ForeverUI: the Blizzard Options-window look of Social Filter Forever, carried by each Forever addon on its own.
--
-- This file is a private copy. Every Forever addon that uses it lists it in its own .toc and gets its own copy of the
-- kit in its own addon namespace (the `...` table the game gives each addon). Nothing here is global: no global
-- variables, no global frame names other than ones built from this addon's own name, no hooks on Blizzard functions.
-- Two Forever addons installed together therefore never share, overwrite or wait for each other's copy, and each one
-- works alone.
--
-- Usage in any file of the addon:   local FUI = select(2, ...).ForeverUI
--
-- Everything is drawn with the game's own parts, so windows look like the game's Options window (SettingsPanel): its
-- flat dark background, its inner frame (Options_InnerFrame), its section headers and Options_HorizontalDivider, its
-- minimal check boxes (checkbox-minimal), its minimal sliders with arrow steppers, its dropdowns (WowStyle2), its
-- tabs (MinimalTabTemplate), its scroll bar (MinimalScrollBar) and its tooltip (SettingsTooltip). Each template and
-- atlas is checked before use, and a missing one leaves the older Blizzard part in place instead of an error.
--
-- Source: Social Filter Forever 0.6.132 Kit.lua and Host.lua (window chrome), generalised.
local ADDON_NAME, NS = ...
if type(NS) ~= "table" then return end
if NS.ForeverUI then return end   -- loaded twice by mistake in the same addon: keep the first copy

local kit = {}
NS.ForeverUI = kit
kit.VERSION = "1.0.0"

local min, max, floor = math.min, math.max, math.floor
local type, pairs, ipairs, pcall, tostring = type, pairs, ipairs, pcall, tostring

-- Colours ---------------------------------------------------------------------------------------------------------
-- The game's own colour objects (NORMAL_FONT_COLOR, ...), read once. The numbers are only a fallback.
local function BlizzColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and c.GetRGB then
        local cr, cg, cb = c:GetRGB()
        return { cr, cg, cb }
    end
    return { r, g, b }
end

local COLOR = {
    normal    = BlizzColor("NORMAL_FONT_COLOR", 1, 0.82, 0),
    highlight = BlizzColor("HIGHLIGHT_FONT_COLOR", 1, 1, 1),
    lightGray = BlizzColor("LIGHTGRAY_FONT_COLOR", 0.75, 0.75, 0.75),
    gray      = BlizzColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5),
    disabled  = BlizzColor("DISABLED_FONT_COLOR", 0.5, 0.5, 0.5),
    green     = BlizzColor("GREEN_FONT_COLOR", 0.1, 1, 0.1),
    red       = BlizzColor("RED_FONT_COLOR", 1, 0.1, 0.1),
    orange    = BlizzColor("ORANGE_FONT_COLOR", 1, 0.5, 0.25),
    yellow    = BlizzColor("YELLOW_FONT_COLOR", 1, 1, 0),
    epic      = BlizzColor("EPIC_PURPLE_COLOR", 0.64, 0.21, 0.93),
}
kit.COLOR = COLOR

-- "|cffRRGGBB" for a colour above, for colour codes inside text.
local function Code(c)
    return string.format("|cff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end
kit.Code = Code
kit.CODE = {}
for k, c in pairs(COLOR) do kit.CODE[k] = Code(c) end
kit.HEX = {}
for k, v in pairs(kit.CODE) do kit.HEX[k] = v:sub(5) end

function kit.Color(fs, c) if fs and c then fs:SetTextColor(c[1], c[2], c[3]) end end

-- Blizzard class colours, for any list that shows a player name.
function kit.NormalizeClassToken(value)
    if type(value) ~= "string" or value == "" then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[value] then return value end
    local compact = value:gsub("[%s_%-]", ""):upper()
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[compact] then return compact end
    local folded = value:lower()
    for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        if type(localized) == "string" and localized:lower() == folded then return token end
    end
    for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
        if type(localized) == "string" and localized:lower() == folded then return token end
    end
end

function kit.ClassColorCode(classToken)
    classToken = kit.NormalizeClassToken(classToken)
    local c = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not c then return nil end
    local function Byte(v)
        v = tonumber(v) or 1
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        return floor(v * 255 + 0.5)
    end
    return string.format("ff%02x%02x%02x", Byte(c.r), Byte(c.g), Byte(c.b))
end

function kit.ClassColoredName(name, classToken)
    if type(name) ~= "string" then name = tostring(name or "") end
    local code = kit.ClassColorCode(classToken)
    return code and ("|c" .. code .. name .. "|r") or name
end

-- Fonts -------------------------------------------------------------------------------------------------------------
-- The Settings panel's type: page titles GameFontHighlightHuge, section headers GameFontHighlightLarge, labels
-- GameFontNormal (gold), body GameFontHighlight, explanations GameFontHighlightSmall in light grey.
local FONT = {
    title      = { "GameFontHighlightHuge", "GameFontNormalHuge" },
    header     = { "GameFontHighlightLarge", "GameFontNormalLarge" },
    group      = { "GameFontNormalSmall" },
    label      = { "GameFontNormal" },
    body       = { "GameFontHighlight" },
    small      = { "GameFontHighlightSmall" },
    desc       = { "GameFontHighlightSmall", color = "lightGray" },
    value      = { "GameFontNormalSmall" },
    faded      = { "GameFontDisable" },
    fadedSmall = { "GameFontDisableSmall" },
    number     = { "GameFontHighlightHuge", "GameFontNormalHuge" },
    navGroup   = { "GameFontHighlightMedium", "GameFontHighlight" },
}
kit.FONT = FONT

local function FontObjectName(style)
    local spec = FONT[style] or { style }
    for _, name in ipairs(spec) do
        if _G[name] then return name, spec end
    end
    return "GameFontHighlight", spec
end

-- Applies a style ("label", "desc", ...) or a font object name to a font string.
function kit.Font(fs, style)
    if not fs then return fs end
    local name, spec = FontObjectName(style)
    fs:SetFontObject(name)
    if spec.color then
        local c = COLOR[spec.color]
        fs:SetTextColor(c[1], c[2], c[3])
    end
    return fs
end

-- A font string in one of the styles above.
function kit.Text(parent, style, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    return kit.Font(fs, style or "body")
end

-- Atlases and templates -------------------------------------------------------------------------------------------
function kit.AtlasExists(atlas)
    if not atlas then return false end
    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(atlas) ~= nil
    end
    return false
end

-- Sets an atlas when the game has it; false otherwise (the texture is left alone).
function kit.SetAtlasSafe(texture, atlas, useAtlasSize)
    if not (texture and texture.SetAtlas and atlas and kit.AtlasExists(atlas)) then return false end
    local ok, result = pcall(texture.SetAtlas, texture, atlas, useAtlasSize)
    return ok and result ~= false
end

function kit.AtlasSize(atlas)
    if C_Texture and C_Texture.GetAtlasInfo and atlas then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info then return info.width, info.height end
    end
end

function kit.TemplateExists(template)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        return C_XMLUtil.GetTemplateInfo(template) ~= nil
    end
    return true
end

-- CreateFrame with the first template of the list that the game has. Returns the frame and the template used.
-- A `false` entry in the list means "no template".
function kit.CreateFrameFrom(kind, name, parent, templates)
    for _, template in ipairs(templates) do
        if template == false then
            return CreateFrame(kind, name, parent), nil
        end
        if kit.TemplateExists(template) then
            local ok, frame = pcall(CreateFrame, kind, name, parent, template)
            if ok and frame then return frame, template end
        end
    end
end

-- Tooltips ------------------------------------------------------------------------------------------------------------
-- The Options window's own tooltip (SettingsTooltip): the name in white, the explanation under it in gold.
function kit.Tooltip()
    return SettingsTooltip or GameTooltip
end

function kit.ShowTip(owner, anchor, title, body)
    if not title or title == "" then return end
    local tip = kit.Tooltip()
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if GameTooltip_AddHighlightLine then
        GameTooltip_AddHighlightLine(tip, title)
    else
        tip:SetText(title, COLOR.highlight[1], COLOR.highlight[2], COLOR.highlight[3])
    end
    if body and body ~= "" then
        if GameTooltip_AddNormalLine then
            GameTooltip_AddNormalLine(tip, body)
        else
            tip:AddLine(body, COLOR.normal[1], COLOR.normal[2], COLOR.normal[3], true)
        end
    end
    tip:Show()
end

function kit.HideTip()
    local tip = kit.Tooltip()
    if tip then tip:Hide() end
    if GameTooltip and tip ~= GameTooltip then GameTooltip:Hide() end
end

-- Attaches the tooltip without replacing a control's existing hover behaviour.
-- title/body may be strings or functions evaluated when the mouse enters the control.
function kit.SetTooltip(widget, title, body, anchor)
    if not widget then return widget end
    widget.fuiTipTitle = title
    widget.fuiTipBody = body
    widget.fuiTipAnchor = anchor or "ANCHOR_RIGHT"
    if not widget.fuiTipHooked then
        widget.fuiTipHooked = true
        widget:HookScript("OnEnter", function(self)
            local t = type(self.fuiTipTitle) == "function" and self.fuiTipTitle(self) or self.fuiTipTitle
            local b = type(self.fuiTipBody) == "function" and self.fuiTipBody(self) or self.fuiTipBody
            kit.ShowTip(self, self.fuiTipAnchor or "ANCHOR_RIGHT", t, b)
        end)
        widget:HookScript("OnLeave", function() kit.HideTip() end)
    end
    return widget
end

-- Shrinks a window on a small screen (never below 72%).
function kit.ApplyResponsiveScale(frame, width, height)
    local pw = max(1, UIParent:GetWidth() or 1)
    local ph = max(1, UIParent:GetHeight() or 1)
    local scale = min(1, (pw - 36) / width, (ph - 36) / height)
    frame:SetScale(max(0.72, scale))
end

-- Windows ---------------------------------------------------------------------------------------------------------------
-- The Options window (SettingsFrameTemplate) and the default panel (DefaultPanelTemplate) share the same gold
-- ButtonFrameTemplateNoPortrait border; what makes the Options window look the way it does is its flat, neutral
-- charcoal body (FlatPanelBackgroundTemplate) with a light veil, and its title on the left. kit.SkinPanel gives an
-- existing DefaultPanelTemplate / ButtonFrameTemplate / BasicFrameTemplate window that body, so the window keeps its
-- size, its anchors, its title and its close button and only changes its look. kit.CreateWindow makes a new one.

-- A frame that draws the Options window's body. Prefers the template itself; otherwise borrows the Bg of one
-- Options-frame instance (made once, never shown).
local borrowedBgSources = {}
-- A background frame is only usable if it really drew something: a client without the template may still hand
-- back an empty frame.
local function HasArt(frame)
    if not (frame and frame.GetNumRegions) then return false end
    if (frame:GetNumRegions() or 0) > 0 then return true end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetNumRegions and (child:GetNumRegions() or 0) > 0 then return true end
    end
    return false
end

local function NewFlatBackground(panel)
    if kit.TemplateExists("FlatPanelBackgroundTemplate") then
        local ok, bg = pcall(CreateFrame, "Frame", nil, panel, "FlatPanelBackgroundTemplate")
        if ok and bg then
            if HasArt(bg) then return bg end
            bg:Hide()
        end
    end
    if kit.TemplateExists("SettingsFrameTemplate") then
        local ok, src = pcall(CreateFrame, "Frame", nil, nil, "SettingsFrameTemplate")
        if ok and src then
            src:Hide()
            local bg = src.Bg
            if bg and bg.SetParent and bg.GetObjectType and bg:GetObjectType() == "Frame" and HasArt(bg) then
                borrowedBgSources[#borrowedBgSources + 1] = src   -- the Options frame the body was taken from
                src.Bg = nil
                bg:SetParent(panel)
                bg:Show()
                return bg
            end
        end
    end
end

-- The points of a region, so a replacement can take exactly its place.
local function CopyPoints(from, to, fallback)
    to:ClearAllPoints()
    local n = from and from.GetNumPoints and from:GetNumPoints() or 0
    if n > 0 then
        for i = 1, n do
            local p, rel, rp, x, y = from:GetPoint(i)
            to:SetPoint(p, rel, rp, x, y)
        end
    else
        fallback(to)
    end
end

-- opts:
--   title        text for the title (optional; the existing title is kept otherwise)
--   leftTitle    true: title on the left, as the Options window draws it (default true)
--   veil         alpha of the neutral veil over the body (default 0.20, as Social Filter Forever)
--   keepBg       true: keep the window's own Bg (only the title and veil change)
function kit.SkinPanel(panel, opts)
    if not panel or panel.fuiSkinned then return panel end
    opts = opts or {}
    panel.fuiSkinned = true

    if not opts.keepBg then
        local old = panel.Bg
        local flat = NewFlatBackground(panel)
        if flat then
            CopyPoints(old, flat, function(t)
                t:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -21)
                t:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
            end)
            -- one level under the window itself, so the window's own labels, lines and border (which live on the
            -- window's level) always draw over it, exactly as the template's Bg texture did
            if flat.SetFrameLevel then flat:SetFrameLevel(max(0, (panel:GetFrameLevel() or 1) - 1)) end
            if not panel.fuiBgLevelHooked and panel.HookScript then
                panel.fuiBgLevelHooked = true
                -- windows that change their own level later (SetFrameLevel after this) keep the body under them
                panel:HookScript("OnShow", function(self)
                    local bg = self.fuiFlatBg
                    if bg then bg:SetFrameLevel(max(0, (self:GetFrameLevel() or 1) - 1)) end
                end)
            end
            if old and old ~= flat and old.Hide then
                old:Hide()
                if old.SetAlpha then old:SetAlpha(0) end
            end
            panel.fuiOldBg = old
            panel.Bg = flat
            panel.fuiFlatBg = flat
        else
            -- no Options art in this client: the dark dialog body the addons used before
            if old and old.SetTexture then
                old:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
                if old.SetHorizTile then old:SetHorizTile(true) end
                if old.SetVertTile then old:SetVertTile(true) end
                old:SetVertexColor(1, 1, 1, 1)
                old:SetAlpha(1)
            end
        end
    end

    -- the restrained neutral veil Social Filter Forever draws over the body
    local host = panel.Bg
    local veilAlpha = opts.veil or 0.20
    if veilAlpha > 0 then
        local veil
        if host and host.CreateTexture then
            veil = host:CreateTexture(nil, "OVERLAY")
            veil:SetAllPoints(host)
        else
            veil = panel:CreateTexture(nil, "BACKGROUND", nil, 7)
            veil:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -21)
            veil:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
        end
        veil:SetColorTexture(0.012, 0.013, 0.016, veilAlpha)
        panel.fuiVeil = veil
    end

    local title = kit.TitleOf(panel)
    if title then
        if opts.title then title:SetText(opts.title) end
        if opts.leftTitle ~= false then
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -6)
            if opts.titleRight then
                title:SetPoint("RIGHT", panel, "RIGHT", -opts.titleRight, 0)
            end
            title:SetJustifyH("LEFT")
        end
    end
    return panel
end

-- The title font string of any Blizzard window template (or nil).
function kit.TitleOf(panel)
    if not panel then return nil end
    if panel.TitleContainer and panel.TitleContainer.TitleText then return panel.TitleContainer.TitleText end
    if panel.NineSlice and panel.NineSlice.Text then return panel.NineSlice.Text end
    if panel.TitleText then return panel.TitleText end
    if panel.GetName and panel:GetName() then
        return _G[panel:GetName() .. "TitleText"]
    end
end

-- A new Options-style window. opts: width, height, title, strata, level, movable (default true),
-- escape (default true: Esc closes it; needs a name), template list.
function kit.CreateWindow(name, parent, opts)
    opts = opts or {}
    local win, template = kit.CreateFrameFrom("Frame", name, parent or UIParent,
        opts.templates or { "SettingsFrameTemplate", "DefaultPanelTemplate", "PortraitFrameTemplate", false })
    win.isOptionsFrame = (template == "SettingsFrameTemplate")
    win:SetSize(opts.width or 600, opts.height or 480)
    if opts.strata then win:SetFrameStrata(opts.strata) end
    if opts.level then win:SetFrameLevel(opts.level) end
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    if opts.movable ~= false then
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
    end
    if win.isOptionsFrame then
        if win.NineSlice and win.NineSlice.Text then
            win.NineSlice.Text:SetText(opts.title or "")
            win.NineSlice.Text:ClearAllPoints()
            win.NineSlice.Text:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -8)
            win.NineSlice.Text:SetJustifyH("LEFT")
        end
        win.CloseButton = win.CloseButton or win.ClosePanelButton
        if win.Bg and win.Bg.CreateTexture then
            local veil = win.Bg:CreateTexture(nil, "OVERLAY")
            veil:SetAllPoints(win.Bg)
            veil:SetColorTexture(0.012, 0.013, 0.016, 0.20)
            win.fuiVeil = veil
        end
        win.fuiSkinned = true
    else
        if win.SetTitle then pcall(win.SetTitle, win, opts.title or "") end
        kit.SkinPanel(win, { title = opts.title })
        if not win.CloseButton then
            win.CloseButton = CreateFrame("Button", nil, win, "UIPanelCloseButton")
            win.CloseButton:SetPoint("TOPRIGHT", win, "TOPRIGHT", -3, -3)
        end
    end
    kit.SafeClose(win)
    if name and opts.escape ~= false and UISpecialFrames then
        local found = false
        for _, n in ipairs(UISpecialFrames) do if n == name then found = true break end end
        if not found then tinsert(UISpecialFrames, name) end
    end
    return win, template
end

-- Blizzard's Settings/Portrait close buttons may route through combat-restricted panel code. These are our own
-- unprotected windows, so the close button just hides the window.
function kit.SafeClose(win, onClose)
    local function Close()
        kit.HideTip()
        if onClose then onClose(win) else win:Hide() end
    end
    for _, key in ipairs({ "CloseButton", "ClosePanelButton" }) do
        local b = win[key]
        if b and b.SetScript then b:SetScript("OnClick", Close) end
    end
end

-- The Forever Collection title-bar controls, as Social Filter Forever draws them: a Blizzard "!" button beside the
-- close button and the addon version in gold to its left. opts: onClick (opens the catalogue), version (text or
-- nil: read from the .toc), strata/level (for windows that keep their own layering), tip.
function kit.AddCollectionButton(win, opts)
    opts = opts or {}
    local overlay = win.fuiHeaderOverlay
    if not overlay then
        overlay = CreateFrame("Frame", nil, win)
        overlay:SetAllPoints(win)
        if opts.strata then overlay:SetFrameStrata(opts.strata) end
        overlay:SetFrameLevel(opts.level or (win:GetFrameLevel() + 20))
        win.fuiHeaderOverlay = overlay
    end
    local b = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    if opts.strata then b:SetFrameStrata(opts.strata) end
    b:SetFrameLevel(overlay:GetFrameLevel() + 1)
    b:SetSize(24, 22)
    b:SetPoint("TOPRIGHT", win, "TOPRIGHT", opts.x or -31, opts.y or -4)
    b:SetText("!")
    b:SetScript("OnClick", function()
        kit.HideTip()
        if opts.onClick then opts.onClick() end
    end)
    b:SetScript("OnEnter", function(self) kit.ShowTip(self, "ANCHOR_TOP", "Forever Collection", opts.tip) end)
    b:SetScript("OnLeave", function() kit.HideTip() end)

    local version = opts.version
    if version == nil then
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        version = get and get(ADDON_NAME, "Version") or ""
    end
    local v = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v:SetText((version and version ~= "") and ("v" .. tostring(version)) or "")
    v:SetPoint("RIGHT", b, "LEFT", -6, 0)
    win.fuiCollectionButton, win.fuiVersionText = b, v
    return b, v
end

-- Panels and dividers --------------------------------------------------------------------------------------------------
-- The Options window draws its category list and its page inside Options_InnerFrame: a thin bronze edge with rounded
-- top corners, a soft dark gradient at the top and a divider between the list and the page. The atlas is cut into
-- pieces (its corners, its edges, the divider) and the plain runs between them are stretched to any size.
local INNER = { atlas = "Options_InnerFrame", W = 890, H = 620, D = 200, E = 16, half = 6 }

local function InnerArt()
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local info = C_Texture.GetAtlasInfo(INNER.atlas)
    if not (info and (info.file or info.filename) and (info.width or 0) > 2 * INNER.E and (info.height or 0) > 2 * INNER.E) then
        return nil
    end
    return info
end
kit.HasInnerArt = function() return InnerArt() ~= nil end

local function Px(info, v, horizontal)
    return v * (horizontal and info.width / INNER.W or info.height / INNER.H)
end

local function Piece(frame, info, layer, sx0, sx1, sy0, sy1, left, right, top, bottom, host)
    local t = (host or frame):CreateTexture(nil, layer, nil, -6)
    t:SetTexture(info.file or info.filename)
    local L, R = info.leftTexCoord or 0, info.rightTexCoord or 1
    local T, B = info.topTexCoord or 0, info.bottomTexCoord or 1
    t:SetTexCoord(L + (R - L) * sx0 / info.width, L + (R - L) * sx1 / info.width,
        T + (B - T) * sy0 / info.height, T + (B - T) * sy1 / info.height)
    local function Point(across, down)
        local rel = (down[1] == "T" and "TOP" or "BOTTOM") .. (across[1] == "L" and "LEFT" or "RIGHT")
        return rel, (across[1] == "L") and across[2] or -across[2], (down[1] == "T") and -down[2] or down[2]
    end
    local rel1, x1, y1 = Point(left, top)
    local rel2, x2, y2 = Point(right, bottom)
    t:SetPoint("TOPLEFT", frame, rel1, x1, y1)
    t:SetPoint("BOTTOMRIGHT", frame, rel2, x2, y2)
    return t
end

-- Draws the frame on `frame`. dividerAt: where the divider sits, from the frame's left edge (nil: no divider).
-- host: the frame that owns the textures (default `frame`); `frame` then only gives the rectangle.
local function DrawInnerFrame(frame, info, layer, dividerAt, host)
    local W, H = info.width, info.height
    local E, Ev = Px(info, INNER.E, true), Px(info, INNER.E, false)
    local D, h = Px(info, INNER.D, true), Px(info, INNER.half, true)
    local cols
    if dividerAt then
        cols = {
            { 0, E, { "L", 0 }, { "L", E } },
            { E, D - h, { "L", E }, { "L", dividerAt - h } },
            { D - h, D + h, { "L", dividerAt - h }, { "L", dividerAt + h } },
            { D + h, W - E, { "L", dividerAt + h }, { "R", E } },
            { W - E, W, { "R", E }, { "R", 0 } },
        }
    else
        cols = {
            { 0, E, { "L", 0 }, { "L", E } },
            { D + h, W - E, { "L", E }, { "R", E } },
            { W - E, W, { "R", E }, { "R", 0 } },
        }
    end
    local rows = {
        { 0, Ev, { "T", 0 }, { "T", Ev } },
        { Ev, H - Ev, { "T", Ev }, { "B", Ev } },
        { H - Ev, H, { "B", Ev }, { "B", 0 } },
    }
    frame.fuiInnerPieces = {}
    for _, c in ipairs(cols) do
        for _, r in ipairs(rows) do
            frame.fuiInnerPieces[#frame.fuiInnerPieces + 1] = Piece(frame, info, layer, c[1], c[2], r[1], r[2], c[3], c[4], r[3], r[4], host)
        end
    end
    return true
end

-- The Options window's inner frame (with an optional divider dividerAt px from its left edge). The caller places
-- the returned frame. nil when the game has no such atlas.
function kit.InnerFrame(parent, dividerAt)
    local info = InnerArt()
    if not info then return nil end
    local f = CreateFrame("Frame", nil, parent)
    DrawInnerFrame(f, info, "BACKGROUND", dividerAt)
    return f
end

-- The game's dark recessed panel (InsetFrameTemplate), used when the Options art is missing.
function kit.Inset(parent)
    local panel = kit.CreateFrameFrom("Frame", nil, parent, { "InsetFrameTemplate" })
    if panel then return panel end
    panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if panel.SetBackdrop and BACKDROP_DARK_DIALOG_32_32 then
        panel:SetBackdrop(BACKDROP_DARK_DIALOG_32_32)
    end
    return panel
end

-- A list or a text panel: the inner frame without its divider. Falls back to the game's recessed panel.
function kit.Box(parent)
    local info = InnerArt()
    if info then
        local f = CreateFrame("Frame", nil, parent)
        DrawInnerFrame(f, info, "BACKGROUND", nil)
        f.isOptionsBox = true
        return f
    end
    return kit.Inset(parent)
end

-- Turns an existing panel (usually a BackdropTemplate box with a tooltip border) into an Options box in place: its
-- backdrop is removed and the inner-frame art is drawn on it. dark = true also gives it the darker data-board fill
-- that Social Filter Forever uses behind lists and tables. Returns false (panel untouched) without the art.
function kit.SkinBox(panel, dark, inset)
    if not panel or panel.fuiBoxSkinned then return false end
    local info = InnerArt()
    if not info then return false end
    panel.fuiBoxSkinned = true
    if panel.SetBackdrop then pcall(panel.SetBackdrop, panel, nil) end
    if panel.NineSlice and panel.NineSlice.Hide then panel.NineSlice:Hide() end
    for _, key in ipairs({ "Bg", "Background" }) do
        local r = panel[key]
        if r and r.Hide and r ~= panel then r:Hide() end
    end
    DrawInnerFrame(panel, info, "BACKGROUND", nil)
    if dark then kit.ApplyDataBoardBackground(panel, inset) end
    return true
end

-- An Options box drawn straight onto `host` (as host's own BACKGROUND textures, so it always sits under host's lines,
-- text and child frames, whatever their frame levels), across the rectangle from (x1, y1) to (x2, y2): TOPLEFT and
-- BOTTOMRIGHT offsets from host's TOPLEFT and BOTTOMRIGHT. dark = the darker data-board interior. Returns the
-- rectangle (an empty frame that only holds the geometry: re-anchor it to move the box), or nil without the art.
function kit.BoardOn(host, x1, y1, x2, y2, dark, inset)
    local info = InnerArt()
    if not (host and info) then return nil end
    local rect = CreateFrame("Frame", nil, host)
    rect:EnableMouse(false)
    rect:SetPoint("TOPLEFT", host, "TOPLEFT", x1 or 0, y1 or 0)
    rect:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", x2 or 0, y2 or 0)
    DrawInnerFrame(rect, info, "BACKGROUND", nil, host)
    if dark then
        inset = inset or 6
        local bg = host:CreateTexture(nil, "BACKGROUND", nil, -5)
        bg:SetPoint("TOPLEFT", rect, "TOPLEFT", inset, -inset)
        bg:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", -inset, inset)
        bg:SetColorTexture(0.025, 0.022, 0.018, 0.78)
        rect.fuiFill = bg
    end
    function rect:SetBoardShown(shown)
        for _, t in ipairs(self.fuiInnerPieces or {}) do t:SetShown(shown) end
        if self.fuiFill then self.fuiFill:SetShown(shown) end
    end
    return rect
end

-- An atlas drawn at its own height, fitted to `width` the way the game's three-part bars are: its two ends
-- (cap atlas pixels each) stay as they are and only the plain middle is stretched.
function kit.AtlasBar(parent, layer, atlas, x, y, width, cap)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local info = C_Texture.GetAtlasInfo(atlas)
    if not (info and (info.file or info.filename) and (info.width or 0) > 4 and (info.height or 0) > 0) then return nil end
    local W, H = info.width, info.height
    cap = min(cap or 28, floor(W / 2) - 1, floor(width / 2))
    local L, R = info.leftTexCoord or 0, info.rightTexCoord or 1
    local T, B = info.topTexCoord or 0, info.bottomTexCoord or 1
    local function Part(sx0, sx1, dx, dw)
        local t = parent:CreateTexture(nil, layer or "ARTWORK")
        t:SetTexture(info.file or info.filename)
        t:SetTexCoord(L + (R - L) * sx0 / W, L + (R - L) * sx1 / W, T, B)
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x + dx, y)
        t:SetSize(dw, H)
        return t
    end
    return {
        Part(0, cap, 0, cap),
        Part(cap, W - cap, cap, width - 2 * cap),
        Part(W - cap, W, width - cap, cap),
    }, H
end

-- The darker interior Social Filter Forever gives the large list/table/readout areas inside pages.
function kit.ApplyDataBoardBackground(panel, inset)
    if not panel or panel.fuiDataBoardBg then return panel end
    inset = inset or 6
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, inset)
    bg:SetColorTexture(0.025, 0.022, 0.018, 0.78)
    panel.fuiDataBoardBg = bg
    return panel
end

function kit.DataBoard(parent)
    return kit.ApplyDataBoardBackground(kit.Box(parent))
end

-- Zebra striping for list/table rows, as Social Filter Forever's lists.
function kit.StripeRow(row, index, left, right)
    if not row then return end
    if not row.fuiStripe then
        local stripe = row:CreateTexture(nil, "BACKGROUND", nil, -1)
        stripe:SetPoint("TOPLEFT", row, "TOPLEFT", left or 0, 0)
        stripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(right or 0), 0)
        row.fuiStripe = stripe
    end
    if (index or 1) % 2 == 1 then
        row.fuiStripe:SetColorTexture(0.18, 0.145, 0.085, 0.24)
    else
        row.fuiStripe:SetColorTexture(0.00, 0.00, 0.00, 0.14)
    end
    row.fuiStripe:Show()
end

-- A thin line drawn the same on every row of the screen: its height is a whole number of screen pixels and it is
-- snapped to the pixel grid, so two identical dividers never look different because one falls between pixels.
local function CrispLine(t, height, vertical)
    if vertical then
        if PixelUtil and PixelUtil.SetWidth then pcall(PixelUtil.SetWidth, t, height, 1) else t:SetWidth(height) end
    elseif PixelUtil and PixelUtil.SetHeight then
        pcall(PixelUtil.SetHeight, t, height, 1)
    else
        t:SetHeight(height)
    end
    if t.SetSnapToPixelGrid then pcall(t.SetSnapToPixelGrid, t, true) end
    if t.SetTexelSnappingBias then pcall(t.SetTexelSnappingBias, t, 0.5) end
end
kit.CrispLine = CrispLine

-- The Settings panel's horizontal divider (Options_HorizontalDivider) across `parent` at height y.
function kit.Divider(parent, y, left, right, thickness)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", left or 0, y)
    t:SetPoint("TOPRIGHT", -(right or 0), y)
    if kit.SetAtlasSafe(t, "Options_HorizontalDivider") then
        CrispLine(t, thickness or 1)
    else
        t:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        t:SetHeight(thickness and thickness * 8 or 8)
    end
    return t
end

-- Turns an existing flat line texture (a WHITE8X8 rule) into the Options divider in place. Its anchors are kept.
-- vertical = true: the same Options divider art turned on its side (the atlas is drawn transposed), so vertical and
-- horizontal dividers match; a plain bronze line when the art is missing.
function kit.SkinDivider(t, vertical)
    if not t then return t end
    if vertical then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Options_HorizontalDivider")
        local file = info and (info.file or info.filename)
        if file then
            local L, R = info.leftTexCoord or 0, info.rightTexCoord or 1
            local T, B = info.topTexCoord or 0, info.bottomTexCoord or 1
            t:SetTexture(file)
            -- corners: top-left, bottom-left, top-right, bottom-right of the line <- the art's length runs downwards
            t:SetTexCoord(L, T, R, T, L, B, R, B)
            t:SetVertexColor(1, 1, 1, 1)
            CrispLine(t, 2, true)
        else
            t:SetColorTexture(0.55, 0.45, 0.26, 0.85)
            CrispLine(t, 1, true)
        end
        return t
    end
    if kit.AtlasExists("Options_HorizontalDivider") then
        t:SetVertexColor(1, 1, 1, 1)
        kit.SetAtlasSafe(t, "Options_HorizontalDivider")
        CrispLine(t, 2)
    end
    return t
end

-- A section header inside a panel: the Settings panel's white header font.
function kit.Header(parent, text, x, y)
    local fs = kit.Text(parent, "header")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- An Options section: white header and the divider under it, across `width` (or to the right edge, `right` px in).
function kit.Section(parent, text, x, y, width, right)
    local fs = kit.Header(parent, text, x, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 2, y - 22)
    if width then
        t:SetWidth(width)
    else
        t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(right or 16), y - 22)
    end
    if kit.SetAtlasSafe(t, "Options_HorizontalDivider") then
        CrispLine(t, 2)
    else
        t:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        t:SetHeight(8)
    end
    return fs, t
end

-- Buttons, text boxes ---------------------------------------------------------------------------------------------------
function kit.MakeButton(parent, x, y, w, h, text, onClick, tipTitle, tipBody, tipAnchor)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    if x then b:SetPoint("TOPLEFT", x, y) end
    b:SetText(text or "")
    if onClick then b:SetScript("OnClick", onClick) end
    if tipTitle then kit.SetTooltip(b, tipTitle, tipBody, tipAnchor) end
    return b
end

function kit.MakeEditBox(parent, x, y, w, hint, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(w, 22)
    if x then box:SetPoint("TOPLEFT", x, y) end
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters or 48)
    box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    box.hint:SetPoint("LEFT", 2, 0)
    box.hint:SetText(hint or "")
    box:SetScript("OnTextChanged", function(self, byUser)
        self.hint:SetShown(self:GetText() == "")
        if self.onChange then self.onChange(self, byUser) end
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

function kit.MakeSearchBox(parent, x, y, w, hint, maxLetters)
    local box = kit.CreateFrameFrom("EditBox", nil, parent, { "SearchBoxTemplate" })
    if not box then return kit.MakeEditBox(parent, x, y, w, hint, maxLetters) end
    box:SetSize(w, 22)
    if x then box:SetPoint("TOPLEFT", x, y) end
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters or 48)
    box.hint = box.Instructions
    if box.hint then box.hint:SetText(hint or "") end
    box:HookScript("OnTextChanged", function(self, byUser)
        if self.hint then self.hint:SetShown(self:GetText() == "") end
        if self.onChange then self.onChange(self, byUser) end
    end)
    return box
end

-- Check boxes, radio buttons -------------------------------------------------------------------------------------------
-- The Options window's check box: a dark square (checkbox-minimal) with the gold checkmark-minimal tick and no glow
-- of its own. Applied to a UICheckButtonTemplate box, so it keeps that button's behaviour; the template's own art
-- stays when the atlases are missing.
local function TexSetAtlas(tex, atlas)
    return tex and tex.SetAtlas and kit.SetAtlasSafe(tex, atlas)
end

function kit.SkinCheck(cb, size)
    if not cb or cb.fuiMinimalCheck then return cb and cb.fuiMinimalCheck or false end
    if not (kit.AtlasExists("checkbox-minimal") and kit.AtlasExists("checkmark-minimal")) then return false end
    TexSetAtlas(cb.GetNormalTexture and cb:GetNormalTexture(), "checkbox-minimal")
    TexSetAtlas(cb.GetPushedTexture and cb:GetPushedTexture(), "checkbox-minimal")
    TexSetAtlas(cb.GetCheckedTexture and cb:GetCheckedTexture(), "checkmark-minimal")
    local dc = cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture()
    if not (dc and TexSetAtlas(dc, "checkmark-minimal-disabled")) then TexSetAtlas(dc, "checkmark-minimal") end
    local dis = cb.GetDisabledTexture and cb:GetDisabledTexture()
    if dis and TexSetAtlas(dis, "checkbox-minimal") and dis.SetDesaturated then dis:SetDesaturated(true) end
    local hl = cb.GetHighlightTexture and cb:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    if size ~= false then cb:SetSize(size or 30, size and (size - 1) or 29) end
    cb.fuiMinimalCheck = true
    return true
end

-- The Options window's hover band behind a row (HoverBackgroundTemplate), shown while the mouse is over `owner`.
function kit.HoverBand(owner, anchorFrom, anchorTo)
    if not owner or owner.fuiHoverBand then return owner and owner.fuiHoverBand end
    if not kit.TemplateExists("HoverBackgroundTemplate") then return end
    local ok, band = pcall(owner.CreateTexture, owner, nil, "BACKGROUND", "HoverBackgroundTemplate")
    if not (ok and band) then return end
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", anchorFrom or owner, "TOPLEFT", -6, 0)
    band:SetPoint("BOTTOMRIGHT", anchorTo or owner, "BOTTOMRIGHT", 5, 0)
    band:Hide()
    owner:HookScript("OnEnter", function() band:Show() end)
    owner:HookScript("OnLeave", function() band:Hide() end)
    owner.fuiHoverBand = band
    return band
end

-- The label of a UICheckButtonTemplate box, whichever way the template exposes it.
function kit.CheckLabel(cb)
    if not cb then return nil end
    local fs = cb.Text or cb.text or cb.label
    if not fs and cb.GetName and cb:GetName() then fs = _G[cb:GetName() .. "Text"] end
    if fs and fs.GetObjectType and fs:GetObjectType() == "FontString" then return fs end
end

-- An existing check box in the Options look: the minimal box, a gold label (the box's own .Text, or `label` when
-- the addon drew its label separately), and the hover band across both. opts: size (default 26, false keeps the
-- size), labelStyle ("label" gold by default, false keeps the label's font), band (default true).
function kit.SkinCheckButton(cb, label, opts)
    if not cb then return cb end
    opts = opts or {}
    local size = opts.size
    if size == nil then size = 26 end
    kit.SkinCheck(cb, size)
    local fs = label or kit.CheckLabel(cb)
    if fs and opts.labelStyle ~= false then
        kit.Font(fs, opts.labelStyle or "label")
        cb.fuiLabel = fs
        if not cb.fuiEnableHooked and cb.HookScript and cb.HasScript and cb:HasScript("OnDisable") then
            cb.fuiEnableHooked = true
            cb:HookScript("OnDisable", function(self) if self.fuiLabel then kit.Font(self.fuiLabel, "faded") end end)
            cb:HookScript("OnEnable", function(self) if self.fuiLabel then kit.Font(self.fuiLabel, opts.labelStyle or "label") end end)
        end
    end
    if opts.band ~= false then kit.HoverBand(cb, cb, fs or cb) end
    return cb
end

-- A check box with its label (gold, like the Settings panel).
function kit.MakeCheckBox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    kit.SkinCheck(cb, 26)
    local own = kit.CheckLabel(cb)
    if own then own:SetText("") end
    cb.label = kit.Text(cb, "label")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetText(label or "")
    kit.HoverBand(cb, cb, cb.label)
    return cb
end

function kit.SetCheckEnabled(cb, enabled)
    cb:SetEnabled(enabled)
    local fs = cb.fuiLabel or cb.label
    if fs then kit.Font(fs, enabled and "label" or "faded") end
end

-- A radio button with its label (UIRadioButtonTemplate). Clicking the label clicks the button.
function kit.MakeRadio(parent, label)
    local rb = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    rb:SetSize(16, 16)
    rb.isRadio = true
    rb.label = kit.Text(rb, "body")
    rb.label:SetPoint("LEFT", rb, "RIGHT", 5, 0)
    rb.label:SetText(label or "")
    local w = (rb.label.GetUnboundedStringWidth and rb.label:GetUnboundedStringWidth()) or rb.label:GetStringWidth() or 60
    rb:SetHitRectInsets(0, -(w + 8), -4, -4)
    return rb
end

-- Sliders ------------------------------------------------------------------------------------------------------------
-- The Options window's slider (MinimalSliderWithSteppersTemplate): a thin bar, a diamond thumb and an arrow stepper
-- on each side. kit.SkinSlider gives an existing slider (OptionsSliderTemplate, UISliderTemplate, a plain Slider)
-- that look in place: the slider stays the same widget, with the same name, size, anchors, Low/High/Text labels,
-- values and scripts, so nothing the addon does with it changes. The art is read from one instance of the game's
-- own template (made once, never shown), so it is exactly the Options window's.
local sliderArt   -- nil: not looked up yet; false: not available
local function TexAtlas(t)
    return t and t.GetAtlas and t:GetAtlas() or nil
end

local function SliderArt()
    if sliderArt ~= nil then return sliderArt or nil end
    sliderArt = false
    if not kit.TemplateExists("MinimalSliderWithSteppersTemplate") then return nil end
    local ok, ref = pcall(CreateFrame, "Frame", nil, nil, "MinimalSliderWithSteppersTemplate")
    if not (ok and ref and ref.Slider) then return nil end
    ref:Hide()
    local s = ref.Slider
    local art = {
        left = TexAtlas(s.Left) or "Minimal_SliderBar_Left",
        right = TexAtlas(s.Right) or "Minimal_SliderBar_Right",
        middle = TexAtlas(s.Middle) or "_Minimal_SliderBar_Middle",
        thumb = TexAtlas(s.Thumb or (s.GetThumbTexture and s:GetThumbTexture())) or "Minimal_SliderBar_Button",
    }
    if not (kit.AtlasExists(art.left) and kit.AtlasExists(art.right) and kit.AtlasExists(art.middle) and kit.AtlasExists(art.thumb)) then
        return nil
    end
    local function Stepper(b, fallback)
        if not b then return nil end
        local st = {
            normal = TexAtlas(b.GetNormalTexture and b:GetNormalTexture()),
            pushed = TexAtlas(b.GetPushedTexture and b:GetPushedTexture()),
            disabled = TexAtlas(b.GetDisabledTexture and b:GetDisabledTexture()),
            highlight = TexAtlas(b.GetHighlightTexture and b:GetHighlightTexture()),
        }
        -- some builds draw the arrow as a texture of the button instead of its normal texture
        if not st.normal then
            for _, r in ipairs({ b:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "Texture" then
                    local a = TexAtlas(r)
                    if a then st.normal = a break end
                end
            end
        end
        st.normal = st.normal or fallback
        if not kit.AtlasExists(st.normal) then return nil end
        local w, h = b:GetSize()
        if not (w and w > 1 and h and h > 1) then w, h = kit.AtlasSize(st.normal) end
        st.w, st.h = w or 11, h or 19
        return st
    end
    art.back = Stepper(ref.Back, "Minimal_SliderBar_Button_Left")
    art.forward = Stepper(ref.Forward, "Minimal_SliderBar_Button_Right")
    sliderArt = art
    return art
end
kit.HasSliderArt = function() return SliderArt() ~= nil end

local function StepperButton(slider, st, dir)
    local b = CreateFrame("Button", nil, slider)
    b:SetSize(st.w, st.h)
    local n = b:CreateTexture(nil, "ARTWORK")
    n:SetAllPoints()
    kit.SetAtlasSafe(n, st.normal)
    b:SetNormalTexture(n)
    if st.pushed then
        local p = b:CreateTexture(nil, "ARTWORK")
        p:SetAllPoints()
        kit.SetAtlasSafe(p, st.pushed)
        b:SetPushedTexture(p)
    end
    if st.disabled then
        local d = b:CreateTexture(nil, "ARTWORK")
        d:SetAllPoints()
        kit.SetAtlasSafe(d, st.disabled)
        b:SetDisabledTexture(d)
    end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    if not (st.highlight and kit.SetAtlasSafe(hl, st.highlight)) then
        kit.SetAtlasSafe(hl, st.normal)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
    end
    b:SetHighlightTexture(hl)
    b:SetScript("OnClick", function()
        if slider.IsEnabled and not slider:IsEnabled() then return end
        local lo, hi = slider:GetMinMaxValues()
        local step = slider.fuiStepperStep
        if type(step) == "function" then step = step(slider) end
        step = step or slider:GetValueStep()
        if not step or step <= 0 then step = ((hi or 1) - (lo or 0)) / 20 end
        local v = (slider:GetValue() or 0) + dir * step
        if lo and v < lo then v = lo end
        if hi and v > hi then v = hi end
        slider:SetValue(v)
        if PlaySound and SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON then pcall(PlaySound, SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
    end)
    return b
end

-- opts: steppers (default true), gap (px between the bar and a stepper, default 4), lowHigh ("keep" default,
-- "hide" removes the Low/High captions, "small" draws them in the small grey font), labelStyle (a kit font style
-- for the slider's own .Text caption, e.g. "label" for the Options window's gold label), step (what one click on an
-- arrow stepper moves: a number or function(slider); default the slider's own value step).
function kit.SkinSlider(slider, opts)
    if not slider or slider.fuiSliderSkinned then return slider and slider.fuiSliderSkinned or false end
    local art = SliderArt()
    if not art then return false end
    opts = opts or {}
    slider.fuiSliderSkinned = true
    slider.fuiStepperStep = opts.step   -- nil: the slider's own value step

    -- the older template's art: its backdrop (OptionsSliderTemplate) or its nine-slice
    if slider.SetBackdrop then pcall(slider.SetBackdrop, slider, nil) end
    if slider.NineSlice and slider.NineSlice.Hide then slider.NineSlice:Hide() end
    for _, key in ipairs({ "Left", "Right", "Middle" }) do
        local r = slider[key]
        if r and r.Hide and r.GetObjectType and r:GetObjectType() == "Texture" then r:Hide() end
    end

    local function Bar(atlas, layer)
        local t = slider:CreateTexture(nil, layer or "BACKGROUND")
        kit.SetAtlasSafe(t, atlas, true)
        return t
    end
    local left, right, middle = Bar(art.left), Bar(art.right), Bar(art.middle)
    left:SetPoint("LEFT", slider, "LEFT", 0, 0)
    right:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
    slider.fuiBar = { left, middle, right }

    local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if not thumb then
        thumb = slider:CreateTexture(nil, "ARTWORK")
        slider:SetThumbTexture(thumb)
        thumb = slider:GetThumbTexture() or thumb
    end
    kit.SetAtlasSafe(thumb, art.thumb, true)

    local name = slider.GetName and slider:GetName()
    if opts.labelStyle then
        local text = slider.Text or (name and _G[name .. "Text"])
        if text then kit.Font(text, opts.labelStyle) end
    end
    local low = slider.Low or (name and _G[name .. "Low"])
    local high = slider.High or (name and _G[name .. "High"])
    if opts.lowHigh == "hide" then
        if low then low:Hide() end
        if high then high:Hide() end
    elseif opts.lowHigh == "small" then
        if low then kit.Font(low, "desc") end
        if high then kit.Font(high, "desc") end
    end

    if opts.steppers ~= false and art.back and art.forward then
        local gap = opts.gap or 4
        local back = StepperButton(slider, art.back, -1)
        local forward = StepperButton(slider, art.forward, 1)
        back:SetPoint("RIGHT", slider, "LEFT", -gap, 0)
        forward:SetPoint("LEFT", slider, "RIGHT", gap, 0)
        slider.fuiBack, slider.fuiForward = back, forward
        slider.fuiSteppers = { back, forward }
        local function Sync(self)
            local on = not self.IsEnabled or self:IsEnabled()
            local v = self:GetValue()
            local lo, hi = self:GetMinMaxValues()
            self.fuiBack:SetEnabled(on and (lo == nil or v == nil or v > lo) and true or false)
            self.fuiForward:SetEnabled(on and (hi == nil or v == nil or v < hi) and true or false)
        end
        slider.fuiSyncSteppers = Sync
        slider:HookScript("OnValueChanged", Sync)
        if slider.HasScript and slider:HasScript("OnEnable") then
            slider:HookScript("OnEnable", Sync)
            slider:HookScript("OnDisable", Sync)
        end
        slider:HookScript("OnShow", Sync)
        pcall(Sync, slider)
    end

    -- the thumb dims with the slider, as the Options sliders do
    if slider.HasScript and slider:HasScript("OnDisable") then
        slider:HookScript("OnDisable", function(self)
            local t = self:GetThumbTexture()
            if t and t.SetDesaturated then t:SetDesaturated(true) end
            for _, b in ipairs(self.fuiBar or {}) do b:SetAlpha(0.5) end
        end)
        slider:HookScript("OnEnable", function(self)
            local t = self:GetThumbTexture()
            if t and t.SetDesaturated then t:SetDesaturated(false) end
            for _, b in ipairs(self.fuiBar or {}) do b:SetAlpha(1) end
        end)
    end
    return true
end

-- A new Options slider: label (gold) above, the bar, and the value under it. opts: x, y (TOPLEFT of the label in
-- parent), width, min, max, step, get(), set(v), format(v) -> text, tip, name.
function kit.MakeSlider(parent, opts)
    local labelFS = kit.Text(parent, "label")
    labelFS:SetPoint("TOPLEFT", opts.x or 0, opts.y or 0)
    labelFS:SetText(opts.label or "")
    local s = CreateFrame("Slider", opts.name, parent, kit.TemplateExists("OptionsSliderTemplate") and "OptionsSliderTemplate" or nil)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(opts.width or 200, 17)
    s:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 16, -8)
    s:SetMinMaxValues(opts.min or 0, opts.max or 100)
    s:SetValueStep(opts.step or 1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    kit.SkinSlider(s, { lowHigh = "hide" })
    local name = s:GetName()
    for _, key in ipairs({ "Text", "Low", "High" }) do
        local fs = s[key] or (name and _G[name .. key])
        if fs then fs:SetText("") end
    end
    local valueFS = kit.Text(parent, "value")
    valueFS:SetPoint("TOP", s, "BOTTOM", 0, -2)
    s.valueText, s.label = valueFS, labelFS
    local fmt = opts.format or function(v) return tostring(v) end
    s:SetScript("OnValueChanged", function(self, v)
        local step = opts.step or 1
        v = floor(v / step + 0.5) * step
        valueFS:SetText(fmt(v))
        if self.fuiRefreshing then return end
        if opts.set then opts.set(v) end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue((self:GetValue() or 0) + (delta > 0 and 1 or -1) * (opts.step or 1))
    end)
    function s:Refresh()
        if not opts.get then return end
        self.fuiRefreshing = true
        self:SetValue(opts.get())
        self.fuiRefreshing = nil
        valueFS:SetText(fmt(self:GetValue()))
    end
    if opts.tip then kit.SetTooltip(s, opts.label, opts.tip) end
    s:Refresh()
    return s
end

-- Tabs ------------------------------------------------------------------------------------------------------------------
-- The Options window's own tabs (MinimalTabTemplate), the game's top tabs (PanelTopTabButtonTemplate) where those
-- are missing. The open one is drawn selected; one with something new waiting has its label in orange.
local ROW_ORDER = setmetatable({}, { __mode = "k" })
local TAB_GLOW = { "LeftHighlight", "MiddleHighlight", "RightHighlight" }

local function TabLabel(b)
    local n = b.unread or 0
    local text = b.label
    if n > 0 then text = text .. " (" .. (n > 99 and "99+" or n) .. ")" end
    if b.alert and not b.active then text = kit.CODE.orange .. text .. "|r" end
    if b.isMinimalTab then
        b.Text:SetText(text)
        local w = (b.Text.GetUnboundedStringWidth and b.Text:GetUnboundedStringWidth()) or b.Text:GetStringWidth() or 40
        b:SetWidth(max(b.minTabWidth or 0, w + 40))
        return
    end
    b:SetText(text)
    if b.isNativeTab and b:IsShown() and PanelTemplates_TabResize then
        local parent = b:GetParent()
        pcall(PanelTemplates_TabResize, b, parent and parent.tabPadding, nil, parent and parent.minTabWidth, parent and parent.maxTabWidth)
    end
end

local function PaintTab(b)
    if b.isRadio then
        b:SetChecked(b.active and true or false)
        return
    end
    TabLabel(b)
    if b.isMinimalTab then
        if b.SetSelected then b:SetSelected(b.active and true or false) end
        if b.active then b:Enable() end
        return
    end
    if b.isNativeTab and PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
        if b.active then PanelTemplates_SelectTab(b) else PanelTemplates_DeselectTab(b) end
        if b.active then b:Enable() end
        b:SetNormalFontObject(b.active and GameFontHighlightSmall or GameFontNormalSmall)
        for _, key in ipairs(TAB_GLOW) do
            if b[key] then b[key]:SetAlpha(b.active and 0 or 0.4) end
        end
    elseif b.active then
        b:LockHighlight()
    else
        b:UnlockHighlight()
    end
end

local function CreateTabButton(parent, text, width, height)
    local b, template = kit.CreateFrameFrom("Button", nil, parent, { "MinimalTabTemplate", "PanelTopTabButtonTemplate", "UIPanelButtonTemplate" })
    b.isMinimalTab = (template == "MinimalTabTemplate") and b.Text ~= nil and b.SetSelected ~= nil
    b.isNativeTab = b.isMinimalTab or ((template == "PanelTopTabButtonTemplate") and b.Left ~= nil and b.LeftActive ~= nil)
    if not b.isNativeTab then b:SetSize(width or 80, height or 22) end
    b.minTabWidth = width
    b.label, b.unread = text, 0
    b.text = b.isMinimalTab and b.Text or (b:GetFontString() or b.Text)
    TabLabel(b)
    if b.isMinimalTab then
        PaintTab(b)
    elseif b.isNativeTab then
        PaintTab(b)
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, b, parent.tabPadding, nil, parent.minTabWidth, parent.maxTabWidth)
        end
    end
    b:HookScript("OnEnter", function(self)
        if self.tipTitle then kit.ShowTip(self, "ANCHOR_TOP", self.tipTitle, self.tipBody) end
    end)
    b:HookScript("OnLeave", function(self)
        if self.tipTitle then kit.HideTip() end
    end)
    return b
end

-- kit.ChipRow(parent, { {key, label, minWidth, tipTitle, tipBody}, ... }, onPick) lays tabs side by side from the
-- left edge of `parent` and returns the buttons by key, and the width they take. The caller sets .active and calls
-- kit.PaintTab. kit.DockTabs puts the row on the top edge of a panel.
function kit.ChipRow(parent, defs, onPick, height)
    local row, order, x = {}, {}, 0
    local prev
    for _, d in ipairs(defs) do
        local b = CreateTabButton(parent, d[2], d[3], height or 24)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", b.isMinimalTab and 5 or (b.isNativeTab and 0 or 4), 0)
        else
            b:SetPoint("TOPLEFT", 0, 0)
        end
        b.tabKey = d[1]
        b.tipTitle, b.tipBody = d[4], d[5]
        b:SetScript("OnClick", function() onPick(d[1]) end)
        row[d[1]] = b
        order[#order + 1] = b
        x = x + (b:GetWidth() or d[3] or 80) + (b.isMinimalTab and 5 or (b.isNativeTab and 0 or 4))
        prev = b
    end
    ROW_ORDER[row] = order
    return row, x
end

function kit.DockTabs(row, panel, xOffset)
    local order = row and ROW_ORDER[row]
    if not (order and order[1]) then return end
    local first = order[1]
    first:ClearAllPoints()
    if first.isNativeTab then
        first:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", xOffset or 6, 0)
    else
        first:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", xOffset or 0, 4)
    end
    for _, b in ipairs(order) do
        b:SetFrameLevel(max(b:GetFrameLevel(), panel:GetFrameLevel() + 2))
    end
    return order[#order]
end

kit.TabLabel = TabLabel
kit.PaintTab = PaintTab
kit.CreateTabButton = CreateTabButton

-- A status switch: a check box with a name and, when withDetail is set, a second line under it. The whole area is
-- one button, so a click anywhere on it toggles. switch:SetState(on) ticks the box; the caller sets the click action.
function kit.CreateSwitch(parent, width, height, label, withDetail)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.switchLabel = label
    b.box = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
    b.box:SetSize(26, 26)
    kit.SkinCheck(b.box, 28)
    b.box:SetPoint("LEFT", -2, 0)
    b.box:EnableMouse(false)
    b.hoverBand = kit.HoverBand(b, b, b)
    b.text = kit.Text(b, "label")
    b.text:SetJustifyH("LEFT")
    b.text:SetText(label)
    if withDetail then
        b.text:SetPoint("TOPLEFT", b.box, "RIGHT", 2, 9)
        b.detail = kit.Text(b, "small")
        b.detail:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -2)
        b.detail:SetJustifyH("LEFT")
    else
        b.text:SetPoint("LEFT", b.box, "RIGHT", 2, 0)
    end
    function b:SetState(on)
        self.isOn = on and true or false
        self.box:SetChecked(self.isOn)
        self.text:SetText(self.switchLabel)
        if self.detail then
            local c = self.isOn and COLOR.green or COLOR.gray
            self.detail:SetTextColor(c[1], c[2], c[3])
        end
    end
    b:SetScript("OnEnter", function(self)
        self.box:LockHighlight()
        if self.tipTitle then kit.ShowTip(self, "ANCHOR_RIGHT", self.tipTitle, self.tipBody) end
    end)
    b:SetScript("OnLeave", function(self)
        self.box:UnlockHighlight()
        if self.tipTitle then kit.HideTip() end
    end)
    b:SetState(false)
    return b
end

-- Drop-down lists -------------------------------------------------------------------------------------------------------
-- The Options window's dropdown (WowStyle2DropdownTemplate: the common-dropdown button and its dark menu) with one
-- radio entry per option. Wide ones also get the Options arrow steppers on each side; they pick the previous / next
-- choice exactly as picking it in the menu does, and grey out at the ends of the list. Falls back to
-- WowStyle1DropdownTemplate, then to UIDropDownMenu (the old list, with a name made from this addon's name).
--
-- options = { { value =, text =, shown = (text on the closed box) } ... } or a function returning that list.
-- get() returns the current value; set(value) is called when one is picked. dd:Refresh() shows the current choice.
-- dd:SetDropdownEnabled(on) enables or disables it and its steppers together.
local ddCount = 0
local STEPPER_MIN_WIDTH = 180

local function Options(options)
    if type(options) == "function" then return options() or {} end
    return options or {}
end

-- kit.CreateDropdown(parent, width, options, get, set, opts): the dropdown, not placed. width is the width of the
-- closed box. Place it with dd:SetPoint(...) as any frame (for the old UIDropDownMenu fallback, dd.fuiLegacy is true).
-- An option may also be { text =, children = { ...options... } }: a submenu (the entry opens a second list).
-- opts:
--   steppers   arrow steppers beside the box (default: width >= 180; WowStyle2 only; 31 px wide each)
--   style      1 = prefer WowStyle1DropdownTemplate (the dropdown of the game's own talent and spell windows);
--              default WowStyle2 (the Options window's)
--   emptyText  text on the closed box when the current value matches no option
--   shownText  function(current value) -> text on the closed box (overrides the option's text)
--   title      a title line at the top of the menu
--   tipTitle, tipBody  the box's tooltip
local function Flatten(list, out)
    out = out or {}
    for _, o in ipairs(list) do
        if o.children then
            Flatten(Options(o.children), out)
        elseif not (o.isTitle or o.isDivider) then
            out[#out + 1] = o
        end
    end
    return out
end

function kit.CreateDropdown(parent, width, options, get, set, opts)
    opts = opts or {}
    ddCount = ddCount + 1
    local function ShownText()
        local cur = get()
        if opts.shownText then
            local t = opts.shownText(cur)
            if t ~= nil then return tostring(t) end
        end
        local text = opts.emptyText or (cur ~= nil and tostring(cur) or "")
        for _, o in ipairs(Flatten(Options(options))) do
            if o.value == cur then text = o.shown or o.text end
        end
        return text
    end
    local function Choices()
        local list = {}
        for _, o in ipairs(Flatten(Options(options))) do
            if not o.disabled then list[#list + 1] = o end
        end
        return list
    end

    local templates = opts.style == 1 and { "WowStyle1DropdownTemplate", "WowStyle2DropdownTemplate" }
        or { "WowStyle2DropdownTemplate", "WowStyle1DropdownTemplate" }
    local dd, template = kit.CreateFrameFrom("DropdownButton", nil, parent, templates)
    if dd and dd.SetupMenu and dd.OverrideText then
        dd.fuiNativeDropdown = true
        dd:SetWidth(width)
        local steppers = opts.steppers
        if steppers == nil then steppers = width >= STEPPER_MIN_WIDTH end
        steppers = steppers and template == "WowStyle2DropdownTemplate"
            and kit.TemplateExists("SteppersDecrementButtonTemplate") and kit.TemplateExists("SteppersIncrementButtonTemplate")
        local function Fill(root, list)
            for _, o in ipairs(list) do
                if o.isTitle and root.CreateTitle then
                    root:CreateTitle(o.text)
                elseif o.isDivider and root.CreateDivider then
                    root:CreateDivider()
                elseif o.children then
                    local sub = root:CreateButton(o.text)
                    if sub then Fill(sub, Options(o.children)) end
                else
                    local entry = root:CreateRadio(o.text, function(opt) return get() == opt.value end, function(opt)
                        set(opt.value)
                        dd:Refresh()
                    end, o)
                    if o.disabled and entry and entry.SetEnabled then entry:SetEnabled(false) end
                    if o.tooltip and entry and entry.SetTooltip and GameTooltip_SetTitle and GameTooltip_AddNormalLine then
                        entry:SetTooltip(function(tip) GameTooltip_SetTitle(tip, o.text); GameTooltip_AddNormalLine(tip, o.tooltip) end)
                    end
                end
            end
        end
        dd:SetupMenu(function(_, root)
            if opts.title and root.CreateTitle then root:CreateTitle(opts.title) end
            Fill(root, Options(options))
        end)
        if steppers then
            local function Step(delta)
                local list, cur = Choices(), get()
                local at
                for i, o in ipairs(list) do if o.value == cur then at = i end end
                local o = at and list[at + delta]
                if o then
                    set(o.value)
                    dd:Refresh()
                end
            end
            dd.decrement = CreateFrame("Button", nil, dd, "SteppersDecrementButtonTemplate")
            dd.decrement:SetPoint("RIGHT", dd, "LEFT", -5, 0)
            dd.decrement:SetScript("OnClick", function() Step(-1) end)
            dd.increment = CreateFrame("Button", nil, dd, "SteppersIncrementButtonTemplate")
            dd.increment:SetPoint("LEFT", dd, "RIGHT", 4, 0)
            dd.increment:SetScript("OnClick", function() Step(1) end)
        end
        function dd:UpdateSteppers()
            if not self.decrement then return end
            local list, cur = Choices(), get()
            local at
            for i, o in ipairs(list) do if o.value == cur then at = i end end
            local on = self:IsEnabled()
            self.decrement:SetEnabled(on and at ~= nil and at > 1)
            self.increment:SetEnabled(on and at ~= nil and at < #list)
        end
        function dd:SetDropdownEnabled(on)
            self:SetEnabled(on and true or false)
            self:UpdateSteppers()
        end
        function dd:Refresh()
            self:OverrideText(ShownText())
            self:UpdateSteppers()
        end
        if opts.tipTitle then kit.SetTooltip(dd, opts.tipTitle, opts.tipBody) end
        dd:Refresh()
        return dd
    elseif dd then
        dd:Hide()
    end

    -- the old drop-down list: same calls, same behaviour
    dd = CreateFrame("Frame", ADDON_NAME .. "FUIDropdown" .. ddCount, parent, "UIDropDownMenuTemplate")
    dd.fuiLegacy = true
    UIDropDownMenu_SetWidth(dd, width - 16)
    local function Add(o, level, cur, index)
        local info = UIDropDownMenu_CreateInfo()
        info.text = o.text
        if o.isTitle then
            info.isTitle, info.notCheckable = true, true
        elseif o.isDivider then
            info.text, info.disabled, info.notCheckable = "", true, true
        elseif o.children then
            info.hasArrow, info.notCheckable, info.value = true, true, index
        else
            info.value = o.value
            info.checked = (cur == o.value)
            info.disabled = o.disabled
            info.func = function()
                set(o.value)
                dd:Refresh()
                if CloseDropDownMenus then CloseDropDownMenus() end
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
    UIDropDownMenu_Initialize(dd, function(_, level)
        level = level or 1
        local cur = get()
        local list = Options(options)
        if level == 1 then
            for i, o in ipairs(list) do Add(o, 1, cur, i) end
        elseif level == 2 then
            local parentOption = list[tonumber(UIDROPDOWNMENU_MENU_VALUE) or 0]
            if parentOption and parentOption.children then
                for i, o in ipairs(Options(parentOption.children)) do Add(o, 2, cur, i) end
            end
        end
    end)
    function dd:Refresh()
        UIDropDownMenu_SetSelectedValue(self, get())
        UIDropDownMenu_SetText(self, ShownText())
    end
    function dd:SetDropdownEnabled(on)
        if on then UIDropDownMenu_EnableDropDown(self) else UIDropDownMenu_DisableDropDown(self) end
    end
    if opts.tipTitle then kit.SetTooltip(dd, opts.tipTitle, opts.tipBody) end
    dd:Refresh()
    return dd
end

-- kit.MakeDropdown(parent, x, y, width, options, get, set): placed where an old UIDropDownMenu with that x, y and
-- width (UIDropDownMenu_SetWidth) would have drawn its box, as Social Filter Forever does.
function kit.MakeDropdown(parent, x, y, width, options, get, set, opts)
    opts = opts or {}
    local steppers = opts.steppers
    if steppers == nil then steppers = width >= STEPPER_MIN_WIDTH end
    local w = width + 14
    local left = x + 16
    local probe = kit.TemplateExists("WowStyle2DropdownTemplate")
    if steppers and probe and kit.TemplateExists("SteppersDecrementButtonTemplate") then left, w = left + 31, w - 62 end
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.steppers = steppers
    local dd = kit.CreateDropdown(parent, w, options, get, set, o)
    if dd.fuiLegacy then
        dd:SetPoint("TOPLEFT", x, y)
    else
        dd:SetPoint("TOPLEFT", left, y - 4)
    end
    return dd
end

-- Helpers for replacing an old UIDropDownMenu in a layout that was measured for it, without re-measuring: the old
-- frame drew its box 16 px in from its left edge and about 4 px under its top, and UIDropDownMenu_SetWidth(w) gave
-- a box about w + 14 px wide.
--   kit.LegacyDropdown(parent, legacyWidth, options, get, set, opts)  -- the new dropdown, sized as the old one was
--   kit.PlaceDropdown(dd, point, relativeTo, relativePoint, x, y)    -- SetPoint with the old frame's coordinates
--   kit.SetDropdownWidth(dd, legacyWidth)                             -- UIDropDownMenu_SetWidth's replacement
kit.LEGACY_DROPDOWN_DX, kit.LEGACY_DROPDOWN_DY, kit.LEGACY_DROPDOWN_DW = 16, -4, 14

function kit.LegacyDropdown(parent, legacyWidth, options, get, set, opts)
    opts = opts or {}
    if opts.steppers == nil then opts.steppers = false end
    local dd = kit.CreateDropdown(parent, (legacyWidth or 120) + kit.LEGACY_DROPDOWN_DW, options, get, set, opts)
    if dd.fuiLegacy then UIDropDownMenu_SetWidth(dd, legacyWidth or 120) end
    return dd
end

function kit.PlaceDropdown(dd, point, relativeTo, relativePoint, x, y)
    dd:ClearAllPoints()
    x, y = x or 0, y or 0
    if not dd.fuiLegacy then
        x = x + kit.LEGACY_DROPDOWN_DX
        if point:find("TOP") then y = y + kit.LEGACY_DROPDOWN_DY
        elseif point:find("BOTTOM") then y = y - kit.LEGACY_DROPDOWN_DY end
    end
    dd:SetPoint(point, relativeTo, relativePoint, x, y)
end

function kit.SetDropdownWidth(dd, legacyWidth)
    if dd.fuiLegacy then
        UIDropDownMenu_SetWidth(dd, legacyWidth)
    else
        dd:SetWidth(legacyWidth + kit.LEGACY_DROPDOWN_DW)
    end
end

-- The scrolling list -----------------------------------------------------------------------------------------------------
-- A scroll frame with the game's current scroll bar (ScrollFrameTemplate: MinimalScrollBar), or the older one.
-- The bar sits just right of the frame, as UIPanelScrollFrameTemplate's did.
function kit.ScrollFrame(parent, name)
    local scroll = kit.CreateFrameFrom("ScrollFrame", name, parent, { "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
    local bar = scroll.ScrollBar
    if bar and bar.SetHideIfUnscrollable then pcall(bar.SetHideIfUnscrollable, bar, true) end
    scroll.fuiMinimal = bar ~= nil and bar.SetHideIfUnscrollable ~= nil
    return scroll
end

-- A row's mouse-over and selection: the quest-title glow the AddOns list and the Group Finder use.
local ROW_GLOW = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
kit.ROW_GLOW = ROW_GLOW

function kit.RowHighlights(r)
    r.hl = r:CreateTexture(nil, "BORDER", nil, 1)
    r.hl:SetAllPoints()
    r.hl:SetTexture(ROW_GLOW)
    r.hl:SetBlendMode("ADD")
    r.hl:SetAlpha(0.7)
    r.hl:Hide()
    r.sel = r:CreateTexture(nil, "BORDER")
    r.sel:SetAllPoints()
    r.sel:SetTexture(ROW_GLOW)
    r.sel:SetBlendMode("ADD")
    r.sel:Hide()
end

return kit
