--[[
	Slash commands for ModernSpellBook.
	/msb reset    - Reset all settings to defaults
	/msb rescan   - Clear trainer cache (rescan on next trainer visit)
--]]

class "CSlashCommands"
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

	-- ======================= COMMANDS =============================

	ResetSettings = function(self)
		local dbVersion = ModernSpellBook_DB.dbVersion
		local spells = ModernSpellBook_DB.spells
		local trainerScanned = ModernSpellBook_DB.trainerScanned

		ModernSpellBook_DB = {
			dbVersion = dbVersion,
			spells = spells or {},
			trainerScanned = trainerScanned,
			showPassives = true,
			isMinimized = false,
			showSpellCounter = true,
			rememberPage = true,
			showUnlearned = true,
			fontSize = 11.5,
			showAllRanks = false,
			highlights = { learnedGlow = true, learnedBadge = true, availableGlow = true, availableBadge = true },
		}

		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Settings reset to defaults. /reload to apply.")
	end;

	ClearTrainerCache = function(self)
		if (ModernSpellBook_DB.trainerScanned) then
			-- Remove all unlearned spell entries
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

			if (ModernSpellBookFrame:IsVisible()) then
				SpellBook:DrawPage()
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r No trainer cache to clear.")
		end
	end;

	PrintHelp = function(self)
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook|r commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  /msb reset - Reset settings to defaults")
		DEFAULT_CHAT_FRAME:AddMessage("  /msb rescan - Clear trainer cache")
	end;
}

SlashCommands = CSlashCommands()
