--[[
	Secure layer of the spellbook, so it works in combat the way DragonUI's
	does. Out of combat the addon lays out every tab and publishes the result
	as attributes on the window. Restricted snippets then open and close the
	window, switch tabs, turn pages and place the spell buttons from those
	attributes, which the client allows in combat. The visuals follow through
	MSB_Sync.

	Works in combat: open/close (keys, micro button, Escape, close button),
	tabs, pages, mouse wheel, casting, dragging player spells, links and the
	What's Training panel.
	Out of combat only: search, settings, rank flyout, resize, moving,
	the one/two page toggle, the Clique panel, dragging pet spells and any
	change to the spell list.
--]]

-- Category ids: 1 class, 2 general, 3 pet (also the tab catchers' IDs)
local PET = 3
local CATEGORIES = 3

local GRID_BARS = {
	{ "MultiBarBottomLeft", 6 }, { "MultiBarBottomRight", 5 },
	{ "MultiBarRight", 3 }, { "MultiBarLeft", 4 },
}

-- Snippets. "root" is the window; slots without a position are hidden.
local LAYOUT = [[
local cat = root:GetAttribute("cat") or 1
local pages = root:GetAttribute("pages-" .. cat)
local page = root:GetAttribute("page") or 1
-- Not published yet (first opening): the remembered page is kept
if pages then
	if page > pages then page = pages end
	if page < 1 then page = 1 end
	root:SetAttribute("page", page)
end
pages = pages or 1
local binding = root:GetAttribute("binding")
for slot = 1, root:GetAttribute("slots") or 0 do
	local seat = root:GetFrameRef("slot" .. slot)
	local key = cat .. "-" .. page .. "-" .. slot
	local x = root:GetAttribute("x-" .. key)
	if x then
		local cast = root:GetAttribute("c-" .. key)
		local auto = root:GetAttribute("a-" .. key)
		if binding then cast, auto = nil, nil end
		seat:ClearAllPoints()
		seat:SetPoint("TOPLEFT", root, "TOPLEFT", x, root:GetAttribute("y-" .. key))
		seat:SetAttribute("type1", cast and "spell" or nil)
		seat:SetAttribute("spell1", cast)
		if auto then
			seat:SetAttribute("type2", "macro")
			seat:SetAttribute("macrotext2", auto)
			seat:SetAttribute("spell2", nil)
		else
			seat:SetAttribute("type2", (cast and cat ~= 3) and "spell" or nil)
			seat:SetAttribute("spell2", cast)
		end
		seat:SetAttribute("shift-type1", (not binding) and "macro" or nil)
		seat:SetAttribute("msb-index", root:GetAttribute("i-" .. key))
		seat:SetAttribute("msb-book", root:GetAttribute("b-" .. key))
		seat:Show()
	else
		seat:Hide()
	end
end
local back, forward = root:GetFrameRef("back"), root:GetFrameRef("forward")
if pages > 1 then
	back:Show()
	forward:Show()
	if page > 1 then back:Enable() else back:Disable() end
	if page < pages then forward:Enable() else forward:Disable() end
else
	back:Hide()
	forward:Hide()
end
]]

-- Spellbook key (LeftButton) and pet book key (RightButton), as Blizzard's
-- ToggleSpellBook: the key of the open book closes it, the other switches.
local TOGGLE = [[
local root = self:GetFrameRef("root")
local cat = root:GetAttribute("cat") or 1
local shown = root:IsShown()
if wantPet then
	if not root:GetAttribute("has-pet") then return end
	if shown and cat == 3 then
		root:Hide()
		return
	end
	cat = 3
else
	if shown and cat ~= 3 then
		root:Hide()
		return
	end
	cat = root:GetAttribute("cat-book") or 1
end
if not shown and not root:GetAttribute("remember") then
	if cat ~= 3 then cat = 1 end
	root:SetAttribute("cat-book", 1)
	root:SetAttribute("page", 1)
end
if cat ~= root:GetAttribute("cat") then root:SetAttribute("page", 1) end
root:SetAttribute("cat", cat)
]] .. LAYOUT .. [[
if shown then
	control:CallMethod("MSB_Sync")
else
	root:Show()
end
]]

local STEP = [[
local root = self:GetFrameRef("root")
local page = (root:GetAttribute("page") or 1) + self:GetAttribute("step")
if page < 1 or page > (root:GetAttribute("pages-" .. (root:GetAttribute("cat") or 1)) or 1) then return end
root:SetAttribute("page", page)
]] .. LAYOUT .. [[
control:CallMethod("MSB_Sync")
]]

local WHEEL = [[
local root = self
local page = (root:GetAttribute("page") or 1) + ((delta > 0) and -1 or 1)
if page < 1 or page > (root:GetAttribute("pages-" .. (root:GetAttribute("cat") or 1)) or 1) then return end
root:SetAttribute("page", page)
]] .. LAYOUT .. [[
control:CallMethod("MSB_Sync")
]]

local TAB = [[
local root = self:GetFrameRef("root")
local cat = self:GetID()
if root:GetAttribute("cat") == cat then return end
root:SetAttribute("cat", cat)
if cat ~= 3 then root:SetAttribute("cat-book", cat) end
root:SetAttribute("page", 1)
]] .. LAYOUT .. [[
control:CallMethod("MSB_Sync")
]]

-- Picked up by Blizzard's secure drag handler, so this works in combat.
-- Pet spells wait for the end of combat: their slots can shift.
local DRAG = [[
local index = self:GetAttribute("msb-index")
if not index then return end
local book = self:GetAttribute("msb-book")
if book == "pet" and PlayerInCombat() then return end
return "spell", index, book
]]

-- The pet tab follows the pet, also in combat
local PET_STATE = [[
local root = self
local hasPet = (newstate == "1") or nil
root:SetAttribute("has-pet", hasPet)
local tab = root:GetFrameRef("tab3")
if tab then
	if hasPet then tab:Show() else tab:Hide() end
end
if not hasPet and root:GetAttribute("cat") == 3 then
	root:SetAttribute("cat", root:GetAttribute("cat-book") or 1)
	root:SetAttribute("page", 1)
]] .. LAYOUT .. [[
end
if root:IsShown() then control:CallMethod("MSB_Sync") end
]]

-- Empty action slots show while the book is open: each bar button keeps a
-- "showgrid" count, and Blizzard ignores changes to it from addon code.
local GRID_SHOW = [[
if self:GetAttribute("msb-grid") then return end
self:SetAttribute("msb-grid", true)
for i = 1, self:GetAttribute("msb-gridcount") or 0 do
	local button = self:GetFrameRef("msb-grid" .. i)
	button:SetAttribute("showgrid", (button:GetAttribute("showgrid") or 0) + 1)
	if not button:GetAttribute("statehidden") then button:Show(true) end
end
]]

local GRID_HIDE = [[
if not self:GetAttribute("msb-grid") then return end
self:SetAttribute("msb-grid", nil)
for i = 1, self:GetAttribute("msb-gridcount") or 0 do
	local button = self:GetFrameRef("msb-grid" .. i)
	local count = button:GetAttribute("showgrid") or 0
	if count > 0 then
		count = count - 1
		button:SetAttribute("showgrid", count)
	end
	if count == 0 and not HasAction(self:GetAttribute("msb-gridslot" .. i)) then button:Hide(true) end
end
]]

-- Escape closes the open book (bound only while it is shown)
local ON_SHOW = [[
for i = 1, select("#", GetBindingKey("TOGGLEGAMEMENU")) do
	local key = select(i, GetBindingKey("TOGGLEGAMEMENU"))
	self:SetBindingClick(true, key, "ModernSpellBookFrameCloseButton")
end
]] .. GRID_SHOW

local ON_HIDE = [[
self:ClearBindings()
]] .. GRID_HIDE

local APPLY = "local root = self\n" .. LAYOUT .. 'control:CallMethod("MSB_Sync")'
local OPEN = "local root = self\n" .. LAYOUT .. 'if root:IsShown() then control:CallMethod("MSB_Sync") else root:Show() end'

MSB_SecureBook = {
	PET = PET,
	CATEGORIES = CATEGORIES,
	slots = 0,
	published = {},
	built = false,
}
local Book = MSB_SecureBook

function Book.Locked()
	return InCombatLockdown()
end

-- Red error text for actions that wait for the end of combat
function Book.RefuseInCombat()
	if (not InCombatLockdown()) then return false end
	UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "You can't do that while in combat", 1.0, 0.1, 0.1, 1.0)
	return true
