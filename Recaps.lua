--* Recaps WoW AddOn
RECAPS_SAVED = RECAPS_SAVED or {}

--* Local variables
local arenastart, logging, recorded

--* Prints out messages to the default chat frame
local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

--* Saves the arena match data
local function saveArena(mapName, teamSize)
	local team0, team1 = GetBattlefieldTeamInfo(0), GetBattlefieldTeamInfo(1)
	local details = {}

	local numScores = GetNumBattlefieldScores()
	for i = 1, numScores do
		local server = GetRealmName()
		local name, killingBlows, _, deaths, _, faction, _, race, _, classToken, damageDone, healingDone = GetBattlefieldScore(i)
		if faction then
			if string.find(name, "%-") then
				name, server = string.split("-", name)
			end
			local _, teamRating, newTeamRating = GetBattlefieldTeamInfo(faction)
			local info = {
				name = name,
				server = server,
				killingBlows = killingBlows,
				deaths = deaths,
				honorGained = newTeamRating - teamRating,
				race = race,
				classToken = classToken,
				damageDone = damageDone,
				healingDone = healingDone,
				teamRating = teamRating
			}
			
			if faction == 0 then
				info.team = team0
				info.faction = "Green"
			else
				info.team = team1
				info.faction = "Gold"
			end
			table.insert(details, info)
		end
	end
	
	table.insert(RECAPS_SAVED, {
		map_name = mapName,
		arenaStop = time(),
		arenaStart = arenastart,
		details = details,
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