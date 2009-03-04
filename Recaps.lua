----------------------------------
--* Arena Recaps WoW AddOn
----------------------------------

--* Global variables
RECAPS_MATCHES = RECAPS_MATCHES or {}

--* Local variables
local arenastart, logging, recorded
local version = GetAddOnMetadata("Recaps", "X-Revision")

--* Prints out messages to the default chat frame
local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

--* Get the timezone offset
local function timezone()
  local now = time()
  local timezone = difftime(now, time(date("!*t", now)))
  local h, m = math.modf(timezone / 3600)
  local zoneText = date("%z")
  zoneText = string.gsub(zoneText, "%s", "")
  zoneText = string.gsub(zoneText, "%l", "")
  return string.format("%s %+.4d",zoneText, 100 * h + 60 * m)
end

--* Saves the arena match data
local function saveArena(mapName, teamSize)
	local team0, team1 = GetBattlefieldTeamInfo(0), GetBattlefieldTeamInfo(1)
	--local matchData = {}
	local green = {
		team = team0,
		members = {}
	}

	local gold = {
		team = team1,
		members = {}
	}

	local numScores = GetNumBattlefieldScores()
	for i = 1, numScores do
		local server = GetRealmName()
		local name, killingBlows, _, _, _, faction, _, race, class, classToken, damageDone, healingDone = GetBattlefieldScore(i)
		if faction then
			if string.find(name, "%-") then
				name, server = string.split("-", name)
			end
			local _, teamRating, newTeamRating = GetBattlefieldTeamInfo(faction)
			local info = {
				name = name,
				killingBlows = killingBlows,
				race = race,
				class = class,
				classToken = classToken,
				damageDone = damageDone,
				healingDone = healingDone,
			}

			local tbl
			if faction == 0 then
				tbl = green
			else
				tbl = gold
			end

			tbl.server = server
			tbl.teamRating = teamRating
			tbl.newTeamRating = newTeamRating
			tbl.honorGained = newTeamRating - teamRating

			table.insert(tbl.members, info)
		end
	end
	
	table.insert(RECAPS_MATCHES, {
		teamSize = teamSize,
		timeZone = timezone(),
		mapName = mapName,
		arenaStop = time(),
		arenaStart = arenastart,
		green = green,
		gold = gold,
		version = version
	})
	LoggingCombat(0);
end

local events = {
	--* Check for arena ending
	["UPDATE_BATTLEFIELD_STATUS"] = function()
			for i = 1, MAX_BATTLEFIELD_QUEUES do
				local status, mapName, _, _, _, teamSize, registeredMatch = GetBattlefieldStatus(i)
				if status == "active" and GetBattlefieldWinner() and not recorded then
					local isArena, isRegistered = IsActiveBattlefieldArena()
					if isArena and isRegistered then
						saveArena(mapName, teamSize)
					end
					break
				end
			end
			recorded = 0
		end,

	--* Check if we are in an arena
	["ZONE_CHANGED_NEW_AREA"] = function()
			local type = select(2, IsInInstance())
			if type == "arena" then
				arenastart = time()
				if not LoggingCombat() then
					logging = true
					LoggingCombat(1)
				end
			end
		end,
}

--* All events are processed in this hidden frame
local eventsFrame = CreateFrame("Frame")
for event in pairs(events) do
	eventsFrame:RegisterEvent(event)
end

--* Send the event to the events table
eventsFrame:SetScript("OnEvent",
	function(self, event, ...)
		events[event](...)
	end)

eventsFrame:SetScript("OnUpdate",
	function(self, ...)
		if recorded then
			recorded = recorded + arg1
			if recorded >= 10 then
				recorded = nil
			end
		end
	end)

--* Matches comment and starring frame
local viewFrame = CreateFrame("Frame", "ArenaRecapsWindow", UIParent)
viewFrame:SetWidth(400)
viewFrame:SetHeight(285)
viewFrame:SetBackdrop({	bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
						edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
						tile = true, tileSize = 16, edgeSize = 16, 
						insets = { left = 4, right = 4, top = 4, bottom = 4 }})
viewFrame:SetBackdropColor(0,0,0,1)
viewFrame:Hide()
viewFrame:SetPoint("CENTER")

viewFrame.icon = viewFrame:CreateTexture(nil, "ARTWORK")
viewFrame.icon:SetTexture("Interface\\AddOns\\Recaps\\icon")
viewFrame.icon:SetWidth(24)
viewFrame.icon:SetHeight(24)
viewFrame.icon:SetPoint("TOPLEFT", 3, -3)

