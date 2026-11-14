--[[
	MSB_CSpellBook: main addon controller.
	Owns ModernSpellBookFrame: window setup, one/two page view, the page
	models behind every tab, page rendering, tabs and events. The secure
	side (combat support) lives in MSB_SecureBook.
--]]

local ASSETS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\"

local DB_VERSION = 4

local windowSettings = {
	posy = 0,
	height = 560,
	width1 = 550,	-- one page
	width2 = 1058,	-- two pages
}

-- Search bar width limits (it shrinks to fit next to the tabs)
local SEARCH_MAX_WIDTH = 200
local SEARCH_MIN_WIDTH = 100

-- Portrait ring: art square (units) and the icon inside it. The ring's
-- opening has a 23 unit radius; the icon is a little larger so its edge
-- tucks under the ring.
local PORTRAIT_ART_SIZE = 80
local PORTRAIT_ICON_SIZE = 48
-- The icon of Blizzard's own spellbook window
local PORTRAIT_ICON = "Interface\\Spellbook\\Spellbook-Icon"

local totalCategoryItems = 0

-- Bookmark texture drawn at 64x256 (128x512 art). The ribbon's body runs
-- about 12-38 px from the texture's left edge, so it is centred at ~25 px.
local BOOKMARK_WIDTH = 64
local BOOKMARK_HEIGHT = 256
local BOOKMARK_BODY_CENTER = 25
-- One page view: left edge of the bookmark, so about half of the ribbon
-- shows left of the right border (the ribbon is cut where the page ends)
local BOOKMARK_X_ONE_PAGE = 515

-- Classes that ship a class-colored bookmark (Assets\Spellbook\Bookmarks\bookmark-<class>.tga)
MSB_BookmarkClasses = {
	DEATHKNIGHT = true, DRUID = true, HUNTER = true, MAGE = true, PALADIN = true,
	PRIEST = true, ROGUE = true, SHAMAN = true, WARLOCK = true, WARRIOR = true,
}

MSB_TRAINER_HINT_LONG = "Visit a class trainer in a major city to fetch the FULL list of available spells."
MSB_TRAINER_HINT_SHORT = "Visit a class trainer to fetch the FULL spell list."

-- Blizzard draws these XP bar parts in DIALOG strata, above the book.
-- They are lowered while the book is open and restored when it closes.
local OVERLAPPING_BAR_FRAMES = { "ExhaustionTick", "MainMenuBarOverlayFrame" }
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
	FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local loweredFrames = {}

local function LowerOverlappingBarFrames(book)
	local bookRank = STRATA_RANK[book:GetFrameStrata()] or STRATA_RANK.HIGH
	for _, name in ipairs(OVERLAPPING_BAR_FRAMES) do
		local f = _G[name]
		local strata = f and f.GetFrameStrata and f:GetFrameStrata()
		local safe = f and not (f.IsProtected and f:IsProtected() and InCombatLockdown())
		if (safe and not loweredFrames[f] and (STRATA_RANK[strata] or 0) > bookRank) then
			local level = f:GetFrameLevel()
			loweredFrames[f] = { strata = strata, level = level }
			f:SetFrameStrata("MEDIUM")
			-- Stay above the bar it decorates now that they share a strata
			local parent = f:GetParent()
			local parentLevel = parent and parent.GetFrameLevel and parent:GetFrameLevel() or 0
			f:SetFrameLevel(math.max(level, parentLevel + 2))
		end
	end
end

local function RestoreOverlappingBarFrames()
	for f, saved in pairs(loweredFrames) do
		-- Leave it alone if another addon changed it meanwhile, or it became locked
		if (f:GetFrameStrata() == "MEDIUM" and not (f:IsProtected() and InCombatLockdown())) then
			f:SetFrameStrata(saved.strata)
			f:SetFrameLevel(saved.level)
		end
		loweredFrames[f] = nil
	end
end

