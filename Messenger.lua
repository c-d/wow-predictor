local AddonName, a = ...
local frame = CreateFrame("Frame");	-- for catching events

AceSerializer = LibStub("AceSerializer-3.0")

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
function m.RequestUpdate(lastUpdate, modelName)
	local broadcasters = split(modelName, ",")
	for i=1, #broadcasters do
		if broadcasters[i] ~= UnitName("player") then
			PredictorAddon:SendCommMessage(AddonCode, REQUEST_UPDATE .. lastUpdate, "WHISPER", broadcasters[i]);
		end
	end
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
		--if i ~= #playerEvents then dprint("Messenger: Sending " .. #playerEvents - i .. " new events to " .. src .. "."); end
	else
		newEvents = playerEvents;
	end
	PredictorAddon:SendCommMessage(AddonCode, UPDATE .. AceSerializer:Serialize(newEvents), "WHISPER", src);
end

function m.HandleUpdate(src, msg)
	local success, events = AceSerializer:Deserialize(msg);
	if success then
		if #events > 0 then
			for i=1, #events do
				if not a.EventLog[src] then a.EventLog[src] = {}; end;
				tinsert(a.EventLog[src], events[i]);
			end
			--dprint("Messenger: " .. #events .. " new events received from " .. src .. ".");
			if string.find(a.ModelInUse, src) then	-- Only update model if the updating source is part of the model we're interested in
				MarkovAnalyser:fullRefresh(a.ModelInUse);
			end
		end
	else
		dprint("Messenger: Error deserializing message from " .. src .. ": " .. events);
	end
end


function m.ParsePlayerInfo(src, msg)
	local class, level, spec = split(msg, ",");
	a.Subscriptions[src] = class, level, spec;
	print("Messenger: Subscription to " .. src .. " established.");
	a.Models[src] = {};
	a.EventLog[src] = {};
	m.RequestUpdate(0, src);
end


-- Timer to automatically request updates
frame:SetScript("OnUpdate", function(self, elapsed)
	timer = timer + elapsed
	if timer > a.SubscriptionUpdateFrequency then
		m.CheckOnline();
		for src,v in pairs(a.Subscriptions) do
			
			if src ~= UnitName("player") and Online[name] then
				local lastUpdate = 0;
				if a.EventLog[src] and #a.EventLog[src] > 0 then 
					lastUpdate = a.EventLog[src][#a.EventLog[src]][3] 
				end
				m.RequestUpdate(lastUpdate, src);
				timer = 0;
			end
		end
	end
end);

function m.CheckOnline()
	for name,_ in pairs(a.Subscriptions) do
		for i=1, GetNumFriends() do
			local fname,_,_,_, fconnect = GetFriendInfo(i);
			if fname == name then
				if fconnect then
					if a.DebugMode and not Online[name] then print(name .. " is connected. Continuing/resuming update requests to this subscription source."); end;
					--m.RequestUpdate(a.EventLog[name][#a.EventLog[name]][3],name);
					Online[name] = true;
				else
					if a.DebugMode and Online[name] then print(fname .. " is not connected. Pausing update requests to this subscription source."); end;
					Online[name] = false;
				end
				break;
			end
			i = i + 1;
		end
	end
end