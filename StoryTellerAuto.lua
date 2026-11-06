-- One line per key press for StoryTeller.
--
-- StoryTeller reads one line per click of its Read button. This client blocks chat
-- sent from a timer, so this addon speaks a line on real input instead: a bound
-- key, the Next Line button, or a slash command.
--
-- /storyauto commands:
--   /storyauto            show the line key
--   /storyauto next       speak the next line
--   /storyauto bind F8    bind one key that speaks a line per press
--   /storyauto status     show the line key
--   /storyauto save <name>   keep StoryTeller's current text as your own story
--   /storyauto delete <n>    remove one of your saved stories
--   /storyauto help       this list

local ADDON_VERSION = "1.5.0"

StoryTellerAutoDB = type(StoryTellerAutoDB) == "table" and StoryTellerAutoDB or {}
local db = StoryTellerAutoDB

local function Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99StoryTeller Auto|r: " .. tostring(msg))
	end
end

-- diagnostics are saved with the addon, so they can be read from disk after a /reload
local function Record(field, value)
	if type(db) ~= "table" then return end
	db.diag = db.diag or {}
	db.diag.version = ADDON_VERSION
	db.diag[field] = value
	db.diag.time = time and date("%H:%M:%S") or nil
end

---------------------------------------------------------------- story library
-- Stories come from the bundled list in Stories.lua, from story pack addons that
-- append to it, and from stories the player saves in game. Saved stories live in
-- StoryTellerAutoDB, so updating the addon never touches them.

local function BundledStories()
	local list = _G.StoryTellerAutoStories
	return type(list) == "table" and list or {}
end

local function ValidStory(story)
	return type(story) == "table"
		and type(story.title) == "string" and strtrim(story.title) ~= ""
		and type(story.lines) == "string" and strtrim(story.lines) ~= ""
end

-- kept clean so a hand-edited SavedVariables file cannot break the picker
local function UserStories()
	if type(db.stories) ~= "table" then db.stories = {} end
	local kept = {}
	for _, story in ipairs(db.stories) do
		if ValidStory(story) then
			table.insert(kept, { title = strtrim(story.title), lines = story.lines })
		end
	end
	db.stories = kept
	return kept
end

--- Every story the player can pick, bundled ones first.
local function Library()
	local library = {}
	for _, story in ipairs(BundledStories()) do
		if ValidStory(story) then
			table.insert(library, { title = story.title, lines = story.lines })
		end
	end
	for _, story in ipairs(UserStories()) do
		table.insert(library, { title = story.title, lines = story.lines, user = true })
	end
	return library
end

local function CountLines(text)
	local count = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		if strtrim(line) ~= "" then count = count + 1 end
	end
	return count
end

--- The text currently in StoryTeller's window, or "" when it is empty or the placeholder.
local function CurrentStoryText()
	local box = _G.StoryTellerFrameText
	local text = box and box:GetText() or ""
	local placeholder = _G.StoryTeller and StoryTeller.Msg and StoryTeller.Msg.PASTE_TEXT
	if placeholder and text == placeholder then return "" end
	return text
end

-- counted without touching the saved stories: UserStories() rebuilds their table
local function BundledCount()
	local count = 0
	for _, story in ipairs(BundledStories()) do
		if ValidStory(story) then count = count + 1 end
	end
	return count
end

--- Save the text from StoryTeller's window as a story of the player's own.
-- Overwrites a saved story that already has this name.
-- @return story, reason, replaced
local function SaveUserStory(title, text)
	title = strtrim(title or "")
	if title == "" then
		return nil, "name the story: /storyauto save <name>"
	end
	for _, story in ipairs(BundledStories()) do
		if type(story.title) == "string" and story.title == title then
			return nil, "a bundled story already uses that name - pick another."
		end
	end
	text = strtrim(text or "")
	if text == "" then
		return nil, "StoryTeller's window is empty - paste a story into it first."
	end
	local userStories = UserStories()
	for _, story in ipairs(userStories) do
		if story.title == title then
			story.lines = text
			return story, nil, true
		end
	end
	local story = { title = title, lines = text }
	table.insert(userStories, story)
	return story, nil, false
end

