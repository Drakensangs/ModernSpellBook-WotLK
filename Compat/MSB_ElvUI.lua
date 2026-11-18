-- ElvUI support: uses ElvUI's font and skins the close button and
-- dropdown menus so they match. Does nothing without ElvUI.

-- English clients' font, in case STANDARD_TEXT_FONT is missing
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

function MSB_GetFont()
	if ElvUI then
		local ok, E = pcall(function() return unpack(ElvUI) end)
		if ok and E and E.media and E.media.normFont then
			return E.media.normFont
		end
	end
	-- The client's own font: FRIZQT__ has no Cyrillic, Korean or Chinese
	-- letters, and those clients point STANDARD_TEXT_FONT at one that does
	return STANDARD_TEXT_FONT or DEFAULT_FONT
end

local function GetElvUI()
	if not ElvUI then return nil, nil end
	local ok, E = pcall(function() return unpack(ElvUI) end)
	if not ok or not E then return nil, nil end
	local S = E:GetModule("Skins", true)
	return E, S
end

function MSB_SkinCloseButton(btn)
	local _, S = GetElvUI()
	if not S or not S.HandleCloseButton then return end
	S:HandleCloseButton(btn)
end

local function ApplyDropDownCompat(E, S)
	if S.SkinDropDownMenu then return end

	local r, g, b    = unpack(E.media.rgbvaluecolor)
	local arrowTex   = E.Media.Textures.ArrowUp
	local arrowAngle = S.ArrowRotation and S.ArrowRotation["right"] or -1.57

	local function SkinDropDownButtons()
		for i = 1, (_G.UIDROPDOWNMENU_MAXLEVELS or 2) do
			for j = 1, (_G.UIDROPDOWNMENU_MAXBUTTONS or 32) do
				local prefix = "DropDownList"..i.."Button"..j
				local button = _G[prefix]
				if not button then break end

				local arrow = _G[prefix.."ExpandArrow"]
				if arrow and not arrow.msbSkinned then
					local norm = arrow:GetNormalTexture()
					if norm then
						norm:SetTexture(arrowTex)
						norm:SetVertexColor(r, g, b)
						norm:SetRotation(arrowAngle)
					end
					local pushed = arrow:GetPushedTexture()
					if pushed then
						pushed:SetTexture(arrowTex)
						pushed:SetVertexColor(r, g, b)
						pushed:SetRotation(arrowAngle)
					end
					arrow.msbSkinned = true
				end

				local check = _G[prefix.."Check"]
				if check and not button.check and not button.msbCheckSkinned then
					check:SetWidth(12)
					check:SetHeight(12)
					check:SetPoint("LEFT", button, "LEFT", 1, 0)
					check:CreateBackdrop()
					check:SetTexture(E.media.normTex)
					check:SetVertexColor(1, 0.82, 0, 0.8)
					button.msbCheckSkinned = true

					button:HookScript("OnShow", function(self)
						if check.backdrop then
							if self.notCheckable then
								check.backdrop:Hide()
							else
								check.backdrop:Show()
							end
						end
					end)
				end
			end
		end
	end

	hooksecurefunc("UIDropDownMenu_InitializeHelper", SkinDropDownButtons)

	SkinDropDownButtons()
end

local function ApplyElvUICompat()
	local E, S = GetElvUI()
	if not E then return end

	local function SkinWindow()
		local closeButton = _G.ModernSpellBookFrameCloseButton
		if closeButton then MSB_SkinCloseButton(closeButton) end

		local font = MSB_GetFont()
		if font and font ~= (STANDARD_TEXT_FONT or DEFAULT_FONT) then
			local msb = _G.ModernSpellBookFrame
			if msb then
				local function ApplyFont(fs, size)
					if not fs then return end
					local _, existingSize, flags = fs:GetFont()
					fs:SetFont(font, size or existingSize or 11, flags or "")
				end
				ApplyFont(msb.trainerHint,   10)
				ApplyFont(msb.spellCounter,  10)
				ApplyFont(msb.upcomingLabel, 10)
				ApplyFont(msb.noresultsText)
				ApplyFont(msb.pageText)
			end
		end
	end

	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_LOGIN")
	loginFrame:SetScript("OnEvent", function()
		loginFrame:UnregisterAllEvents()
		-- After a /reload in combat the window is built when combat ends
		if (MSB_SpellBook.isSetUp) then
			SkinWindow()
		else
			MSB_SpellBook:AfterSetup(SkinWindow)
		end
		ApplyDropDownCompat(E, S)
	end)
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function()
	if arg1 ~= "ModernSpellBook" then return end
	bootFrame:UnregisterAllEvents()
	ApplyElvUICompat()
end)
