--[[
	Spell entry on the page: icon, name/rank text and the trail behind it.
	The button is secure: MSB_SecureBook places it and sets what a click
	casts and what a drag picks up, also in combat. This class draws it and
	handles tooltips, shift-click links and Clique binding.
--]]

local ICON_SIZE = 28
local SPELL_HORIZONTAL_SPACING = 150
local VERTICAL_SPACING = 50
local SECOND_PAGE_OFFSET = 510
local HORIZONTAL_OFFSET = 40
local SPELL_INSET = 20
local RANK_ARROW_TEXTURE = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\rank-arrow"
local RANK_ARROW_SIZE = 16
local RANK_ARROW_HIT_WIDTH = 20
local RANK_ARROW_HIT_HEIGHT = 12

-- Top-left corner of a spell on the page, from the window's top-left corner
function MSB_SpellItemPosition(page, row, gridX)
	return HORIZONTAL_OFFSET + SPELL_INSET + SECOND_PAGE_OFFSET * (page - 1) + gridX * SPELL_HORIZONTAL_SPACING,
		MSB_LAYOUT.contentTop + row * -VERTICAL_SPACING
end

-- Clique's binding panel is open: clicks bind spells instead of casting them
local function IsCliqueBinding()
	return Clique and CliqueFrame and CliqueFrame:IsVisible()
end

