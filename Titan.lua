-- Titan Panel plugin for the StoryTeller story picker.
--
-- Left click opens the story list, right click opens Titan's menu.
-- The button shows the story that was loaded last.
--
-- Follows the plugin scheme used by Titan 9.x (see TitanBag.lua): a button created
-- with TitanPanelComboTemplate plus a .registry table.

local TITAN_ID = "StoryTellerAuto"
local TITAN_BUTTON = "TitanPanelStoryTellerAutoButton"
local TITAN_VERSION = "1.5.1"
local TITAN_ICON = "Interface\\Icons\\INV_Misc_Book_08"

local function API()
	return _G.StoryTellerAuto
end

local function GetButtonText()
	local api = API()
	if api and api.Title() then
		return "Story", api.Title()
	end
	return "Story", "pick"
end

local function GetTooltipText()
	local api = API()
	local lines = { "Left click: open the story list", "Right click: menu" }
	if api and api.Title() then
		lines[#lines + 1] = ("Loaded: %s"):format(tostring(api.Title()))
	end
	lines[#lines + 1] = "Press the line key for each line."
	return table.concat(lines, "\n")
end

local function OnClick(self, mouseButton)
	local api = API()
	if mouseButton == "RightButton" and _G.MenuUtil and MenuUtil.CreateContextMenu then
		return -- Titan's modern context menu handles it
	end
	-- left click, and right click when the client has no MenuUtil: open the list
	-- (Titan's legacy dropdown path is broken on this client)
	if api then pcall(api.Toggle) end
end

-- Menu entries. Titan's old dropdown scheme is broken on this client
-- (UIDropDownMenu_UAddButton indexes a nil listFrame), so only the newer
-- MenuUtil context menu is offered, and only when the client has MenuUtil.
local function BuildContextMenu(owner, rootDescription)
	rootDescription:CreateButton("Speak the next line", function()
		if _G.SpeakNext then pcall(_G.SpeakNext) end
	end)
	rootDescription:CreateButton("Open the story list", function()
		local api = API()
		if api then pcall(api.Toggle) end
	end)
	rootDescription:CreateButton("Play a random story", function()
		local api = API()
		if api then pcall(api.PlayRandom) end
	end)
end

local function CreateFrames()
	if _G[TITAN_BUTTON] then return end
	if not (_G.Titan_G and _G.Titan_G.plugins) then return end

	local parent = CreateFrame("Frame", nil, UIParent)
	local button = CreateFrame("Button", TITAN_BUTTON, parent, "TitanPanelComboTemplate")
	button:SetFrameStrata("FULLSCREEN")

	button.registry = {
		id = TITAN_ID,
		category = "General",
		version = TITAN_VERSION,
		menuText = "StoryTeller",
		menuContextFunction = (_G.MenuUtil and MenuUtil.CreateContextMenu) and BuildContextMenu or nil,
		buttonTextFunction = GetButtonText,
		tooltipTitle = "StoryTeller",
		tooltipTextFunction = GetTooltipText,
		icon = TITAN_ICON,
		iconWidth = 16,
		notes = "Adds the story picker to Titan Panel. Left click opens it, right click opens this menu.",
		controlVariables = {
			ShowIcon = true,
			ShowLabelText = true,
			ShowColoredText = false,
			DisplayOnRightSide = true,
		},
		savedVariables = {
			ShowIcon = 1,
			ShowLabelText = 1,
			ShowColoredText = 0,
			DisplayOnRightSide = false,
		},
	}

	button:SetScript("OnShow", function(self)
		Titan_G.plugins.OnShow(self)
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		OnClick(self, mouseButton)
		Titan_G.plugins.OnClick(self, mouseButton)
	end)
end

-- Called by the addon whenever reading starts or stops.
function StoryTellerAuto_Changed()
	if _G[TITAN_BUTTON] and _G.Titan_G and _G.Titan_G.plugins and _G.Titan_G.plugins.UpdateButton then
		pcall(Titan_G.plugins.UpdateButton, TITAN_ID)
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(_, event, addOnName)
	if event == "ADDON_LOADED" and addOnName ~= "Titan" then return end
	pcall(CreateFrames)
end)




