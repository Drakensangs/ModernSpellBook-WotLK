-- Combat edges: the settings and view-toggle buttons are disabled while in
-- combat, and the spellbook is told when combat starts and ends
-- (MSB_CSpellBook:OnCombatStart/OnCombatEnd).

MSB_class "MSB_CCombatGuard"
{
	__init = function(self)
		self.frame = CreateFrame("Frame", "MSB_CombatGuardFrame")
		self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

		self.disabledFrames = {}

		local guard = self
		self.frame:SetScript("OnEvent", function()
			if (event == "PLAYER_REGEN_DISABLED") then
				guard:OnEnterCombat()
			elseif (event == "PLAYER_REGEN_ENABLED") then
				guard:OnLeaveCombat()
			end
		end)
	end;

	RegisterCombatDisabledFrame = function(self, frame)
		if (not frame) then return end
		for _, existing in ipairs(self.disabledFrames) do
			if (existing == frame) then return end
		end
		table.insert(self.disabledFrames, frame)

		if (InCombatLockdown()) then
			frame:Disable()
		end
	end;

	-- Fires before the lockdown starts
	OnEnterCombat = function(self)
		for _, frame in ipairs(self.disabledFrames) do
			if (frame.Disable) then frame:Disable() end
		end

		if (CloseDropDownMenus) then
			securecall(CloseDropDownMenus)
		end
		if (MSB_SpellBook) then MSB_SpellBook:OnCombatStart() end
	end;

	OnLeaveCombat = function(self)
		for _, frame in ipairs(self.disabledFrames) do
			if (frame.Enable) then frame:Enable() end
		end
		if (MSB_SpellBook) then MSB_SpellBook:OnCombatEnd() end
	end;
}

MSB_CombatGuard = MSB_CCombatGuard()
