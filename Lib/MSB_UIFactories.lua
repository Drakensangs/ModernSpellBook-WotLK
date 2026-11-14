-- Shared UI pieces: glows and "NEW"-style badges (both returned hidden,
-- frameLevel relative to the parent), the common pulse animation and the
-- training cost tooltip line.

function MSB_CreateGlow(parent, size, color, frameLevel, texture)
    local glowFrame = CreateFrame("Frame", nil, parent)
    glowFrame:SetWidth(size)
    glowFrame:SetHeight(size)
    glowFrame:SetFrameLevel(parent:GetFrameLevel() + (frameLevel or 5))
    glowFrame:Hide()

    local glowTex = glowFrame:CreateTexture(nil, "OVERLAY")
    glowTex:SetAllPoints(glowFrame)
    glowTex:SetTexture(texture or "Interface\\Buttons\\CheckButtonGlow")
    glowTex:SetBlendMode("ADD")
    if color then
        glowTex:SetVertexColor(color[1], color[2], color[3])
    end
    glowTex:SetAlpha(1)

    return glowFrame, glowTex
end

function MSB_CreateBadge(parent, text, bgColor, borderColor, frameLevel)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetWidth(32)
    badge:SetHeight(14)
    badge:SetFrameLevel(parent:GetFrameLevel() + (frameLevel or 7))
    badge:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    badge:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    badge:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    badge:Hide()

    local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badgeText:SetPoint("CENTER", badge, "CENTER", 0, 1)
    badgeText:SetText(text)
    badgeText:SetFont(MSB_GetFont(), 8)
    badgeText:SetTextColor(1, 1, 1)

    return badge, badgeText
end

-- ==================== PULSE DRIVER ====================
-- One OnUpdate drives every pulsing texture, so all glows breathe in step.
-- Textures register while shown and drop out on their own when hidden.
-- Curve from DragonUI's "not on action bars" glow: 1 s period, alpha 1 -> 0.5 -> 1.

local pulseTextures = {}
local pulseClock = 0
local pulseDriver = CreateFrame("Frame")
pulseDriver:Hide()
pulseDriver:SetScript("OnUpdate", function(self, elapsed)
    elapsed = elapsed or arg1 or 0
    pulseClock = math.fmod(pulseClock + elapsed, 1)
    local u
    if (pulseClock < 0.5) then u = 1 - pulseClock / 0.5 else u = (pulseClock - 0.5) / 0.5 end
    local alpha = 1 - 0.5 * u * u
    local any = false
    for tex in pairs(pulseTextures) do
        if (tex:IsVisible()) then
            tex:SetAlpha(alpha)
            any = true
        elseif (not tex:GetParent():IsShown()) then
            pulseTextures[tex] = nil
        end
    end
    -- Nothing on screen (book closed): sleep until a glow is shown again
    if (not any) then self:Hide() end
end)

function MSB_StartPulse(texture)
    pulseTextures[texture] = true
    pulseDriver:Show()
end

function MSB_StopPulse(texture)
    pulseTextures[texture] = nil
    texture:SetAlpha(1)
end

-- ==================== TRAINING COST ====================
-- "Training cost: 1g 20s" line for tooltips; red when you can't afford it.
-- The cost is the one the trainer showed when it was last visited
-- (reputation discounts included at that time).

local function FormatMoney(copper)
    if (GetCoinTextureString) then
        return GetCoinTextureString(copper)
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.fmod(copper, 10000) / 100)
    local cop = math.fmod(copper, 100)
    local text = ""
    if (gold > 0) then text = gold .. "g " end
    if (gold > 0 or silver > 0) then text = text .. silver .. "s " end
    return text .. cop .. "c"
end

function MSB_AddTrainingCostLine(tooltip, cost)
    if (not cost) then return end
    if (cost <= 0) then
        tooltip:AddDoubleLine("Training cost:", "Free", 1, 0.82, 0, 1, 1, 1)
        return
    end
    local r, g, b = 1, 1, 1
    if (GetMoney and GetMoney() < cost) then r, g, b = 1, 0.2, 0.2 end
    tooltip:AddDoubleLine("Training cost:", FormatMoney(cost), 1, 0.82, 0, r, g, b)
end