--- Remove one of the player's saved stories by its library number.
local function DeleteUserStory(index)
	local userStories = UserStories()
	local bundledCount = BundledCount()
	if index <= bundledCount then
		return nil, ("story %d ships with the addon and cannot be deleted."):format(index)
	end
	local story = userStories[index - bundledCount]
	if not story then
		return nil, ("no story %s - try /storyauto list."):format(tostring(index))
	end
	table.remove(userStories, index - bundledCount)
	return story
end

--- Remove one of the player's saved stories by name, used by the picker.
local function DeleteUserStoryNamed(title)
	local userStories = UserStories()
	for index, story in ipairs(userStories) do
		if story.title == title then
			table.remove(userStories, index)
			return story
		end
	end
	return nil, ("no story named \"%s\"."):format(tostring(title))
end

--- Rewrite the story the editor was opened on, renaming it if the name changed.
local function UpdateUserStory(oldTitle, newTitle, text)
	newTitle = strtrim(newTitle or "")
	text = strtrim(text or "")
	if newTitle == "" then
		return nil, "name the story first."
	end
	if text == "" then
		return nil, "the story is empty - add at least one line."
	end
	for _, story in ipairs(BundledStories()) do
		if type(story.title) == "string" and story.title == newTitle then
			return nil, "a bundled story already uses that name - pick another."
		end
	end
	local userStories = UserStories()
	local edited
	for _, story in ipairs(userStories) do
		if story.title == oldTitle then
			edited = story
			break
		end
	end
	if not edited then
		return nil, ("\"%s\" is no longer in your stories."):format(oldTitle)
	end
	for _, story in ipairs(userStories) do
		if story ~= edited and story.title == newTitle then
			return nil, "another of your stories already has that name."
		end
	end
	edited.title = newTitle
	edited.lines = text
	return edited
end

local function StoryAvailable()
	local storyTeller = _G.StoryTeller
	return type(storyTeller) == "table"
		and type(storyTeller.text) == "table"
		and storyTeller.Frame ~= nil
		and type(storyTeller.Frame.Read) == "function"
end

-- StoryTeller sends through the chat edit box, which this client blocks for addons.
-- The common channels are sent directly; macros and anything else are left to StoryTeller.
local CHANNELS = {
	s = "SAY", say = "SAY",
	e = "EMOTE", em = "EMOTE", emote = "EMOTE",
	y = "YELL", yell = "YELL",
	p = "PARTY", party = "PARTY",
	ra = "RAID", raid = "RAID",
	rw = "RAID_WARNING", raidwarning = "RAID_WARNING",
	g = "GUILD", guild = "GUILD",
	o = "OFFICER", officer = "OFFICER",
	i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT",
}

local lastError
local lastSend -- what happened to the most recent line, shown by /storyauto test

--- Send one script line.
-- @return true when sent, false when StoryTeller has to handle it (a macro),
--         nil plus a reason when sending failed
local function SendDirect(line)
	local command, rest = line:match("^/(%S+)%s*(.*)$")
	local channel
	if command then
		command = strlower(command)
		if command == "w" or command == "whisper" or command == "t" or command == "tell" then
			local target, message = rest:match("^(.-)%s*,%s*(.*)$")
			if not target then target, message = rest:match("^(%S+)%s+(.*)$") end
			if not (target and message) then return false end
			local ok, err = pcall(SendChatMessage, message, "WHISPER", nil, target)
			if not ok then
				lastError = tostring(err)
				lastSend = "whisper failed: " .. tostring(err)
				return nil, tostring(err)
			end
			lastSend = "sent WHISPER to " .. target
			return true
		end
		channel = CHANNELS[command]
		if not channel then return false end -- a macro or a command we do not handle
	else
		rest = line
		channel = "SAY"
	end
	if rest == "" then rest = " " end
	local ok, err = pcall(SendChatMessage, rest, channel)
	if not ok then
		lastError = tostring(err)
		lastSend = "send failed: " .. tostring(err)
		Record("lastSend", lastSend)
		Record("lastError", lastError)
		return nil, tostring(err)
	end
	lastSend = "sent " .. channel
	Record("lastSend", lastSend)
	return true
end

local function AdvanceLine()
	local storyTeller = StoryTeller
	storyTeller.textCursor = (storyTeller.textCursor or 1) + 1
	if storyTeller.Frame.HighlightCurrentLine then storyTeller.Frame.HighlightCurrentLine() end
	if storyTeller.Frame.Refresh then storyTeller.Frame.Refresh() end
