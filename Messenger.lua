local AddonName, a = ...
local frame = CreateFrame("Frame");	-- for catching events

local Serializer = LibStub("AceSerializer-3.0")

Messenger = {}
local m = Messenger
local markov = MarkovAnalyser
--local subscribers = {}	-- treat this like a key set where the key is subscriber name, and value is true/false
local AddonCode = AddonName
local AvailableSources = {}
local Online = {}
local timer = 0;

-- Transmission constants
local REQUEST_SUBSCRIBE = "REQSUB"
-- local REQUEST_UNSUBSCRIBE = "REQUNSUB"
local PLAYER_INFO = "PLAYERINFO"
local UPDATE = "UPDATE"	-- The main update message, triggered whenever a broadcasters predictive sequences change
local DUMP = "DUMP"	-- The main update message, triggered whenever a broadcasters predictive sequences change
local REQUEST_UPDATE = "REQUPD"

PredictorAddon:RegisterComm(AddonCode, function (prefix, message, distribution, sender)
	m.Receive(message, sender);
end)

-- Takes any message, figures out where it needs to go, and triggers the requested action
-- This also requires removing any control information that needs to be included in broadcasts
function m.Receive(msg, src)
	--print(msg);
	--print("source: " .. src);
	--print("message: " .. msg);
	-- Only check the very beginning of the string, just in case this sequence of characters also turns up in the midst of the a string
	if startsWith(msg, REQUEST_SUBSCRIBE) then
		m.RegisterSubscriber(src);
	-- elseif startsWith(msg, REQUEST_UNSUBSCRIBE) then
		-- m.DeregisterSubscriber(src);
	elseif startsWith(msg, UPDATE) then
		msg = msg:sub(UPDATE:len() + 1);
		m.HandleUpdate(src, msg);
	elseif startsWith(msg, PLAYER_INFO) then
		msg = msg:sub(PLAYER_INFO:len() + 1);
		m.ParsePlayerInfo(src, msg);
	elseif startsWith(msg, REQUEST_UPDATE) then
		msg = msg:sub(REQUEST_UPDATE:len() + 1);
		m.HandleUpdateRequest(src, msg);
	end
end

-- Returns true if str starts with seq
function startsWith(str, seq)
	return str:sub(1, seq:len()):find(seq);
end


function m.RegisterSubscriber(name)
	-- MarkovAnalyser:dumpTo(name);
	-- a.Subscribers[name] = true;
	print("Messenger: " .. name .. " subscribed to your broadcasts.");
	local class, level, primarytalent, t1, t2, t3 = PredictorAddon:PlayerInfo();
	message = PLAYER_INFO .. class .. "," .. level .. "," .. primarytalent .. "," .. 
				t1 .. "," .. t2 .. "," .. t3;
	PredictorAddon:SendCommMessage(AddonCode,message, "WHISPER", name);
	-- SendChatMessage(AddonName .. ": Subscription added successfully.", "WHISPER", nil, name);
	-- Online[name] = true;
end

function m.SubscribeToBroadcaster(subscriberName, broadcasterName)
	PredictorAddon:SendCommMessage(AddonCode, REQUEST_SUBSCRIBE, "WHISPER", broadcasterName);
end

-- function m.UnSubscribeToBroadcaster(subscriberName, broadcasterName)
	--PredictorAddon:SendCommMessage(AddonCode,REQUEST_UNSUBSCRIBE, "WHISPER", broadcasterName);
-- end

-- function m.ListSubscribers()
	-- count = 0;
	-- print("Messenger: Registered subscribers:");
	-- for name, _ in pairs(a.Subscribers) do
		-- print("    " .. name);
		-- count = count + 1;
	-- end
-- end

-- Request an update from a broadcaster, for all events that have occurred since lastUpdate
function m.RequestUpdate(lastUpdate, broadcasterName)
	PredictorAddon:SendCommMessage(AddonCode, REQUEST_UPDATE .. lastUpdate, "WHISPER", broadcasterName);
end

-- Generate an update in response to an update request (may be no update needed)
function m.HandleUpdateRequest(src, lastUpdate)
	-- Check for any events that have occurred since lastUpdate
	-- TODO: Will need to do some serious checking for performance here
	local newEvents = {};
	local playerEvents = a.EventLog[UnitName("player")];
	if lastUpdate then
		-- Start at the end of the log and go backwards (so we should only have to check unsubmitted events)
		local i = #playerEvents;
		
		while i > 0 and playerEvents[i][3] > tonumber(lastUpdate) do
			tinsert(newEvents, 1, playerEvents[i]); -- insert at beginning of table (since we are going backwards)
			i = i - 1;
		end
		if i ~= #playerEvents then dprint("Messenger: Sending " .. #playerEvents - i .. " new events to " .. src .. "."); end
	else
		newEvents = playerEvents;
	end
	PredictorAddon:SendCommMessage(AddonCode, UPDATE .. Serializer:Serialize(newEvents), "WHISPER", src);
end

function m.HandleUpdate(src, msg)
	local success, events = Serializer:Deserialize(msg);
	if success then
		if #events > 0 then
			for i=1, #events do
				tinsert(a.EventLog[src], events[i]);
			end
			dprint("Messenger: " .. #events .. " new events received from " .. src .. ".");
			MarkovAnalyser:fullRefresh(src);
		end
	else
		dprint("Messenger: Error deserializing message from " .. src .. ": " .. events);
	end
end


function m.ParsePlayerInfo(src, msg)
	print("received");
	local class, level, primarytalent, talent1, talent2, talent3 = split(msg, ",");
	a.Subscriptions[src] = class, level, primarytalent, talent1, talent2, talent3;
	--TODO not sure if this should be here or elsewhere
	a.Models[src] = {};
	m.RequestUpdate(0, src);
end


-- Timer to automatically request updates
frame:SetScript("OnUpdate", function(self, elapsed)
	timer = timer + elapsed
	if timer > a.SubscriptionUpdateFrequency then
		if a.ModelInUse ~= UnitName("player") then
			local lastUpdate = 0;
			if a.EventLog[a.ModelInUse] and #a.EventLog[a.ModelInUse] > 0 then 
				lastUpdate = a.EventLog[a.ModelInUse][#a.EventLog[a.ModelInUse]][3] 
			end
			m.RequestUpdate(lastUpdate, a.ModelInUse);
			timer = 0;
		end
	end
end);

-- function m.CheckOnline()
	-- for i=1, GetNumFriends() do
		-- for name,_ in pairs(a.Subscriptions) do
			-- fname,_,_,_, fconnect = GetFriendInfo(i);
			-- if fname == name then
				-- if fconnect then
					-- if a.DebugMode then print(name .. " is connected. Continuing/resuming update requests to this subscription source."); end;
					-- m.RequestUpdate(a.EventLog[name][#a.EventLog[name]][3],name);
					-- Online[name] = true;
				-- else
					-- if a.DebugMode then print(fname .. " is not connected. Pausing update requests to this subscription source."); end;
					-- Online[name] = false;
				-- end
				-- break;
			-- end
		-- end
		-- i = i + 1;
	-- end
-- end