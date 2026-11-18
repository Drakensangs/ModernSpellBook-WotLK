--[[
	Rank flyout: opened from the arrow under a spell that has more than one
	learned rank. Shows every learned rank as a regular spellbook button
	(click to cast, drag to action bars, shift-click to link, tooltips,
	cooldowns, Clique binding) on a dark panel above the page.
--]]

local ICON_SIZE = 28
local ICON_GAP = 10
local MAX_COLUMNS = 7
local PADDING = 10
local ICONS_TOP = 26        -- space reserved for the title row
local OWNER_GAP = 12        -- distance between the spell icon and the panel
local BOOK_EDGE = 14        -- keep the panel inside the book frame border
local OPEN_DURATION = 0.15  -- opening animation: fade in while sliding into place
local OPEN_SLIDE = 8        -- pixels the panel travels away from the spell
local CLOSE_DURATION = 0.12 -- closing animation: fade out while sliding back
local BORDER_TEXTURE = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\spell_border_gray"

-- Panel colors: dark enough that the page underneath doesn't compete with
-- the rank icons, but still lets a hint of the parchment show through.
local BACKGROUND_COLOR = {0.07, 0.055, 0.04, 0.9}
local BORDER_COLOR = {0.82, 0.66, 0.35, 1}
local ICON_BORDER_COLOR = {0.95, 0.78, 0.42}

local function IsMouseOverFrame(frame)
	if (not frame or not frame:IsVisible()) then return false end
	if (frame.IsMouseOver) then return frame:IsMouseOver() end
	if (MouseIsOver) then return MouseIsOver(frame) end
	return false
end

-- Returns true/false for "any mouse button is down", or nil if the client
-- can't tell us (then outside clicks are caught by the book's OnMouseDown).
local mouseButtonApiWorks = (IsMouseButtonDown ~= nil)
local function IsAnyMouseButtonDown()
	if (not mouseButtonApiWorks) then return nil end
	local ok, left = pcall(IsMouseButtonDown, "LeftButton")
	if (not ok) then
		mouseButtonApiWorks = false
		return nil
	end
	local _, right = pcall(IsMouseButtonDown, "RightButton")
	return (left or right) and true or false
end

-- ============================================================
-- MSB_CRankButton: one rank inside the flyout. Reuses MSB_CSpellItem's click,
-- tooltip, cooldown and drag handlers so it behaves like any other spell.
-- ============================================================

MSB_class "MSB_CRankButton"
:extends("MSB_CSpellItem")
{
	__init = function(self, parent, index)
		self.frame = CreateFrame("Button", "ModernSpellBookRankButton"..index, parent, "SecureActionButtonTemplate")
		self.frame:SetWidth(ICON_SIZE)
		self.frame:SetHeight(ICON_SIZE)
		self.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		self.frame:SetMovable(true)
		self.frame:RegisterForDrag("LeftButton")

		self.spellIcon = MSB_CSpellBookIcon(self.frame)
		self:InstallScripts()
		local rankButton = self
		self.frame:SetScript("OnDragStart", function()
			local info = rankButton.cooldownSpell
			if (info and info.spellID and not InCombatLockdown()) then
				PickupSpell(info.spellID, info.bookType or BOOKTYPE_SPELL)
			end
		end)

		-- Compact look: thin gold border, no socket / leaf frame
		local icon = self.spellIcon
		icon.socket:Hide()
		icon.border:SetTexture(BORDER_TEXTURE)
		icon.border:SetVertexColor(ICON_BORDER_COLOR[1], ICON_BORDER_COLOR[2], ICON_BORDER_COLOR[3])
		icon.border_frame:SetWidth(ICON_SIZE + 4)
		icon.border_frame:SetHeight(ICON_SIZE + 4)
		icon.border_frame:Show()

		-- Rank number in the bottom-right corner (above the cooldown swipe)
		self.rankLabel = icon.border_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.rankLabel:SetPoint("BOTTOMRIGHT", icon.icon, "BOTTOMRIGHT", -1, 2)
		self.rankLabel:SetFont(MSB_GetFont(), 11, "OUTLINE")
		self.rankLabel:SetTextColor(1, 1, 1)
		self.rankLabel:SetJustifyH("RIGHT")

		self.frame:Hide()
	end;

	Set = function(self, spellInfo, x, y)
		self:SetClickHandler(spellInfo)
		self:ApplyCastAttributes()

		self.spellIcon.icon:SetTexture(spellInfo.spellIcon)
		self.spellIcon:SetDesaturated(false)
		self.spellIcon.icon:SetAlpha(1)
		self.spellIcon.border:SetAlpha(1)
		self.rankLabel:SetText(spellInfo.rankNum or "")

		local spellKey = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
		self:SetTooltipHandler(spellInfo, spellKey, false)
		self:SetCooldownAndDrag(spellInfo)

		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", self.frame:GetParent(), "TOPLEFT", x, y)
		self.frame:Show()
	end;
}