end

local function ReadViaStoryTeller()
	local storyTeller = StoryTeller
	local before = storyTeller.textCursor
	local ok, err = pcall(storyTeller.Frame.Read)
	if not ok then
		lastError = tostring(err)
		return false, tostring(err)
	end
	if (storyTeller.textCursor or 1) == before then
		return false, "StoryTeller refused the line"
	end
	return true
end

---------------------------------------------------------------- one line per keypress
-- This client refuses chat sent from a timer ("Interface action failed because of an
-- AddOn"), so reading is driven by real input: a bound key, a click, or a slash command.
-- Each of those is a hardware event, which the client allows.

local lineButton
local LINE_BUTTON = "StoryTellerAutoLineButton"
-- SetBindingClick can store either form; both resolve to a click on the line button.
local LINE_COMMANDS = { "CLICK " .. LINE_BUTTON, "CLICK " .. LINE_BUTTON .. ":LeftButton" }

local function CreateLineButton()
	if lineButton then return lineButton end
	lineButton = CreateFrame("Button", LINE_BUTTON, UIParent)
	lineButton:SetSize(1, 1)
	lineButton:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -2, 2)
	lineButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	lineButton:SetScript("OnClick", function() SpeakNext() end)
	return lineButton
end

local function CurrentLineKey()
	if not GetBindingKey then return nil end
	for _, command in ipairs(LINE_COMMANDS) do
		local ok, key = pcall(GetBindingKey, command)
		if ok and key then return key end
	end
	return nil
end

--- Bind a key to the line button. Returns the key the client actually kept, plus a reason when it did not.
local function BindLineKey(key)
	-- binding names are case sensitive; "f8" is silently rejected, "F8" works
	key = strtrim(key or ""):upper()
	if key == "" then return nil, "no key given." end
	CreateLineButton()

	local previous = CurrentLineKey()
	if previous and previous ~= key then
		pcall(SetBinding, previous) -- free the old key before taking a new one
	end

	pcall(SetBindingClick, key, LINE_BUTTON, "LeftButton")
	local kept = CurrentLineKey()
	if kept ~= key then
		-- some clients only accept the plain CLICK command
		pcall(SetBinding, key, LINE_COMMANDS[1])
		kept = CurrentLineKey()
	end
	if kept ~= key then
		return nil, ("the client did not keep %s as a key."):format(key)
	end
	pcall(SaveBindings, GetCurrentBindingSet and GetCurrentBindingSet() or 1)
	return kept
end

--- First login convenience: bind F8 when nothing is bound yet and F8 is free.
local function SetupDefaultBinding()
	if CurrentLineKey() then return end
	if GetBindingAction then
		local ok, action = pcall(GetBindingAction, "F8")
		if ok and action and action ~= "" then
			Print(("F8 is already bound to %s - /storyauto bind <key> picks the line key."):format(tostring(action)))
			return
		end
	end
	local kept = BindLineKey("F8")
	if kept then
		Print("F8 speaks one line per press - /storyauto bind <key> changes it.")
	end
end

-- create it now, so a binding resolves even before a story is loaded
CreateLineButton()

--- Speak the current line. Must run from real input: keypress, click or slash command.
SpeakNext = function()
	local ok, err = pcall(function()
		if not StoryAvailable() then
			Print("StoryTeller is not loaded - enable it in the AddOns list first.")
			return
		end
		local storyTeller = StoryTeller
		local lineCount = #storyTeller.text
		local cursor = storyTeller.textCursor or 1
		if lineCount == 0 then
			Print("no text loaded - pick a story first.")
			return
		end
		if cursor > lineCount then
			Print("finished reading.")
			return
		end
		local line = storyTeller.text[cursor] and storyTeller.text[cursor][1]
		if not line then
			Print("finished reading.")
			return
		end

		local sent = SendDirect(line)
		if sent then
			AdvanceLine()
			db.diag = db.diag or {}
			db.diag.sent = (db.diag.sent or 0) + 1
			Record("lastSend", lastSend)
		else
			local read, why = ReadViaStoryTeller()
			if not read then
				Record("lastError", tostring(why))
				Print("could not read the line: " .. tostring(why))
				return
			end
		end

		local now = storyTeller.textCursor or 1
		if now > lineCount then
			Record("lastStop", "finished reading.")
			Print("finished reading.")
		end
	end)
	if not ok then
		Record("lastNextError", tostring(err))
		Print("could not read the line: " .. tostring(err))
	end
