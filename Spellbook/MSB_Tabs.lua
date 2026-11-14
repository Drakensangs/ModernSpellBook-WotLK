--[[
	Tab button in the strip under the title bar: class, general, pet,
	plus the optional Clique and Training tabs (two page view only; the
	one page view shows those two as side buttons, see MSB_CSideButton below).

	Tabs hang from the strip with their metal lip on top. Their bottoms
	tuck under the separator bar, so the unfinished edge of Blizzard's tab
	art never shows. The selected tab is taller, brighter and lit by a soft
	glow from the separator, so it stands out above the rest.
--]]

local SELECTED_TEXTURE = "Interface\\Spellbook\\UI-SpellBook-Tab3-Selected"
local UNSELECTED_TEXTURE = "Interface\\Spellbook\\UI-SpellBook-Tab-Unselected"
-- Blizzard's own spellbook tab highlight (SpellBookFrameTabButtonTemplate)
local GLOW_TEXTURE = "Interface\\SpellBook\\UI-SpellbookPanel-Tab-Highlight"
local TEX_WIDTH, TEX_HEIGHT = 128, 64

--[[
	Pixel rects on the 128x64 tab textures, flipped so the metal lip is on
	top. Tabs are cut into six slices: the bevelled corners keep their size,
	the middle and straight sides stretch to fit the label and state.
	  left/right        edges of the art
	  capLeft/capRight  where the corner caps end
	  top / lip         the lip's outer edge / where its bevel ends
	  bottom            the open end, above the selected art's second bevel
	                    (rows 12-17) so no notched corners show
	  textX/textY       label centre from the tab's bottom centre. The art is
	                    off-centre (thicker metal on the left), and textY sits
	                    1 px below the face's middle because letters sit high.
--]]
local SELECTED_ART = { left = 12, capLeft = 28, capRight = 100, right = 116,
	top = 45, lip = 37, bottom = 18, height = 33, textX = 2, textY = 15 }
local UNSELECTED_ART = { left = 13, capLeft = 29, capRight = 99, right = 115,
	top = 46, lip = 39, bottom = 18, height = 26, textX = 1.5, textY = 13 }

-- Warm glow rising from the separator behind the selected tab's label.
-- Only the glow's upper half is used, its brightest edge sits under the separator.
local GLOW_RECT = { 17, 115, 18, 31 }
local GLOW_HEIGHT = 16
local GLOW_INSET = 4		-- keeps the glow inside the tab's metal sides
local GLOW_ALPHA = 0.3

local HIGHLIGHT_ALPHA = 0.35

local TAB_GAP = 4			-- space between tabs
local TAB_PADDING = 30		-- added to the text width
local TAB_MIN_WIDTH = 70

-- Text colors
local normalFontColor = {1, 0.82, 0}
local highlightFontColor = {1, 1, 1}
local disabledFontColor = {0.5, 0.41, 0}