end

function Book.IsOpen()
	return Book.root ~= nil and Book.root:IsShown() and true or false
end

-- ====================== PUBLISHING ==============================

-- One more secure spell button (out of combat only)
local function AddSlot(spellBook)
	local root = Book.root
	local index = Book.slots + 1
	local item = spellBook:GetOrCreateSpellItem(index)
	local seat = item.frame
	seat:SetAttribute("_ondragstart", DRAG)
	seat:SetAttribute("_onreceivedrag", DRAG)
	seat:SetAttribute("checkselfcast", true)
	seat:SetAttribute("shift-macrotext1", "")
	SecureHandlerSetFrameRef(root, "slot" .. index, seat)
	Book.slots = index
	root:SetAttribute("slots", index)
end

-- Publishes one tab's pages: per page and slot the position, what a click
-- casts, what a right click does and what a drag picks up. Only changed
-- attributes are written.
function Book.Publish(spellBook, cat, model)
	local root = Book.root
	local wanted = {}
	local pages = model and model.pages or {}
	wanted["pages-" .. cat] = math.max(1, table.getn(pages))
	for page, elements in ipairs(pages) do
		local slot = 0
		for _, element in ipairs(elements) do
			if (not element.isCategory) then
				slot = slot + 1
				while (slot > Book.slots) do AddSlot(spellBook) end
				local info = element.spellInfo
				local key = cat .. "-" .. page .. "-" .. slot
				local x, y = spellBook:GetSpellItemPosition(element)
				wanted["x-" .. key] = x
				wanted["y-" .. key] = y
				if (not info.isUnlearned and not info.isPassive) then
					wanted["c-" .. key] = info.isPetSpell and info.spellName or info.castName
					if (info.spellID) then
						wanted["i-" .. key] = info.spellID
						wanted["b-" .. key] = info.bookType
					end
					if (info.isPetSpell and info.canAutocast) then
						wanted["a-" .. key] = "/petautocasttoggle " .. info.spellName
					end
				end
			end
		end
	end
	local previous = Book.published[cat] or {}
	for name in pairs(previous) do
		if (wanted[name] == nil) then root:SetAttribute(name, nil) end
	end
	for name, value in pairs(wanted) do
		if (previous[name] ~= value) then root:SetAttribute(name, value) end
	end
	Book.published[cat] = wanted
