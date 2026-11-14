--[[
	MSB_CSpellBookIcon: MSB_CIcon plus the spellbook visuals:
	glows (new, available to train, active stance), the pulsing glow on
	spells not on any action bar, the pet autocast corners and sparks,
	and badges (New, Train).
--]]

local SPELLBOOK_ASSETS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\"
local DEFAULT_ICON_SIZE = 28
local DEFAULT_SOCKET_SIZE = 22

-- Passive spells: smooth gold ring around a round (portrait) icon.
-- The texture is 64x64 so it scales down to the ~36px ring without aliasing.
local PASSIVE_RING_TEXTURE = SPELLBOOK_ASSETS .. "passive-ring"
local PASSIVE_RING_PADDING = 8
-- Every spell icon has a thin frame baked into its edge. Drawing the round
-- passive icon a bit larger than the button tucks that frame under the
-- gold ring, so it never shows inside the circle.
local PASSIVE_ICON_SIZE = 34
-- Square icons crop their built-in edge (same values as MSB_CIcon)
local ICON_TEXCOORD = { 0.04, 0.96, 0.04, 0.96 }
-- Unlearned spells: greyed out, then tinted slightly warm so they sit on the page
local UNLEARNED_TINT = { 1, 0.93, 0.8 }

-- Glow traced on the icon frame's octagon (art from DragonUI's spellbook).
-- The ring sits on the frame's inner edge at this size for a 28 icon.
local UNPLACED_TEXTURE = SPELLBOOK_ASSETS .. "unplaced-glow"
local UNPLACED_SIZE = 39
local UNPLACED_TEXCOORD = 127 / 128

-- Pet autocast: gold corners when the spell can autocast, and sparks
-- circling the icon while autocast is on (as on the pet action bar).
local AUTOCAST_CORNERS_TEXTURE = SPELLBOOK_ASSETS .. "autocast-corners"
local AUTOCAST_CORNERS_TEXCOORD = 90 / 128
local AUTOCAST_CORNERS_SIZE = 30
local SPARK_TEXTURE = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
local SPARK_SIZES = { 12, 9, 6, 4 }
local SPARK_LAP_SECONDS = { 8, 16, 24, 32 }

-- One driver moves the sparks of every visible pet spell
local sparkEmitters = {}
local sparkClock = 0
local sparkDriver = CreateFrame("Frame")
sparkDriver:Hide()

-- Point at fraction t (0..1) of the way around a square, from its top-left corner
local function Perimeter(t, side)
	local u = math.fmod(t, 1) * 4
	local edge = math.floor(u)
	local f = u - edge
	if (edge == 0) then return f * side, 0 end
	if (edge == 1) then return side, -f * side end
	if (edge == 2) then return side - f * side, -side end
	return 0, f * side - side
end

sparkDriver:SetScript("OnUpdate", function(self, elapsed)
	elapsed = elapsed or arg1 or 0
	sparkClock = sparkClock + elapsed
	local any = false
	for emitter in pairs(sparkEmitters) do
		if (emitter:IsVisible()) then
			any = true
			local side = emitter:GetWidth()
			for _, dot in ipairs(emitter.dots) do
				dot:SetPoint("CENTER", emitter, "TOPLEFT", Perimeter(sparkClock / dot.lap + dot.lane, side))
			end
		elseif (not emitter:IsShown()) then
			sparkEmitters[emitter] = nil
		end
	end
	if (not any) then self:Hide() end
end)

local function CreateSparks(parent, anchor)
	local emitter = CreateFrame("Frame", nil, parent)
	emitter:SetAllPoints(anchor)
	emitter.dots = {}
	for lane = 0, 3 do
		for size = 1, 4 do
			local dot = emitter:CreateTexture(nil, "OVERLAY")
			dot:SetWidth(SPARK_SIZES[size])
			dot:SetHeight(SPARK_SIZES[size])
			dot:SetTexture(SPARK_TEXTURE)
			dot:SetTexCoord(0.3984375, 0.4453125, 0.40234375, 0.44921875)
			dot:SetBlendMode("ADD")
			dot:SetVertexColor(0.95, 0.95, 0.32)
			dot.lap = SPARK_LAP_SECONDS[size]
			dot.lane = lane / 4
			table.insert(emitter.dots, dot)
		end
	end
	emitter:Hide()
	return emitter
end