viewFrame.title = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.title:SetWidth(300)
viewFrame.title:SetPoint("TOPRIGHT", -4, -6)
viewFrame.title:SetFontObject(GameTooltipText)
viewFrame.title:SetText("Arena Recaps Recent Matches")

viewFrame.titleBG = viewFrame:CreateTexture(nil, "BACKGROUND")
viewFrame.titleBG:SetTexture(29/255, 189/255, 229/255, 0.5)
viewFrame.titleBG:SetWidth(376)
viewFrame.titleBG:SetHeight(22)
viewFrame.titleBG:SetPoint("TOPRIGHT", -3, -3)

viewFrame.matchID = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.matchID:SetWidth(65)
viewFrame.matchID:SetPoint("TOPLEFT", 5, -30)
viewFrame.matchID:SetFontObject(GameTooltipTextSmall)
viewFrame.matchID:SetTextColor(29/255, 189/255, 229/255)
viewFrame.matchID:SetText("ID")

viewFrame.headerDate = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.headerDate:SetWidth(110)
viewFrame.headerDate:SetPoint("LEFT", viewFrame.matchID, "RIGHT", 4, 0)
viewFrame.headerDate:SetFontObject(GameTooltipTextSmall)
viewFrame.headerDate:SetTextColor(29/255, 189/255, 229/255)
viewFrame.headerDate:SetText("Date")

viewFrame.headerAgainst = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.headerAgainst:SetWidth(160)
viewFrame.headerAgainst:SetPoint("LEFT", viewFrame.headerDate, "RIGHT", 4, 0)
viewFrame.headerAgainst:SetFontObject(GameTooltipTextSmall)
viewFrame.headerAgainst:SetTextColor(29/255, 189/255, 229/255)
viewFrame.headerAgainst:SetText("Against")

viewFrame.headerResult = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.headerResult:SetWidth(100)
viewFrame.headerResult:SetPoint("LEFT", viewFrame.headerAgainst, "RIGHT", 4, 0)
viewFrame.headerResult:SetFontObject(GameTooltipTextSmall)
viewFrame.headerResult:SetTextColor(29/255, 189/255, 229/255)
viewFrame.headerResult:SetText("Result")

viewFrame.scroll = CreateFrame("ScrollFrame", "ArenaRecapsWindowScroll", viewFrame, "FauxScrollFrameTemplate")
viewFrame.scroll:SetPoint("BOTTOMRIGHT", -25, 4)
viewFrame.scroll:SetWidth(370)
viewFrame.scroll:SetHeight(235)

viewFrame.scroll:SetScript("OnVerticalScroll",
	function(self, val)
		FauxScrollFrame_OnVerticalScroll(self, val, 14, ArenaRecaps_ScrollMatches)
	end)

viewFrame.scroll:SetScript("OnShow",
	function(self)
		ArenaRecaps_ScrollMatches()
	end)

viewFrame.scroll:SetScript("OnMouseWheel",
	function(self, val)
		ScrollFrameTemplate_OnMouseWheel(self, val)
	end)

for i = 1, 15 do
	local frame = CreateFrame("Button", nil, viewFrame)
	frame:SetWidth(394)
	frame:SetHeight(16)
	if i == 1 then
		frame:SetPoint("TOPLEFT", 4, -44)
	else
		frame:SetPoint("TOPLEFT", viewFrame["row"..i-1], "BOTTOMLEFT", 0, 0)
	end

	frame.match = frame:CreateFontString(nil, "ARTWORK")
	frame.match:SetWidth(40)
	frame.match:SetPoint("LEFT")
	frame.match:SetFontObject(GameTooltipTextSmall)

	frame.star = CreateFrame("CheckButton", nil, frame)
	frame.star:SetWidth(14)
	frame.star:SetHeight(14)
	frame.star:SetPoint("LEFT", frame.match, "RIGHT", 4, 0)
	frame.star:SetCheckedTexture("Interface\\AddOns\\Recaps\\starred")
	frame.star:SetDisabledCheckedTexture("Interface\\AddOns\\Recaps\\unstarred")

	frame.star:SetScript("OnClick",
		function(self)
			local matchID = self:GetParent().matchID
			RECAPS_MATCHES[matchID].starred = self:GetChecked()
		end)

	frame.date = frame:CreateFontString(nil, "ARTWORK")
	frame.date:SetWidth(110)
	frame.date:SetPoint("LEFT", frame.star, "RIGHT", 12, 0)
	frame.date:SetFontObject(GameTooltipTextSmall)

	frame.against = frame:CreateFontString(nil, "ARTWORK")
	frame.against:SetWidth(160)
	frame.against:SetPoint("LEFT", frame.date, "RIGHT", 4, 0)
	frame.against:SetFontObject(GameTooltipTextSmall)

	frame.result = frame:CreateFontString(nil, "ARTWORK")
	frame.result:SetWidth(100)
	frame.result:SetPoint("LEFT", frame.against, "RIGHT", 4, 0)
	frame.result:SetFontObject(GameTooltipTextSmall)
	
	if math.fmod(i, 2) == 0 then
		frame.bg = frame:CreateTexture(nil, "BACKGROUND")
		frame.bg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		frame.bg:SetBlendMode("ADD")
		frame.bg:SetAllPoints(frame)
		frame.bg:SetVertexColor(0.3, 0.3, 0.3)
	end

	viewFrame["row"..i] = frame
