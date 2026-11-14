--[[
	Window frame: slim metal border, title bar with two button sockets,
	the dark stone strip behind the tabs and the metal separator bar
	between the tabs and the pages.

	All pieces come from Assets\Frame\frame-chrome (Blizzard's world map
	border and character screen stone). Long pieces are seamless tiles
	repeated along the edge, so the metal keeps its detail at any size.
--]]

-- Window layout shared by the spellbook, its tabs and the top bar.
-- Y values are offsets from the top of the window.
MSB_LAYOUT = {
	titleBarHeight = 24,
	titleTextY = -11,		-- centre of the title bar's stone
	-- The pages meet the metal's inner edge on every side (tucked 1 px under
	-- it so no backing shows through at fractional UI scales): the metal ends
	-- 8 px in from the window's sides and bottom and 62 px from its top.
	pageTop = -61,			-- right below the separator's metal line
	separatorTop = -54,		-- top of the separator bar (its metal line is 2 px lower)
	tabBottom = -59,		-- tab bottoms tuck under the separator's metal line
	tabCatcherHeight = 33,	-- the selected (tallest) tab
	pageLeft = 7,
	pageRight = -7,
	pageBottom = 7,
	pageSplit = 527,		-- x where the right page starts
	-- Page contents, placed relative to the pages above
	contentTop = -83,		-- first category header / spell row
	footerBottom = 18,		-- spell counter and trainer hint, below the bottom ornament
	pageTextBottom = 56,	-- "Page x / y" and its arrows
	tabsLeft = 56,			-- first tab, clear of the portrait
	-- Centre of the portrait ring, from the top-left corner. Its 31.5 unit
	-- radius overhangs the window by ~11 units on the left and top.
	portraitX = 20,
	portraitY = -20,
	-- Centres of the two title bar sockets, from the top-right corner
	sockets = { { x = -36, y = -11 }, { x = -14, y = -11 } },
	-- Blizzard's 32x32 panel buttons draw their art half a pixel left of centre
	socketButtonOffsetX = 0.5,
	-- Settings cog left of the search bar: frame size, transparent margin
	-- around the cog art and the visible gap to the search bar
	cogSize = 24,
	cogMargin = 3,
	cogGap = 9,				-- plus cogMargin: 12 px from the cog art to the search bar
	-- Side buttons (Clique, What's Training) in the one page view
	sideButtonTop = -65,
	sideButtonSpacing = 49,
}

local ATLAS = "Interface\\AddOns\\ModernSpellBook\\Assets\\Frame\\frame-chrome"
local ATLAS_WIDTH, ATLAS_HEIGHT = 512, 128

-- Pieces on the atlas: { left, top, right, bottom } in pixels.
-- Tiles have a 1 px wrapped copy on each repeating edge so scaled windows
-- don't show seams between repeats.
local RECT = {
	title          = {   2,  0, 202, 26 },	-- horizontal tile (rows 0-1: outer outline)
	strip          = {   2, 32, 202, 66 },	-- horizontal tile
	topLeft        = { 264,  0, 296, 26 },
	topRight       = { 300,  0, 381, 26 },	-- includes both sockets
	left           = { 264, 61, 278, 125 },	-- vertical tile, along the pages
	leftPlain      = { 282, 61, 296, 125 },	-- vertical tile, next to the stone strip
	right          = { 300, 61, 314, 125 },
	rightPlain     = { 318, 61, 332, 125 },
	bottom         = { 340, 64, 404, 78 },	-- horizontal tile
	separator      = { 410, 64, 474, 78 },	-- horizontal tile: the bottom profile upside down
	bottomLeft     = { 386, 40, 400, 54 },
	bottomRight    = { 406, 40, 420, 54 },
	-- Where the separator meets the sides (mitred inner corner). They replace
	-- the sides over their height and carry a 2 px apron of the neighbouring
	-- art on the atlas, so the joins stay seamless at any UI scale.
	junctionLeft   = { 424, 84, 442, 106 },
	junctionRight  = { 452, 84, 470, 106 },
}

local function Size(rect)
	return rect[3] - rect[1], rect[4] - rect[2]
