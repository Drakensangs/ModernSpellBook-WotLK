--[[
	Search bar: filters the book as you type (spell name, rank, category,
	"talent", and the description on clients that provide one). Has a
	placeholder, search icon and clear button.
--]]

MSB_class "MSB_CSearchBar"
{
	__init = function(self, parent, placeholderText, onTextChanged)
		self.frame = CreateFrame("EditBox", "ModernSpellBookFrameSearchBar", parent)
		self.frame:SetWidth(200)
		self.frame:SetHeight(20)
		self.frame:SetAutoFocus(false)
		self.frame:SetFontObject(ChatFontNormal)
		self.frame:SetTextInsets(16, 20, 0, 0)

		-- Background
		local left = self.frame:CreateTexture(nil, "BACKGROUND")
		left:SetTexture("Interface\\Common\\Common-Input-Border")
		left:SetWidth(8)
		left:SetHeight(20)
		left:SetPoint("LEFT", self.frame, "LEFT", -5, 0)
		left:SetTexCoord(0, 0.0625, 0, 0.625)

		local right = self.frame:CreateTexture(nil, "BACKGROUND")
		right:SetTexture("Interface\\Common\\Common-Input-Border")
		right:SetWidth(8)
		right:SetHeight(20)
		right:SetPoint("RIGHT", self.frame, "RIGHT", 5, 0)
		right:SetTexCoord(0.9375, 1, 0, 0.625)

		local mid = self.frame:CreateTexture(nil, "BACKGROUND")
		mid:SetTexture("Interface\\Common\\Common-Input-Border")
		mid:SetWidth(10)
		mid:SetHeight(20)
		mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
		mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
		mid:SetTexCoord(0.0625, 0.9375, 0, 0.625)

		-- Search icon
		self.searchIcon = self.frame:CreateTexture(nil, "OVERLAY")
		self.searchIcon:SetWidth(14)
		self.searchIcon:SetHeight(14)
		-- The glass sits high in its texture; nudge it down to centre it in the box
		self.searchIcon:SetPoint("LEFT", self.frame, "LEFT", 2, -1)
		self.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)

		-- Placeholder text
		self.instructions = self.frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		self.instructions:SetPoint("LEFT", self.frame, "LEFT", 16, 0)
		self.instructions:SetPoint("RIGHT", self.frame, "RIGHT", -20, 0)
		self.instructions:SetJustifyH("LEFT")
		self.instructions:SetText(placeholderText)

		-- Clear button
		self.clearButton = CreateFrame("Button", nil, self.frame)
		self.clearButton:SetWidth(14)
		self.clearButton:SetHeight(14)
		self.clearButton:SetPoint("RIGHT", self.frame, "RIGHT", -3, 0)
		self.clearButton:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
		self.clearButton:Hide()

		-- ====================== SCRIPTS ==========================

		local instructions = self.instructions
		local clearBtn = self.clearButton
		local editBox = self.frame

		-- Several scripts below fire for one edit; refresh only on a real change
		local lastText = ""
		local function notify()
			local text = editBox:GetText() or ""
			if (text == lastText) then return end
			lastText = text
			onTextChanged()
		end

		clearBtn:SetScript("OnClick", function()
			if (MSB_SecureBook.RefuseInCombat()) then return end
			editBox:SetText("")
			instructions:Show()
			clearBtn:Hide()
			editBox:SetFocus()
			notify()
		end)

		editBox:SetScript("OnTextChanged", function()
			notify()
			local inputText = editBox:GetText()
			if (inputText == "") then
				clearBtn:Hide()
				return
			end
			instructions:Hide()
			clearBtn:Show()
		end)

		editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
		editBox:SetScript("OnEnterPressed", function() editBox:ClearFocus() end)

		editBox:SetScript("OnEditFocusLost", function()
			local inputText = editBox:GetText()
			if (inputText == "" or string.find(inputText, "^%s*$")) then
				instructions:Show()
				editBox:SetText("")
			end
			editBox:HighlightText(0, 0)
			notify()
		end)

		editBox:SetScript("OnEditFocusGained", function()
			-- The search rebuilds the pages, which waits for the end of combat
			if (MSB_SecureBook.RefuseInCombat()) then
				editBox:ClearFocus()
				return
			end
			editBox:HighlightText()
			instructions:Hide()
		end)

		-- Click outside to defocus
		parent:HookScript("OnMouseDown", function()
			if (editBox.HasFocus and not editBox:HasFocus()) then return end
			if (editBox.IsCurrentFocusEditBox and not editBox:IsCurrentFocusEditBox()) then return end
			editBox:ClearFocus()
		end)
	end;


	Hide = function(self)
		self.frame:Hide()
	end;

	Show = function(self)
		self.frame:Show()
	end;

	IsShown = function(self)
		return self.frame:IsShown()
	end;

	GetText = function(self)
		return self.frame:GetText()
	end;

	SetText = function(self, text)
		self.frame:SetText(text)
	end;

	ClearFocus = function(self)
		self.frame:ClearFocus()
	end;

	SetPoint = function(self, ...)
		self.frame:SetPoint(...)
	end;

	Clear = function(self)
		self.frame:SetText("")
		self.instructions:Show()
		self.frame:ClearFocus()
	end;
}