end

local Play -- defined with the story picker below
local RefreshPicker -- defined with the story picker below

local function ReportSave(story, reason, replaced)
	if not story then
		Print(reason)
		return nil
	end
	Print(("%s \"%s\" - %d lines. /storyauto list shows it.")
		:format(replaced and "updated" or "saved", story.title, CountLines(story.lines)))
	if RefreshPicker then RefreshPicker() end
	return story
end

local function SaveStoryAndReport(title, text)
	local story, reason, replaced = SaveUserStory(title, text)
	return ReportSave(story, reason, replaced)
end

local function UpdateStoryAndReport(oldTitle, newTitle, text)
	local story, reason = UpdateUserStory(oldTitle, newTitle, text)
	return ReportSave(story, reason, true)
end

local function RunTest()
	local list = Library()
	Print(("v%s - %d stories, StoryTeller %s"):format(ADDON_VERSION, #list, StoryAvailable() and "found" or "MISSING"))
	local storyTeller = _G.StoryTeller
	if type(storyTeller) == "table" and type(storyTeller.text) == "table" then
		local total = #storyTeller.text
		local cursor = storyTeller.textCursor or 1
		Print(("lines loaded: %d, next line: %d"):format(total, cursor))
		local entry = storyTeller.text[cursor]
		if entry and entry[1] then
			local text = entry[1]
			Print("next: " .. text)
			local command = text:match("^/(%S+)")
			if command then
				Print(("slash /%s -> %s"):format(strlower(command), CHANNELS[strlower(command)] or "left to StoryTeller"))
			else
				Print("no slash command -> SAY")
			end
		end
	else
		Print("StoryTeller has no text yet - play a story first.")
	end
	Print("SendChatMessage is " .. type(_G.SendChatMessage))
	if type(storyTeller) == "table" and storyTeller.InChatMessagingLockdown then
		local ok, locked = pcall(storyTeller.InChatMessagingLockdown)
		Print("chat lockdown: " .. (ok and tostring(locked) or "call failed"))
	end
	if lastError then Print("last error: " .. tostring(lastError)) end
	if lastSend then Print("last line: " .. tostring(lastSend)) end
	local diag = db.diag or {}
	Print(("lines sent this session: %d"):format(diag.sent or 0))
	Print("line key: " .. tostring(CurrentLineKey() or "none - /storyauto bind F8"))
end

local function HandleCommand(msg)
	msg = strtrim(msg or "")
	local command, rest = msg:match("^(%S*)%s*(.-)$")
	command = strlower(command or "")

	if command == "next" then
		SpeakNext()
	elseif command == "bind" then
		local key = strtrim(rest or "")
		if key == "" then
			local current = CurrentLineKey()
			Print(current and ("line key is " .. current .. " - /storyauto bind <key> changes it")
				or "no line key yet - /storyauto bind F8 binds the key you press once per line")
			return
		end
		local kept, reason = BindLineKey(key)
		if kept then
			Print(("line key set to %s - press it once for each line."):format(kept))
		else
			Print(reason or "could not bind that key.")
			Print("try /storyauto bind SHIFT-F8 or another key.")
		end
	elseif command == "status" then
		Print("line key: " .. (CurrentLineKey() or "none - /storyauto bind F8"))
	elseif command == "help" then
		Print("/storyauto next - speak the next line;  /storyauto bind F8 - one key for every line")
		Print("/storylist - pick a story;  /storyauto play <n>;  /storyauto test - diagnostics")
		Print("/storyauto save <name> - keep the current StoryTeller text as your own story")
		Print("/storyauto delete <n> - remove one of your saved stories")
		Print("The picker: Add Story saves what is in StoryTeller; right-click your own story to edit or delete.")
	elseif command == "" then
		local key = CurrentLineKey()
		Print(key and ("press " .. key .. " for each line - /storyauto next works too")
			or "no line key set - /storyauto bind F8, then press it once per line")
	elseif command == "test" then
		RunTest()
	elseif command == "say" then
		local text = (rest ~= "" and rest) or "chat test"
		local ok, err = pcall(SendChatMessage, text, "SAY")
		if ok then
			Print("sent \"" .. text .. "\" to SAY - check your chat frame now")
		else
			Print("SendChatMessage failed: " .. tostring(err))
		end
	elseif command == "list" then
		local list = Library()
		if #list == 0 then
			Print("no stories installed.")
			return
		end
		for index, story in ipairs(list) do
			Print(("%d. %s%s"):format(index, story.title, story.user and "  (yours)" or ""))
		end
	elseif command == "save" then
		SaveStoryAndReport(rest, CurrentStoryText())
	elseif command == "delete" then
		local index = tonumber(rest)
		if not index then
			Print("which one? /storyauto delete <number from /storyauto list>")
			return
		end
		local story, reason = DeleteUserStory(index)
		if not story then
			Print(reason)
			return
		end
		Print(("deleted \"%s\"."):format(story.title))
		if RefreshPicker then RefreshPicker() end
	elseif command == "play" then
		local list = Library()
		local index = tonumber(rest) or 1
		if not list[index] then
			Print(("no story %s - try /storyauto list."):format(tostring(rest)))
			return
		end
		Play(list[index])
	else
		Print("unknown command - try /storyauto help.")
	end
end

---------------------------------------------------------------- story picker
local currentTitle

--- Load a story into StoryTeller and read it from start to finish
local function PlayStory(story)
	if not StoryAvailable() then
		Print("StoryTeller is not loaded - enable it in the AddOns list first.")
		return
	end
	local box = _G.StoryTellerFrameText
	if not box or not StoryTeller.Frame.Load then
		Print("StoryTeller is not ready yet - open /story once, then try again.")
		return
	end

	currentTitle = story.title
	box:SetText(story.lines)
	StoryTeller.Frame.Load() -- resets the cursor to the first line
	if _G.StoryTellerFrame then StoryTellerFrame:Show() end
	CreateLineButton()

	local lineCount = #StoryTeller.text
	local key = CurrentLineKey()
	Print(("loaded \"%s\" - %d lines."):format(story.title, lineCount))
	if key then
		Print(("Press %s to speak each line. /storyauto test for details."):format(key))
	else
		Print("Press Read in StoryTeller, or /storyauto next, for each line.")
		Print("To use one key for the whole story: /storyauto bind F8")
	end
end

-- anything the client rejects shows up in chat instead of failing silently
Play = function(story)
	local ok, err = pcall(PlayStory, story)
	if not ok then
		Record("lastPlayError", tostring(err))
		Print("could not start the story: " .. tostring(err))
	end
end

---------------------------------------------------------------- story editor
-- Same scroll frame plus multiline edit box pattern StoryTeller's own editor uses.
local editor
local editingTitle

local function BuildEditor()
	local frame = CreateFrame("Frame", "StoryTellerAutoEditFrame", UIParent)
	frame:SetSize(460, 430)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.08, 0.97)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("New Story")
	frame.titleText = title

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	close:HookScript("OnClick", function() editingTitle = nil end)

	local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -14)
	nameLabel:SetText("Name")

	local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	nameBox:SetSize(280, 20)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(60)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	frame.nameBox = nameBox

	local bodyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bodyLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -16)
	bodyLabel:SetText("Script - one line per chat message (/s, /e, ...)")

	local scroll = CreateFrame("ScrollFrame", "StoryTellerAutoEditScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", bodyLabel, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -34, 46)

	local body = CreateFrame("EditBox", "StoryTellerAutoEditText", scroll)
	body:SetSize(390, 300)
	body:SetMultiLine(true)
	body:SetAutoFocus(false)
	body:SetFontObject(GameFontHighlightSmall)
	body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(body)
	frame.body = body

	-- keep the text under the cursor visible, the way StoryTeller does it
	body:SetScript("OnTextChanged", function(self)
		if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, self:GetParent()) end
	end)
	body:SetScript("OnCursorChanged", function(self, ...)
		if ScrollingEdit_OnCursorChanged then ScrollingEdit_OnCursorChanged(self, ...) end
	end)
	body:SetScript("OnUpdate", function(self, elapsed)
		if ScrollingEdit_OnUpdate then ScrollingEdit_OnUpdate(self, elapsed, self:GetParent()) end
	end)
	scroll:SetScript("OnMouseUp", function()
		if not body:HasFocus() then body:SetFocus() end
	end)

	nameBox:SetScript("OnEnterPressed", function() body:SetFocus() end)

	local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	cancelButton:SetSize(90, 22)
	cancelButton:SetPoint("BOTTOMRIGHT", -14, 14)
	cancelButton:SetText("Cancel")
	cancelButton:SetScript("OnClick", function()
		editingTitle = nil
		frame:Hide()
	end)

	local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	saveButton:SetSize(90, 22)
	saveButton:SetPoint("RIGHT", cancelButton, "LEFT", -8, 0)
	saveButton:SetText("Save")
	saveButton:SetScript("OnClick", function() frame:Save() end)

	frame.Save = function(self)
		local name = strtrim(self.nameBox:GetText() or "")
		local text = strtrim(self.body:GetText() or "")
		if name == "" then
			Print("give the story a name first.")
			self.nameBox:SetFocus()
			return
		end
		if text == "" then
			Print("the story is empty - add its lines first.")
			self.body:SetFocus()
			return
		end
		local story
		if editingTitle then
			story = UpdateStoryAndReport(editingTitle, name, text)
		else
			story = SaveStoryAndReport(name, text)
		end
		if story then
			editingTitle = nil
			self:Hide()
		end
	end

	tinsert(UISpecialFrames, "StoryTellerAutoEditFrame") -- Escape closes it
	frame:Hide()
	return frame
