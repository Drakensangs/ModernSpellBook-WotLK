--[[
	MSB_CIcon: a plain icon widget (socket, icon, square and round borders,
	hover highlight, optional cooldown) with no spellbook logic.
	Parts are used directly (icon.border:SetTexture(...)); methods only
	cover changes that touch several parts at once.
--]]

local DEFAULT_ICON_SIZE = 28

MSB_class "MSB_CIcon"
{
	__init = function(self, parent, size)
		self.parent = parent
		self.size = size or DEFAULT_ICON_SIZE

		-- Socket background
		self.socket = parent:CreateTexture(nil, "ARTWORK")
		self.socket:SetWidth(self.size)
		self.socket:SetHeight(self.size)
		self.socket:SetPoint("CENTER", parent, "CENTER", 0, 0)

		-- Icon texture
		self.icon = parent:CreateTexture(nil, "OVERLAY")
		self.icon:SetWidth(self.size)
		self.icon:SetHeight(self.size)
		self.icon:SetPoint("CENTER", parent, "CENTER", 0, 0)
		self.icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

		-- Border frame overlay
		self.border_frame = CreateFrame("Frame", nil, parent)
		self.border_frame:SetWidth(self.size)
		self.border_frame:SetHeight(self.size)
		self.border_frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
		self.border_frame:SetFrameLevel(parent:GetFrameLevel() + 3)
		self.border = self.border_frame:CreateTexture(nil, "OVERLAY")
		self.border:SetAllPoints(self.border_frame)

		-- Hover highlight
		self.hover_frame, self.hover_glow = MSB_CreateGlow(parent, self.size, nil, 4, "Interface\\Buttons\\CheckButtonHilight")
		self.hover_frame:SetPoint("CENTER", self.icon, "CENTER", 0, 0)
		self.hover_frame:Show()
		self.hover_glow:SetAlpha(0.5)
		self.hover_glow:Hide()

		-- Cooldown
		local cdName = parent:GetName() and (parent:GetName() .. "Cooldown") or nil
		local cd_ok, cd_frame = pcall(CreateFrame, "Cooldown", cdName, parent, "CooldownFrameTemplate")
		if (cd_ok and cd_frame) then
			self.cooldown = cd_frame
			self.cooldown:SetPoint("TOPLEFT", self.icon, "TOPLEFT", 0, 0)
			self.cooldown:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", 0, 0)
			if (self.cooldown.SetDrawEdge) then
				self.cooldown:SetDrawEdge(false)
			end
		else
			self.cooldown = nil
		end
	end;

	SetDesaturated = function(self, desaturated)
		self.socket:SetDesaturated(desaturated)
	self.icon:SetDesaturated(desaturated)
		self.border:SetDesaturated(desaturated)
		self.hover_glow:SetDesaturated(desaturated)
	end;
}
