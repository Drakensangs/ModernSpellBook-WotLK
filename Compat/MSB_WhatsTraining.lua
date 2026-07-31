local ROW_HEIGHT   = 14
local WT_PAGE_SIZE = 22   -- WT's internal page size, do not change
local MAX_ROWS     = 31   -- visible rows in our frame; edit freely

local WT_ADDON_NAMES = { "WhatsTraining_WotLK", "Whats-Training-Epoch" }

local function IsWTLoaded()
    for _, name in ipairs(WT_ADDON_NAMES) do
        if IsAddOnLoaded(name) then return true end
    end
    return false
end

local function GetWTHighlight()
    for _, name in ipairs(WT_ADDON_NAMES) do
        if IsAddOnLoaded(name) then
            return "Interface\\AddOns\\" .. name .. "\\res\\highlight"
        end
    end
end

local function GetWTRowName(i)
    if IsAddOnLoaded("Whats-Training-Epoch") then
        return "WhatsTrainingFrameContentRow" .. i
    end
    return "WhatsTrainingFrameRow" .. i
end

local companion    = nil
local snapshot     = {}
local snapCount    = 0
local searchFilter = nil  -- lowercase search string from MSB search bar, or nil

-- hooksecurefunc on FauxScrollFrame_Update to intercept WT's render calls.
-- When WT calls FauxScrollFrame_Update with its scrollbar, we capture numItems
-- and read the currently-visible rows into our snapshot at the current offset.
-- We accumulate across all pages as the user (or we) scroll WT's frame.
local function HookFauxScrollUpdate()
    local wtScrollBarName = "WhatsTrainingFrameScrollBar"
    hooksecurefunc("FauxScrollFrame_Update", function(scrollFrame, numItems)
        if scrollFrame:GetName() ~= wtScrollBarName then return end
        snapCount = numItems or 0
        local offset = FauxScrollFrame_GetOffset(scrollFrame)
        for i = 1, WT_PAGE_SIZE do
            local row = _G[GetWTRowName(i)]
            if row then
                if row.currentSpell then
                    snapshot[offset + i] = row.currentSpell
                else
                    snapshot[offset + i] = nil
                end
            end
        end
        -- Trim stale entries beyond current total
        for k in pairs(snapshot) do
            if k > snapCount then snapshot[k] = nil end
        end
        if companion and companion:IsShown() then
            RenderCompanion()
        end
    end)
end

-- Drive WT's scrollbar through all pages to populate the full snapshot.
local function BuildSnapshot()
    local wtScrollBar = _G["WhatsTrainingFrameScrollBar"]
    if not wtScrollBar then return end

    -- Trigger OnShow to ensure RebuildData has run and wt.Update fires for page 0
    local onShow = wtScrollBar:GetScript("OnShow")
    if onShow then onShow(wtScrollBar) end

    -- Now page through remaining pages via OnVerticalScroll
    -- snapCount was set by the hooksecurefunc during the OnShow call above
    local originalOffset = wtScrollBar.offset or 0
    local offset = WT_PAGE_SIZE
    while offset < snapCount do
        wtScrollBar.offset = offset
        local onScroll = wtScrollBar:GetScript("OnVerticalScroll")
        if onScroll then onScroll(wtScrollBar, offset * ROW_HEIGHT) end
        offset = offset + WT_PAGE_SIZE
    end

    -- Restore original offset
    if (wtScrollBar.offset or 0) ~= originalOffset then
        wtScrollBar.offset = originalOffset
        local onScroll = wtScrollBar:GetScript("OnVerticalScroll")
        if onScroll then onScroll(wtScrollBar, originalOffset * ROW_HEIGHT) end
    end
end