end

--- Open the editor on one of the player's stories, or on the text in StoryTeller's window.
local function OpenEditor(story)
	if not editor then editor = BuildEditor() end
	editingTitle = (story and story.user) and story.title or nil
	editor.titleText:SetText(editingTitle and "Edit Story" or "New Story")
	editor.nameBox:SetText(editingTitle or "")
	editor.body:SetText(story and story.lines or CurrentStoryText())
	editor:Show()
	if editor.nameBox:GetText() == "" then
		editor.nameBox:SetFocus()
	else
		editor.body:SetFocus()
	end
end

local picker
local MANAGE_POPUP = "STORYTELLERAUTO_MANAGE_STORY"
local DELETE_POPUP = "STORYTELLERAUTO_DELETE_STORY"

local function BuildPicker()
	local frame = CreateFrame("Frame", "StoryTellerAutoFrame", UIParent)
	frame:SetSize(430, 400)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.06, 0.06, 0.08, 0.97)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("Stories")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	addButton:SetSize(96, 22)
	addButton:SetPoint("TOPRIGHT", -40, -6)
	addButton:SetText("Add Story")
	addButton:SetScript("OnClick", function() OpenEditor(nil) end)
	addButton:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Add a story")
		GameTooltip:AddLine("Saves the text in StoryTeller's window under a name.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	addButton:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	hint:SetText("Click to play. Right-click yours to edit or delete.")

	local scroll = CreateFrame("ScrollFrame", "StoryTellerAutoScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -60)
	scroll:SetPoint("BOTTOMRIGHT", -34, 44)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(340, 10)
	scroll:SetScrollChild(child)

	-- rebuilt whenever a story is saved or deleted
	local buttons = {}
	local function Refresh()
		local list = Library()
		for index, story in ipairs(list) do
			local button = buttons[index]
			if not button then
				button = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
				button:SetSize(330, 24)
				if button.RegisterForClicks then
					button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				end
				button:SetScript("OnClick", function(self, mouseButton)
					local chosen = self.story
					if not chosen then return end
					if mouseButton == "RightButton" then
						if chosen.user and StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs[MANAGE_POPUP] then
							StaticPopup_Show(MANAGE_POPUP, chosen.title, nil, chosen)
						end
						return
					end
					Play(chosen)
				end)
				button:SetScript("OnEnter", function(self)
					local chosen = self.story
					if not chosen or not GameTooltip then return end
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:AddLine(chosen.title, 1, 1, 1)
					GameTooltip:AddLine(chosen.user and "Left-click to play. Right-click to edit or delete."
						or "Left-click to play.", 0.8, 0.8, 0.8, true)
					GameTooltip:Show()
				end)
				button:SetScript("OnLeave", function()
					if GameTooltip then GameTooltip:Hide() end
				end)
				buttons[index] = button
			end
			button.story = story
			button:SetPoint("TOPLEFT", 0, -((index - 1) * 28))
			button:SetText(story.user and (story.title .. "  |cff9d9d9d(yours)|r") or story.title)
			button:Show()
		end
		for index = #list + 1, #buttons do
			buttons[index]:Hide()
		end
		child:SetHeight(math.max(1, #list * 28))
	end
	frame.RefreshStories = Refresh
	Refresh()

	local stopButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	local randomButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	randomButton:SetSize(100, 22)
	randomButton:SetPoint("BOTTOMLEFT", 12, 12)
	randomButton:SetText("Surprise Me")
	randomButton:SetScript("OnClick", function()
		local list = Library()
		if #list == 0 then
			Print("no stories installed.")
			return
		end
		Play(list[math.random(#list)])
	end)

	-- one click per line: chat can only be sent from real input on this client
	local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	nextButton:SetSize(96, 22)
	nextButton:SetPoint("LEFT", randomButton, "RIGHT", 6, 0)
	nextButton:SetText("Next Line")
	nextButton:SetScript("OnClick", function() SpeakNext() end)

	local bindButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	bindButton:SetSize(90, 22)
	bindButton:SetPoint("LEFT", nextButton, "RIGHT", 6, 0)
	bindButton:SetText("Bind F8")
	bindButton:SetScript("OnClick", function()
		local kept, reason = BindLineKey("F8")
		if kept then
			Print(("line key set to %s - press it once for each line."):format(kept))
		else
			Print(reason or "could not bind F8.")
			Print("try /storyauto bind SHIFT-F8 or another key.")
		end
	end)

	tinsert(UISpecialFrames, "StoryTellerAutoFrame") -- Escape closes it
	frame:Hide()
	return frame
end

local function TogglePicker()
	local ok, err = pcall(function()
		if not picker then picker = BuildPicker() end
		picker:SetShown(not picker:IsShown())
	end)
	if not ok then
		Record("lastPickerError", tostring(err))
		Print("could not open the story list: " .. tostring(err))
	end
end

RefreshPicker = function()
	if picker and picker.RefreshStories then
		local ok, err = pcall(picker.RefreshStories)
		if not ok then Record("lastPickerError", tostring(err)) end
	end
end

---------------------------------------------------------------- story management dialogs
if StaticPopupDialogs then
	StaticPopupDialogs[MANAGE_POPUP] = {
		text = "\"%s\"\n\nEdit or delete this story.",
		button1 = "Edit",
		button2 = "Delete",
		OnAccept = function(_, story)
			if story then OpenEditor(story) end
		end,
		OnCancel = function(_, story)
			if story and StaticPopup_Show then
				StaticPopup_Show(DELETE_POPUP, story.title, nil, story.title)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopupDialogs[DELETE_POPUP] = {
		text = "Delete the story \"%s\"?\n\nThis cannot be undone.",
		button1 = "Delete",
		button2 = "Cancel",
		OnAccept = function(_, title)
			if not title then return end
			local story, reason = DeleteUserStoryNamed(title)
			if not story then
				Print(reason)
				return
			end
			Print(("deleted \"%s\"."):format(story.title))
			RefreshPicker()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

SLASH_STORYTELLERAUTO1 = "/storyauto"
SlashCmdList.STORYTELLERAUTO = function(msg)
	pcall(HandleCommand, msg)
end

SLASH_STORYTELLERSTORIES1 = "/storylist"
SLASH_STORYTELLERSTORIES2 = "/stories"
SlashCmdList.STORYTELLERSTORIES = function()
	pcall(TogglePicker)
end

---------------------------------------------------------------- startup note
local announce = CreateFrame("Frame")
announce:RegisterEvent("PLAYER_LOGIN")
announce:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	Print(("v%s ready - /storylist to pick a story, /storyauto test to check it."):format(ADDON_VERSION))
	pcall(SetupDefaultBinding)
end)

---------------------------------------------------------------- exposed for the Titan Panel plugin
StoryTellerAuto = {
	Toggle = TogglePicker,
	Title = function() return currentTitle end,
	Count = function() return #Library() end,
	PlayRandom = function()
		local list = Library()
		if #list == 0 then
			Print("no stories installed.")
			return
		end
		Play(list[math.random(#list)])
	end,
}