end

local STRIP_INSET = 4		-- the strip runs under the side borders (whose inner rim is see-through)
-- The top pieces carry the sides' outer outline (dark line plus faint
-- shadow) in two rows above the metal, so they sit this far above the window.
local TOP_OUTLINE = 2
local JUNCTION_TOP = 50		-- top of the junction pieces, from the top of the window
local JUNCTION_BOTTOM = 72	-- the sides start again here

MSB_class "MSB_CFrameChrome"
{
	__init = function(self, parent)
		self.parent = parent
		self.pools = {}

		-- Border pieces sit on their own frame, above the pages, tabs and bookmark
		self.frame = CreateFrame("Frame", nil, parent)
		self.frame:SetAllPoints(parent)
		self.frame:SetFrameLevel(parent:GetFrameLevel() + 2)

		-- Solid backing for anything the pages don't cover
		self.fill = parent:CreateTexture(nil, "BACKGROUND")
		self.fill:SetTexture(0.05, 0.045, 0.04, 1)
		self.fill:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
		self.fill:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
	end;

	-- ======================== PIECES =============================

	-- Reuses textures between layouts instead of creating new ones
	NextPiece = function(self, owner, layer, x1, y1, x2, y2)
		local pool = self.pools[owner]
		if (not pool) then
			pool = { used = 0 }
			self.pools[owner] = pool
		end
		pool.used = pool.used + 1
		local piece = pool[pool.used]
		if (not piece) then
			piece = owner:CreateTexture(nil, layer)
			piece:SetTexture(ATLAS)
			pool[pool.used] = piece
		end
		piece:SetDrawLayer(layer)
		piece:SetTexCoord(x1 / ATLAS_WIDTH, x2 / ATLAS_WIDTH, y1 / ATLAS_HEIGHT, y2 / ATLAS_HEIGHT)
		piece:ClearAllPoints()
		piece:Show()
		return piece
	end;

	-- A whole piece at its natural size, pinned to one corner
	Place = function(self, owner, layer, rect, point, x, y)
		local piece = self:NextPiece(owner, layer, rect[1], rect[2], rect[3], rect[4])
		local width, height = Size(rect)
		piece:SetWidth(width)
		piece:SetHeight(height)
		piece:SetPoint(point, self.parent, point, x, y)
		return piece
	end;

	-- Repeats a horizontal tile leftwards from `right` (distance from the
	-- right edge), so the right end always lines up with the next piece.
	-- `point` is TOPRIGHT (y from the top) or BOTTOMRIGHT (y from the bottom).
	TileLeftward = function(self, owner, layer, rect, point, right, y, length)
		local tileWidth, height = Size(rect)
		local offset = 0
		while (offset < length) do
			local chunk = math.min(tileWidth, length - offset)
			local piece = self:NextPiece(owner, layer, rect[3] - chunk, rect[2], rect[3], rect[4])
			piece:SetWidth(chunk)
			piece:SetHeight(height)
			piece:SetPoint(point, self.parent, point, -(right + offset), y)
			offset = offset + chunk
		end
	end;

	-- Repeats a vertical tile downwards from `top` (distance from the top).
	-- `point` is TOPLEFT or TOPRIGHT, the side it hugs.
	TileDownward = function(self, owner, layer, rect, point, top, length)
		local width, tileHeight = Size(rect)
		local offset = 0
		while (offset < length) do
			local chunk = math.min(tileHeight, length - offset)
			local piece = self:NextPiece(owner, layer, rect[1], rect[2], rect[3], rect[2] + chunk)
			piece:SetWidth(width)
			piece:SetHeight(chunk)
			piece:SetPoint(point, self.parent, point, 0, -(top + offset))
			offset = offset + chunk
		end
	end;

	-- Repeats the separator tile between the two junctions. Whole tiles run
	-- rightwards from the left junction starting on the tile's first column,
	-- and the last, partial piece ends on the tile's last column, so the
	-- metal's speckle runs straight into both junction pieces.
	TileSeparator = function(self, owner, layer, rect, left, y, length)
		local tileWidth, height = Size(rect)
		local whole = math.floor(length / tileWidth)
		local rest = length - whole * tileWidth
		for i = 0, whole - 1 do
			local piece = self:NextPiece(owner, layer, rect[1], rect[2], rect[3], rect[4])
			piece:SetWidth(tileWidth)
			piece:SetHeight(height)
			piece:SetPoint("TOPLEFT", self.parent, "TOPLEFT", left + i * tileWidth, y)
		end
		if (rest > 0) then
			local piece = self:NextPiece(owner, layer, rect[3] - rest, rect[2], rect[3], rect[4])
			piece:SetWidth(rest)
			piece:SetHeight(height)
			piece:SetPoint("TOPLEFT", self.parent, "TOPLEFT", left + whole * tileWidth, y)
		end
	end;

	-- ======================== LAYOUT =============================

	-- Call after every size change
	Layout = function(self)
		for _, pool in pairs(self.pools) do
			for i = 1, pool.used do
				pool[i]:Hide()
			end
			pool.used = 0
		end

		local width = math.floor(self.parent:GetWidth() + 0.5)
		local height = math.floor(self.parent:GetHeight() + 0.5)
		local border = self.frame
		local titleBarHeight = MSB_LAYOUT.titleBarHeight
		local topLeftWidth = Size(RECT.topLeft)
		local topRightWidth = Size(RECT.topRight)
		local _, bottomHeight = Size(RECT.bottom)
		local cornerWidth = Size(RECT.bottomLeft)

		-- Stone strip behind the tabs (on the main frame so tabs draw above it)
		self:TileLeftward(self.parent, "BORDER", RECT.strip, "TOPRIGHT",
			STRIP_INSET, -titleBarHeight, width - 2 * STRIP_INSET)

		-- Title bar
		self:Place(border, "ARTWORK", RECT.topLeft, "TOPLEFT", 0, TOP_OUTLINE)
		self:Place(border, "ARTWORK", RECT.topRight, "TOPRIGHT", 0, TOP_OUTLINE)
		self:TileLeftward(border, "ARTWORK", RECT.title, "TOPRIGHT",
			topRightWidth, TOP_OUTLINE, width - topLeftWidth - topRightWidth)

		-- Sides: plain next to the strip, and the page variant along the
		-- pages. They stop for the junction pieces where the separator joins.
		self:TileDownward(border, "ARTWORK", RECT.leftPlain, "TOPLEFT",
			titleBarHeight, JUNCTION_TOP - titleBarHeight)
		self:TileDownward(border, "ARTWORK", RECT.left, "TOPLEFT",
			JUNCTION_BOTTOM, height - JUNCTION_BOTTOM - bottomHeight)
		self:TileDownward(border, "ARTWORK", RECT.rightPlain, "TOPRIGHT",
			titleBarHeight, JUNCTION_TOP - titleBarHeight)
		self:TileDownward(border, "ARTWORK", RECT.right, "TOPRIGHT",
			JUNCTION_BOTTOM, height - JUNCTION_BOTTOM - bottomHeight)

		-- Bottom: one bar between two corners
		self:Place(border, "ARTWORK", RECT.bottomLeft, "BOTTOMLEFT", 0, 0)
		self:Place(border, "ARTWORK", RECT.bottomRight, "BOTTOMRIGHT", 0, 0)
		self:TileLeftward(border, "ARTWORK", RECT.bottom, "BOTTOMRIGHT",
			cornerWidth, 0, width - 2 * cornerWidth)

		-- Separator between the tabs and the pages, above the tabs so their
		-- bottoms tuck under it. Its ends are the junction pieces, which take
		-- the sides' place there so the bars join instead of crossing.
		local junctionWidth = Size(RECT.junctionLeft)
		self:TileSeparator(border, "OVERLAY", RECT.separator,
			junctionWidth, MSB_LAYOUT.separatorTop, width - 2 * junctionWidth)
		self:Place(border, "OVERLAY", RECT.junctionLeft, "TOPLEFT", 0, -JUNCTION_TOP)
		self:Place(border, "OVERLAY", RECT.junctionRight, "TOPRIGHT", 0, -JUNCTION_TOP)
	end;
}
