--[[
	Keeps the "active" marker on stance, form, aura and presence spells
	in sync with the one currently in use.
--]]

MSB_class "MSB_CStanceTracker"
{
	__init = function(self)
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
		self.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

		self.frame:SetScript("OnEvent", function()
			if (not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
			if (not ModernSpellBookFrame.stanceButtons) then return end

			local activeName = nil
			for i = 1, 20 do
				local texture, name, isActive = GetShapeshiftFormInfo(i)
				if (not texture) then break end
				if (isActive) then
					activeName = name
					break
				end
			end

			for stanceName, stanceButton in pairs(ModernSpellBookFrame.stanceButtons) do
				stanceButton:SetStance(stanceName == activeName)
			end
		end)
	end;
}

local stanceTracker = MSB_CStanceTracker()