end

-- Places the buttons for the current tab and page, then redraws
function Book.Apply()
	if (not Book.built or Book.Locked()) then return end
	SecureHandlerExecute(Book.root, APPLY)
end

-- Out of combat only: the window is protected
function Book.Open(pet)
	if (not Book.built or Book.Locked()) then return end
	local root = Book.root
	local cat = root:GetAttribute("cat-book") or 1
	if (pet and root:GetAttribute("has-pet")) then cat = PET end
	if (not root:IsShown() and not root:GetAttribute("remember")) then
		if (cat ~= PET) then cat = 1 end
		root:SetAttribute("cat-book", 1)
		root:SetAttribute("page", 1)
	end
	if (cat ~= root:GetAttribute("cat")) then root:SetAttribute("page", 1) end
	root:SetAttribute("cat", cat)
	SecureHandlerExecute(root, OPEN)
end

function Book.Close()
	if (Book.IsOpen() and not Book.Locked()) then Book.root:Hide() end
end

function Book.Toggle(pet)
	if (Book.IsOpen() and (not pet) == (Book.root:GetAttribute("cat") ~= PET)) then
		Book.Close()
	else
		Book.Open(pet)
	end
end

-- Out of combat: switches tab (page 1) and redraws
function Book.SelectTab(cat)
	if (not Book.built or Book.Locked()) then return end
	local root = Book.root
	root:SetAttribute("cat", cat)
	if (cat ~= PET) then root:SetAttribute("cat-book", cat) end
	root:SetAttribute("page", 1)
	Book.Apply()
end

function Book.SetPage(page)
	if (not Book.built or Book.Locked()) then return end
	Book.root:SetAttribute("page", page)
	Book.Apply()
end

-- Clique's binding panel is open: spell clicks bind instead of casting
function Book.SetBinding(binding)
	if (not Book.built or Book.Locked()) then return end
	Book.root:SetAttribute("binding", binding and true or nil)
	Book.Apply()
end

function Book.SetRemember(remember)
	if (not Book.built or Book.Locked()) then return end
	Book.root:SetAttribute("remember", remember and true or nil)
end

-- ====================== SECURE PIECES ===========================

local function SetupGrids(root)
	local count = 0
	for _, bar in ipairs(GRID_BARS) do
		local barFrame = _G[bar[1]]
		local page = (barFrame and barFrame:GetAttribute("actionpage")) or bar[2]
		for i = 1, (NUM_MULTIBAR_BUTTONS or 12) do
			local button = _G[bar[1] .. "Button" .. i]
			if (button and not button.noGrid) then
				count = count + 1
				SecureHandlerSetFrameRef(root, "msb-grid" .. count, button)
				root:SetAttribute("msb-gridslot" .. count, button:GetID() + (page - 1) * (NUM_ACTIONBAR_BUTTONS or 12))
			end
		end
	end
	root:SetAttribute("msb-gridcount", count)