MSB_class "MSB_CSpellBook"
{
	-- The window (ModernSpellBookFrame) is created in Setup, out of combat;
	-- events arrive on a plain frame and go to handlers[eventName]
	__init = function(self)
		self.models = {}
		self.spellLists = {}
		self.dirty = true

		local spellBook = self
		self.handlers = {
			ADDON_LOADED = function() spellBook:OnAddonLoaded() end,
			SPELLS_CHANGED = function() spellBook:OnSpellsChanged() end,
			SPELL_UPDATE_COOLDOWN = function() spellBook:UpdateCooldowns() end,
			PET_BAR_UPDATE_COOLDOWN = function() spellBook:UpdateCooldowns() end,
			UNIT_PET = function() if (arg1 == "player") then spellBook:OnSpellsChanged() end end,
			UPDATE_BINDINGS = function() MSB_SecureBook.BindKeys() end,
			PLAYER_ENTERING_WORLD = function() MSB_SecureBook.PlaceMicroCatcher() end,
			UI_SCALE_CHANGED = function() MSB_SecureBook.PlaceMicroCatcher() end,
			DISPLAY_SIZE_CHANGED = function() MSB_SecureBook.PlaceMicroCatcher() end,
		}
		self.events = CreateFrame("Frame")
		for name in pairs(self.handlers) do self.events:RegisterEvent(name) end
		self.events:SetScript("OnEvent", function()
			local handler = spellBook.handlers[event]
			if (handler) then handler() end
		end)
	end;

	-- A protected, standalone window: shown, hidden and paged by secure
	-- snippets in combat (see MSB_SecureBook)
	CreateWindow = function(self)
		self.frame = CreateFrame("Frame", "ModernSpellBookFrame", UIParent,
			"SecureHandlerShowHideTemplate,SecureHandlerMouseWheelTemplate,SecureHandlerStateTemplate")
		self.frame:Hide()
		self.frame:SetToplevel(true)
		self.frame.Tabgroups = {}
		local spellBook = self
		-- Hooked: the secure template owns OnShow and OnHide
		self.frame:HookScript("OnShow", function()
			spellBook:OnShow()
		end)
		self.frame:HookScript("OnHide", function()
			spellBook:OnHide()
		end)
		_G.ModernSpellBookFrame = self.frame
	end;

	-- ========================= EVENTS ============================

	OnAddonLoaded = function(self)
		if (arg1 ~= "ModernSpellBook") then return end
		self.events:UnregisterEvent("ADDON_LOADED")

		-- Saved settings from an incompatible version are reset
		if (not ModernSpellBook_DB) then
			ModernSpellBook_DB = {}
		end
		if (ModernSpellBook_DB.dbVersion ~= DB_VERSION) then
			local hadOldData = (next(ModernSpellBook_DB) ~= nil)
			for k in pairs(ModernSpellBook_DB) do
				ModernSpellBook_DB[k] = nil
			end
			if (hadOldData) then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Settings reset (DB version " .. DB_VERSION .. ").")
			end
		end

		MSB_ApplyDefaults(ModernSpellBook_DB)
		-- Leftovers from removed options ("All ranks" checkbox, passive icon frame)
		ModernSpellBook_DB.showAllRanks = nil
		ModernSpellBook_DB.iconFrame.passives = nil
		ModernSpellBook_DB.dbVersion = DB_VERSION

		-- The rank flyout needs every learned rank in the spellbook API,
		-- which the client only provides with this CVar on.
		pcall(function()
			if (GetCVar("ShowAllSpellRanks") ~= "1") then
				SetCVar("ShowAllSpellRanks", "1")
			end
		end)

		-- The window is protected: after a /reload in combat it is built
		-- once combat ends (Blizzard's book works until then)
		if (InCombatLockdown()) then
			self.setupPending = true
			return
		end
		self:Setup()
	end;

	Setup = function(self)
		self.setupPending = nil
		self:CreateWindow()
		self.frame.ClientLocale = MSB_Localization.current
		self.frame.stanceButtons = {}
		self.frame.unlockedStances = {}
		self.frame.isFirstLoad = true
		local remember = ModernSpellBook_DB.rememberPage
		self.frame.selectedTab = remember and ModernSpellBook_DB.lastTab or 1
		if (self.frame.selectedTab ~= 1 and self.frame.selectedTab ~= 2) then self.frame.selectedTab = 1 end
		self.frame.currentPage = remember and ModernSpellBook_DB.lastPage or 1
		self.frame.maxPages = 1

		self:SetupFrame()
		self:RestorePosition()
		self:AddSearchBar()

		local className = UnitClass("player")
		self.frame.tab1 = self:NewTab(className)
		self.frame.tab2 = self:NewTab(GENERAL)
		self.frame.tab3 = self:NewTab("Pet")
		self.frame.customTabs = {}

		MSB_SecureBook.Build(self)
		self.frame:SetAttribute("cat", self.frame.selectedTab)
		self.frame:SetAttribute("cat-book", self.frame.selectedTab)
		self.frame:SetAttribute("page", self.frame.currentPage)
		MSB_SecureBook.SetRemember(remember)

		self:AddPageButtons()
		self:AddCancelButton()
		self:AddViewToggleButton()

		self.frame.settingsMenu = MSB_CSettingsMenu(
			self.frame,
			function() MSB_SpellBook:DrawPage() end
		)

		-- Created after the settings menu, so the cog exists for the top bar layout
		self.frame.rankFlyout = MSB_CRankFlyout(self.frame)

		self.frame.tab3:UpdateAsPetTab()
		self:SetShape(ModernSpellBook_DB.isMinimized)
		self:PositionAllTabs()
		self:UpdateLockVisuals()
		self:InstallBlizzardHooks()
		self.isSetUp = true
		for _, callback in ipairs(self.afterSetup or {}) do callback() end
		self.afterSetup = nil
	end;

	-- Runs once the window exists
	AfterSetup = function(self, callback)
		self.afterSetup = self.afterSetup or {}
		table.insert(self.afterSetup, callback)
	end;

	-- SPELLS_CHANGED comes in bursts (learning, talents, pet summons): one
	-- rebuild 0.3 s after the first event. A closed book rebuilds when opened;
	-- in combat the old pages stay until combat ends.
	OnSpellsChanged = function(self)
		if (not self.isSetUp) then return end
		self:MarkDirty()
		if (self.redrawQueued) then return end
		self.redrawQueued = true
		MSB_After(0.3, function()
			self.redrawQueued = false
			self.frame.tab3:UpdateAsPetTab()
			if (self.frame:IsVisible()) then self:DrawPage() end
		end)
	end;

	OnShow = function(self)
		PlaySound(MSB_SOUND.IG_SPELLBOOK_OPEN)
		LowerOverlappingBarFrames(self.frame)
		if (UpdateMicroButtons) then UpdateMicroButtons() end

		-- The upcoming spells row always opens scrolled to the start
		if (self.frame.upcomingScrollOffset) then
			self.frame.upcomingScrollOffset = 0
		end

		if (self.frame.isFirstLoad) then
			self.frame.isFirstLoad = false
			-- First run: spells you already know are not "New". Checked on learned
			-- entries, since a trainer visit can save unlearned ones first.
			if (not MSB_SpellDataService:HasLearnedSpells()) then
				MSB_SpellDataService:SetupInitiallyKnownSpells()
			end
		end
		if (not self.integrationsDone) then self:SetupIntegrations() end

		self.frame.tab3:UpdateAsPetTab()
		if (self.dirty and not InCombatLockdown()) then
			self:Rebuild()
		else
			self:Sync()
		end
	end;

	OnHide = function(self)
		PlaySound(MSB_SOUND.IG_SPELLBOOK_CLOSE)
		RestoreOverlappingBarFrames()
		self:StopResize()
		self.frame:StopMovingOrSizing()
		if (self.frame.searchBar) then self.frame.searchBar:ClearFocus() end
		if (GameTooltip:IsOwned(self.frame)) then GameTooltip:Hide() end
		if (UpdateMicroButtons) then UpdateMicroButtons() end
	end;

	-- Clique and What's Training: on the first out-of-combat opening
	SetupIntegrations = function(self)
		if (InCombatLockdown()) then return end
		self.integrationsDone = true
		self:SetupCliqueIntegration()
		self:SetupWhatsTrainingIntegration()
	end;

	-- ========================= COMBAT ============================

	-- PLAYER_REGEN_DISABLED fires before the lockdown starts: the last moment
	-- to close what can't stay open and to publish pages that changed.
	OnCombatStart = function(self)
		if (not self.isSetUp) then return end
		self:StopResize()
		self.frame:StopMovingOrSizing()
		if (self.isMoving) then
			self.isMoving = false
			self:SavePosition()
		end
		if (self.frame.rankFlyout) then self.frame.rankFlyout:Close(true) end
		if (self.frame.searchBar) then self.frame.searchBar:ClearFocus() end
		if (CliqueFrame and CliqueFrame:IsShown()) then CliqueFrame:Hide() end
		if (self.dirty) then self:Rebuild() end
	end;

	OnCombatEnd = function(self)
		if (self.setupPending) then
			self:Setup()
			self:ReclaimBlizzardBook()
			return
		end
		if (not self.isSetUp) then return end
		if (MSB_SecureBook.keysPending) then MSB_SecureBook.BindKeys() end
		MSB_SecureBook.PlaceMicroCatcher()
		self.frame.tab3:UpdateAsPetTab()
		self:PositionAllTabs()
		if (not self.integrationsDone and self.frame:IsShown()) then self:SetupIntegrations() end
		if (self.dirty) then
			if (self.frame:IsShown()) then self:Rebuild() end
		else
			self:RefreshCastAttributes()
		end
		self:ReclaimBlizzardBook()
	end;

	-- ================== BLIZZARD'S SPELLBOOK =====================

	-- Out of combat Blizzard's book is swapped for this one. In combat it
	-- stays usable as it is (MSB never changes it); the swap waits.
	ReclaimBlizzardBook = function(self)
		if (InCombatLockdown() or not SpellBookFrame:IsShown()) then return end
		local pet = (SpellBookFrame.bookType == BOOKTYPE_PET)
		HideUIPanel(SpellBookFrame)
		MSB_SecureBook.Open(pet)
	end;

	InstallBlizzardHooks = function(self)
		local spellBook = self
		-- Hiding it inside its own ShowUIPanel would re-enter the panel manager
		SpellBookFrame:HookScript("OnShow", function()
			if (not InCombatLockdown()) then
				MSB_After(0, function() spellBook:ReclaimBlizzardBook() end)
			end
		end)

		-- Close the book when the Character or Talents window opens
		local function CloseOnOpen()
			if (not InCombatLockdown()) then MSB_SecureBook.Close() end
		end
		if (CharacterFrame) then
			CharacterFrame:HookScript("OnShow", CloseOnOpen)
		end
		hooksecurefunc("ShowUIPanel", function(frame)
			if (frame and frame == PlayerTalentFrame) then CloseOnOpen() end
		end)
		hooksecurefunc("CloseAllWindows", CloseOnOpen)
		-- Also runs when the vehicle bar hands the micro buttons back
		hooksecurefunc("UpdateMicroButtons", function()
			MSB_SecureBook.PlaceMicroCatcher()
			if (MSB_SecureBook.IsOpen() and SpellbookMicroButton) then
				SpellbookMicroButton:SetButtonState("PUSHED", 1)
			end
		end)
		-- UIErrorsFrame shares the HIGH strata; keep messages above the open book
		hooksecurefunc(UIErrorsFrame, "AddMessage", function(messages)
			if (MSB_SecureBook.IsOpen()) then messages:Raise() end
		end)
	end;

	-- ========================= SETUP =============================

	-- Default teal bookmark, or the class-colored one
	-- (Assets\Spellbook\Bookmarks\bookmark-<class>.tga)
	UpdateBookmarkTexture = function(self)
		if (not self.frame or not self.frame.bookmark) then return end
		local path = ASSETS .. "bookmark"
		if (ModernSpellBook_DB.classColoredBookmark) then
			local _, englishClass = UnitClass("player")
			if (englishClass and MSB_BookmarkClasses[englishClass]) then
				path = ASSETS .. "Bookmarks\\bookmark-" .. string.lower(englishClass)
			end
		end
		self.frame.bookmark:SetTexture(path)
		self:LayoutBookmark(ModernSpellBook_DB.isMinimized)
	end;

	-- Two pages: the ribbon hangs centred on the seam between the pages, its
	-- top tucked under the separator. One page: only its left half peeks out
	-- from under the right border, as if tucked into the binding; the texture
	-- is cut under the border's metal (where the page ends) so nothing shows
	-- through or past the border.
	LayoutBookmark = function(self, isMinimized)
		local bookmark = self.frame and self.frame.bookmark
		if (not bookmark) then return end
		local x = isMinimized and BOOKMARK_X_ONE_PAGE or (MSB_LAYOUT.pageSplit - BOOKMARK_BODY_CENTER)
		local width = BOOKMARK_WIDTH
		if (isMinimized) then
			local clipRight = windowSettings.width1 + MSB_LAYOUT.pageRight
			width = math.max(1, math.min(BOOKMARK_WIDTH, clipRight - x))
		end
		bookmark:ClearAllPoints()
		bookmark:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, MSB_LAYOUT.pageTop - 3)
		bookmark:SetWidth(width)
		bookmark:SetHeight(BOOKMARK_HEIGHT)
		bookmark:SetTexCoord(0, width / BOOKMARK_WIDTH, 0, 1)
	end;

	UpdateLockVisuals = function(self)
		local locked = ModernSpellBook_DB.lockPositionAndScale
		self.frame:SetMovable(not locked)
		if (self.frame.resizeHandle) then
			if (locked) then
				self.frame.resizeHandle:Hide()
			else
				self.frame.resizeHandle:Show()
			end
		end
	end;

	-- Ends a resize and saves the result
	StopResize = function(self)
		if (not self.isResizing) then return end
		self.isResizing = false
		self.frame.resizeHandle:SetScript("OnUpdate", nil)
		ModernSpellBook_DB.windowScale = self.frame:GetScale()
		self:SavePosition()
	end;

	AddSearchBar = function(self)
		self.frame.searchBar = MSB_CSearchBar(
			self.frame,
			self.frame.ClientLocale.SearchAbilities,
			function() MSB_SpellBook:RefreshPage() end
		)
		-- Right end of the tab strip (the settings cog sits to its left)
		self.frame.searchBar:SetPoint("RIGHT", self.frame, "TOPRIGHT", -16, -self:GetStripMiddle())
	end;

	SetupFrame = function(self)
		self.frame:EnableMouse(true)
		self.frame:SetMovable(true)
		self.frame:RegisterForDrag("LeftButton")
		self.frame:SetScript("OnDragStart", function(frame)
			if (ModernSpellBook_DB.lockPositionAndScale or InCombatLockdown()) then return end
			MSB_SpellBook.isMoving = true
			frame:StartMoving()
		end)
		-- A move still running when combat starts is ended by OnCombatStart
		self.frame:SetScript("OnDragStop", function(frame)
			if (not MSB_SpellBook.isMoving or InCombatLockdown()) then return end
			frame:StopMovingOrSizing()
			MSB_SpellBook.isMoving = false
			MSB_SpellBook:SavePosition()
		end)
		self.frame:SetWidth(windowSettings.width2)
		self.frame:SetHeight(windowSettings.height)
		self.frame:SetFrameStrata("HIGH")
		self.frame:SetFrameLevel(50)

		-- Slim metal border, title bar and the strip behind the tabs
		self.chrome = MSB_CFrameChrome(self.frame)

		-- Resize handle: drag the bottom-right corner to change the scale
		local resizeHandle = CreateFrame("Button", nil, self.frame)
		resizeHandle:SetWidth(20)
		resizeHandle:SetHeight(20)
		resizeHandle:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -12, MSB_LAYOUT.pageBottom + 2)
		resizeHandle:SetFrameLevel(self.frame:GetFrameLevel() + 10)

		resizeHandle:SetNormalTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\resize-button")
		resizeHandle:SetHighlightTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\resize-button")
		resizeHandle:GetHighlightTexture():SetBlendMode("ADD")
		resizeHandle:SetPushedTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\resize-button")
		resizeHandle:GetPushedTexture():SetVertexColor(0.7, 0.7, 0.7)

		resizeHandle:SetScript("OnEnter", function()
			GameTooltip:SetOwner(resizeHandle, "ANCHOR_TOPLEFT")
			if (ModernSpellBook_DB.lockPositionAndScale) then
				GameTooltip:SetText("Position & scale locked")
			else
				GameTooltip:SetText("Drag to resize")
			end
			GameTooltip:Show()
		end)
		resizeHandle:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		self.frame.resizeHandle = resizeHandle

		resizeHandle:SetScript("OnMouseDown", function()
			if (ModernSpellBook_DB.lockPositionAndScale) then return end
			if (MSB_SecureBook.RefuseInCombat()) then return end
			local startX, startY = GetCursorPosition()
			local startScale = self.frame:GetScale()
			-- Keep the top-left corner pinned while scaling
			local left, top = self.frame:GetLeft(), self.frame:GetTop()
			local es = self.frame:GetEffectiveScale()
			local screenLeft = left * es
			local screenTop = top * es
			self.isResizing = true
			resizeHandle:SetScript("OnUpdate", function()
				-- The release can be missed (window closed, button let go elsewhere)
				if (InCombatLockdown() or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton"))) then
					self:StopResize()
					return
				end
				local curX, curY = GetCursorPosition()
				local dx = curX - startX
				local dy = startY - curY
				local delta = (dx + dy) / 2
				local newScale = math.max(0.5, math.min(1.5, startScale + delta / 500))
				self.frame:SetScale(newScale)
				local nes = self.frame:GetEffectiveScale()
				self.frame:ClearAllPoints()
				self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenLeft / nes, screenTop / nes)
			end)
		end)
		resizeHandle:SetScript("OnMouseUp", function()
			self:StopResize()
		end)

		-- Title, centred in the title bar (on the border frame so it draws above it)
		self.frame.title = self.chrome.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.title:SetPoint("CENTER", self.frame, "TOP", 0, MSB_LAYOUT.titleTextY)
		self.frame.title:SetText(SPELLBOOK)

		-- Portrait: metal ring over the top-left corner with the game's
		-- spellbook icon masked to a circle inside. Atlas halves (80x80 units
		-- each): left = ring and its shadows, right = dark disc behind the icon.
		local portrait = CreateFrame("Frame", nil, self.frame)
		portrait:SetWidth(PORTRAIT_ART_SIZE)
		portrait:SetHeight(PORTRAIT_ART_SIZE)
		portrait:SetPoint("CENTER", self.frame, "TOPLEFT", MSB_LAYOUT.portraitX, MSB_LAYOUT.portraitY)
		portrait:SetFrameLevel(self.frame:GetFrameLevel() + 5)
		self.frame.portraitBorderFrame = portrait

		self.frame.portraitBacking = portrait:CreateTexture(nil, "BACKGROUND")
		self.frame.portraitBacking:SetAllPoints(portrait)
		self.frame.portraitBacking:SetTexture(ASSETS .. "spellbook-portrait")
		self.frame.portraitBacking:SetTexCoord(0.5, 1, 0, 1)

		self.frame.portraitIcon = portrait:CreateTexture(nil, "ARTWORK")
		self.frame.portraitIcon:SetWidth(PORTRAIT_ICON_SIZE)
		self.frame.portraitIcon:SetHeight(PORTRAIT_ICON_SIZE)
		self.frame.portraitIcon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		SetPortraitToTexture(self.frame.portraitIcon, PORTRAIT_ICON)

		self.frame.portraitBorder = portrait:CreateTexture(nil, "OVERLAY")
		self.frame.portraitBorder:SetAllPoints(portrait)
		self.frame.portraitBorder:SetTexture(ASSETS .. "spellbook-portrait")
		self.frame.portraitBorder:SetTexCoord(0, 0.5, 0, 1)

		-- Pages (anchored in SetShape, which depends on the one/two page view)
		self.frame.backgroundLeft = self.frame:CreateTexture(nil, "BORDER")
		self.frame.backgroundLeft:SetTexture(ASSETS .. "spellbook-page-1")

		self.frame.backgroundRight = self.frame:CreateTexture(nil, "BORDER")
		self.frame.backgroundRight:SetTexture(ASSETS .. "spellbook-page-2")

		-- Bookmark hanging from under the separator (placed per view in LayoutBookmark)
		self.frame.bookmark = self.frame:CreateTexture(nil, "ARTWORK")
		self:UpdateBookmarkTexture()

		self.frame.noresultsText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.noresultsText:SetPoint("CENTER", self.frame.backgroundLeft, "CENTER", 0, 0)
		self.frame.noResultsMessage = self.frame.ClientLocale.NoResults .. NEW .. ", " .. TALENT .. "'"
		self.frame.noresultsText:SetText(self.frame.noResultsMessage)
		self.frame.noresultsText:SetTextColor(0, 0, 0)
		self.frame.noresultsText:SetShadowOffset(0, 0)
		self.frame.noresultsText:Hide()

		-- Footer texts sit below the pages' bottom ornament, clear of the last
		-- row of spells. PositionFooterTexts places the hint per view.
		self.frame.trainerHint = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.trainerHint:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, MSB_LAYOUT.footerBottom)
		self.frame.trainerHint:SetText(MSB_TRAINER_HINT_LONG)
		self.frame.trainerHint:SetFont(MSB_GetFont(), 10)
		self.frame.trainerHint:SetTextColor(1, 1, 1)
		self.frame.trainerHint:Hide()

		self.frame.spellCounter = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.spellCounter:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 60, MSB_LAYOUT.footerBottom)
		self.frame.spellCounter:SetFont(MSB_GetFont(), 10)
		self.frame.spellCounter:SetTextColor(1, 1, 1)

		-- "New spells at level X" row at the top of the left page
		local UPCOMING_ICON_SIZE = 24
		local UPCOMING_ICON_SPACING = 14
		local UPCOMING_VISIBLE_COUNT = 5
		local UPCOMING_ARROW_SIZE = 16

		self.frame.upcomingFrame = CreateFrame("Frame", nil, self.frame)
		self.frame.upcomingFrame:SetHeight(UPCOMING_ICON_SIZE)
		self.frame.upcomingFrame:SetWidth(UPCOMING_VISIBLE_COUNT * UPCOMING_ICON_SIZE + (UPCOMING_VISIBLE_COUNT - 1) * UPCOMING_ICON_SPACING)
		self.frame.upcomingFrame:SetPoint("TOPRIGHT", self.frame.backgroundLeft, "TOPRIGHT", -100, -24)

		self.frame.upcomingLabel = self.frame.upcomingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.upcomingLabel:SetFont(MSB_GetFont(), 10)
		self.frame.upcomingLabel:SetTextColor(1, 1, 1)
		self.frame.upcomingLabel:SetPoint("BOTTOM", self.frame.upcomingFrame, "TOP", 0, 6)

		self.frame.upcomingScrollOffset = 0

		self.frame.upcomingIcons = {}
		for i = 1, UPCOMING_VISIBLE_COUNT do
			local parent = CreateFrame("Button", nil, self.frame.upcomingFrame)
			parent:SetWidth(UPCOMING_ICON_SIZE)
			parent:SetHeight(UPCOMING_ICON_SIZE)
			parent:SetPoint("TOPRIGHT", self.frame.upcomingFrame, "TOPRIGHT", -(i - 1) * (UPCOMING_ICON_SIZE + UPCOMING_ICON_SPACING), 0)
			parent:Hide()

			local icon = MSB_CIcon(parent, UPCOMING_ICON_SIZE)
			icon.border:SetTexture("Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spell_border_gray")
			icon.border_frame:SetWidth(UPCOMING_ICON_SIZE + 4)
			icon.border_frame:SetHeight(UPCOMING_ICON_SIZE + 4)
			icon.socket:Hide()
			icon.hover_alpha = 0

		-- Same gold as the "New" spell glow (untinted additive
		-- CheckButtonGlow), scaled down from 60-on-28 to fit this icon.
		local glowFrame = MSB_CreateGlow(parent, 52, {1, 1, 1}, 5)
		glowFrame:SetPoint("CENTER", icon.icon, "CENTER", 0, 0)
		glowFrame:Show()
		parent.ring = glowFrame

			parent:SetScript("OnEnter", function()
				if (parent.tipName) then
					GameTooltip:SetOwner(parent, "ANCHOR_TOP")
					local text = parent.tipName
					if (parent.tipRank and parent.tipRank ~= "") then
						text = text .. " (" .. parent.tipRank .. ")"
					end
					GameTooltip:SetText(text, 1, 1, 1)
					if (parent.tipDesc) then
						GameTooltip:AddLine(parent.tipDesc, 1, 0.82, 0, true)
					end
					MSB_AddTrainingCostLine(GameTooltip, parent.tipCost)
					GameTooltip:Show()
				end
			end)
			parent:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)

			parent.icon = icon
			self.frame.upcomingIcons[i] = parent
		end

		self.frame.upcomingPrevArrow = CreateFrame("Button", nil, self.frame.upcomingFrame)
		self.frame.upcomingPrevArrow:SetWidth(UPCOMING_ARROW_SIZE)
		self.frame.upcomingPrevArrow:SetHeight(UPCOMING_ARROW_SIZE)
		self.frame.upcomingPrevArrow:SetPoint("RIGHT", self.frame.upcomingFrame, "LEFT", -4, 0)
		self.frame.upcomingPrevArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
		self.frame.upcomingPrevArrow:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
		self.frame.upcomingPrevArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
		self.frame.upcomingPrevArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
		self.frame.upcomingPrevArrow:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.IG_ABILITY_PAGE_TURN)
			self.frame.upcomingScrollOffset = math.max(0, self.frame.upcomingScrollOffset - 1)
			self:UpdateUpcomingSpells()
		end)
		self.frame.upcomingPrevArrow:Hide()

		self.frame.upcomingNextArrow = CreateFrame("Button", nil, self.frame.upcomingFrame)
		self.frame.upcomingNextArrow:SetWidth(UPCOMING_ARROW_SIZE)
		self.frame.upcomingNextArrow:SetHeight(UPCOMING_ARROW_SIZE)
		self.frame.upcomingNextArrow:SetPoint("LEFT", self.frame.upcomingFrame, "RIGHT", 4, 0)
		self.frame.upcomingNextArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		self.frame.upcomingNextArrow:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
		self.frame.upcomingNextArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
		self.frame.upcomingNextArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
		self.frame.upcomingNextArrow:SetScript("OnClick", function()
			PlaySound(MSB_SOUND.IG_ABILITY_PAGE_TURN)
			self.frame.upcomingScrollOffset = self.frame.upcomingScrollOffset + 1
			self:UpdateUpcomingSpells()
		end)
		self.frame.upcomingNextArrow:Hide()

	end;

	-- "Page x / y" left of the secure page arrows (MSB_SecureBook), which
	-- are anchored to the window so they never need moving in combat
	AddPageButtons = function(self)
		local back, forward = MSB_SecureBook.back, MSB_SecureBook.forward
		back:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -100, MSB_LAYOUT.pageTextBottom - 6.5)
		forward:SetPoint("TOPLEFT", back, "TOPLEFT", 24, 0)
		self.frame.previousPage = back
		self.frame.nextPage = forward

		self.frame.pageText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.frame.pageText:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -110, MSB_LAYOUT.pageTextBottom)
		self.frame.pageText:SetText("Page 1")
		self.frame.pageText:SetTextColor(1, 1, 1)
		self.frame:EnableMouseWheel(true)
	end;

	-- Secure close button (MSB_SecureBook) in the right title bar socket
	AddCancelButton = function(self)
		local closeSocket = MSB_LAYOUT.sockets[2]
		local close = MSB_SecureBook.closeButton
		close:SetPoint("CENTER", self.frame, "TOPRIGHT",
			closeSocket.x + MSB_LAYOUT.socketButtonOffsetX, closeSocket.y)
		close:SetFrameLevel(self.frame:GetFrameLevel() + 5)
		self.frame.CloseButton = close
	end;

	-- Button next to the close button: switches between one and two pages
	AddViewToggleButton = function(self)
		local socket = MSB_LAYOUT.sockets[1]
		local button = CreateFrame("Button", nil, self.frame)
		button:SetWidth(32)
		button:SetHeight(32)
		button:SetPoint("CENTER", self.frame, "TOPRIGHT", socket.x + MSB_LAYOUT.socketButtonOffsetX, socket.y)
		-- Above the border so it sits inside its socket
		button:SetFrameLevel(self.frame:GetFrameLevel() + 5)
		button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
		button:GetHighlightTexture():SetBlendMode("ADD")

		button:SetScript("OnClick", function()
			if (MSB_SecureBook.RefuseInCombat()) then return end
			PlaySound(MSB_SOUND.IG_MAINMENU_OPTION_CHECKBOX_ON)
			MSB_SpellBook:ToggleView()
			if (GameTooltip:IsOwned(button)) then
				button:GetScript("OnEnter")()
			end
		end)
		button:SetScript("OnEnter", function()
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			if (ModernSpellBook_DB.isMinimized) then
				GameTooltip:SetText("Two page view", 1, 1, 1)
			else
				GameTooltip:SetText("One page view", 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		if (MSB_CombatGuard and MSB_CombatGuard.RegisterCombatDisabledFrame) then
			MSB_CombatGuard:RegisterCombatDisabledFrame(button)
		end

		self.frame.viewToggle = button
	end;

	-- Arrow points out (bigger) in one page view and in (smaller) in two page view
	UpdateViewToggle = function(self)
		local button = self.frame.viewToggle
		if (not button) then return end
		local name = ModernSpellBook_DB.isMinimized and "BiggerButton" or "SmallerButton"
		button:SetNormalTexture("Interface\\Buttons\\UI-Panel-" .. name .. "-Up")
		button:SetPushedTexture("Interface\\Buttons\\UI-Panel-" .. name .. "-Down")
	end;

	-- Saved scale and position, or the default (centred, scale 1)
	RestorePosition = function(self)
		if (InCombatLockdown()) then return end
		local scale = ModernSpellBook_DB.windowScale or 1
		self.frame:SetScale(scale)
		self.frame:ClearAllPoints()
		local pos = ModernSpellBook_DB.position
		if (pos) then
			self.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
		else
			self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, windowSettings.posy)
		end
	end;

	-- Puts every saved setting into effect (used after /msb reset)
	ApplySettings = function(self)
		self:RestorePosition()
		self:SetShape(ModernSpellBook_DB.isMinimized)
		self:PositionAllTabs()
		self:UpdateLockVisuals()
		self:UpdateBookmarkTexture()
		MSB_SecureBook.SetRemember(ModernSpellBook_DB.rememberPage)
		self:MarkDirty()
		MSB_SecureBook.SetPage(1)
		if (self.frame:IsVisible()) then
			self:DrawPage()
		end
	end;

	SavePosition = function(self)
		local point, _, relPoint, x, y = self.frame:GetPoint()
		ModernSpellBook_DB.position = { point = point, relPoint = relPoint, x = x, y = y }
	end;

	-- ========================= SHAPE =============================

	-- Switches between one and two pages, keeping the window's left edge
	-- in place and staying on the same spells.
	ToggleView = function(self)
		if (InCombatLockdown()) then return end
		local toOnePage = not ModernSpellBook_DB.isMinimized

		local left, top = self.frame:GetLeft(), self.frame:GetTop()
		ModernSpellBook_DB.isMinimized = toOnePage
		self:SetShape(toOnePage)
		if (left and top) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
			self:SavePosition()
		end

		-- Two-page spread N holds single pages 2N-1 and 2N
		local page = self.frame.currentPage or 1
		if (toOnePage) then
			page = page * 2 - 1
		else
			page = math.ceil(page / 2)
		end
		self.frame:SetAttribute("page", page)

		self:PositionAllTabs()
		self:DrawPage()
		self:ReplaceCompatPanels()
	end;

	-- Sizes the window and its pages for the one page (minimized) or two page view
	SetShape = function(self, isMinimized)
		local frame = self.frame
		frame:SetWidth(isMinimized and windowSettings.width1 or windowSettings.width2)
		frame:SetHeight(windowSettings.height)

		local left, right = frame.backgroundLeft, frame.backgroundRight
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", MSB_LAYOUT.pageLeft, MSB_LAYOUT.pageTop)
		right:ClearAllPoints()
		if (isMinimized) then
			-- The single page stretches to the right border
			left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", MSB_LAYOUT.pageRight, MSB_LAYOUT.pageBottom)
			right:Hide()
		else
			left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", MSB_LAYOUT.pageSplit, MSB_LAYOUT.pageBottom)
			right:SetPoint("TOPLEFT", frame, "TOPLEFT", MSB_LAYOUT.pageSplit, MSB_LAYOUT.pageTop)
			right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", MSB_LAYOUT.pageRight, MSB_LAYOUT.pageBottom)
			right:Show()
		end

		self.chrome:Layout()
		self:LayoutBookmark(isMinimized)
		self:UpdateViewToggle()
		self:PositionFooterTexts(isMinimized)
		self:LayoutCompatActions()
		self:LayoutTopBar()
	end;

	-- Spell counter (bottom-left) and trainer hint share the strip below
	-- the bottom ornament of the pages.
	PositionFooterTexts = function(self, isMainFrameMinimized)
		local hint = self.frame.trainerHint
		if (not hint) then return end
		hint:ClearAllPoints()
		if (isMainFrameMinimized) then
			-- Single page: shorter text, right-aligned to stay clear of the counter
			hint:SetText(MSB_TRAINER_HINT_SHORT)
			hint:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -45, MSB_LAYOUT.footerBottom)
		else
			-- Two pages: centred under the right page
			hint:SetText(MSB_TRAINER_HINT_LONG)
			hint:SetPoint("BOTTOM", self.frame.backgroundRight, "BOTTOM", 0, 12)
		end
	end;

	-- ==================== PAGE RENDERING =========================

	CalculateSpellPositions = function(self, AllSpells, isPetTab)
		local pageCollection = {}
		local spellPage = {}
		local currentPageRows = -2
		local totalSpells = 0; local totalCategories = 0
		local maxPagesPerView = ModernSpellBook_DB.isMinimized and 1 or 2
		local drawingPageNumber = 1

		local allSpellCategories = {}
		for category, _ in pairs(AllSpells) do
			table.insert(allSpellCategories, category)
		end
		table.sort(allSpellCategories, function(a, b) return a < b end)

		for _, category in ipairs(allSpellCategories) do
			if (AllSpells[category] ~= nil and table.getn(AllSpells[category]) > 0) then
				local spells = AllSpells[category]

				if (category == "Professions" and currentPageRows ~= -2) then
					currentPageRows = -2
					drawingPageNumber = math.fmod(drawingPageNumber, maxPagesPerView) +1
					if (drawingPageNumber == 1) then
						table.insert(pageCollection, spellPage)
						spellPage = {}
					end
				elseif (currentPageRows +(table.getn(spells) < 3 and 3 or 4) > 7.5) then
					currentPageRows = -2
					drawingPageNumber = math.fmod(drawingPageNumber, maxPagesPerView) +1
					if (drawingPageNumber == 1) then
						table.insert(pageCollection, spellPage)
						spellPage = {}
					end
				end
				currentPageRows = currentPageRows +2
				totalCategories = totalCategories +1

				table.insert(spellPage, {isCategory = true, category = category, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber})

				local grid_x = -1
				local totalSpellsInCategory = table.getn(spells)
				for i, spellInfo in ipairs(spells) do
					totalSpells = totalSpells +1
					grid_x = math.fmod(grid_x + 1, 3)
					if (grid_x == 0) then
						-- A category's last row of one or two spells may use an 8th row
						-- on a left (or single) page instead of starting a new page
						local isLastRowOnLeftPage = i +2 > totalSpellsInCategory and drawingPageNumber == 1
						local maxRowLength = isLastRowOnLeftPage and 8.5 or 7.75
						if (currentPageRows +1 > maxRowLength) then
							currentPageRows = 0
							drawingPageNumber = math.fmod(drawingPageNumber, maxPagesPerView) +1
							if (drawingPageNumber == 1) then
								table.insert(pageCollection, spellPage)
								spellPage = {}
							end
							-- Repeat the header on top of the page the category carries on to
							-- (its row is reserved either way)
							if (ModernSpellBook_DB.showContinuationHeaders) then
								totalCategories = totalCategories +1
								table.insert(spellPage, {isCategory = true, category = category, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber})
							end
						end
						currentPageRows = currentPageRows +1
					end

					table.insert(spellPage, {isCategory = false, spellInfo = spellInfo, currentPageRows = currentPageRows, drawingPageNumber = drawingPageNumber, gridX = grid_x})
				end
			end
		end

		table.insert(pageCollection, spellPage)
		return pageCollection
	end;

	-- ================== MODELS AND REDRAWS =======================

	-- Spell lists changed (or settings that shape them): rebuilt on the next
	-- out-of-combat redraw
	MarkDirty = function(self)
		self.dirty = true
		self.spellLists = {}
	end;

	-- One tab's pages, from its spell list and the search text
	BuildModel = function(self, cat)
		local list = self.spellLists[cat]
		if (not list) then
			list = { MSB_SpellDataService:GetAvailableSpells(cat) }
			self.spellLists[cat] = list
		end
		local allSpells, isPetTab = list[1], list[2]
		local model = { allSpells = allSpells, pages = {} }
		if (isPetTab and next(allSpells) == nil) then
			model.empty = self.frame.ClientLocale.NoPetSpells
			return model
		end
		local filterString = self.frame.searchBar:GetText() or ""
		local filtered = MSB_SpellDataService:FilterSpells(filterString, allSpells)
		if (next(filtered) == nil) then
			model.empty = self.frame.noResultsMessage
		else
			model.pages = self:CalculateSpellPositions(filtered, isPetTab)
		end
		return model
	end;

	-- Out of combat: rebuilds every tab, publishes them to the secure side
	-- and redraws. In combat the change waits (the pages on screen stay).
	Rebuild = function(self)
		if (not self.isSetUp) then return end
		-- The learned counter only changes with the spell lists, not with paging
		MSB_SpellDataService:UpdateSpellCounter()
		if (InCombatLockdown()) then
			self.dirty = true
			self:Sync()
			return
		end
		for cat = 1, MSB_SecureBook.CATEGORIES do
			self.models[cat] = self:BuildModel(cat)
			MSB_SecureBook.Publish(self, cat, self.models[cat])
		end
		self.dirty = false
		MSB_SecureBook.Apply()
	end;

	-- Everything that changes the spell lists
	DrawPage = function(self)
		self:MarkDirty()
		self:Rebuild()
	end;

	-- Search text changed: only the filtering is redone
	RefreshPage = function(self)
		self:Rebuild()
	end;

	-- Redraws the visuals of the current tab and page from the secure state
	-- (MSB_Sync, after every secure layout). Safe in combat.
	Sync = function(self)
		if (not self.isSetUp) then return end
		local root = self.frame
		local cat = root:GetAttribute("cat") or 1
		local page = root:GetAttribute("page") or 1
		if (self.drawnCat and root:IsShown() and (cat ~= self.drawnCat or page ~= self.drawnPage)) then
			PlaySound(MSB_SOUND.IG_ABILITY_PAGE_TURN)
		end
		self.drawnCat, self.drawnPage = cat, page
		root.selectedTab = cat
		root.currentPage = page
		root.isPetTab = (cat == MSB_SecureBook.PET)
		ModernSpellBook_DB.lastTab = root:GetAttribute("cat-book") or 1
		if (not root.isPetTab) then ModernSpellBook_DB.lastPage = page end

		for _, tab in ipairs(root.Tabgroups) do
			if (tab.tab_number == cat) then
				tab:SetSelected()
			else
				tab:SetDeselected()
			end
		end

		local model = self.models[cat] or { pages = {} }
		root.AllSpells = model.allSpells
		root.pageCollection = model.pages
		self:RefreshPageElements()
		if (model.empty) then
			root.noresultsText:SetText(model.empty)
			root.noresultsText:Show()
		else
			root.noresultsText:Hide()
		end
		self:UpdateUpcomingSpells()
		self:UpdateTrainerHint()
	end;

	-- Trainer hint: only until the trainer has been visited once
	UpdateTrainerHint = function(self)
		local hint = self.frame.trainerHint
		if (not hint) then return end
		if (ModernSpellBook_DB.showUnlearned and not ModernSpellBook_DB.trainerScanned) then
			hint:Show()
		else
			hint:Hide()
		end
	end;

	-- Fills the current page's headers and spell buttons. The buttons were
	-- already placed (and shown) by the secure layout; this sets what they show.
	RefreshPageElements = function(self)
		self:CleanPages()
		-- Rebuilt on every redraw: the pooled items show other spells after a
		-- page flip or search, so stale entries would light the wrong icon
		self.frame.stanceButtons = {}
		-- Re-read the action bars once per redraw for the "not on bars" highlight
		MSB_ActionBarHelper:InvalidatePlacedSpells()

		local pageCollection = self.frame.pageCollection or {}
		self.frame.maxPages = math.max(1, table.getn(pageCollection))
		local currentPage = math.max(1, math.min(self.frame.currentPage or 1, self.frame.maxPages))

		if (self.frame.maxPages > 1) then
			self.frame.pageText:SetText(string.format(PRODUCT_CHOICE_PAGE_NUMBER, currentPage, self.frame.maxPages))
			self.frame.pageText:Show()
		else
			self.frame.pageText:Hide()
		end

		local page = pageCollection[currentPage]
		if (page == nil) then return end
		local totalCategories = 0
		local totalSpells = 0
		local grid_x = -1
		for i, element in ipairs(page) do
			if (element.isCategory) then
				grid_x = -1
				totalCategories = totalCategories +1
				-- First spell icon in this category, the header's fallback icon
				local fallbackIcon = nil
				for j = i + 1, table.getn(page) do
					local nextElement = page[j]
					if (nextElement.isCategory) then break end
					if (nextElement.spellInfo and nextElement.spellInfo.spellIcon) then
						fallbackIcon = nextElement.spellInfo.spellIcon
						break
					end
				end
				self:GetOrCreateCategory(totalCategories):Set(element.category, element.currentPageRows, element.drawingPageNumber, fallbackIcon)
			else
				grid_x = math.fmod(grid_x + 1, 3)
				totalSpells = totalSpells +1
				local item = self.frame["Spell" .. totalSpells]
				if (item) then item:Set(element.spellInfo) end
			end
		end
	end;

	-- Where a spell element sits, from the window's top-left corner
	GetSpellItemPosition = function(self, element)
		return MSB_SpellItemPosition(element.drawingPageNumber, element.currentPageRows, element.gridX)
	end;

	-- Updates only the autocast corners and sparks of the visible spells,
	-- used when autocast is toggled on the pet bar while the book is open.
	UpdateAutocast = function(self)
		for i = 1, MSB_SecureBook.slots do
			local item = self.frame["Spell".. i]
			if (item:IsShown()) then
				item:UpdateAutocast()
			end
		end
	end;

	-- Refreshes the cooldown swipes of the visible spells and rank flyout
	UpdateCooldowns = function(self)
		if (not self.frame:IsVisible()) then return end
		for i = 1, MSB_SecureBook.slots do
			local item = self.frame["Spell".. i]
			if (item:IsShown()) then
				item:UpdateCooldown()
			end
		end
		if (self.frame.rankFlyout) then
			self.frame.rankFlyout:UpdateCooldowns()
		end
	end;

	-- Updates only the "not on action bars" glow of the visible spells,
	-- used when the bars change while the spellbook is open.
	UpdateUnplacedHighlights = function(self)
		for i = 1, MSB_SecureBook.slots do
			local item = self.frame["Spell".. i]
			if (item:IsShown()) then
				item:UpdateUnplacedHighlight()
			end
		end
	end;

	-- ================ UPCOMING SPELLS ============================

	UpdateUpcomingSpells = function(self)
		local UPCOMING_VISIBLE_COUNT = table.getn(self.frame.upcomingIcons)

		-- Hide all icons first
		for i = 1, UPCOMING_VISIBLE_COUNT do
			self.frame.upcomingIcons[i]:Hide()
		end
		self.frame.upcomingLabel:SetText("")
		self.frame.upcomingPrevArrow:Hide()
		self.frame.upcomingNextArrow:Hide()

		if (not ModernSpellBook_DB.showUpcoming) then
			self.frame.upcomingFrame:Hide()
			return
		end

		if (self.frame.selectedTab ~= 1) then
			self.frame.upcomingFrame:Hide()
			return
		end

		if (not ModernSpellBook_DB.trainerScanned) then
			self.frame.upcomingFrame:Hide()
			return
		end

		local upcoming, nextLevel = MSB_SpellDataService:GetUpcomingSpells()
		local totalUpcoming = table.getn(upcoming)
		if (not nextLevel or totalUpcoming == 0) then
			self.frame.upcomingFrame:Hide()
			return
		end

		self.frame.upcomingLabel:SetText("New spells at ".. nextLevel ..":")
		self.frame.upcomingFrame:Show()

		local maxOffset = math.max(0, totalUpcoming - UPCOMING_VISIBLE_COUNT)
		if (self.frame.upcomingScrollOffset > maxOffset) then
			self.frame.upcomingScrollOffset = maxOffset
		end
		local offset = self.frame.upcomingScrollOffset

		local count = math.min(UPCOMING_VISIBLE_COUNT, totalUpcoming - offset)
		for i = 1, count do
			local spell = upcoming[offset + i]
			local btn = self.frame.upcomingIcons[i]
			btn.icon.icon:SetTexture(spell.icon)
			btn.icon:SetDesaturated(true)
			btn.icon.icon:SetAlpha(0.7)
			btn.tipName = spell.name
			btn.tipRank = spell.rank
			btn.tipDesc = spell.desc
			btn.tipCost = spell.cost
			btn:Show()
		end

		if (offset > 0) then
			self.frame.upcomingPrevArrow:Show()
			self.frame.upcomingPrevArrow:Enable()
		end
		if (offset < maxOffset) then
			self.frame.upcomingNextArrow:Show()
			self.frame.upcomingNextArrow:Enable()
		end

		-- Label stays centered above the fixed-width window regardless
		-- of how many icons are actually showing this scroll position.
		self.frame.upcomingLabel:ClearAllPoints()
		self.frame.upcomingLabel:SetPoint("BOTTOM", self.frame.upcomingFrame, "TOP", 0, 6)
	end;

	-- ==================== POOL FACTORIES =========================

	-- Hides the headers; the spell buttons are shown and hidden by the secure layout
	CleanPages = function(self)
		if (self.frame.rankFlyout) then
			self.frame.rankFlyout:Close()
		end
		for i = 1, totalCategoryItems do
			self.frame["Category".. i]:Hide()
		end
	end;

	GetOrCreateCategory = function(self, i)
		local item = self.frame["Category".. i]
		if (item ~= nil) then
			return item
		end
		totalCategoryItems = totalCategoryItems + 1
		item = MSB_CCategoryItem(self.frame)
		self.frame["Category".. i] = item
		return item
	end;

	GetOrCreateSpellItem = function(self, i)
		local item = self.frame["Spell".. i]
		if (item ~= nil) then
			return item
		end
		item = MSB_CSpellItem(self.frame, i)
		self.frame["Spell".. i] = item
		return item
	end;

	-- =================== TAB MANAGEMENT ==========================

	NewTab = function(self, name)
		local tabNumber = table.getn(self.frame.Tabgroups) + 1

		-- Clicks reach the tab's secure catcher (MSB_SecureBook); this only
		-- runs if the catcher is missing
		local tab = MSB_CTab(self.frame, name, tabNumber, function(clickedTab)
			if (self.frame.selectedTab == clickedTab.tab_number) then return end
			self:SelectTab(clickedTab.tab_number)
		end)

		table.insert(self.frame.Tabgroups, tab)
		return tab
	end;

	-- Switches to a tab on its first page (out of combat; in combat the
	-- tab catchers do this). skipDraw: the caller redraws.
	SelectTab = function(self, tabNumber, skipDraw)
		if (InCombatLockdown()) then return end
		self.frame:SetAttribute("cat", tabNumber)
		if (tabNumber ~= MSB_SecureBook.PET) then self.frame:SetAttribute("cat-book", tabNumber) end
		self.frame:SetAttribute("page", 1)
		if (not skipDraw) then
			MSB_SecureBook.Apply()
		end
	end;

	PositionAllTabs = function(self)
		for _, tab in ipairs(self.frame.Tabgroups) do
			tab:UpdatePosition(self.frame.Tabgroups)
		end
		MSB_SecureBook.PlaceTabCatchers()
		self:LayoutTopBar()
	end;

	-- Vertical centre of the stone strip between the title bar and the separator
	GetStripMiddle = function(self)
		return (MSB_LAYOUT.titleBarHeight - MSB_LAYOUT.separatorTop) / 2
	end;

	-- Fits the search bar between the last tab and the settings cog. Without
	-- room for the search bar the cog moves to the right end of the strip,
	-- so the settings are always reachable.
	LayoutTopBar = function(self)
		local searchBar = self.frame.searchBar
		if (not searchBar or not self.frame.Tabgroups) then return end

		local tabsRight = MSB_LAYOUT.tabsLeft
		for _, tab in ipairs(self.frame.Tabgroups) do
			if (tab:IsShown()) then
				tabsRight = tabsRight + tab:GetWidthWithGap()
			end
		end

		-- Right margin 16, the cog plus its gap, 10 gap after the tabs
		local room = self.frame:GetWidth() - 16 - (MSB_LAYOUT.cogSize + MSB_LAYOUT.cogGap) - 10 - tabsRight
		local width = math.min(SEARCH_MAX_WIDTH, room)
		local cog = self.frame.settingsButton
		if (cog) then cog:ClearAllPoints() end
		if (width >= SEARCH_MIN_WIDTH) then
			searchBar.frame:SetWidth(width)
			searchBar:Show()
			if (cog) then cog:SetPoint("RIGHT", searchBar.frame, "LEFT", -MSB_LAYOUT.cogGap, 0) end
		else
			if (searchBar:IsShown()) then
				-- Clearing a typed search also refreshes the page
				if ((searchBar:GetText() or "") ~= "") then searchBar:Clear() end
				searchBar:Hide()
			end
			if (cog) then cog:SetPoint("RIGHT", self.frame, "TOPRIGHT", -16 + MSB_LAYOUT.cogMargin, -self:GetStripMiddle()) end
		end
	end;

	-- ================= COMPATIBILITY BUTTONS =====================

	-- Registers an addon panel (Clique, What's Training). It is a tab in the
	-- two page view and a side button in the one page view, stacked in the
	-- order the panels were added. Returns the tab.
	-- action = { name, tabLabel, tooltip, icon, texCoord, onClick, isOpen }
	AddCompatAction = function(self, action)
		local frame = self.frame
		frame.compatActions = frame.compatActions or {}

		local tabNumber = table.getn(frame.Tabgroups) + 1
		local tab = MSB_CTab(frame, action.tabLabel, tabNumber, function()
			action.onClick()
		end)
		table.insert(frame.Tabgroups, tab)

		local sideButton = MSB_CSideButton(frame, "ModernSpellBookFrame_Side" .. action.name,
			action.icon, action.texCoord, action.tooltip, action.onClick, action.isOpen)

		table.insert(frame.compatActions, { tab = tab, sideButton = sideButton, isOpen = action.isOpen })
		self:LayoutCompatActions()
		self:PositionAllTabs()
		return tab, sideButton
	end;

	-- Shows each panel as a tab (two pages) or a side button (one page)
	LayoutCompatActions = function(self)
		local actions = self.frame.compatActions
		if (not actions) then return end
		local onePage = ModernSpellBook_DB.isMinimized
		local slot = 0
		for _, action in ipairs(actions) do
			if (onePage) then
				action.tab:Hide()
				slot = slot + 1
				action.sideButton:SetSlot(slot)
				action.sideButton:Show()
				action.sideButton:UpdateChecked()
			else
				action.sideButton:Hide()
				action.tab:Show()
			end
		end
		for _, tab in ipairs(self.frame.Tabgroups) do
			tab:UpdatePosition(self.frame.Tabgroups)
		end
		MSB_SecureBook.PlaceTabCatchers()
	end;

	-- Clique's panel opened or closed: spell clicks switch between casting
	-- and binding
	RefreshCastAttributes = function(self)
		if (InCombatLockdown()) then return end
		MSB_SecureBook.SetBinding(CliqueFrame and CliqueFrame:IsVisible())
		local flyout = self.frame.rankFlyout
		if (flyout) then
			for _, button in ipairs(flyout.buttons) do
				button:ApplyCastAttributes()
			end
		end
	end;

	-- Refreshes the lit state of the side buttons (a panel opened or closed)
	UpdateCompatButtons = function(self)
		local actions = self.frame.compatActions
		if (not actions) then return end
		for _, action in ipairs(actions) do
			action.sideButton:UpdateChecked()
		end
	end;

	-- Where an addon panel opens: beside the window, clear of the side buttons
	GetCompatPanelOffset = function(self)
		if (ModernSpellBook_DB.isMinimized and self.frame.compatActions
			and table.getn(self.frame.compatActions) > 0) then
			return 39
		end
		return 6
	end;

	-- After a view switch: moves open addon panels that sit beside the window,
	-- so they clear the side buttons (one page) or close the gap (two pages).
	-- Panels the player dragged elsewhere are left alone.
	ReplaceCompatPanels = function(self)
		local panels = self.frame.compatPanels
		if (not panels) then return end
		for panel in pairs(panels) do
			if (panel:IsShown()) then
				local _, relativeTo = panel:GetPoint(1)
				if (relativeTo == self.frame) then
					self:PlaceCompatPanel(panel)
				end
			end
		end
	end;

	-- Opens an addon panel beside the window: on the right, else on the
	-- left, else over the window (kept on screen, one strata above it)
	PlaceCompatPanel = function(self, panel)
		local root = self.frame
		root.compatPanels = root.compatPanels or {}
		root.compatPanels[panel] = true
		local scale = panel:GetEffectiveScale()
		local ratio = root:GetEffectiveScale() / scale
		local screen = GetScreenWidth() * UIParent:GetEffectiveScale() / scale
		local offset = self:GetCompatPanelOffset()
		local width = panel:GetWidth()
		local fitsRight = (root:GetRight() or 0) * ratio + offset + width <= screen
		local fitsLeft = (root:GetLeft() or 0) * ratio - 6 - width >= 0
		panel:ClearAllPoints()
		if (fitsRight or not fitsLeft) then
			panel:SetPoint("TOPLEFT", root, "TOPRIGHT", offset, 0)
		else
			panel:SetPoint("TOPRIGHT", root, "TOPLEFT", -6, 0)
		end
		panel:SetFrameStrata((fitsRight or fitsLeft) and "HIGH" or "DIALOG")
	end;

	-- =================== ADDON INTEGRATIONS ======================

	SetupCliqueIntegration = function(self)
		if (MSB_SetupCliqueIntegration) then
			MSB_SetupCliqueIntegration(self)
		end
	end;

	SetupWhatsTrainingIntegration = function(self)
		if (MSB_SetupWhatsTrainingIntegration) then
			MSB_SetupWhatsTrainingIntegration(self)
		end
	end;
}

MSB_SpellBook = MSB_CSpellBook()

-- On level up, let spells you can now train glow again
local levelTracker = CreateFrame("Frame")
levelTracker:RegisterEvent("PLAYER_LEVEL_UP")
levelTracker:SetScript("OnEvent", function()
	for _, entry in pairs(ModernSpellBook_DB.spells) do
		if (not entry.learned) then
			entry.seen_trainable = false
		end
	end
	-- Spells that just became trainable get their "Train" badge right away
	MSB_SpellBook:OnSpellsChanged()
end)
