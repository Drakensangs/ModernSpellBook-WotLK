--[[
	Settings cog (left of the search bar) and its dropdown menu.
	Every option is saved in ModernSpellBook_DB.
--]]

-- Default for every setting. Filled in at login for missing keys (tables
-- key by key) and restored by /msb reset.
MSB_DEFAULTS = {
	showPassives = true,
	showSpellCounter = true,
	rememberPage = true,
	showUnlearned = true,
	showUpcoming = true,
	showContinuationHeaders = true,
	lockPositionAndScale = false,
	classColoredBookmark = false,
	highlightUnplaced = false,
	isMinimized = false,
	fontSize = 11.5,
	textColorMode = "light",
	highlights = { learnedGlow = true, learnedBadge = true, availableGlow = true, availableBadge = true },
	iconFrame = { spells = true, other = true, unlearned = false },
}

function MSB_ApplyDefaults(db)
	for key, value in pairs(MSB_DEFAULTS) do
		if (type(value) == "table") then
			if (type(db[key]) ~= "table") then db[key] = {} end
			for subKey, subValue in pairs(value) do
				if (db[key][subKey] == nil) then db[key][subKey] = subValue end
			end
		elseif (db[key] == nil) then
			db[key] = value
		end
	end
	if (not db.spells) then db.spells = {} end
end