function RenderCompanion()
    if not companion then return end
    local offset = FauxScrollFrame_GetOffset(companion.scroll)
    for i, row in ipairs(companion.rows) do
        local spell = snapshot[i + offset]
        row.spell = spell
        if not spell then
            row:Hide()
        elseif spell.isHeader then
            row.spellFrame:Hide()
            row.header:Show()
            row.header:SetText(spell.formattedName or spell.name or "")
            row.hl:SetTexture(nil)
            if row.headerCount and spell.spells then
                row.headerCount:SetText(string.format("(%d)", #spell.spells))
                row.headerCount:Show()
            elseif row.headerCount then
                row.headerCount:Hide()
            end
            row:SetAlpha(1)
            row:Show()
        else
            row.header:Hide()
            if row.headerCount then row.headerCount:Hide() end
            row.spellFrame:Show()
            row.hl:SetTexture(GetWTHighlight())
            row.spellFrame.label:SetText(spell.name or "")
            row.spellFrame.subLabel:SetText(spell.formattedSubText or "")
            if spell.hideLevel then
                row.spellFrame.level:Hide()
            else
                row.spellFrame.level:Show()
                row.spellFrame.level:SetText(spell.formattedLevel or "")
                if spell.levelColor then
                    local c = spell.levelColor
                    row.spellFrame.level:SetTextColor(c.r, c.g, c.b)
                end
            end
            row.spellFrame.icon:SetTexture(spell.icon)
            if searchFilter and searchFilter ~= "" then
                local name = string.lower(spell.name or "")
                row:SetAlpha(string.find(name, searchFilter, 1, true) and 1 or 0.35)
            else
                row:SetAlpha(1)
            end
            row:Show()
        end
    end
    FauxScrollFrame_Update(companion.scroll, snapCount, MAX_ROWS, ROW_HEIGHT,
                           nil, nil, nil, nil, nil, nil, true)
end

local function BuildCompanionFrame()
    local f = CreateFrame("Frame", "MSBWhatsTrainingCompanion", UIParent)
    f:SetWidth(365)
    f:SetHeight(MAX_ROWS * ROW_HEIGHT + 123.5)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(50)
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    f:Hide()

    local closeBtn = CreateFrame("Button", "MSBWhatsTrainingCloseButton", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 6, 6)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    if MSB_SkinCloseButton then MSB_SkinCloseButton(closeBtn) end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("What's Training?")
    title:SetTextColor(1, 0.82, 0)

    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        if ModernSpellBook_DB then
            local point, _, relPoint, x, y = this:GetPoint()
            ModernSpellBook_DB.wtCompanionPos = { point=point, relPoint=relPoint, x=x, y=y }
        end
    end)

    -- Scroll frame: right edge leaves room for the scrollbar widget inside the border
    local scroll = CreateFrame("ScrollFrame", "MSBWhatsTrainingCompanionScroll",
                               f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",  12, -34)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 12)
    f.scroll = scroll

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function()
        local scrollBar = _G["MSBWhatsTrainingCompanionScrollScrollBar"]
        if not scrollBar then return end
        local current = scrollBar:GetValue()
        if arg1 > 0 then
            scrollBar:SetValue(current - ROW_HEIGHT)
        else
            scrollBar:SetValue(current + ROW_HEIGHT)
        end
    end)

    local tip = CreateFrame("GameTooltip", "MSBWhatsTrainingTip", UIParent, "GameTooltipTemplate")
    local function ShowTip(owner, spell)
        if not spell then return end
        if spell.isHeader then
            if not spell.cost or spell.cost <= 0 then return end
            tip:SetOwner(owner, "ANCHOR_RIGHT")
            tip:ClearLines()
            local coinStr = spell.formattedCost or GetCoinTextureString(spell.cost)
            if GetMoney() < spell.cost then
                coinStr = RED_FONT_COLOR_CODE .. coinStr .. FONT_COLOR_CODE_CLOSE
            end
            tip:AddLine(HIGHLIGHT_FONT_COLOR_CODE ..
                string.format(spell.costFormat or "Total Cost: %s", coinStr) ..
                FONT_COLOR_CODE_CLOSE)
            tip:Show()
            return
        end
        tip:SetOwner(owner, "ANCHOR_RIGHT")
        tip:ClearLines()
        if spell.id then tip:SetSpellByID(spell.id) end
        if spell.cost and spell.cost > 0 then
            local coinStr = spell.formattedCost or GetCoinTextureString(spell.cost)
            if GetMoney() < spell.cost then
                coinStr = RED_FONT_COLOR_CODE .. coinStr .. FONT_COLOR_CODE_CLOSE
            end
            tip:AddLine(HIGHLIGHT_FONT_COLOR_CODE ..
                string.format(spell.costFormat or "Cost: %s", coinStr) ..
                FONT_COLOR_CODE_CLOSE)
        end
        if spell.tooltip and spell.tooltip ~= "" then
            tip:AddLine(spell.tooltip, 1, 0.82, 0, true)
        end
        tip:Show()
    end

    local rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        row.hl = hl

        local header = row:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        header:SetAllPoints()
        header:SetJustifyV("MIDDLE")
        header:SetJustifyH("CENTER")
        row.header = header

        local headerCount = row:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        headerCount:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        headerCount:SetJustifyH("RIGHT")
        headerCount:SetJustifyV("MIDDLE")
        headerCount:SetTextColor(0.53, 0.53, 0.53)
        headerCount:Hide()
        row.headerCount = headerCount


        local sf = CreateFrame("Frame", nil, row)
        sf:SetPoint("LEFT",   row, "LEFT")
        sf:SetPoint("TOP",    row, "TOP")
        sf:SetPoint("BOTTOM", row, "BOTTOM")

        local icon = sf:CreateTexture(nil, "OVERLAY")
        icon:SetPoint("TOPLEFT",    sf)
        icon:SetPoint("BOTTOMLEFT", sf)
        icon:SetWidth(ROW_HEIGHT)

        local label = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", sf, "TOPLEFT", ROW_HEIGHT + 4, 0)
        label:SetPoint("BOTTOM",  sf)
        label:SetJustifyV("MIDDLE")
        label:SetJustifyH("LEFT")

        local levelLabel = sf:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        levelLabel:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -4, 0)
        levelLabel:SetPoint("BOTTOM",   sf)
        levelLabel:SetJustifyH("RIGHT")
        levelLabel:SetJustifyV("MIDDLE")

        local subLabel = sf:CreateFontString(nil, "OVERLAY", "SpellFont_Small")
        subLabel:SetTextColor(1, 1, 153/255)
        subLabel:SetJustifyH("LEFT")
        subLabel:SetJustifyV("MIDDLE")
        subLabel:SetPoint("TOPLEFT", label,      "TOPRIGHT", 2, 0)
        subLabel:SetPoint("BOTTOM",  label)
        subLabel:SetPoint("RIGHT",   levelLabel, "LEFT")

        sf.icon     = icon
        sf.label    = label
        sf.subLabel = subLabel
        sf.level    = levelLabel
        row.spellFrame = sf

        if i == 1 then
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -36)
        else
            row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2)
        end
        row:SetPoint("RIGHT", scroll)

        row:SetScript("OnEnter", function(self) ShowTip(self, self.spell) end)
        row:SetScript("OnLeave", function() tip:Hide() end)

        rows[i] = row
    end
    f.rows = rows

    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT,
            function() RenderCompanion() end)
    end)

    return f