end

-- Page arrows: secure, anchored to the window (the page number follows them)
local function BuildArrow(root, direction, step)
	local arrow = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
	arrow:SetWidth(25)
	arrow:SetHeight(25)
	arrow:RegisterForClicks("LeftButtonUp")
	local art = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
	arrow:SetNormalTexture(art .. "Up")
	arrow:SetPushedTexture(art .. "Down")
	arrow:SetDisabledTexture(art .. "Disabled")
	arrow:SetHighlightTexture(art .. "Down")
	arrow:SetAttribute("step", step)
	SecureHandlerSetFrameRef(arrow, "root", root)
	arrow:SetAttribute("_onclick", STEP)
	arrow:Hide()
	return arrow
end

-- Invisible secure button over a core tab (class, general, pet). The tab
-- itself stays plain so it can be restyled and moved in combat.
local function BuildTabCatcher(root, tab, cat)
	local catcher = CreateFrame("Button", "ModernSpellBookFrame_TabCatcher" .. cat, root, "SecureHandlerClickTemplate")
	catcher:SetID(cat)
	catcher:RegisterForClicks("LeftButtonUp")
	catcher:SetFrameLevel(tab.frame:GetFrameLevel() + 5)
	SecureHandlerSetFrameRef(catcher, "root", root)
	catcher:SetAttribute("_onclick", TAB)
	catcher:SetScript("OnEnter", function()
		tab.frame:LockHighlight()
		tab.frame:GetFontString():SetTextColor(1, 1, 1)
	end)
	catcher:SetScript("OnLeave", function()
		tab.frame:UnlockHighlight()
		tab:SetDefaultFontColor()
	end)
	if (cat == PET) then SecureHandlerSetFrameRef(root, "tab3", catcher) end
	return catcher
end