MSB_class "MSB_CSpellBookIcon"
:extends("MSB_CIcon")
{
	__init = function(self, parent)
		MSB_CIcon.__init(self, parent, DEFAULT_ICON_SIZE)

		-- Spellbook socket & border textures
		self.socket:SetTexture(SPELLBOOK_ASSETS .. "spell-socket")
		self.socket:SetHeight(self.size + DEFAULT_SOCKET_SIZE)
		self.socket:SetWidth(self.size + DEFAULT_SOCKET_SIZE)

		-- Glow: shared for new/available highlights (changes color)
		self.glow_frame, self.glow_tex = MSB_CreateGlow(parent, 60, nil, 15)

		-- Pulsing glow: spell is not on any action bar. Drawn right on the
		-- icon frame, above it but below the rank arrow.
		self.unplaced_frame = CreateFrame("Frame", nil, parent)
		self.unplaced_frame:SetFrameLevel(parent:GetFrameLevel() + 5)
		self.unplaced_frame:SetAllPoints(self.icon)
		self.unplaced = self.unplaced_frame:CreateTexture(nil, "OVERLAY")
		self.unplaced:SetTexture(UNPLACED_TEXTURE)
		self.unplaced:SetTexCoord(0, UNPLACED_TEXCOORD, 0, UNPLACED_TEXCOORD)
		self.unplaced:SetBlendMode("ADD")
		self.unplaced:SetWidth(UNPLACED_SIZE)
		self.unplaced:SetHeight(UNPLACED_SIZE)
		self.unplaced:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.unplaced_frame:Hide()

		-- Pet autocast corners and sparks, above the icon frame
		self.autocast_frame = CreateFrame("Frame", nil, parent)
		self.autocast_frame:SetFrameLevel(parent:GetFrameLevel() + 6)
		self.autocast_frame:SetAllPoints(self.icon)
		self.autocast_corners = self.autocast_frame:CreateTexture(nil, "OVERLAY")
		self.autocast_corners:SetTexture(AUTOCAST_CORNERS_TEXTURE)
		self.autocast_corners:SetTexCoord(0, AUTOCAST_CORNERS_TEXCOORD, 0, AUTOCAST_CORNERS_TEXCOORD)
		self.autocast_corners:SetWidth(AUTOCAST_CORNERS_SIZE)
		self.autocast_corners:SetHeight(AUTOCAST_CORNERS_SIZE)
		self.autocast_corners:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.autocast_corners:Hide()
		self.autocast_sparks = CreateSparks(self.autocast_frame, self.icon)

		-- Badge: "New" for learned spells
		self.badge_new = MSB_CreateBadge(parent, "New", {1, 0.878, 0.078, 0.7}, {1, 0.9, 0.1, 0.8}, 12)
		self.badge_new:SetPoint("BOTTOM", parent, "TOP", 0, 2)

		-- Badge: "Train" for available spells
		self.badge_train = MSB_CreateBadge(parent, "Train", {0, 0.8, 0, 0.4}, {0.1, 0.8, 0.1, 0.8}, 7)
		self.badge_train:SetPoint("BOTTOM", self.icon, "TOP", 0, 2)

		-- Glow: stance active indicator
		self.glow_active_frame = CreateFrame("Frame", nil, parent)
		self.glow_active_frame:SetWidth(self.size + 2)
		self.glow_active_frame:SetHeight(self.size + 2)
		self.glow_active_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.glow_active_frame:SetFrameLevel(parent:GetFrameLevel() + 5)
		self.glow_active = self.glow_active_frame:CreateTexture(nil, "OVERLAY")
		self.glow_active:SetWidth(self.size + 2)
		self.glow_active:SetHeight(self.size + 2)
		self.glow_active:SetAllPoints(self.glow_active_frame)
		self.glow_active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		self.glow_active:SetBlendMode("ADD")
		self.glow_active:SetAlpha(0)

	end;

	-- ========================= STYLE =============================

	SetSpell = function(self, spellInfo)

		local showBorder = true

		if (ModernSpellBook_DB and ModernSpellBook_DB.iconFrame) then
			local is_other_tab = ModernSpellBookFrame.selectedTab and ModernSpellBookFrame.selectedTab > 2
			if (spellInfo.isUnlearned) then
				showBorder = ModernSpellBook_DB.iconFrame.unlearned
			elseif (is_other_tab) then
				showBorder = ModernSpellBook_DB.iconFrame.other
			else
				showBorder = ModernSpellBook_DB.iconFrame.spells
			end
		end

		if (showBorder) then
			self.border_frame:Show()
			self.socket:Hide()
		else
			self.border_frame:Hide()
			self.socket:Show()
		end


		if (spellInfo.isPassive) then
			-- Round icon: use the full portrait (no edge crop), so the circle
			-- stays perfectly round and the ring covers its edge evenly.
			SetPortraitToTexture(self.icon, spellInfo.spellIcon)
			self.icon:SetTexCoord(0, 1, 0, 1)
			self.icon:SetWidth(PASSIVE_ICON_SIZE)
			self.icon:SetHeight(PASSIVE_ICON_SIZE)
			-- Passives get no hover highlight (it showed as a square around the ring)
			self.hover_glow:Hide()
			self.border:SetTexture(PASSIVE_RING_TEXTURE)
			self.border_frame:SetWidth(self.size + PASSIVE_RING_PADDING)
			self.border_frame:SetHeight(self.size + PASSIVE_RING_PADDING)
			self.socket:Hide()
		else
			self.icon:SetTexture(spellInfo.spellIcon)
			self.icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
			self.icon:SetWidth(self.size)
			self.icon:SetHeight(self.size)
			self.hover_glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
			self.border:SetTexture(SPELLBOOK_ASSETS .. "spellbook-frame")
			self.border_frame:SetWidth(self.size + 18)
			self.border_frame:SetHeight(self.size + 18)
		end


	end;

	-- ======================= HIGHLIGHTS ==========================

	SetHighlights = function(self, spellInfo, isNew)
		local hl = ModernSpellBook_DB.highlights

		-- Reset
		self.glow_frame:Hide()
		self.badge_new:Hide()
		self.badge_train:Hide()

		-- Newly learned: gold glow and "New" badge
		if (isNew and not spellInfo.isPassive) then
			if (hl and hl.learnedGlow) then
				self.glow_tex:SetVertexColor(1, 1, 1)
				self.glow_frame:ClearAllPoints()
				self.glow_frame:SetPoint("CENTER", self.icon, "CENTER", 0.5, 0)
				self.glow_frame:Show()
			end
			if (hl and hl.learnedBadge) then
				self.badge_new:Show()
			end
			return
		end

		-- Trainable now: blue glow and green "Train" badge
		if (spellInfo.isUnlearned and not spellInfo.isTalent and spellInfo.levelReq) then
			local player_level = UnitLevel("player")
			local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
			local entry = ModernSpellBook_DB.spells[key]
			local already_seen = entry and entry.seen_trainable
			if (spellInfo.levelReq <= player_level and not already_seen and not spellInfo.talentBlocked) then
				if (hl and hl.availableGlow) then
					self.glow_tex:SetVertexColor(0.204, 0.765, 0.922)
					self.glow_frame:ClearAllPoints()
					self.glow_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
					self.glow_frame:Show()
				end
				if (hl and hl.availableBadge) then
					self.badge_train:Show()
				end
			end
		end
	end;

	DismissNewHighlight = function(self)
		self.glow_frame:Hide()
		self.badge_new:Hide()
		self:RefreshUnplacedGlow()
	end;

	-- Hidden while a new/available glow is showing, so only one cue shows at a time
	SetUnplaced = function(self, isUnplaced)
		self.isUnplaced = isUnplaced
		self:RefreshUnplacedGlow()
	end;

	RefreshUnplacedGlow = function(self)
		if (self.isUnplaced and not self.glow_frame:IsShown()) then
			self.unplaced_frame:Show()
			MSB_StartPulse(self.unplaced)
		else
			self.unplaced_frame:Hide()
			MSB_StopPulse(self.unplaced)
		end
	end;

	-- ======================== AUTOCAST ===========================

	-- allowed: the pet spell can autocast; enabled: autocast is on
	SetAutocast = function(self, allowed, enabled)
		if (allowed) then
			self.autocast_corners:Show()
		else
			self.autocast_corners:Hide()
		end
		if (enabled) then
			self.autocast_sparks:Show()
			sparkEmitters[self.autocast_sparks] = true
			sparkDriver:Show()
		else
			self.autocast_sparks:Hide()
			sparkEmitters[self.autocast_sparks] = nil
		end
	end;

	DismissAvailableHighlight = function(self, spellInfo)
		-- Either cue may be on its own (the glow and badge are separate options)
		if (self.glow_frame:IsShown() or self.badge_train:IsShown()) then
			self.glow_frame:Hide()
			self.badge_train:Hide()
			local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
			local entry = ModernSpellBook_DB.spells[key]
			if (entry) then
				entry.seen_trainable = true
			end
		end
	end;

	-- ===================== LEARNED STATE =========================

	SetLearnedState = function(self, spellInfo)
		if (spellInfo.isUnlearned) then
			self:SetDesaturated(true)
			self.socket:SetAlpha(0.5)
			self.icon:SetAlpha(0.5)
			self.border:SetAlpha(0.5)
			-- Warm the grey towards the parchment tone
			self.icon:SetVertexColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3])
			self.border:SetVertexColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3])

			local show_unlearned = ModernSpellBook_DB and ModernSpellBook_DB.iconFrame and ModernSpellBook_DB.iconFrame.unlearned
			if (not show_unlearned) then
				self.border_frame:Hide()
			end

			self.hover_glow:Hide()
		else
			self:SetDesaturated(false)
			self.socket:SetAlpha(1.0)
			self.icon:SetAlpha(1.0)
			self.border:SetAlpha(1.0)
			self.icon:SetVertexColor(1, 1, 1)
			self.border:SetVertexColor(1, 1, 1)
		end
	end;

	-- ======================== STANCE =============================

	SetStance = function(self, is_active)
		self.glow_active:SetAlpha(is_active and 1 or 0)
	end;
}
