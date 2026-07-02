class "CCombatGuard"
{
	__init = function(self)
		self.frame = CreateFrame("Frame", "MSB_CombatGuardFrame")
		self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

		self.disabledFrames = {}

		if (SpellBookFrame and CreateFrame) then
			self.spellbookCloseProxy = CreateFrame("Frame", "MSB_SpellbookCloseProxy", nil, "SecureHandlerStateTemplate")
			self.spellbookCloseProxy:SetFrameRef("spellbook", SpellBookFrame)
			self.spellbookCloseProxy:SetAttribute("_onstate-msbcombat", [[
				if newstate == "combat" then
					local book = self:GetFrameRef("spellbook")
					if book:IsShown() then
						book:Hide()
					end
				end
			]])
			RegisterStateDriver(self.spellbookCloseProxy, "msbcombat", "[combat] combat; nocombat")
		end

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

	CanOpenSpellbook = function(self)
		if (InCombatLockdown()) then
			self:WarnCannotOpen()
			return false
		end
		return true
	end;

	WarnCannotOpen = function(self)
		local now = GetTime()
		if (self.lastWarnTime and now - self.lastWarnTime < 2) then return end
		self.lastWarnTime = now

		if (UIErrorsFrame) then
			UIErrorsFrame:AddMessage("Cannot open spellbook while in combat.", 1.0, 0.1, 0.1, 1.0)
		end
	end;

	OnEnterCombat = function(self)
		for _, frame in ipairs(self.disabledFrames) do
			if (frame.Disable) then frame:Disable() end
		end

		if (CloseDropDownMenus) then
			securecall(CloseDropDownMenus)
		end

	end;

	OnLeaveCombat = function(self)
		for _, frame in ipairs(self.disabledFrames) do
			if (frame.Enable) then frame:Enable() end
		end

	end;
}

MSB_CombatGuard = CCombatGuard()