end

function MSB_SetupWhatsTrainingIntegration(spellBookObj)
    if spellBookObj.frame.wtIntegrated then return end
    if not IsWTLoaded() then return end
    spellBookObj.frame.wtIntegrated = true

    companion = BuildCompanionFrame()
    HookFauxScrollUpdate()

    local function PositionCompanion()
        companion:ClearAllPoints()
        if ModernSpellBook_DB and ModernSpellBook_DB.wtCompanionPos then
            local p = ModernSpellBook_DB.wtCompanionPos
            companion:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
        else
            companion:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPRIGHT", 6, 0)
        end
    end

    local tabNumber = table.getn(spellBookObj.frame.Tabgroups) + 1
    local tab = CTab(spellBookObj.frame, "Training", tabNumber, function(clickedTab)
        if companion:IsShown() then
            companion:Hide()
        else
            PositionCompanion()
            companion:Show()
            BuildSnapshot()
            RenderCompanion()
        end
    end)

    table.insert(spellBookObj.frame.Tabgroups, tab)
    spellBookObj.frame.wtTab = tab

    spellBookObj.frame:HookScript("OnHide", function()
        companion:Hide()
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:SetScript("OnEvent", function()
        wipe(snapshot)
        snapCount = 0
        if companion:IsShown() then
            BuildSnapshot()
            RenderCompanion()
        end
    end)

    spellBookObj.frame.searchBar.frame:HookScript("OnTextChanged", function()
        local text = spellBookObj.frame.searchBar:GetText() or ""
        text = string.lower(text:match("^%s*(.-)%s*$"))
        searchFilter = (text ~= "") and text or nil
        if companion and companion:IsShown() then
            RenderCompanion()
        end
    end)

    spellBookObj:PositionAllTabs()
end

-- The Blizzard ShowAllSpellRanksCheckBox leaks onto screen after MSB unparents it,
-- because WTE calls Show() on it at login. Hook OnShow to immediately hide it.
do
    local cb = _G["ShowAllSpellRanksCheckBox"]
    if cb then
        cb:HookScript("OnShow", function(self) self:Hide() end)
    end
end