MSB_class "MSB_CTab"
{
	__init = function(self, parent, name, tabNumber, onClickCallback)
		self.tab_number = tabNumber
		self.name = name

		self.frame = CreateFrame("Button", "ModernSpellBookFrame_Tab".. tabNumber, parent)
		self.frame:SetHeight(UNSELECTED_ART.height)

		-- Tab art, its mouseover brightening, and the selected tab's glow
		self.slices = self:CreateSlices("BORDER")
		self.highlightSlices = self:CreateSlices("HIGHLIGHT")
		self.glow = self.frame:CreateTexture(nil, "ARTWORK")
		self.glow:SetTexture(GLOW_TEXTURE)
		self.glow:SetTexCoord(GLOW_RECT[1] / TEX_WIDTH, GLOW_RECT[2] / TEX_WIDTH,
			GLOW_RECT[3] / TEX_HEIGHT, GLOW_RECT[4] / TEX_HEIGHT)
		self.glow:SetBlendMode("ADD")
		self.glow:SetAlpha(GLOW_ALPHA)
		self.glow:SetHeight(GLOW_HEIGHT)
		self.glow:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", GLOW_INSET, 0)
		self.glow:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -GLOW_INSET, 0)
		self.glow:Hide()

		local tabText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame:SetFontString(tabText)

		self:SetName(name)

		if (tabNumber == 1) then
			self:SetSelected()
		else
			self:SetDeselected()
		end

		local tab = self
		self.frame:SetScript("OnClick", function()
			onClickCallback(tab)
		end)

		self.frame:SetScript("OnEnter", function()
			tab.frame:GetFontString():SetTextColor(unpack(highlightFontColor))
		end)

		self.frame:SetScript("OnLeave", function()
			tab:SetDefaultFontColor()
		end)
	end;

	-- ========================= METHODS ===========================

	SetName = function(self, name)
		self.name = name
		self.frame:GetFontString():SetText(name)
		local textWidth = 60
		if (self.frame:GetFontString().GetStringWidth) then
			textWidth = self.frame:GetFontString():GetStringWidth()
		end
		self.frame:SetWidth(math.max(TAB_MIN_WIDTH, textWidth + TAB_PADDING))
	end;

	-- Lines the tab up after the previous visible tab, bottoms on the separator
	UpdatePosition = function(self, tabgroups)
		self.frame:ClearAllPoints()

		local anchor = nil
		for j = self.tab_number - 1, 1, -1 do
			local prevTab = tabgroups[j]
			if (prevTab and prevTab:IsShown()) then
				anchor = prevTab
				break
			end
		end

		-- leftOffset (from the window's left edge) places the secure tab catchers
		if (anchor) then
			self.frame:SetPoint("BOTTOMLEFT", anchor.frame, "BOTTOMRIGHT", TAB_GAP, 0)
			self.leftOffset = (anchor.leftOffset or MSB_LAYOUT.tabsLeft) + anchor.frame:GetWidth() + TAB_GAP
		else
			self.frame:SetPoint("BOTTOMLEFT", ModernSpellBookFrame, "TOPLEFT",
				MSB_LAYOUT.tabsLeft, MSB_LAYOUT.tabBottom)
			self.leftOffset = MSB_LAYOUT.tabsLeft
		end
	end;

	GetWidthWithGap = function(self)
		return self.frame:GetWidth() + TAB_GAP
	end;

	SetDefaultFontColor = function(self)
		if (ModernSpellBookFrame.selectedTab == self.tab_number) then
			self.frame:GetFontString():SetTextColor(unpack(normalFontColor))
		else
			self.frame:GetFontString():SetTextColor(unpack(disabledFontColor))
		end
	end;

	UpdateAsPetTab = function(self)
		local petType = UnitCreatureType("pet")
		if (petType) then
			self:SetName(petType)
			self.frame:Show()
		else
			self.frame:Hide()
			-- Pet gone while its tab is open: back to the class tab (in combat
			-- the secure pet state does this)
			if (ModernSpellBookFrame.selectedTab == self.tab_number and not InCombatLockdown()) then
				MSB_SpellBook:SelectTab(1)
			end
		end

		MSB_SpellBook:PositionAllTabs()
	end;

	-- ======================== VISUAL STATE =======================

	-- Six textures on one layer: lip and body for the left cap, middle and right cap
	CreateSlices = function(self, layer)
		local slices = {}
		for i = 1, 6 do
			slices[i] = self.frame:CreateTexture(nil, layer)
		end
		return slices
	end;

	-- Cuts one state's art over a set of slices. The caps keep their natural
	-- width, the lip its natural height; the rest follows the frame's size.
	LayoutSlices = function(self, slices, path, art)
		local frame = self.frame
		local capWidth = art.capLeft - art.left
		local lipHeight = art.top - art.lip
		-- Per column: texture x range, then the left and right edges as
		-- (side of the frame, offset)
		local columns = {
			{ art.left, art.capLeft, "LEFT", 0, "LEFT", capWidth },
			{ art.capLeft, art.capRight, "LEFT", capWidth, "RIGHT", -capWidth },
			{ art.capRight, art.right, "RIGHT", -capWidth, "RIGHT", 0 },
		}
		for c = 1, 3 do
			local column = columns[c]
			local x1, x2 = column[1] / TEX_WIDTH, column[2] / TEX_WIDTH
			local lip, body = slices[c * 2 - 1], slices[c * 2]

			lip:SetTexture(path)
			lip:SetTexCoord(x1, x2, art.top / TEX_HEIGHT, art.lip / TEX_HEIGHT)
			lip:ClearAllPoints()
			lip:SetPoint("TOPLEFT", frame, "TOP" .. column[3], column[4], 0)
			lip:SetPoint("BOTTOMRIGHT", frame, "TOP" .. column[5], column[6], -lipHeight)

			body:SetTexture(path)
			body:SetTexCoord(x1, x2, art.lip / TEX_HEIGHT, art.bottom / TEX_HEIGHT)
			body:ClearAllPoints()
			body:SetPoint("TOPLEFT", frame, "TOP" .. column[3], column[4], -lipHeight)
			body:SetPoint("BOTTOMRIGHT", frame, "BOTTOM" .. column[5], column[6], 0)
		end
	end;

	-- Art and height for one state; the highlight brightens the same art
	SetTabArt = function(self, path, art, brightness)
		self.frame:SetHeight(art.height)
		local label = self.frame:GetFontString()
		label:ClearAllPoints()
		label:SetPoint("CENTER", self.frame, "BOTTOM", art.textX, art.textY)
		self:LayoutSlices(self.slices, path, art)
		for _, slice in ipairs(self.slices) do
			slice:SetVertexColor(brightness, brightness, brightness, 1)
		end
		self:LayoutSlices(self.highlightSlices, path, art)
		for _, slice in ipairs(self.highlightSlices) do
			slice:SetBlendMode("ADD")
			slice:SetAlpha(HIGHLIGHT_ALPHA)
		end
	end;

	SetSelected = function(self)
		self:SetTabArt(SELECTED_TEXTURE, SELECTED_ART, 1)
		self.glow:Show()
		self.frame:GetFontString():SetTextColor(unpack(normalFontColor))
	end;

	SetDeselected = function(self)
		self:SetTabArt(UNSELECTED_TEXTURE, UNSELECTED_ART, 0.8)
		self.glow:Hide()
		self.frame:GetFontString():SetTextColor(unpack(disabledFontColor))
	end;

	-- ====================== DELEGATION ===========================

	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;

	GetRight = function(self)
		return self.frame:GetRight()
	end;
}

