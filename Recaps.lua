----------------------------------
--* Arena Recaps WoW AddOn
----------------------------------

--* Global variables
RECAPS_MATCHES = RECAPS_MATCHES or {}

--* Local variables
local arenastart, logging, recorded

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
		local name, killingBlows, _, _, _, faction, _, race, _, classToken, damageDone, healingDone = GetBattlefieldScore(i)
		if faction then
			if string.find(name, "%-") then
				name, server = string.split("-", name)
			end
			local _, teamRating, newTeamRating = GetBattlefieldTeamInfo(faction)
			local info = {
				name = name,
				killingBlows = killingBlows,
				race = race,
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
		gold = gold
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
viewFrame:SetHeight(300)
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

table.insert(UISpecialFrames, "ArenaRecapsWindow")

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