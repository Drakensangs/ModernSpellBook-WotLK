--[[
	Slash commands:
	/msb          - Open or close the spellbook
	/msb reset    - Reset settings to defaults (keeps the spell cache)
	/msb rescan   - Forget unlearned spells found at trainers; they're
	                rescanned on your next trainer visit
--]]

MSB_class "MSB_CSlashCommands"
{
	__init = function(self)
		self.enabled = true

		SLASH_MODERNSPELLBOOK1 = "/msb"
		local commands = self
		SlashCmdList["MODERNSPELLBOOK"] = function(msg)
			commands:OnCommand(msg or "")
		end
	end;

	OnCommand = function(self, msg)
		local cmd = string.lower(msg)
		cmd = string.gsub(cmd, "^%s+", "")
		cmd = string.gsub(cmd, "%s+$", "")

		if (cmd == "") then
			self:Toggle()
		elseif (cmd == "reset") then
			self:ResetSettings()
		elseif (cmd == "rescan") then
			self:ClearTrainerCache()
		else
			self:PrintHelp()
		end
	end;

	-- Like the spellbook key, but plain code can't open the protected
	-- window in combat: the key, micro button and Escape still work there
	Toggle = function(self)
		if (InCombatLockdown()) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r /msb can't open the book in combat. Use your spellbook key.")
			return
		end
		if (MSB_SpellBook.isSetUp) then MSB_SecureBook.Toggle(false) end
	end;

	-- Back to MSB_DEFAULTS, applied at once. The spell cache survives.
	ResetSettings = function(self)
		-- Moving and scaling the window is blocked in combat
		if (InCombatLockdown()) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Can't reset settings in combat.")
			return
		end
		local old = ModernSpellBook_DB
		ModernSpellBook_DB = {
			dbVersion = old.dbVersion,
			spells = old.spells or {},
			trainerScanned = old.trainerScanned,
			trainerServiceCount = old.trainerServiceCount,
			trainerCostsSaved = old.trainerCostsSaved,
		}
		MSB_ApplyDefaults(ModernSpellBook_DB)
		MSB_SpellBook:ApplySettings()

		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Settings reset to defaults.")
	end;

	ClearTrainerCache = function(self)
		if (ModernSpellBook_DB.trainerScanned) then
			-- Drop every spell that was only seen at a trainer
			local keysToRemove = {}
			for key, entry in pairs(ModernSpellBook_DB.spells) do
				if (not entry.learned) then
					table.insert(keysToRemove, key)
				end
			end
			for _, key in ipairs(keysToRemove) do
				ModernSpellBook_DB.spells[key] = nil
			end
			ModernSpellBook_DB.trainerScanned = false
			ModernSpellBook_DB.trainerServiceCount = nil
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Trainer cache cleared. Visit a trainer to rescan.")

			MSB_SpellBook:MarkDirty()
			if (ModernSpellBookFrame and ModernSpellBookFrame:IsVisible()) then
				MSB_SpellBook:DrawPage()
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r No trainer cache to clear.")
		end
	end;

	PrintHelp = function(self)
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook|r commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  /msb - Open or close the spellbook")
		DEFAULT_CHAT_FRAME:AddMessage("  /msb reset - Reset settings to defaults")
		DEFAULT_CHAT_FRAME:AddMessage("  /msb rescan - Forget trainer spells (rescanned on your next visit)")
	end;
}

local slashCommands = MSB_CSlashCommands()
