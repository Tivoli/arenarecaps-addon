----------------------------------
--* Arena Recaps WoW AddOn
----------------------------------

--* Global variables
RECAPS_MATCHES = RECAPS_MATCHES or {}
RECAPS_SUBSCRIBE = RECAPS_SUBSCRIBE or {}

--* Local variables
local arenastart, logging, recorded
local version = GetAddOnMetadata("Recaps", "X-Revision")

--* Class icons
local classIcon = {
	["WARRIOR"]		= {0, 0.25, 0, 0.25},
	["MAGE"]		= {0.25, 0.49609375, 0, 0.25},
	["ROGUE"]		= {0.49609375, 0.7421875, 0, 0.25},
	["DRUID"]		= {0.7421875, 0.98828125, 0, 0.25},
	["HUNTER"]		= {0, 0.25, 0.25, 0.5},
	["SHAMAN"]	 	= {0.25, 0.49609375, 0.25, 0.5},
	["PRIEST"]		= {0.49609375, 0.7421875, 0.25, 0.5},
	["WARLOCK"]		= {0.7421875, 0.98828125, 0.25, 0.5},
	["PALADIN"]		= {0, 0.25, 0.5, 0.75},
	["DEATHKNIGHT"]	= {0.25, .5, 0.5, .75},
}

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
	
	table.insert(RECAPS_MATCHES, 1, {
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

--* Display the review frame
local function toggleReview(id)
	if RecapsReview:IsShown() and RecapsReview.matchID == id then
		RecapsReview:Hide()
		RecapsReview.matchID = nil
	else
		RecapsReview:Show()
		RecapsReview.matchID = id
		local tbl = RECAPS_MATCHES[id]
		for i = 1, 5 do
			local greenRow = RecapsReview["green"..i]
			local goldRow = RecapsReview["gold"..i]
			local greenMember = tbl.green.members[i]
			local goldMember = tbl.gold.members[i]
			if i <= tbl.teamSize then
				greenRow:Show()
				greenRow.class:SetTexCoord(unpack(classIcon[greenMember.classToken]))
				greenRow.name:SetText(greenMember.name)
				greenRow.kb:SetText(greenMember.killingBlows)
				greenRow.damage:SetText(greenMember.damageDone)
				greenRow.healing:SetText(greenMember.healingDone)

				goldRow:Show()
				goldRow.class:SetTexCoord(unpack(classIcon[goldMember.classToken]))
				goldRow.name:SetText(goldMember.name)
				goldRow.kb:SetText(goldMember.killingBlows)
				goldRow.damage:SetText(goldMember.damageDone)
				goldRow.healing:SetText(goldMember.healingDone)
			else
				greenRow:Hide()
				goldRow:Hide()
			end
		end

		RecapsReview.greenTeam:SetText(tbl.green.team)
		RecapsReview.greenResult:SetFormattedText("%d (%d)", tbl.green.newTeamRating, tbl.green.honorGained)
		if tbl.green.honorGained < 0 then
			RecapsReview.greenResult:SetTextColor(1, 0, 0)
		else
			RecapsReview.greenResult:SetTextColor(0, 1, 0)
		end

		RecapsReview.goldTeam:SetText(tbl.gold.team)
		RecapsReview.goldResult:SetFormattedText("%d (%d)", tbl.gold.newTeamRating, tbl.gold.honorGained)
		if tbl.gold.honorGained < 0 then
			RecapsReview.goldResult:SetTextColor(1, 0, 0)
		else
			RecapsReview.goldResult:SetTextColor(0, 1, 0)
		end

		RecapsReview.goldTeam:ClearAllPoints()
		RecapsReview.goldTeam:SetPoint("TOPLEFT", RecapsReview["green"..tbl.teamSize], "BOTTOMLEFT", 0, -8)
		RecapsReview:SetHeight((16 * tbl.teamSize + 18) * 2)
	end
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
local viewFrame = CreateFrame("Frame", "RecapsWindow", UIParent)
viewFrame:SetWidth(400)
viewFrame:SetHeight(285)
viewFrame:SetBackdrop({	bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
						edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
						tile = true, tileSize = 16, edgeSize = 16, 
						insets = { left = 4, right = 4, top = 4, bottom = 4 }})
viewFrame:SetBackdropColor(0,0,0,1)
viewFrame:Hide()
viewFrame:SetPoint("CENTER")
viewFrame:RegisterForDrag("LeftButton")
viewFrame:SetClampedToScreen(true)
viewFrame:SetMovable(true)
viewFrame:EnableMouse(true)

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

viewFrame.version = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.version:SetWidth(100)
viewFrame.version:SetJustifyH("RIGHT")
viewFrame.version:SetPoint("TOPRIGHT", -5, -14)
viewFrame.version:SetFontObject(GameTooltipTextSmall)
viewFrame.version:SetFormattedText("Vers: %s", version)

viewFrame.title = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.title:SetWidth(300)
viewFrame.title:SetPoint("TOPRIGHT", -4, -6)
viewFrame.title:SetFontObject(GameTooltipText)
viewFrame.title:SetText("Arena Recaps Recent Matches")

viewFrame.titleBG = viewFrame:CreateTexture(nil, "BACKGROUND")
viewFrame.titleBG:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
viewFrame.titleBG:SetVertexColor(229/255, 0, 0)
viewFrame.titleBG:SetWidth(376)
viewFrame.titleBG:SetHeight(23)
viewFrame.titleBG:SetPoint("TOPRIGHT", -3, -3)

viewFrame.matchID = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.matchID:SetWidth(50)
viewFrame.matchID:SetPoint("TOPLEFT", 5, -30)
viewFrame.matchID:SetFontObject(GameTooltipTextSmall)
viewFrame.matchID:SetTextColor(29/255, 189/255, 229/255)
viewFrame.matchID:SetText("ID")

viewFrame.star = viewFrame:CreateTexture(nil, "ARTWORK")
viewFrame.star:SetTexture("Interface\\AddOns\\Recaps\\starred")
viewFrame.star:SetWidth(14)
viewFrame.star:SetHeight(14)
viewFrame.star:SetPoint("LEFT", viewFrame.matchID, "RIGHT", 0, 0)

viewFrame.headerDate = viewFrame:CreateFontString(nil, "ARTWORK")
viewFrame.headerDate:SetWidth(110)
viewFrame.headerDate:SetPoint("LEFT", viewFrame.star, "RIGHT", 12, 0)
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

viewFrame.scroll = CreateFrame("ScrollFrame", "RecapsWindowScroll", viewFrame, "FauxScrollFrameTemplate")
viewFrame.scroll:SetPoint("BOTTOMRIGHT", -25, 4)
viewFrame.scroll:SetWidth(370)
viewFrame.scroll:SetHeight(235)

viewFrame.scroll:SetScript("OnVerticalScroll",
	function(self, val)
		FauxScrollFrame_OnVerticalScroll(self, val, 14, Recaps_ScrollMatches)
	end)

viewFrame.scroll:SetScript("OnShow",
	function(self)
		Recaps_ScrollMatches()
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
	frame.match:SetWidth(25)
	frame.match:SetPoint("LEFT")
	frame.match:SetFontObject(GameTooltipTextSmall)

	frame.view = CreateFrame("Button", nil, frame)
	frame.view:SetWidth(14)
	frame.view:SetHeight(14)
	frame.view:SetPoint("LEFT", frame.match, "RIGHT", 4, 0)
	frame.view:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP")
	frame.view:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
	frame.view:SetScript("OnClick",
		function(self)
			local matchID = self:GetParent().matchID
			toggleReview(matchID)
		end)

	frame.star = CreateFrame("CheckButton", nil, frame)
	frame.star:SetWidth(14)
	frame.star:SetHeight(14)
	frame.star:SetPoint("LEFT", frame.view, "RIGHT", 9, 0)
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

viewFrame:SetScript("OnShow",
	function(self)
		Recaps_ScrollMatches()
	end)

viewFrame:SetScript("OnHide",
	function(self)
		RecapsReview:Hide()
		RecapsReview.matchID = nil
	end)

viewFrame:SetScript("OnDragStart",
	function(self)
		self:StartMoving()
	end)

viewFrame:SetScript("OnDragStop",
	function(self)
		self:StopMovingOrSizing()
	end)

table.insert(UISpecialFrames, "RecapsWindow")

local function getTeams(tbl)
	local name = UnitName("player")
	local server = GetRealmName()
	for _, val in ipairs(tbl.gold.members) do
		if val.name == name and tbl.gold.server == server then
			return tbl.gold, tbl.green
		end
	end
	return tbl.green, tbl.gold
end

function Recaps_ScrollMatches()
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
			local home, against = getTeams(tbl)
			row.against:SetText(against.team)
			row.result:SetText(home.honorGained)
			if home.honorGained >= 0 then
				row.result:SetTextColor(0, 1, 0)
			else
				row.result:SetTextColor(1, 0, 0)
			end
			row.star:SetChecked(tbl.starred)
		end
	end

	local frame = RecapsWindowScroll
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

--* Create the match review frame
local reviewFrame = CreateFrame("Frame", "RecapsReview", RecapsWindow)
reviewFrame:SetWidth(300)
reviewFrame:SetHeight(200)
reviewFrame:SetBackdrop({bgFile = "Interface/Buttons/WHITE8X8", 
						edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
						tile = true, tileSize = 16, edgeSize = 16, 
						insets = { left = 4, right = 4, top = 4, bottom = 4 }})
reviewFrame:SetBackdropColor(0,0,0,1)
reviewFrame:Hide()
reviewFrame:SetPoint("TOP", 0, -45)
reviewFrame:SetFrameStrata("HIGH")

reviewFrame.greenTeam = reviewFrame:CreateFontString(nil, "ARTWORK")
reviewFrame.greenTeam:SetWidth(230)
reviewFrame.greenTeam:SetPoint("TOPLEFT", 5, -5)
reviewFrame.greenTeam:SetFontObject(GameTooltipTextSmall)
reviewFrame.greenTeam:SetTextColor(0, 1, 0)

reviewFrame.greenResult = reviewFrame:CreateFontString(nil, "ARTWORK")
reviewFrame.greenResult:SetWidth(60)
reviewFrame.greenResult:SetPoint("LEFT", reviewFrame.greenTeam, "RIGHT", 0, 0)
reviewFrame.greenResult:SetFontObject(GameTooltipTextSmall)
reviewFrame.greenResult:SetJustifyH("RIGHT")

reviewFrame.goldTeam = reviewFrame:CreateFontString(nil, "ARTWORK")
reviewFrame.goldTeam:SetWidth(230)
reviewFrame.goldTeam:SetPoint("TOPLEFT", reviewFrame.greenTeam, "BOTTOMLEFT", 0, -5)
reviewFrame.goldTeam:SetFontObject(GameTooltipTextSmall)
reviewFrame.goldTeam:SetTextColor(1, 1, 0)

reviewFrame.goldResult = reviewFrame:CreateFontString(nil, "ARTWORK")
reviewFrame.goldResult:SetWidth(60)
reviewFrame.goldResult:SetPoint("LEFT", reviewFrame.goldTeam, "RIGHT", 0, 0)
reviewFrame.goldResult:SetFontObject(GameTooltipTextSmall)
reviewFrame.goldResult:SetJustifyH("RIGHT")

local function createRows(team)
	for i = 1, 5 do
		local frame = CreateFrame("Button", nil, reviewFrame)
		frame:SetWidth(290)
		frame:SetHeight(16)
		if i == 1 then
			frame:SetPoint("TOPLEFT", reviewFrame[team.."Team"], "BOTTOMLEFT", 0, 0)
		else
			frame:SetPoint("TOPLEFT", reviewFrame[team..i-1], "BOTTOMLEFT", 0, 0)
		end

		frame.class = frame:CreateTexture(nil, "BACKGROUND")
		frame.class:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		frame.class:SetWidth(14)
		frame.class:SetHeight(14)
		frame.class:SetPoint("LEFT")
	
		frame.name = frame:CreateFontString(nil, "ARTWORK")
		frame.name:SetWidth(90)
		frame.name:SetPoint("LEFT", frame.class, "RIGHT", 5, 0)
		frame.name:SetFontObject(GameTooltipTextSmall)
	
		frame.kb = frame:CreateFontString(nil, "ARTWORK")
		frame.kb:SetWidth(20)
		frame.kb:SetPoint("LEFT", frame.name, "RIGHT", 5, 0)
		frame.kb:SetFontObject(GameTooltipTextSmall)
		frame.kb:SetTextColor(1, 0.5, 0)
	
		frame.damage = frame:CreateFontString(nil, "ARTWORK")
		frame.damage:SetWidth(90)
		frame.damage:SetPoint("LEFT", frame.kb, "RIGHT", 5, 0)
		frame.damage:SetFontObject(GameTooltipTextSmall)
		frame.damage:SetTextColor(1, 0, 0.25)
	
		frame.healing = frame:CreateFontString(nil, "ARTWORK")
		frame.healing:SetWidth(90)
		frame.healing:SetPoint("LEFT", frame.damage, "RIGHT", 5, 0)
		frame.healing:SetFontObject(GameTooltipTextSmall)
		frame.healing:SetTextColor(0, 0.5, 1)
	
		frame.bg = frame:CreateTexture(nil, "BACKGROUND")
		frame.bg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		frame.bg:SetBlendMode("ADD")
		frame.bg:SetAllPoints(frame)
		if team == "green" then
			frame.bg:SetVertexColor(0, 1, 0)
		end
	
		reviewFrame[team..i] = frame
	end
end

createRows("green")
createRows("gold")

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