MSB_class "MSB_CSettingsMenu"
{
	__init = function(self, parent, onSettingChanged)
		self.on_setting_changed = onSettingChanged

		-- Gear button: an iron cog in the frame's own metal, sitting on the
		-- stone strip. The 32x32 texture has a 4 px margin around the cog
		-- (3 px at the button's 24x24 size).
		local COG = "Interface\\AddOns\\ModernSpellBook\\Assets\\Frame\\settings-cog"
		self.button = CreateFrame("Button", nil, parent)
		self.button:SetWidth(MSB_LAYOUT.cogSize)
		self.button:SetHeight(MSB_LAYOUT.cogSize)
		self.button:SetHitRectInsets(MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin)
		self.button:SetPoint("RIGHT", ModernSpellBookFrame.searchBar.frame, "LEFT", -MSB_LAYOUT.cogGap, 0)
		self.button:SetNormalTexture(COG)
		-- Hover: a warm glow around the teeth and in the hub
		self.button:SetHighlightTexture(COG .. "-highlight", "ADD")
		-- Pressed: the cog sinks a pixel and darkens
		self.button:SetPushedTexture(COG)
		local pushed = self.button:GetPushedTexture()
		pushed:ClearAllPoints()
		pushed:SetPoint("TOPLEFT", self.button, "TOPLEFT", 1, -1)
		pushed:SetPoint("BOTTOMRIGHT", self.button, "BOTTOMRIGHT", 1, -1)
		pushed:SetVertexColor(0.75, 0.75, 0.75)
		-- The hover glow sinks with the cog while it's pressed
		local cogButton = self.button
		local highlight = self.button:GetHighlightTexture()
		local function SetHighlightPressed(pressed)
			local offset = pressed and 1 or 0
			highlight:ClearAllPoints()
			highlight:SetPoint("TOPLEFT", cogButton, "TOPLEFT", offset, -offset)
			highlight:SetPoint("BOTTOMRIGHT", cogButton, "BOTTOMRIGHT", offset, -offset)
		end
		self.button:SetScript("OnMouseDown", function() SetHighlightPressed(true) end)
		self.button:SetScript("OnMouseUp", function() SetHighlightPressed(false) end)
		self.button:SetScript("OnHide", function() SetHighlightPressed(false) end)

		-- Plain dropdown: only its menu is used, the box itself is hidden
		self.dropdown = CreateFrame("Frame", "ModernSpellBookSettingsDropDown", parent, "UIDropDownMenuTemplate")

		local settingsMenu = self
		local initFunc = function(frame, level, menuList) settingsMenu:InitializeDropdown(level) end

		local ddName = self.dropdown:GetName()
		_G[ddName.."Left"]:Hide()
		_G[ddName.."Middle"]:Hide()
		_G[ddName.."Right"]:Hide()
		_G[ddName.."ButtonNormalTexture"]:SetTexture("")
		_G[ddName.."ButtonDisabledTexture"]:SetTexture("")
		_G[ddName.."ButtonPushedTexture"]:SetTexture("")
		_G[ddName.."ButtonHighlightTexture"]:SetTexture("")
		local ddButton = _G[ddName.."Button"]
		ddButton:ClearAllPoints()
		ddButton:SetPoint("LEFT", ddName.."Text", "LEFT", -9, 0)
		ddButton:SetPoint("RIGHT", ddName.."Text", "RIGHT", 6, 0)
		self.dropdown.displayMode = "MENU"

		self.dropdown.initialize = initFunc

		-- Nudge submenus a little away from the main menu so they don't cover it.
		-- Done right after the game positions the submenu (same frame), not on a
		-- delay: the stock submenu arrow re-opens the submenu every time it's
		-- hovered, and a delayed nudge made that re-open visibly flicker/jump.
		local dropdown = self.dropdown
		local SUBMENU_NUDGE = 10
		hooksecurefunc("ToggleDropDownMenu", function(level)
			if not level or level < 2 then return end
			if UIDROPDOWNMENU_OPEN_MENU ~= dropdown then return end
			local list = _G["DropDownList"..level]
			if not list or not list:IsShown() then return end
			local point, anchor, relPoint, x, y = list:GetPoint(1)
			if not point or not anchor then return end
			-- Opened to the left when it would run off screen: nudge left instead
			local nudge = string.find(point, "RIGHT") and -SUBMENU_NUDGE or SUBMENU_NUDGE
			list:ClearAllPoints()
			list:SetPoint(point, anchor, relPoint, (x or 0) + nudge, y or 0)
		end)

		self.button:SetScript("OnClick", function()
			if (MSB_SecureBook.RefuseInCombat()) then return end
			PlaySound(MSB_SOUND.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ToggleDropDownMenu(1, nil, dropdown, settingsMenu.button, MSB_LAYOUT.cogMargin, MSB_LAYOUT.cogMargin)
		end)

		-- Closing the spellbook closes the menu (hooked: the window's secure
		-- template owns OnHide)
		parent:HookScript("OnHide", function()
			if (UIDROPDOWNMENU_OPEN_MENU == dropdown) then CloseDropDownMenus() end
		end)

		ModernSpellBookFrame.settingsButton = self.button
		MSB_CombatGuard:RegisterCombatDisabledFrame(self.button)
	end;

	-- =================== DROPDOWN ================================

	InitializeDropdown = function(self, level)
		level = level or 1
		local info
		local onChanged = self.on_setting_changed

		if (level == 1) then
			-- Show passive spells
			info = {}
			info.text = (ModernSpellBookFrame.ClientLocale and ModernSpellBookFrame.ClientLocale.ShowPassive) or "Show passives"
			info.checked = ModernSpellBook_DB.showPassives
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showPassives = not ModernSpellBook_DB.showPassives
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Remember page
			info = {}
			info.text = "Remember page"
			info.checked = ModernSpellBook_DB.rememberPage
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.rememberPage = not ModernSpellBook_DB.rememberPage
				MSB_SecureBook.SetRemember(ModernSpellBook_DB.rememberPage)
			end
			UIDropDownMenu_AddButton(info, level)

			-- Spell counter
			info = {}
			info.text = "Spell counter"
			info.checked = ModernSpellBook_DB.showSpellCounter
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showSpellCounter = not ModernSpellBook_DB.showSpellCounter
				MSB_SpellDataService:UpdateSpellCounter()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Show unlearned spells
			info = {}
			info.text = "Show unlearned"
			info.checked = ModernSpellBook_DB.showUnlearned
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showUnlearned = not ModernSpellBook_DB.showUnlearned
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Show upcoming spells
			info = {}
			info.text = "Show upcoming"
			info.checked = ModernSpellBook_DB.showUpcoming
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showUpcoming = not ModernSpellBook_DB.showUpcoming
				MSB_SpellBook:UpdateUpcomingSpells()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Continuation headers
			info = {}
			info.text = "Continuation headers"
			info.checked = ModernSpellBook_DB.showContinuationHeaders
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.showContinuationHeaders = not ModernSpellBook_DB.showContinuationHeaders
				onChanged()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Lock position & scale
			info = {}
			info.text = "Lock position & scale"
			info.checked = ModernSpellBook_DB.lockPositionAndScale
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.lockPositionAndScale = not ModernSpellBook_DB.lockPositionAndScale
				MSB_SpellBook:UpdateLockVisuals()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Class-colored bookmark
			info = {}
			info.text = "Class-colored bookmark"
			info.checked = ModernSpellBook_DB.classColoredBookmark
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.classColoredBookmark = not ModernSpellBook_DB.classColoredBookmark
				MSB_SpellBook:UpdateBookmarkTexture()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Glow on spells that aren't on any action bar
			info = {}
			info.text = "Highlight spells not on action bars"
			info.checked = ModernSpellBook_DB.highlightUnplaced
			info.keepShownOnClick = 1
			info.func = function()
				ModernSpellBook_DB.highlightUnplaced = not ModernSpellBook_DB.highlightUnplaced
				MSB_ActionBarHelper:InvalidatePlacedSpells()
				MSB_SpellBook:UpdateUnplacedHighlights()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Highlights submenu
			info = {}
			info.text = "Highlights"
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "highlights"
			UIDropDownMenu_AddButton(info, level)

			-- Font size submenu
			info = {}
			info.text = "Font size"
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "fontSize"
			UIDropDownMenu_AddButton(info, level)

			-- Spell Text Color submenu
			info = {}
			info.text = "Spell text color"
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "textColor"
			UIDropDownMenu_AddButton(info, level)

			-- Icon Frame submenu
			info = {}
			info.text = "Spell icon frame"
			info.hasArrow = 1
			info.notCheckable = 1
			info.value = "iconFrame"
			UIDropDownMenu_AddButton(info, level)

			info = {}
			info.text = "Reset position & scale"
			info.notCheckable = 1
			info.func = function()
				ModernSpellBook_DB.position = nil
				ModernSpellBook_DB.windowScale = nil
				MSB_SpellBook:RestorePosition()
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

		elseif (level == 2) then
			if (UIDROPDOWNMENU_MENU_VALUE == "textColor") then
				info = {}
				info.text = "Light"
				info.checked = ModernSpellBook_DB.textColorMode ~= "dark"
				info.func = function()
					ModernSpellBook_DB.textColorMode = "light"
					onChanged()
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Dark"
				info.checked = ModernSpellBook_DB.textColorMode == "dark"
				info.func = function()
					ModernSpellBook_DB.textColorMode = "dark"
					onChanged()
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)

			elseif (UIDROPDOWNMENU_MENU_VALUE == "fontSize") then
				local sizes = {9, 10, 10.5, 11, 11.5, 12, 13}
				for _, size in ipairs(sizes) do
					local fontSize = size
					info = {}
					info.text = tostring(size)
					info.value = size
					info.checked = (ModernSpellBook_DB.fontSize == size)
					info.func = function()
						ModernSpellBook_DB.fontSize = fontSize
						onChanged()
						CloseDropDownMenus()
					end
					UIDropDownMenu_AddButton(info, level)
				end

			elseif (UIDROPDOWNMENU_MENU_VALUE == "highlights") then
				info = {}
				info.text = "Learned spells glow"
				info.checked = ModernSpellBook_DB.highlights.learnedGlow
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.learnedGlow = not ModernSpellBook_DB.highlights.learnedGlow
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Learned spells badge"
				info.checked = ModernSpellBook_DB.highlights.learnedBadge
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.learnedBadge = not ModernSpellBook_DB.highlights.learnedBadge
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Available spells glow"
				info.checked = ModernSpellBook_DB.highlights.availableGlow
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.availableGlow = not ModernSpellBook_DB.highlights.availableGlow
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Available spells badge"
				info.checked = ModernSpellBook_DB.highlights.availableBadge
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.highlights.availableBadge = not ModernSpellBook_DB.highlights.availableBadge
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

			elseif (UIDROPDOWNMENU_MENU_VALUE == "iconFrame") then
				info = {}
				info.text = "Spells"
				info.checked = ModernSpellBook_DB.iconFrame.spells
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.spells = not ModernSpellBook_DB.iconFrame.spells
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Other"
				info.checked = ModernSpellBook_DB.iconFrame.other
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.other = not ModernSpellBook_DB.iconFrame.other
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)

				info = {}
				info.text = "Unlearned"
				info.checked = ModernSpellBook_DB.iconFrame.unlearned
				info.keepShownOnClick = 1
				info.func = function()
					ModernSpellBook_DB.iconFrame.unlearned = not ModernSpellBook_DB.iconFrame.unlearned
					onChanged()
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end;
}