-- Over the micro button, never anchored to it: that would make the button
-- and its bar protected (DragonUI's approach)
function Book.PlaceMicroCatcher()
	local catcher = Book.microCatcher
	if (not catcher or Book.Locked()) then return end
	if (SecureCmdOptionParse("[vehicleui] hide; show") == "hide") then return end
	local button = SpellbookMicroButton
	local left, bottom, width, height
	if (button) then left, bottom, width, height = button:GetRect() end
	if (not left or not button:IsVisible()) then
		catcher:Hide()
		return
	end
	local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	catcher:ClearAllPoints()
	catcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
	catcher:SetWidth(width * ratio)
	catcher:SetHeight(height * ratio)
	catcher:SetFrameStrata(button:GetFrameStrata())
	catcher:SetFrameLevel(button:GetFrameLevel() + 5)
	catcher:Show()
end

local function BuildMicroCatcher(root)
	local catcher = CreateFrame("Button", "ModernSpellBookMicroCatcher", UIParent,
		"SecureHandlerClickTemplate,SecureHandlerStateTemplate")
	catcher:Hide()
	catcher:RegisterForClicks("LeftButtonUp")
	SecureHandlerSetFrameRef(catcher, "root", root)
	catcher:SetAttribute("_onclick", "local wantPet = false\n" .. TOGGLE)
	-- The vehicle bar takes the micro buttons; the catcher is placed again when
	-- they return (UpdateMicroButtons), or at the end of combat
	catcher:SetAttribute("_onstate-vehicle", [[if newstate == "hide" then self:Hide() end]])
	catcher.MSB_Sync = root.MSB_Sync
	catcher:SetScript("OnEnter", function(self)
		Book.PlaceMicroCatcher()
		if (not self:IsShown() or not MouseIsOver(self)) then return end
		if (MicroButtonTooltipText and GameTooltip_AddNewbieTip) then
			GameTooltip_AddNewbieTip(self, MicroButtonTooltipText(SPELLBOOK_ABILITIES_BUTTON, "TOGGLESPELLBOOK"),
				1.0, 1.0, 1.0, NEWBIE_TOOLTIP_SPELLBOOK)
		end
		SpellbookMicroButton:LockHighlight()
	end)
	catcher:SetScript("OnLeave", function()
		SpellbookMicroButton:UnlockHighlight()
		GameTooltip:Hide()
	end)
	RegisterStateDriver(catcher, "vehicle", "[vehicleui] hide; show")
	Book.microCatcher = catcher

	-- Reaching the real button means the catcher is not over it
	local button = SpellbookMicroButton
	if (button) then
		button:HookScript("OnEnter", Book.PlaceMicroCatcher)
		button:HookScript("OnShow", Book.PlaceMicroCatcher)
		button:HookScript("OnHide", Book.PlaceMicroCatcher)
	end
end

-- The spellbook and pet book keys click the toggle button instead
local keyOwner, lastKeys
function Book.BindKeys()
	if (not keyOwner) then return end
	if (Book.Locked()) then
		Book.keysPending = true
		return
	end
	Book.keysPending = nil
	local bookKeys = { GetBindingKey("TOGGLESPELLBOOK") }
	local petKeys = { GetBindingKey("TOGGLEPETBOOK") }
	local signature = table.concat(bookKeys, " ") .. "/" .. table.concat(petKeys, " ")
	if (signature == lastKeys) then return end
	lastKeys = signature
	ClearOverrideBindings(keyOwner)
	for _, key in ipairs(bookKeys) do
		SetOverrideBindingClick(keyOwner, false, key, "ModernSpellBookToggle", "LeftButton")
	end
	for _, key in ipairs(petKeys) do
		SetOverrideBindingClick(keyOwner, false, key, "ModernSpellBookToggle", "RightButton")
	end
end

-- Out of combat, once. root: ModernSpellBookFrame; spellBook: MSB_SpellBook.
function Book.Build(spellBook)
	if (Book.built) then return end
	local root = spellBook.frame
	Book.root = root

	root.MSB_Sync = function() spellBook:Sync() end
	root:SetAttribute("_onshow", ON_SHOW)
	root:SetAttribute("_onhide", ON_HIDE)
	root:SetAttribute("_onmousewheel", WHEEL)
	root:SetAttribute("_onstate-msbpet", PET_STATE)
	SetupGrids(root)

	local close = CreateFrame("Button", "ModernSpellBookFrameCloseButton", root, "SecureHandlerClickTemplate")
	close:SetWidth(32)
	close:SetHeight(32)
	close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
	close:GetHighlightTexture():SetBlendMode("ADD")
	close:RegisterForClicks("AnyUp")
	SecureHandlerSetFrameRef(close, "root", root)
	close:SetAttribute("_onclick", [[self:GetFrameRef("root"):Hide()]])
	Book.closeButton = close

	local back = BuildArrow(root, "Prev", -1)
	local forward = BuildArrow(root, "Next", 1)
	SecureHandlerSetFrameRef(root, "back", back)
	SecureHandlerSetFrameRef(root, "forward", forward)
	Book.back, Book.forward = back, forward

	Book.tabCatchers = {}
	for cat = 1, CATEGORIES do
		Book.tabCatchers[cat] = BuildTabCatcher(root, spellBook.frame.Tabgroups[cat], cat)
	end

	local toggle = CreateFrame("Button", "ModernSpellBookToggle", UIParent, "SecureHandlerClickTemplate")
	toggle:Hide()
	toggle:RegisterForClicks("AnyUp")
	SecureHandlerSetFrameRef(toggle, "root", root)
	toggle:SetAttribute("_onclick", 'local wantPet = (button == "RightButton")\n' .. TOGGLE)
	toggle.MSB_Sync = root.MSB_Sync
	for _, catcher in ipairs(Book.tabCatchers) do catcher.MSB_Sync = root.MSB_Sync end
	back.MSB_Sync, forward.MSB_Sync = root.MSB_Sync, root.MSB_Sync

	BuildMicroCatcher(root)
	keyOwner = CreateFrame("Frame")
	Book.built = true

	-- The pet tab exists while there is a pet
	RegisterStateDriver(root, "msbpet", "[pet] 1; 0")
	Book.BindKeys()
	Book.PlaceMicroCatcher()
end

-- Tab catchers follow the tabs' layout (out of combat)
function Book.PlaceTabCatchers()
	if (not Book.built) then return end
	if (Book.Locked()) then
		Book.catchersPending = true
		return
	end
	Book.catchersPending = nil
	local root = Book.root
	-- The pet tab's catcher is placed even while hidden: a pet summoned in
	-- combat shows it through the secure pet state
	for cat, catcher in ipairs(Book.tabCatchers) do
		local tab = root.Tabgroups[cat]
		catcher:ClearAllPoints()
		catcher:SetPoint("BOTTOMLEFT", root, "TOPLEFT", tab.leftOffset or MSB_LAYOUT.tabsLeft, MSB_LAYOUT.tabBottom)
		catcher:SetWidth(tab.frame:GetWidth())
		catcher:SetHeight(MSB_LAYOUT.tabCatcherHeight)
		if (cat ~= PET or root:GetAttribute("has-pet")) then
			catcher:Show()
		else
			catcher:Hide()
		end
	end
end
