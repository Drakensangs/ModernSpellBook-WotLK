--[[
	ElvUI compatibility
--]]

function MSB_GetFont()
	if ElvUI then
		local ok, E = pcall(function() return unpack(ElvUI) end)
		if ok and E and E.media and E.media.normFont then
			return E.media.normFont
		end
	end
	return "Fonts\\FRIZQT__.TTF"
end

local function GetElvUI()
	if not ElvUI then return nil, nil end
	local ok, E = pcall(function() return unpack(ElvUI) end)
	if not ok or not E then return nil, nil end
	local S = E:GetModule("Skins", true)
	return E, S
end

local function FixCloseButton()
	local msb = _G.ModernSpellBookFrame
	if not msb or not msb.CloseButton then return end
	local btn = _G.SpellBookFrameCloseButton or _G.SpellBookCloseButton
	if not btn then return end
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", msb.CloseButton, "CENTER", 0, 0)
end

local function SkinCheckBox(frame, S)
	if not frame or frame.isSkinned then return end
	if not S or not S.HandleCheckBox then return end
	S:HandleCheckBox(frame)
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

	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_LOGIN")
	loginFrame:SetScript("OnEvent", function()
		loginFrame:UnregisterAllEvents()

		FixCloseButton()

		local font = MSB_GetFont()
		if font and font ~= "Fonts\\FRIZQT__.TTF" then
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
				if msb.ShowPassiveSpellsCheckBox and msb.ShowPassiveSpellsCheckBox.text then
					ApplyFont(msb.ShowPassiveSpellsCheckBox.text, 10)
				end
			end
		end

		SkinCheckBox(_G.ShowPassiveSpellsCheckBox, S)
		ApplyDropDownCompat(E, S)
	end)

	if _G.SpellBookFrame then
		_G.SpellBookFrame:HookScript("OnShow", function()
			FixCloseButton()
			SkinCheckBox(_G.ShowAllSpellRanksCheckbox, S)
		end)
	end
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function()
	if arg1 ~= "ModernSpellBook" then return end
	bootFrame:UnregisterAllEvents()
	ApplyElvUICompat()
end)
