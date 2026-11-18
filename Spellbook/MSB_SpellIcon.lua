--[[
	MSB_CSpellBookIcon: MSB_CIcon plus the spellbook visuals:
	glows (new, available to train, active stance), the pulsing glow on
	spells not on any action bar, the pet autocast corners and sparks,
	badges (New, Train), round passives, and the unlearned icon cut to
	the frame's opening.
--]]

local SPELLBOOK_ASSETS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Spellbook\\"
local DEFAULT_ICON_SIZE = 28
local DEFAULT_SOCKET_SIZE = 22

-- Square socket under the icon when the icon frame is off
local SOCKET_TEXTURE = SPELLBOOK_ASSETS .. "spell-socket"

-- Passive icons are round, at the scale of a normal 28 px icon (as in
-- 1.12.1). 1.12.1 clips the square icon with a mask texture; 3.3.5a has no
-- masks, and SetPortraitToTexture can't crop the icon's built-in dark edge
-- (it shows as a square inside the ring). So the cropped square icon is cut
-- to a disc out of horizontal strips (see DiscPieces): the same pixels the
-- mask leaves, at any alpha, greyed or not.

-- Passives with the icon frame on: gold ring (64x64 art for a 36 px ring).
-- The ring starts at the icon's edge with a thin dark line, then the gold.
local PASSIVE_RING_TEXTURE = SPELLBOOK_ASSETS .. "passive-ring"
local PASSIVE_RING_PADDING = 8
-- Disc under the ring: where 1.12.1's passive-ring-mask clips the icon
-- (half coverage at radius 13.75), on the ring's dark inner line
local PASSIVE_DISC_RADIUS = 13.75
-- Size of the (hidden) icon quad, which the badges and glows anchor on
local PASSIVE_ICON_SIZE = 30
-- Passives with the icon frame off: round copy of the square socket, with
-- the same rim bands around the icon as the square socket
local PASSIVE_SOCKET_TEXTURE = SPELLBOOK_ASSETS .. "passive-socket"
local PASSIVE_SOCKET_SIZE = 34
local PASSIVE_SOCKET_ICON_SIZE = 26.6
local PASSIVE_SOCKET_DISC_RADIUS = PASSIVE_SOCKET_ICON_SIZE / 2
-- Largest distance of a strip's corner from the true circle, in UI units
-- (about a pixel's width / 6 at the usual UI scales)
local DISC_TOLERANCE = 0.15
-- Hover highlight: the game's CheckButtonHilight, or a round copy of it for
-- passives, sized to sit as far from the opening as the square one
local HOVER_TEXTURE = "Interface\\Buttons\\CheckButtonHilight"
local PASSIVE_HOVER_TEXTURE = SPELLBOOK_ASSETS .. "passive-highlight"
local PASSIVE_HOVER_SIZE = 28
local PASSIVE_SOCKET_HOVER_SIZE = PASSIVE_SOCKET_ICON_SIZE
-- Glow of new and trainable spells: CheckButtonGlow, or for passives a round
-- copy of it (same gold, same 1 px line and falloff, 128 px anti-aliased).
-- At 60 px its line sits on the gold ring's outer edge (radius ~17.4).
local GLOW_TEXTURE = "Interface\\Buttons\\CheckButtonGlow"
local PASSIVE_GLOW_TEXTURE = SPELLBOOK_ASSETS .. "passive-glow"
local GLOW_SIZE = 60
-- In the round socket the line sits on the socket's edge instead
local PASSIVE_SOCKET_GLOW_SIZE = 53
-- Square icons crop their built-in edge (same values as MSB_CIcon)
local ICON_TEXCOORD = { 0.04, 0.96, 0.04, 0.96 }
-- Unlearned spells: greyed out, then tinted slightly warm so they sit on the page
local UNLEARNED_TINT = { 1, 0.93, 0.8 }

-- ============== Unlearned icon inside the square icon frame ==============
-- The frame is half transparent on unlearned spells, so the square icon
-- would show through its cut corners. 3.3.5a has neither mask textures nor
-- vertex offsets, so the icon is drawn as a stack of rects instead: one
-- band filling the opening between the corner cuts, and OCT_STEPS rows above
-- and below it that step in along the cuts. Each row ends where the cut
-- crosses its middle, so the steps sit on the frame's black inner line.
-- Rows share their edges exactly: nothing overlaps or leaves a seam.
--
-- Opening of spellbook-frame (128 px drawn at 46), in UI units from the
-- icon's centre (+y up), at half coverage of the black inner line
local OCT_LEFT, OCT_RIGHT, OCT_TOP, OCT_BOTTOM = -13.295, 13.284, 13.299, -13.371
-- Corner cuts of the opening: h along the top or bottom edge, v along the side
local OCT_CUTS = {
	TL = { h = 2.641, v = 2.875 }, TR = { h = 2.873, v = 2.923 },
	BL = { h = 3.093, v = 2.320 }, BR = { h = 3.328, v = 2.423 },
}
-- Rows per corner cut (each under 0.75 units tall)
local OCT_STEPS = 4

-- Texture coordinate of a point (UI units from the centre) on the cropped
-- 28 px icon, so each piece shows the pixels the square icon had there
local function IconTexCoord(x, y)
	local half = DEFAULT_ICON_SIZE / 2
	local u = ICON_TEXCOORD[1] + (x + half) / DEFAULT_ICON_SIZE * (ICON_TEXCOORD[2] - ICON_TEXCOORD[1])
	local v = ICON_TEXCOORD[3] + (half - y) / DEFAULT_ICON_SIZE * (ICON_TEXCOORD[4] - ICON_TEXCOORD[3])
	return u, v
end

-- The pieces: rect { left, right, top, bottom } from the icon's centre and
-- its texture coordinates { left, right, top, bottom }
local OCTAGON_PIECES = (function()
	local L, R, T, B = OCT_LEFT, OCT_RIGHT, OCT_TOP, OCT_BOTTOM
	-- One height for both top cuts (and both bottom ones): the rows stay rects
	local topV = (OCT_CUTS.TL.v + OCT_CUTS.TR.v) / 2
	local botV = (OCT_CUTS.BL.v + OCT_CUTS.BR.v) / 2
	local rects = {}
	-- Middle band, full width
	table.insert(rects, { L, R, T - topV, B + botV })
	for i = 1, OCT_STEPS do
		-- Fraction of the cut covered at the row's middle, from the outer edge
		local f = (i - 0.5) / OCT_STEPS
		-- Top rows, from the top edge down
		table.insert(rects, {
			L + OCT_CUTS.TL.h * (1 - f), R - OCT_CUTS.TR.h * (1 - f),
			T - topV * (i - 1) / OCT_STEPS, T - topV * i / OCT_STEPS,
		})
		-- Bottom rows, from the bottom edge up
		table.insert(rects, {
			L + OCT_CUTS.BL.h * (1 - f), R - OCT_CUTS.BR.h * (1 - f),
			B + botV * i / OCT_STEPS, B + botV * (i - 1) / OCT_STEPS,
		})
	end
	local pieces = {}
	for _, r in ipairs(rects) do
		local u0, v0 = IconTexCoord(r[1], r[3])
		local u1, v1 = IconTexCoord(r[2], r[4])
		table.insert(pieces, { rect = r, texCoord = { u0, u1, v0, v1 } })
	end
	return pieces
end)()

-- ====================== Round passive icon ======================
-- A disc of the given radius as horizontal strips (rects from the centre,
-- +y up, with their texture coordinates). Each strip is as tall as it can
-- be while its corners stay within DISC_TOLERANCE of the circle, so the
-- strips are tall near the middle and thin near the top and bottom.
-- Neighbours share their edge exactly: nothing overlaps or leaves a seam.
local function DiscPieces(radius)
	local e = DISC_TOLERANCE
	local outer, inner = (radius + e) * (radius + e), (radius - e) * (radius - e)
	-- Outer edge of the strip starting at y0 (>= 0), and its half width
	local function Strip(y0)
		local y1 = math.min(radius, math.sqrt(y0 * y0 + 4 * radius * e))
		local wOut = math.sqrt(math.max(0, outer - y1 * y1))
		local wIn = math.sqrt(math.max(0, inner - y0 * y0))
		return y1, (wOut + wIn) / 2
	end
	local rects = {}
	-- Middle strip, across the centre
	local y, w = Strip(0)
	table.insert(rects, { -w, w, y, -y })
	while (y < radius) do
		local y1
		y1, w = Strip(y)
		table.insert(rects, { -w, w, y1, y })
		table.insert(rects, { -w, w, -y, -y1 })
		y = y1
	end
	local pieces = {}
	for _, r in ipairs(rects) do
		local u0, v0 = IconTexCoord(r[1], r[3])
		local u1, v1 = IconTexCoord(r[2], r[4])
		table.insert(pieces, { rect = r, texCoord = { u0, u1, v0, v1 } })
	end
	return pieces
end
local PASSIVE_RING_PIECES = DiscPieces(PASSIVE_DISC_RADIUS)
local PASSIVE_SOCKET_PIECES = DiscPieces(PASSIVE_SOCKET_DISC_RADIUS)

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
		self.glow_frame, self.glow_tex = MSB_CreateGlow(parent, GLOW_SIZE, nil, 15)

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

		-- The icon cut to a shape (OCTAGON_PIECES, or a disc for passives),
		-- shown instead of self.icon. Made as needed by SetCutPieces.
		self.cut_pieces = {}
		self.cut_shape = nil

		-- Badge: "New" for learned spells (the game's own word)
		self.badge_new = MSB_CreateBadge(parent, MSB_STR.NEW, {1, 0.878, 0.078, 0.7}, {1, 0.9, 0.1, 0.8}, 12)
		self.badge_new:SetPoint("BOTTOM", parent, "TOP", 0, 2)

		-- Badge: "Train" for available spells
		self.badge_train = MSB_CreateBadge(parent, MSB_L.BADGE_TRAIN, {0, 0.8, 0, 0.4}, {0.1, 0.8, 0.1, 0.8}, 7)
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

	-- Whether the icon frame (square frame or gold ring) shows for a spell.
	-- Icon frame setting: "Spells" covers the class and General tabs, "Other"
	-- the pet and "Other" tabs.
	ShowsBorder = function(self, spellInfo)
		local frameSetting = ModernSpellBook_DB and ModernSpellBook_DB.iconFrame
		if (not frameSetting) then return true end
		local is_other_tab = ModernSpellBookFrame.selectedTab and ModernSpellBookFrame.selectedTab > 2
		if (spellInfo.isUnlearned) then
			return frameSetting.unlearned
		elseif (is_other_tab) then
			return frameSetting.other
		end
		return frameSetting.spells
	end;

	-- Round glow around passives, square around the other spells. Called from
	-- SetHighlights, which runs before SetSpell.
	SetGlowShape = function(self, spellInfo)
		local size = GLOW_SIZE
		if (spellInfo.isPassive) then
			self.glow_tex:SetTexture(PASSIVE_GLOW_TEXTURE)
			if (not self:ShowsBorder(spellInfo)) then
				size = PASSIVE_SOCKET_GLOW_SIZE
			end
		else
			self.glow_tex:SetTexture(GLOW_TEXTURE)
		end
		self.glow_frame:SetWidth(size)
		self.glow_frame:SetHeight(size)
	end;

	SetSpell = function(self, spellInfo)

		local showBorder = self:ShowsBorder(spellInfo)

		if (showBorder) then
			self.border_frame:Show()
			self.socket:Hide()
		else
			self.border_frame:Hide()
			self.socket:Show()
		end


		if (spellInfo.isPassive) then
			-- Round icon: the cropped icon cut to a disc (see DiscPieces)
			self.icon:SetTexture(spellInfo.spellIcon)
			self.icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
			self.hover_glow:SetTexture(PASSIVE_HOVER_TEXTURE)
			self.border:SetTexture(PASSIVE_RING_TEXTURE)
			self.border_frame:SetWidth(self.size + PASSIVE_RING_PADDING)
			self.border_frame:SetHeight(self.size + PASSIVE_RING_PADDING)
			if (showBorder) then
				-- Under the gold ring, out to its dark inner line
				self.icon:SetWidth(PASSIVE_ICON_SIZE)
				self.icon:SetHeight(PASSIVE_ICON_SIZE)
				self:SetHoverSize(PASSIVE_HOVER_SIZE)
				self:SetCutPieces(PASSIVE_RING_PIECES, spellInfo.spellIcon)
			else
				-- In the round socket
				self.icon:SetWidth(PASSIVE_SOCKET_ICON_SIZE)
				self.icon:SetHeight(PASSIVE_SOCKET_ICON_SIZE)
				self:SetHoverSize(PASSIVE_SOCKET_HOVER_SIZE)
				self.socket:SetTexture(PASSIVE_SOCKET_TEXTURE)
				self.socket:SetWidth(PASSIVE_SOCKET_SIZE)
				self.socket:SetHeight(PASSIVE_SOCKET_SIZE)
				self:SetCutPieces(PASSIVE_SOCKET_PIECES, spellInfo.spellIcon)
			end
		else
			self.icon:SetTexture(spellInfo.spellIcon)
			self.icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
			self.icon:SetWidth(self.size)
			self.icon:SetHeight(self.size)
			self.hover_glow:SetTexture(HOVER_TEXTURE)
			self:SetHoverSize(self.size)
			self.border:SetTexture(SPELLBOOK_ASSETS .. "spellbook-frame")
			self.border_frame:SetWidth(self.size + 18)
			self.border_frame:SetHeight(self.size + 18)
			self.socket:SetTexture(SOCKET_TEXTURE)
			self.socket:SetWidth(self.size + DEFAULT_SOCKET_SIZE)
			self.socket:SetHeight(self.size + DEFAULT_SOCKET_SIZE)
			-- The frame is faded on unlearned spells: cut the icon to its opening
			if (showBorder and spellInfo.isUnlearned) then
				self:SetCutPieces(OCTAGON_PIECES, spellInfo.spellIcon)
			else
				self:SetCutPieces(nil)
			end
		end
	end;

	-- Hover highlight size (the texture fills its frame)
	SetHoverSize = function(self, size)
		self.hover_frame:SetWidth(size)
		self.hover_frame:SetHeight(size)
	end;

	-- The icon cut to a shape (a list of pieces, see OCTAGON_PIECES and
	-- DiscPieces) in place of self.icon, or the plain icon for nil
	SetCutPieces = function(self, shape, texture)
		local pieces = self.cut_pieces
		if (shape ~= self.cut_shape) then
			local parent = self.icon:GetParent()
			for i, spec in ipairs(shape or {}) do
				local piece = pieces[i]
				if (not piece) then
					piece = parent:CreateTexture(nil, "OVERLAY")
					pieces[i] = piece
				end
				local r = spec.rect
				piece:ClearAllPoints()
				piece:SetPoint("TOPLEFT", parent, "CENTER", r[1], r[3])
				piece:SetPoint("BOTTOMRIGHT", parent, "CENTER", r[2], r[4])
				piece:SetTexCoord(spec.texCoord[1], spec.texCoord[2], spec.texCoord[3], spec.texCoord[4])
			end
			self.cut_shape = shape
			self.cut_count = shape and table.getn(shape) or 0
			-- New pieces take the current look
			self:SetCutColor(self.cut_r or 1, self.cut_g or 1, self.cut_b or 1, self.cut_a or 1)
			self:SetCutDesaturated(self.cut_desaturated)
		end
		for i, piece in ipairs(pieces) do
			if (i <= self.cut_count) then
				piece:SetTexture(texture)
				piece:Show()
			else
				piece:Hide()
			end
		end
		if (shape) then self.icon:Hide() else self.icon:Show() end
	end;

	SetCutColor = function(self, r, g, b, a)
		self.cut_r, self.cut_g, self.cut_b, self.cut_a = r, g, b, a
		for _, piece in ipairs(self.cut_pieces) do
			piece:SetVertexColor(r, g, b)
			piece:SetAlpha(a)
		end
	end;

	SetCutDesaturated = function(self, desaturated)
		self.cut_desaturated = desaturated and true or false
		for _, piece in ipairs(self.cut_pieces) do piece:SetDesaturated(self.cut_desaturated) end
	end;

	SetDesaturated = function(self, desaturated)
		MSB_CIcon.SetDesaturated(self, desaturated)
		self:SetCutDesaturated(desaturated)
	end;

	-- ======================= HIGHLIGHTS ==========================

	SetHighlights = function(self, spellInfo, isNew)
		local hl = ModernSpellBook_DB.highlights

		-- Reset
		self.glow_frame:Hide()
		self.badge_new:Hide()
		self.badge_train:Hide()

		self:SetGlowShape(spellInfo)

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
			self:SetCutColor(UNLEARNED_TINT[1], UNLEARNED_TINT[2], UNLEARNED_TINT[3], 0.5)

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
			self:SetCutColor(1, 1, 1, 1)
		end
	end;

	-- ======================== STANCE =============================

	SetStance = function(self, is_active)
		self.glow_active:SetAlpha(is_active and 1 or 0)
	end;
}