-- ============================================================
-- MSB_CRankFlyout: the shared panel (one per spellbook).
-- ============================================================

MSB_class "MSB_CRankFlyout"
{
	__init = function(self, book)
		self.book = book
		self.owner = nil
		self.buttons = {}

		self.frame = CreateFrame("Frame", "ModernSpellBookRankFlyout", book)
		-- Above every spell on the page (their glows reach ~+15 levels)
		self.frame:SetFrameStrata("DIALOG")
		self.frame:SetFrameLevel(book:GetFrameLevel() + 20)
		self.frame:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
		})
		self.frame:SetBackdropColor(BACKGROUND_COLOR[1], BACKGROUND_COLOR[2], BACKGROUND_COLOR[3], BACKGROUND_COLOR[4])
		self.frame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
		-- Swallow clicks on the panel so they never reach spells underneath
		self.frame:EnableMouse(true)
		self.frame:Hide()

		self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING, -9)
		self.title:SetFont(MSB_GetFont(), 10)
		self.title:SetTextColor(1, 0.82, 0)
		self.title:SetJustifyH("LEFT")

		-- Close when clicking anywhere outside the panel / its arrow
		local flyout = self
		self.frame:SetScript("OnUpdate", function(_, elapsed)
			if (flyout.anim) then flyout:StepAnimation(elapsed or arg1 or 0) end

			local isDown = IsAnyMouseButtonDown()
			if (isDown == nil) then return end
			if (isDown and not flyout.wasMouseDown) then
				local overArrow = flyout.owner and IsMouseOverFrame(flyout.owner.rankArrow)
				if (not IsMouseOverFrame(flyout.frame) and not overArrow) then
					flyout:Close()
				end
			end
			flyout.wasMouseDown = isDown
		end)

		-- Fallback for clicks on the book background, and cleanup on close
		book:HookScript("OnMouseDown", function()
			flyout:Close()
		end)
		-- No fade here: OnUpdate doesn't run in a hidden book, so the fade
		-- would stay paused and finish on the next opening (the empty panel
		-- flashed). The panel hides at once with the book.
		book:HookScript("OnHide", function()
			flyout:Close(true)
		end)
	end;

	-- ======================= STATE ===============================

	UpdateCooldowns = function(self)
		if (not self.frame:IsShown()) then return end
		for _, button in ipairs(self.buttons) do
			if (button.frame:IsShown()) then
				button:UpdateCooldown()
			end
		end
	end;

	IsOpenFor = function(self, item)
		return self.owner ~= nil and self.owner == item and self.frame:IsShown()
	end;

	Toggle = function(self, item)
		if (self:IsOpenFor(item)) then
			self:Close()
		else
			self:Open(item)
		end
	end;

	-- immediate: no fade (combat is about to start)
	Close = function(self, immediate)
		-- The panel holds secure buttons: it can't be hidden in combat. It is
		-- closed when combat starts, so it is never open then.
		if (InCombatLockdown()) then return end
		if (self.owner) then
			self.owner:SetRankArrowExpanded(false)
			self.owner = nil
		end
		if (not self.frame:IsShown()) then
			self.anim = nil
			return
		end
		if (immediate) then
			-- Also ends a fade already under way (puts the panel back in place)
			self:FinishClose()
			return
		end
		if (self.anim and self.anim.closing) then return end
		-- Hide the rank buttons up front so they can't be clicked mid-fade
		for _, button in ipairs(self.buttons) do
			button.frame:Hide()
		end
		self:StartCloseAnimation()
	end;

	-- ======================= BUILD ===============================

	GetOrCreateButton = function(self, i)
		local button = self.buttons[i]
		if (not button) then
			button = MSB_CRankButton(self.frame, i)
			self.buttons[i] = button
		end
		return button
	end;

	MakeRankEntry = function(self, rankInfo)
		local entry = {}
		for key, value in pairs(rankInfo) do
			entry[key] = value
		end
		entry.learnedRanks = nil
		entry.isRankEntry = true
		return entry
	end;

	Open = function(self, item)
		if (InCombatLockdown()) then return end
		local spellInfo = item.spellInfo
		local ranks = spellInfo and spellInfo.learnedRanks
		if (not ranks or table.getn(ranks) < 2) then return end

		self:Close()
		self.owner = item

		local count = table.getn(ranks)
		local rows = math.ceil(count / MAX_COLUMNS)
		local columns = math.ceil(count / rows)

		self.title:SetText(spellInfo.spellName)
		local titleWidth = self.title.GetStringWidth and self.title:GetStringWidth() or 0

		local gridWidth = columns * ICON_SIZE + (columns - 1) * ICON_GAP
		local width = math.max(gridWidth + 2 * PADDING, titleWidth + 2 * PADDING)
		local height = ICONS_TOP + rows * ICON_SIZE + (rows - 1) * ICON_GAP + PADDING + 2
		local gridX = math.floor((width - gridWidth) / 2)

		for i = 1, count do
			local column = math.fmod(i - 1, columns)
			local row = math.floor((i - 1) / columns)
			self:GetOrCreateButton(i):Set(
				self:MakeRankEntry(ranks[i]),
				gridX + column * (ICON_SIZE + ICON_GAP),
				-(ICONS_TOP + row * (ICON_SIZE + ICON_GAP))
			)
		end
		for i = count + 1, table.getn(self.buttons) do
			self.buttons[i].frame:Hide()
		end

		self.frame:SetWidth(width)
		self.frame:SetHeight(height)
		self.gridX = gridX
		self:Position(item, width, height, gridX)

		item:SetRankArrowExpanded(true)
		self.wasMouseDown = IsAnyMouseButtonDown()
		self:StartAnimation()
		self.frame:Show()
	end;

	-- ======================= ANIMATION ===========================

	-- Starts transparent and slightly closer to the spell, then eases into place
	StartAnimation = function(self)
		local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
		if (not point) then return end
		self.anim = {
			elapsed = 0,
			point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
			-- A panel below the spell slides down, a flipped one slides up
			dy = self.isFlipped and -OPEN_SLIDE or OPEN_SLIDE,
		}
		self:ApplyAnimation(0)
	end;

	StepAnimation = function(self, elapsed)
		local anim = self.anim
		anim.elapsed = anim.elapsed + elapsed
		if (anim.closing) then
			local t = anim.elapsed / CLOSE_DURATION
			if (t >= 1 or InCombatLockdown()) then
				self:FinishClose()
			else
				self:ApplyCloseAnimation(t * t)   -- ease-in
			end
			return
		end
		local t = anim.elapsed / OPEN_DURATION
		if (t >= 1 or InCombatLockdown()) then
			self:StopAnimation()
		else
			self:ApplyAnimation(1 - (1 - t) * (1 - t) * (1 - t))   -- ease-out
		end
	end;

	ApplyAnimation = function(self, progress)
		local anim = self.anim
		self.frame:SetAlpha(progress)
		-- The panel holds secure buttons: it can only move out of combat
		if (not InCombatLockdown()) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint,
				anim.x, anim.y + anim.dy * (1 - progress))
		end
	end;

	-- Jumps to the final state (animation finished, interrupted or closed)
	StopAnimation = function(self)
		local anim = self.anim
		if (not anim) then return end
		if (anim.closing) then
			self:FinishClose()
			return
		end
		self.anim = nil
		self.frame:SetAlpha(1)
		if (not InCombatLockdown()) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint, anim.x, anim.y)
		end
	end;

	-- Closing: fades out while sliding back the way the panel came in
	StartCloseAnimation = function(self)
		local point, relativeTo, relativePoint, x, y = self.frame:GetPoint(1)
		if (not point) then
			self:FinishClose()
			return
		end
		self.anim = {
			closing = true,
			elapsed = 0,
			alpha = self.frame:GetAlpha() or 1,
			point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y,
			dy = self.isFlipped and -OPEN_SLIDE or OPEN_SLIDE,
		}
		self:ApplyCloseAnimation(0)
	end;

	ApplyCloseAnimation = function(self, progress)
		local anim = self.anim
		self.frame:SetAlpha(anim.alpha * (1 - progress))
		-- The panel holds secure buttons: it can only move out of combat
		if (not InCombatLockdown()) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint,
				anim.x, anim.y + anim.dy * progress)
		end
	end;

	-- Close animation done (or impossible): hide the panel for real
	FinishClose = function(self)
		local anim = self.anim
		self.anim = nil
		self.frame:SetAlpha(1)
		if (anim and not InCombatLockdown()) then
			self.frame:ClearAllPoints()
			self.frame:SetPoint(anim.point, anim.relativeTo, anim.relativePoint, anim.x, anim.y)
		end
		self.frame:Hide()
	end;

	-- Below the spell (first rank lined up with the spell icon), kept
	-- inside the book; flips above the spell near the bottom of the page.
	Position = function(self, item, width, height, gridX)
		local book = self.book
		local owner = item.frame
		self.frame:ClearAllPoints()
		self.isFlipped = false

		local bookLeft, bookTop = book:GetLeft(), book:GetTop()
		local ownerLeft, ownerTop, ownerBottom = owner:GetLeft(), owner:GetTop(), owner:GetBottom()
		if (not bookLeft or not bookTop or not ownerLeft or not ownerTop or not ownerBottom) then
			self.frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -gridX, -OWNER_GAP)
			return
		end

		local x = (ownerLeft - bookLeft) - gridX
		x = math.max(BOOK_EDGE, math.min(x, book:GetWidth() - BOOK_EDGE - width))

		local y = (ownerBottom - bookTop) - OWNER_GAP
		if (y - height < -(book:GetHeight() - BOOK_EDGE)) then
			y = (ownerTop - bookTop) + OWNER_GAP + height
			self.isFlipped = true
		end

		self.frame:SetPoint("TOPLEFT", book, "TOPLEFT", x, y)
	end;
}
