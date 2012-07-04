local frame = CreateFrame("Frame");	-- for catching events

--local comm = LibStub("AceComm-3.0")

Messenger = {}
local m = Messenger
local markov = MarkovAnalyser
--local subscribers = {}	-- treat this like a key set where the key is subscriber name, and value is true/false
local AddonCode = AddonName
local AvailableSources = {}
local Online = {}

-- Transmission constants
local REQUEST_SUBSCRIBE = "REQSUB"
local REQUEST_UNSUBSCRIBE = "REQUNSUB"
local PLAYER_INFO = "PLAYERINFO"
local UPDATE = "UPDATE"	-- The main update message, triggered whenever a broadcasters predictive sequences change
local DUMP = "DUMP"	-- The main update message, triggered whenever a broadcasters predictive sequences change

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
	elseif startsWith(msg, REQUEST_UNSUBSCRIBE) then
		m.DeregisterSubscriber(src);
	elseif startsWith(msg, DUMP) then
		msg = msg:sub(DUMP:len() + 1);
		Chain:InitFromString(src, msg);
	elseif startsWith(msg, UPDATE) then
		msg = msg:sub(UPDATE:len() + 1);
		Chain:InitFromString(src, msg);
	elseif startsWith(msg, PLAYER_INFO) then
		msg = msg:sub(PLAYER_INFO:len() + 1);
		m.ParsePlayerInfo(src, msg);
	end
end

-- Returns true if str starts with seq
function startsWith(str, seq)
	return str:sub(1, seq:len()):find(seq);
end


function m.RegisterSubscriber(name)
	-- First send a full dump of the model to-date, to bring our new subscriber up to speed
	MarkovAnalyser:dumpTo(name);
	a.Subscribers[name] = true;
	print("Messenger: " .. name .. " subscribed to your broadcasts.");
	local class, level, primarytalent, t1, t2, t3 = PredictorAddon:PlayerInfo();
	message = PLAYER_INFO .. class .. "," .. level .. "," .. primarytalent .. "," .. 
				t1 .. "," .. t2 .. "," .. t3;
	PredictorAddon:SendCommMessage(AddonCode,message, "WHISPER", name);
	SendChatMessage(AddonName .. ": Subscription added successfully.", "WHISPER", nil, name);
	Online[name] = true;
end

function m.DeregisterSubscriber(name)
	a.Subscribers[name] = nil;
	print("Messenger: " .. name .. " unsubscribed.");
	PredictorAddon:SaveGlobalData();
	SendChatMessage(AddonName .. ": Subscription removed.", "WHISPER", nil, name);
end

function m.SubscribeToBroadcaster(subscriberName, broadcasterName)
	PredictorAddon:SendCommMessage(AddonCode, REQUEST_SUBSCRIBE, "WHISPER", broadcasterName);
end

function m.UnSubscribeToBroadcaster(subscriberName, broadcasterName)
	PredictorAddon:SendCommMessage(AddonCode,REQUEST_UNSUBSCRIBE, "WHISPER", broadcasterName);
end

function m.ListSubscribers()
	count = 0;
	print("Messenger: Registered subscribers:");
	for name, _ in pairs(a.Subscribers) do
		print("    " .. name);
		count = count + 1;
	end
end

function m.Broadcast(message) 
	--print("Sending message: " .. message);
	for name, _ in pairs(a.Subscribers) do
		if Online[name] then
			PredictorAddon:SendCommMessage(AddonCode, UPDATE .. message, "WHISPER", name);
		end
	end
end

function m.DumpTo(message, name) 
	PredictorAddon:SendCommMessage(AddonCode, DUMP .. message, "WHISPER", name);
end

function m.ParsePlayerInfo(source, msg)
	class, level, primarytalent, talent1, talent2, talent3 = split(msg, ",");
	a.SourceInfo[source] = class, level, primarytalent, talent1, talent2, talent3;
end

function m.CheckOnline()
	for i=1, GetNumFriends() do
		for name,_ in pairs(a.Subscribers) do
			fname,_,_,_, fconnect = GetFriendInfo(i);
			if fname == name then
				if fconnect then
					if a.DebugMode then print(name .. " is connected. Continuing/resuming updates to this subscriber."); end;
					Online[name] = true;
				else
					if a.DebugMode then print(fname .. " is not connected. Pausing updates to this subscriber."); end;
					Online[name] = false;
				end
				break;
			end
		end
		i = i + 1;
	end
end