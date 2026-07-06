--[[
	Spell list entry: CSpellIcon + name/rank text + trail background.
--]]

local ICON_SIZE = 28
local SPELL_HORIZONTAL_SPACING = 150
local VERTICAL_SPACING = 50
local SECOND_PAGE_OFFSET = 510
local HORIZONTAL_OFFSET = 40
local SPELL_INSET = 20

class "CSpellItem"
{
	__init = function(self, parent, index)
		-- Button frame (the interactive root).
		self.frame = CreateFrame("Button", "ModernSpellBookSpell"..index, parent, "SecureActionButtonTemplate")
		self.frame:SetWidth(ICON_SIZE)
		self.frame:SetHeight(ICON_SIZE)
		self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		self.frame:SetMovable(true)
		self.frame:RegisterForDrag("LeftButton")

		-- Spell icon (all icon-area visuals)
		self.spellIcon = CSpellBookIcon(self.frame)

		-- OnLeave: hide tooltip and hover glow
		local spellIcon = self.spellIcon
		self.frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
			spellIcon.hover_glow:Hide()
		end)

		-- Text container (positioned to the right of the icon)
		self.textGroup = CreateFrame("Frame", nil, self.frame)
		self.textGroup:SetWidth(98)
		self.textGroup:SetHeight(ICON_SIZE)
		self.textGroup:SetPoint("LEFT", self.frame, "LEFT", 36, 0)

		-- Spell name
		self.nameText = self.textGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.nameText:SetPoint("TOPLEFT", self.textGroup, "TOPLEFT", 0, 0)
		if (self.nameText.SetWordWrap) then self.nameText:SetWordWrap(true) end
		self.nameText:SetWidth(98)
		self.nameText:SetJustifyH("LEFT")
		self.nameText:SetFont(MSB_GetFont(), ModernSpellBook_DB and ModernSpellBook_DB.fontSize or 11.5)
		if (self.nameText.SetJustifyV) then self.nameText:SetJustifyV("TOP") end

		-- Trail background behind text
		self.trailBg = self.frame:CreateTexture(nil, "ARTWORK")
		self.trailBg:SetWidth(170)
		self.trailBg:SetHeight(40)
		self.trailBg:SetPoint("LEFT", self.frame, "CENTER", 0, 0)
		self.trailBg:SetTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spellbook-trail")
		self.trailBg:SetAlpha(1)

		-- Rank / subtitle text
		self.rankText = self.textGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.rankText:SetPoint("TOPLEFT", self.nameText, "BOTTOMLEFT", 0, -1)
		self.rankText:SetFont(MSB_GetFont(), 9.5)
		self.rankText:SetJustifyH("LEFT")
		if (self.rankText.SetWordWrap) then self.rankText:SetWordWrap(true) end
		self.rankText:SetWidth(80)
		self.rankText:SetHeight(10)

		-- Apply initial text style
		TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")

		self.spellID = nil
		self.bookType = nil
	end;

	-- ====================== DELEGATION ===========================

	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	SetStance = function(self, isActive)
		self.spellIcon:SetStance(isActive)
	end;

	-- ==================== CONFIGURATION ==========================

	SetClickHandler = function(self, spellInfo)
		local frame = self.frame
		local iconTex = self.spellIcon.icon

		if (not spellInfo.isUnlearned and not spellInfo.isPassive and spellInfo.castName) then
			frame:SetAttribute("type1", "spell")
			frame:SetAttribute("spell1", spellInfo.castName)
		else
			frame:SetAttribute("type1", nil)
			frame:SetAttribute("spell1", nil)
		end

		frame:SetAttribute("shift-type1", "macro")
		frame:SetAttribute("shift-macrotext1", "")

		frame:SetAttribute("type2", nil)

		frame:SetScript("PreClick", function(_, button)
			if (Clique and CliqueFrame and CliqueFrame:IsVisible()) then
				if (spellInfo.isPassive) then
					if (StaticPopup_Show) then StaticPopup_Show("CLIQUE_PASSIVE_SKILL") end
					return
				end

				local clickButton = button
				if (Clique.editSet == Clique.clicksets[Clique.Locals.CLICKSET_HARMFUL]) then
					clickButton = string.format("%s%d", "harmbutton", Clique:GetButtonNumber(button))
				elseif (Clique.editSet == Clique.clicksets[Clique.Locals.CLICKSET_HELPFUL]) then
					clickButton = string.format("%s%d", "helpbutton", Clique:GetButtonNumber(button))
				else
					clickButton = Clique:GetButtonNumber(button)
				end

				local rank = spellInfo.spellRank
				if (not GetCVarBool("ShowAllSpellRanks")) then
					rank = nil
				end

				local bindingEntry = {
					["button"] = clickButton,
					["modifier"] = Clique:GetModifierText(),
					["texture"] = spellInfo.spellIcon,
					["type"] = "spell",
					["arg1"] = spellInfo.spellName,
					["arg2"] = rank,
				}

				local key = bindingEntry.modifier .. bindingEntry.button
				if (Clique:CheckBinding(key)) then
					if (StaticPopup_Show) then StaticPopup_Show("CLIQUE_BINDING_PROBLEM") end
					return
				end

				Clique.editSet[key] = bindingEntry
				Clique:ListScrollUpdate()
				Clique:UpdateClicks()
				if (not InCombatLockdown()) then
					Clique:PLAYER_REGEN_ENABLED()
				end
				return
			end

			if (IsShiftKeyDown()) then
				-- Macro edit box: insert plain spell name for /cast
				if (not spellInfo.isPassive and MacroFrameText and MacroFrameText:IsVisible()) then
					local macroText
					if (spellInfo.spellRank and spellInfo.spellRank ~= "") then
						macroText = spellInfo.spellName .. "(" .. spellInfo.spellRank .. ")"
					else
						macroText = spellInfo.spellName
					end
					MacroFrameText:Insert(macroText)
				elseif (ChatEdit_InsertLink) then
					-- ChatEdit_InsertLink (not a specific
					-- ChatFrameNEditBox) is the correct, standard way to do
					-- this - it inserts into whichever chat edit box
					-- currently has focus, and opens one if none does,
					-- exactly like Blizzard's own SpellButton_OnModifiedClick
					-- does.
					local link
					if (spellInfo.isTalent and spellInfo.talentGrid) then
						link = MSB_GetTalentLink(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
					elseif (spellInfo.spellID) then
						link = GetSpellLink(spellInfo.spellID, spellInfo.bookType)
					end
					if (link) then
						ChatEdit_InsertLink(link)
					end
				end
				return
			end

			if (spellInfo.isUnlearned) then return end
			if (spellInfo.isPassive) then return end
			if (spellInfo.isPetSpell) then
				if (spellInfo.castName) then
					C_Timer.After(0.2, function()
						local name, texture = GetPetActionInfo(spellInfo.castName)
						if (texture) then
							iconTex:SetTexture(texture)
						end
					end)
				else
					UIErrorsFrame:AddMessage("ModernSpellBook: Warning - Pet spell ".. spellInfo.spellName.. " cannot be cast outside the pet action bar. Please drag the spell there.", 1.0, 0.1, 0.1, 1.0)
					PlaySound("igQuestFailed")
				end
			end
		end)
	end;

	SetTextContent = function(self, spellInfo)
		self.nameText:SetFont(MSB_GetFont(), ModernSpellBook_DB and ModernSpellBook_DB.fontSize or 11.5)
		self.spellIcon.icon:SetTexture(spellInfo.spellIcon)
		self.nameText:SetText(spellInfo.spellName)
		if (spellInfo.isUnlearned and spellInfo.levelReq and spellInfo.levelReq > 0) then
			local rankText = spellInfo.spellRank or ""
			if (rankText ~= "") then
				self.rankText:SetText(rankText .. " (Lvl " .. spellInfo.levelReq .. ")")
			else
				self.rankText:SetText("Lvl " .. spellInfo.levelReq)
			end
		else
			self.rankText:SetText(spellInfo.spellRank)
		end
		self.spellID = spellInfo.spellID
		self.bookType = spellInfo.bookType
	end;

	SetTextPosition = function(self, spellInfo)
		local nameHeight = 13
		if (self.nameText.GetStringHeight) then
			nameHeight = self.nameText:GetStringHeight()
		elseif (self.nameText.GetHeight) then
			nameHeight = self.nameText:GetHeight()
		end
		local subHeight = 0
		local hasSubText = (spellInfo.spellRank and spellInfo.spellRank ~= "")
			or (spellInfo.isUnlearned and spellInfo.levelReq and spellInfo.levelReq > 0)
		if (hasSubText) then
			subHeight = 11
		end
		local totalHeight = nameHeight + subHeight
		local yOffset = (ICON_SIZE - totalHeight) / 2
		self.textGroup:ClearAllPoints()
		self.textGroup:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 36, -yOffset)
	end;

	SetChatLinkHandler = function(self, spellInfo)
	end;

	SetTooltipHandler = function(self, spellInfo, spellKey, isNew)
		local spellIcon = self.spellIcon
		local frame = self.frame
		frame:SetScript("OnEnter", function()
			spellIcon.hover_glow:Show()

			-- Dismiss available-to-learn highlight on hover
			spellIcon:DismissAvailableHighlight(spellInfo)

			-- Dismiss new-spell highlight on hover (and all lower ranks)
			if (isNew) then
				local entry = ModernSpellBook_DB.spells[spellKey]
				if (entry) then entry.seen_new = true end
				-- Mark all lower ranks as seen too
				local hadOtherRanks = false
				for key, other in pairs(ModernSpellBook_DB.spells) do
					if (other.learned and not other.seen_new) then
						local pipePos = string.find(key, "|", 1, true)
						if (pipePos) then
							local name = string.sub(key, 1, pipePos - 1)
							if (name == spellInfo.spellName) then
								other.seen_new = true
								hadOtherRanks = true
							end
						end
					end
				end
				isNew = false
				-- Refresh visible items so lower rank glows dismiss immediately
				if (hadOtherRanks) then
					SpellBook:RefreshPageElements()
				end
			end
			spellIcon:DismissNewHighlight()

			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
			if (spellInfo.isUnlearned) then
				local shownFullTooltip = false
				if (spellInfo.isTalent and spellInfo.talentGrid and GameTooltip.SetTalent) then
					pcall(function()
						GameTooltip:SetTalent(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
						shownFullTooltip = true
					end)
					if (shownFullTooltip) then
						MSB_StripLearnPromptFromTooltip()
					end
				end
				if (not shownFullTooltip) then
					local rankText = spellInfo.spellRank or ""
					if (rankText ~= "") then
						GameTooltip:SetText(spellInfo.spellName .. " - " .. rankText, 1, 1, 1)
					else
						GameTooltip:SetText(spellInfo.spellName, 1, 1, 1)
					end
					if (spellInfo.description) then
						GameTooltip:AddLine(spellInfo.description, 1, 0.82, 0, true)
					end
				end
				if (spellInfo.levelReq and spellInfo.levelReq > 0) then
					local playerLevel = UnitLevel("player") or 0
					if (playerLevel >= spellInfo.levelReq) then
						GameTooltip:AddLine("Requires Level " .. spellInfo.levelReq, 0.2, 1, 0.2)
					else
						GameTooltip:AddLine("Requires Level " .. spellInfo.levelReq, 1, 0.2, 0.2)
					end
				end
				if (spellInfo.isTalent) then
					GameTooltip:AddLine("Requires talent point.", 1, 0.82, 0)
				else
					GameTooltip:AddLine("Visit a class trainer to learn.", 1, 0.82, 0)
				end
			elseif (not spellInfo.isTalent) then
				if (spellInfo.bookType) then
					GameTooltip:SetSpell(spellInfo.spellID, spellInfo.bookType)
				else
					MSB_SetTooltipSpell(spellInfo.spellID)
				end
			else
				if (GameTooltip.SetTalent) then
					GameTooltip:SetTalent(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
					MSB_StripLearnPromptFromTooltip()
				else
					local talentLink = MSB_GetTalentLink(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
					if (talentLink) then
						GameTooltip:SetHyperlink(talentLink)
					else
						GameTooltip:SetText(spellInfo.spellName)
					end
				end
			end
			GameTooltip:Show()
		end)
	end;

	SetCooldownAndDrag = function(self, spellInfo)
		local frame = self.frame
		local cooldown = self.spellIcon.cooldown

		if (cooldown) then
			cooldown.mark = 1
		end
		if (not spellInfo.isPassive and not spellInfo.isUnlearned) then
			frame:SetMovable(true)
			frame:SetScript("OnDragStart", function()
				if (spellInfo.isPetSpell) then
					PickupSpell(spellInfo.spellID, BOOKTYPE_PET)
				else
					PickupSpell(spellInfo.spellID, BOOKTYPE_SPELL)
				end
			end)
			frame:SetScript("OnUpdate", function()
				if (not frame:IsVisible()) then return end
				-- Query by spell name to avoid CTD from stale slot indices
				local ok, start, duration, enable = pcall(GetSpellCooldown, spellInfo.castName or spellInfo.spellName)
				if (ok and start and cooldown) then
					local cdFunc = CooldownFrame_SetTimer or CooldownFrame_Set
					if (cdFunc) then cdFunc(cooldown, start, duration, enable) end
				end
			end)
		else
			if (cooldown) then cooldown:Hide() end
			frame:SetMovable(false)
			frame:SetScript("OnUpdate", nil)
			frame:SetScript("OnDragStart", nil)
		end
	end;

	-- =================== LEARNED STATE ===========================

	SetLearnedState = function(self, spellInfo)
		-- Delegate icon-level visual changes
		self.spellIcon:SetLearnedState(spellInfo)
		-- Handle text-level styling and frame interactivity
		if (spellInfo.isUnlearned) then
			TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "unlearned")
			self.frame:SetMovable(false)
			self.frame:SetScript("OnDragStart", nil)
			self.frame:SetScript("OnUpdate", nil)
		else
			TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")
		end
	end;

	-- =================== MAIN ENTRY POINT ========================

	Set = function(self, spellInfo, currentPageRows, page, grid_x)
		self:SetClickHandler(spellInfo)
		self:SetTextContent(spellInfo)

		-- Stance detection
		local stanceState = false
		if (spellInfo.stanceIndex ~= nil) then
			local _, _, isActive = GetShapeshiftFormInfo(spellInfo.stanceIndex)
			stanceState = isActive
			ModernSpellBookFrame.stanceButtons[spellInfo.spellName] = self
		end
		self.spellIcon:SetStance(stanceState)

		self:SetTextPosition(spellInfo)

		-- New spell detection
		local spellKey = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
		local entry = ModernSpellBook_DB.spells[spellKey]
		local isNew = entry and entry.learned and not entry.seen_new

		self.spellIcon:SetHighlights(spellInfo, isNew)

		-- Position on page
		self.frame:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPLEFT",
			HORIZONTAL_OFFSET + SPELL_INSET + SECOND_PAGE_OFFSET*(page-1) + grid_x*SPELL_HORIZONTAL_SPACING,
			-80 + currentPageRows * -VERTICAL_SPACING)

		self:SetChatLinkHandler(spellInfo)
		self:SetTooltipHandler(spellInfo, spellKey, isNew)
		self:SetCooldownAndDrag(spellInfo)

		self.frame:Show()

		self.spellIcon:SetSpell(spellInfo)
		self:SetLearnedState(spellInfo)
	end;
}