end

viewFrame:SetScript("OnShow", ArenaRecaps_ScrollMatches)
table.insert(UISpecialFrames, "ArenaRecapsWindow")

function ArenaRecaps_ScrollMatches()
	local function format_row(row, num)
		row.match:SetText(nil)
		row.date:SetText(nil)
		row.against:SetText(nil)
		row.result:SetText(nil)
		row.star:SetChecked(nil)
		
		if RECAPS_MATCHES[num] then
			local tbl = RECAPS_MATCHES[num]
			row.matchID = num
			row.match:SetFormattedText("[%d]", num)
			row.date:SetText(date("%c", tbl.arenaStop))
			row.against:SetText(tbl.green.team)
			row.result:SetText(tbl.green.honorGained)
			if tbl.green.honorGained >= 0 then
				row.result:SetTextColor(0, 1, 0)
			else
				row.result:SetTextColor(1, 0, 0)
			end
			row.star:SetChecked(tbl.starred)
		end
	end

	local frame = ArenaRecapsWindowScroll
	FauxScrollFrame_Update(frame, #RECAPS_MATCHES, 15, 16)
	for line = 1, 15 do
		local offset = line + FauxScrollFrame_GetOffset(frame)
		local row = viewFrame["row"..line]
		if offset <= #RECAPS_MATCHES then
			format_row(row, offset)
			row:Show()
		else
			row:Hide()
		end
	end
end

--* Create the minimap menu icon
local menuIcon = CreateFrame("Button", "RecapsMinimap", Minimap)
menuIcon:SetWidth(33)
menuIcon:SetHeight(33)
menuIcon:SetFrameStrata("LOW")
menuIcon:SetMovable(true)
menuIcon:RegisterForClicks("AnyUp")
menuIcon:RegisterForDrag("LeftButton")
menuIcon:SetPoint("CENTER", -12, -80)

menuIcon.icon = menuIcon:CreateTexture(nil, "BACKGROUND")
menuIcon.icon:SetTexture("Interface\\AddOns\\Recaps\\icon")
menuIcon.icon:SetWidth(22)
menuIcon.icon:SetHeight(22)
menuIcon.icon:SetPoint("CENTER", -1, 3)

menuIcon.border = menuIcon:CreateTexture(nil, "ARTWORK")
menuIcon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
menuIcon.border:SetWidth(52)
menuIcon.border:SetHeight(52)
menuIcon.border:SetPoint("TOPLEFT")

local function onupdate(self)
	if self.isMoving then
		local xpos, ypos = GetCursorPosition()
		local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()

		xpos = xmin - xpos/Minimap:GetEffectiveScale() + 70
		ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
		local angle = math.deg(math.atan2(ypos, xpos))
		xpos = 80 * cos(angle)
		ypos = 80 * sin(angle)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", "Minimap", "TOPLEFT", 52-xpos, ypos-52)
	end
end

menuIcon:SetScript("OnClick",
	function(self)
		if viewFrame:IsShown() then
			viewFrame:Hide()
		else
			viewFrame:Show()
		end
	end)

menuIcon:SetScript("OnDragStart",
	function(self)
		if IsShiftKeyDown() then
			self.isMoving = true
			self:SetScript("OnUpdate", function(self) onupdate(self) end)
		end
	end)

menuIcon:SetScript("OnDragStop",
	function(self)
		self.isMoving = nil
		self:SetScript("OnUpdate", nil)
		self:SetUserPlaced(true)
	end)
menuIcon:SetScript("OnEnter",
	function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Arena Recaps", 0, 0.75, 1)
		GameTooltip:AddLine("Shift + Drag - Move Button", 0.75, 0.75, 0.75)
		GameTooltip:AddLine("Click - Toggle Recent Matches", 0.75, 0.75, 0.75)
		GameTooltip:Show()
	end)

menuIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