--[[
	MSB_CSideButton: square button on the right edge of the window, styled like
	Blizzard's spellbook skill line tabs (icon in a metal socket). Used for
	the Clique and What's Training panels in the one page view, where the
	tab strip has no room for them.
--]]

local SIDE_BUTTON_SIZE = 32
local SIDE_SOCKET_TEXTURE = "Interface\\SpellBook\\SpellBook-SkillLineTab"

MSB_class "MSB_CSideButton"
{
	-- isOpen: returns true while the button's panel is shown (lights the button)
	__init = function(self, parent, name, icon, texCoord, tooltip, onClick, isOpen)
		self.isOpen = isOpen
		self.tooltip = tooltip

		local button = CreateFrame("CheckButton", name, parent)
		button:SetWidth(SIDE_BUTTON_SIZE)
		button:SetHeight(SIDE_BUTTON_SIZE)
		-- Below the border, so the socket's flange tucks under the window edge
		button:SetFrameLevel(parent:GetFrameLevel() + 1)

		local socket = button:CreateTexture(nil, "BACKGROUND")
		socket:SetTexture(SIDE_SOCKET_TEXTURE)
		socket:SetWidth(64)
		socket:SetHeight(64)
		socket:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 11)

		button:SetNormalTexture(icon)
		if (texCoord) then
			button:GetNormalTexture():SetTexCoord(unpack(texCoord))
		end
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		button:GetHighlightTexture():SetBlendMode("ADD")
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		button:GetCheckedTexture():SetBlendMode("ADD")

		local sideButton = self
		button:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.IG_MAINMENU_OPTION_CHECKBOX_ON)
			onClick()
			sideButton:UpdateChecked()
		end)
		button:SetScript("OnEnter", function()
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(sideButton.tooltip, 1, 1, 1)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		button:SetScript("OnShow", function()
			sideButton:UpdateChecked()
		end)

		button:Hide()
		self.frame = button
	end;

	UpdateChecked = function(self)
		self.frame:SetChecked(self.isOpen and self.isOpen() and true or false)
	end;

	-- slot 1 is the top position, slot 2 below it
	SetSlot = function(self, slot)
		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPRIGHT", -1,
			MSB_LAYOUT.sideButtonTop - (slot - 1) * MSB_LAYOUT.sideButtonSpacing)
	end;

	Show = function(self)
		self.frame:Show()
	end;

	Hide = function(self)
		self.frame:Hide()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;
}