MSB_class "MSB_CSpellItem"
{
	__init = function(self, parent, index)
		-- Button frame (the interactive root).
		self.frame = CreateFrame("Button", "ModernSpellBookSpell"..index, parent,
			"SecureActionButtonTemplate,SecureHandlerDragTemplate")
		self.frame:SetWidth(ICON_SIZE)
		self.frame:SetHeight(ICON_SIZE)
		self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		self.frame:RegisterForDrag("LeftButton")
		self.frame:Hide()

		self.spellIcon = MSB_CSpellBookIcon(self.frame)
		self:InstallScripts()

		-- Text to the right of the icon
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

		-- Soft shadow behind the text. It starts under the icon's right edge
		-- (not its center), so it never shows through faded unlearned icons.
		self.trailBg = self.frame:CreateTexture(nil, "BACKGROUND")
		self.trailBg:SetWidth(162)
		self.trailBg:SetHeight(44)
		self.trailBg:SetPoint("LEFT", self.frame, "CENTER", 8, 0)
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
		MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")

		-- Arrow under the icon that opens the rank flyout
		self:CreateRankArrow()

		self.spellID = nil
		self.bookType = nil
	end;

	-- ====================== RANK ARROW ===========================

	CreateRankArrow = function(self)
		local item = self
		local arrow = CreateFrame("Button", nil, self.frame)
		arrow:SetWidth(RANK_ARROW_HIT_WIDTH)
		arrow:SetHeight(RANK_ARROW_HIT_HEIGHT)
		arrow:SetPoint("CENTER", self.spellIcon.icon, "BOTTOM", 0, -2)
		-- Above the icon border, hover, stance and new/train glows
		arrow:SetFrameLevel(self.frame:GetFrameLevel() + 16)
		arrow:RegisterForClicks("LeftButtonUp")

		arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
		arrow.tex:SetWidth(RANK_ARROW_SIZE)
		arrow.tex:SetHeight(RANK_ARROW_SIZE)
		arrow.tex:SetPoint("CENTER", arrow, "CENTER", 0, 0)
		arrow.tex:SetTexture(RANK_ARROW_TEXTURE)

		arrow.highlight = arrow:CreateTexture(nil, "HIGHLIGHT")
		arrow.highlight:SetAllPoints(arrow.tex)
		arrow.highlight:SetTexture(RANK_ARROW_TEXTURE)
		arrow.highlight:SetBlendMode("ADD")
		arrow.highlight:SetAlpha(0.6)

		arrow:SetScript("OnClick", function()
			if (MSB_SecureBook.RefuseInCombat()) then return end
			PlaySound(MSB_SOUND.IG_MAINMENU_OPTION_CHECKBOX_ON)
			if (ModernSpellBookFrame.rankFlyout) then
				ModernSpellBookFrame.rankFlyout:Toggle(item)
			end
			-- Refresh the "Show / Hide ranks" tooltip text
			if (GameTooltip:IsOwned(arrow)) then
				local onEnter = arrow:GetScript("OnEnter")
				if (onEnter) then onEnter() end
			end
		end)
		arrow:SetScript("OnEnter", function()
			GameTooltip:SetOwner(arrow, "ANCHOR_RIGHT")
			if (ModernSpellBookFrame.rankFlyout and ModernSpellBookFrame.rankFlyout:IsOpenFor(item)) then
				GameTooltip:SetText("Hide ranks", 1, 1, 1)
			else
				GameTooltip:SetText("Show all ranks", 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		arrow:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		arrow:Hide()
		self.rankArrow = arrow
	end;

	-- Arrow points down when collapsed, up while the flyout is open
	SetRankArrowExpanded = function(self, isExpanded)
		if (isExpanded) then
			self.rankArrow.tex:SetTexCoord(0, 1, 1, 0)
			self.rankArrow.highlight:SetTexCoord(0, 1, 1, 0)
		else
			self.rankArrow.tex:SetTexCoord(0, 1, 0, 1)
			self.rankArrow.highlight:SetTexCoord(0, 1, 0, 1)
		end
	end;

	UpdateRankArrow = function(self, spellInfo)
		self.spellInfo = spellInfo
		self:SetRankArrowExpanded(false)
		if (not spellInfo.isUnlearned and spellInfo.learnedRanks and table.getn(spellInfo.learnedRanks) > 1) then
			self.rankArrow:Show()
		else
			self.rankArrow:Hide()
		end
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

	-- Scripts are set once; they read the spell the button shows right now
	InstallScripts = function(self)
		local item = self
		self.frame:SetScript("OnEnter", function() item:OnEnter() end)
		self.frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
			item.spellIcon.hover_glow:Hide()
		end)
		self.frame:SetScript("PreClick", function(_, button) item:OnPreClick(button) end)
	end;

	-- Rank flyout buttons only (page buttons get theirs from the secure
	-- layout): left click casts, shift-click runs an empty macro so PreClick
	-- can link the spell instead. While Clique's panel is open no click casts
	-- anything; PreClick adds the binding.
	ApplyCastAttributes = function(self)
		local spellInfo = self.clickSpellInfo
		if (not spellInfo or InCombatLockdown()) then return end
		local frame = self.frame
		local binding = IsCliqueBinding()

		local spell = nil
		if (not binding and not spellInfo.isUnlearned and not spellInfo.isPassive) then
			if (spellInfo.isPetSpell) then
				spell = spellInfo.spellName
			else
				spell = spellInfo.castName
			end
		end
		frame:SetAttribute("type1", spell and "spell" or nil)
		frame:SetAttribute("spell1", spell)

		frame:SetAttribute("shift-type1", (not binding) and "macro" or nil)
		frame:SetAttribute("shift-macrotext1", "")

		frame:SetAttribute("type2", nil)
	end;

	SetClickHandler = function(self, spellInfo)
		self.clickSpellInfo = spellInfo
	end;

	OnPreClick = function(self, button)
		local spellInfo = self.clickSpellInfo
		if (not spellInfo) then return end
		-- Clicking any spell on the page closes an open rank flyout
		-- (clicks inside the flyout itself keep it open)
		if (not spellInfo.isRankEntry and ModernSpellBookFrame.rankFlyout) then
			ModernSpellBookFrame.rankFlyout:Close()
		end

		if (IsCliqueBinding()) then
			if (spellInfo.isPassive) then
				if (StaticPopup_Show) then StaticPopup_Show("CLIQUE_PASSIVE_SKILL") end
				return
			end

			local clickButton
			if (Clique.editSet == Clique.clicksets[Clique.Locals.CLICKSET_HARMFUL]) then
				clickButton = string.format("%s%d", "harmbutton", Clique:GetButtonNumber(button))
			elseif (Clique.editSet == Clique.clicksets[Clique.Locals.CLICKSET_HELPFUL]) then
				clickButton = string.format("%s%d", "helpbutton", Clique:GetButtonNumber(button))
			else
				clickButton = Clique:GetButtonNumber(button)
			end

			-- A spell on the page binds without a rank, so it follows newly
			-- trained ranks; an entry in the rank flyout binds its exact rank.
			-- (Clique's own check of ShowAllSpellRanks can't be used: the
			-- addon always turns that setting on.)
			local rank = spellInfo.isRankEntry and spellInfo.spellRank or nil

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
			local editBox = GetCurrentKeyBoardFocus()
			if (editBox and editBox ~= MacroFrameText) then
				local link
				if (spellInfo.isTalent and spellInfo.talentGrid) then
					link = MSB_GetTalentLink(spellInfo.talentGrid[1], spellInfo.talentGrid[2])
				elseif (spellInfo.spellID) then
					link = GetSpellLink(spellInfo.spellID, spellInfo.bookType)
				end
				if (link) then
					ChatEdit_InsertLink(link)
				end
			elseif (MacroFrame and MacroFrame:IsShown() and MacroFrameText) then
				if (not spellInfo.isPassive) then
					if (spellInfo.spellRank and spellInfo.spellRank ~= "") then
						MacroFrameText:Insert("/cast " .. spellInfo.spellName .. "(" .. spellInfo.spellRank .. ")")
					else
						MacroFrameText:Insert("/cast " .. spellInfo.spellName)
					end
				end
			end
			return
		end
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

	SetTooltipHandler = function(self, spellInfo, spellKey, isNew)
		self.tipInfo, self.tipKey, self.tipIsNew = spellInfo, spellKey, isNew
	end;

	OnEnter = function(self)
		local spellInfo, spellKey, isNew = self.tipInfo, self.tipKey, self.tipIsNew
		if (not spellInfo) then return end
		local spellIcon = self.spellIcon
		local frame = self.frame
		-- No icon highlight on passives: the round ring stays clean on hover
		if (not spellInfo.isPassive) then
			spellIcon.hover_glow:Show()
		end

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
			self.tipIsNew = false
			-- Refresh visible items so lower rank glows dismiss immediately
			if (hadOtherRanks) then
				MSB_SpellBook:RefreshPageElements()
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
				-- Saved from the trainer's list on the last visit
				MSB_AddTrainingCostLine(GameTooltip, spellInfo.cost)
				GameTooltip:AddLine("Visit a class trainer to learn.", 1, 0.82, 0)
			end
		elseif (not spellInfo.isTalent) then
			GameTooltip:SetSpell(spellInfo.spellID, spellInfo.bookType or BOOKTYPE_SPELL)
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
		if (not spellInfo.isRankEntry and ModernSpellBook_DB.highlightUnplaced
			and MSB_ActionBarHelper:IsSpellUnplaced(spellInfo)) then
			GameTooltip:AddLine("Not on your action bars", 1, 0.45, 0.2)
		end
		GameTooltip:Show()
	end;

	-- Dragging is secure on page buttons (MSB_SecureBook); rank buttons
	-- override this with a plain pickup
	SetCooldownAndDrag = function(self, spellInfo)
		-- Lets the Cooldowns addon put its timer text on this button
		local cooldown = self.spellIcon.cooldown
		if (cooldown) then
			cooldown.mark = 1
		end
		if (not spellInfo.isPassive and not spellInfo.isUnlearned) then
			self.cooldownSpell = spellInfo
		else
			self.cooldownSpell = nil
		end
		self.cdStart, self.cdDuration = nil, nil
		self:UpdateCooldown()
	end;

	-- Cooldown swipe, refreshed by Set and SPELL_UPDATE_COOLDOWN. The timer
	-- is only restarted when the cooldown changed: restarting it also resets
	-- the Cooldowns addon's counter text.
	UpdateCooldown = function(self)
		local cooldown = self.spellIcon.cooldown
		if (not cooldown) then return end
		local spellInfo = self.cooldownSpell
		if (not spellInfo) then
			self.cdStart, self.cdDuration = nil, nil
			cooldown:Hide()
			return
		end
		local ok, start, duration, enable
		if (spellInfo.isPetSpell) then
			ok, start, duration, enable = pcall(GetSpellCooldown, spellInfo.spellID, BOOKTYPE_PET)
		else
			-- By name: a stale spellbook slot index can crash the client
			ok, start, duration, enable = pcall(GetSpellCooldown, spellInfo.castName or spellInfo.spellName)
		end
		local cdFunc = CooldownFrame_SetTimer or CooldownFrame_Set
		if (ok and start and cdFunc) then
			if (start == self.cdStart and duration == self.cdDuration) then return end
			self.cdStart, self.cdDuration = start, duration
			cdFunc(cooldown, start, duration, enable)
		else
			self.cdStart, self.cdDuration = nil, nil
			cooldown:Hide()
		end
	end;

	-- "Not on action bars" glow (settings cog option)
	UpdateUnplacedHighlight = function(self, spellInfo)
		spellInfo = spellInfo or self.spellInfo
		local isUnplaced = ModernSpellBook_DB.highlightUnplaced and MSB_ActionBarHelper:IsSpellUnplaced(spellInfo)
		self.spellIcon:SetUnplaced(isUnplaced and true or false)
	end;

	-- Autocast corners and sparks on pet spells, read from the pet book
	UpdateAutocast = function(self, spellInfo)
		spellInfo = spellInfo or self.spellInfo
		local allowed, enabled = false, false
		if (spellInfo and spellInfo.isPetSpell and not spellInfo.isPassive
			and spellInfo.spellID and GetSpellAutocast) then
			local ok, a, e = pcall(GetSpellAutocast, spellInfo.spellID, BOOKTYPE_PET)
			if (ok) then
				allowed = a and true or false
				enabled = e and true or false
			end
		end
		self.spellIcon:SetAutocast(allowed, enabled)
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;

	-- =================== LEARNED STATE ===========================

	SetLearnedState = function(self, spellInfo)
		self.spellIcon:SetLearnedState(spellInfo)
		if (spellInfo.isUnlearned) then
			MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "unlearned")
		else
			MSB_TextStyle:ApplyToSpell(self.nameText, self.rankText, self.trailBg, "normal")
		end
	end;

	-- =================== MAIN ENTRY POINT ========================

	-- What the button shows. Its position and click actions come from the
	-- secure layout, so this is safe in combat.
	Set = function(self, spellInfo)
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
		self:UpdateUnplacedHighlight(spellInfo)
		self:UpdateAutocast(spellInfo)

		self:SetTooltipHandler(spellInfo, spellKey, isNew)
		self:SetCooldownAndDrag(spellInfo)

		self.spellIcon:SetSpell(spellInfo)
		self:SetLearnedState(spellInfo)
		self:UpdateRankArrow(spellInfo)
	end;
}
