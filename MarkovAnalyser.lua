local AddonName, a = ...
local m = Messenger

MarkovAnalyser = {}
local markov = MarkovAnalyser

-- Useful for measuring performance
-- local startTime = GetTime();
-- local complete = GetTime() - startTime;
-- print("Refresh time (millis): " .. complete);
local events = {};
-- Main loop.
--  Checks the event buffer for new additions - if something has changed, refresh all of our sequences.
local frame = CreateFrame("Frame");
local lastTime = time();
local lastEvent = nil;
frame:SetScript("OnUpdate", function(self, ...)
	if a.ProcessEvents then	-- Flag to pause event processing if needed.
		if EventBuffer then
			if lastEvent and lastEvent ~= EventBuffer[#EventBuffer] then
				--print("diff = " .. (EventBuffer[#EventBuffer][3] - lastEvent[3]));
				EventBuffer = filterEvents(EventBuffer);	-- Remove irrelevant stuff.	
				if #EventBuffer > 0 then
					-- Now that this is filtered, let predictor know that something relevant occurred.
					-- Do this whenever eventbuffer isn't empty - don't want to wait for it to be ready
					if lastEvent ~= EventBuffer[#EventBuffer] then 
						Predictor:AddEventForPrediction(EventBuffer[#EventBuffer]);	
					end;
				end
				if #EventBuffer > a.Size[UnitName("player")] then
					--dprint(EventBuffer[#EventBuffer][2][2]);
					-- Now make a sub-buffer of pre-sequence + result
					local sub = {};
					for i=1,a.Size[UnitName("player")] + 1 do
						sub[i] = EventBuffer[i];
					end
					markov:refresh(sub, UnitName("player"));
					tremove(EventBuffer,1); 
				end
			end
			lastEvent = EventBuffer[#EventBuffer];
		end
	end
end);

function markov:fullRefresh(source)
	local sources = split(source, ",");
	local filteredBuffer = {};
	if #sources == 1 then
		filteredBuffer = filterEvents(a.EventLog[source]);
	else
		for i=1, #sources do
			local f = filterEvents(a.EventLog[sources[i]]);
			for j=1, #f do
				tinsert(filteredBuffer, f[j]);
			end
			print("source: " .. sources[i] .. " -- " .. #f .. " found");
		end
	end	
	a.Models[source] = {};
	markov:refresh(filteredBuffer, source);
end

function filterEvents(buffer)
	local result = {}
	if buffer then
		for i=1,# buffer do
			if buffer[i][1]:find("UNIT_SPELLCAST_SUCCEEDED") then	-- ignoring other event types for now
				if buffer[i][2][1] == "player" then -- only process player actions - this can be changed later if wanted.
					if buffer[i][2][2] ~= "Auto Shot" then -- Here add individual filters...
						table.insert(result, buffer[i]);
					end
				end
			end
		end
	end
	return result;
end

function markov:refresh(buffer, modelName)
	local events = {}	-- refresh events
	local times = {};
	if buffer then
		for i=1,# buffer do
			eType = buffer[i][1];
			if eType:find("UNIT_SPELLCAST_SUCCEEDED") then	-- ignoring other event types for now
				actor = buffer[i][2][1];
				action = buffer[i][2][2];
				if actor == "player" then -- only process player actions - this can be changed later if wanted.
					table.insert(events, actor .. "&" .. action);
					table.insert(times, buffer[i][3]);
					--print(action);
				end
			end
		end
	end
	changed = false;
	if #events > a.Size[modelName] then	-- don't want to build any short chains
		Queue:Init(events, a.Size[modelName]);
		for i=a.Size[modelName] + 1,#events do
			--print(times[i] - times[i - 1]);
			if times[i] - times[i - 1] < a.MaxTimeBetweenEvents then
				--print(times[i] .. " -- " .. times[i - 1]);
				key = Queue:GetString();
				--print(key);
				chain = a.Models[modelName][key]
				if not chain then 
					--dprint("New chain: " .. key);
					chain = Chain.Init(key)
					a.Models[modelName][key] = chain;
					changed = true;
				end
				Chain.AddEvent(chain, events[i]);
			else
				-- This was removed in case the model being generated was not the model being visualized. However, this might be okay to return for now..
				--Predictor:Break();
			end
			Queue:Add(events[i]);	-- get next event
		end
	end
	if changed then 
		entries = 0;
		for k,v in pairs(a.Models[modelName]) do
			eventCodes = split(v["prefix"], "#");
			if #eventCodes == a.Size[modelName] then
				entries = entries + 1;
			end
		end
		dprint("MarkovAnalyzer updated. Model name = " .. modelName .. ". Chain length = " .. a.Size[modelName] .. ". " .. entries .. " pre-sequences recognized."); 
	end
end


function markov:dump() 
	print("Dumping data for model: " .. a.ModelInUse);
	count = 0;
	for k,v in pairs(a.Models[a.ModelInUse]) do
		eventCodes = split(v["prefix"], "#");
		if #eventCodes == a.Size[a.ModelInUse] then
			print("[" .. k .. "]:");
			for i=1, #v["links"] do
				print("   " .. v["links"][i]["count"] .. ": " .. v["links"][i]["event"]);
			end
			count = count + 1;
		end
	end
	print(count .. " sequences found");
end

-- Perform a dump of all data to a specified subscriber.
function markov:dumpTo(subscriber)
	print("Dumping data to subscriber " .. subscriber);
	for k,v in pairs(a.Models[UnitName("player")]) do
		chain = a.Models[UnitName("player")][k]
		if chain then
			--print("dumping");
			m.DumpTo(Chain.ToString(chain), subscriber);
		end
	end
end

function markov:reset()
	a.Models[a.ModelInUse] = {}
	a.EventLog = {};
	a.EventLog[UnitName("player")] = {};
	print(#a.EventLog);
	PredictorAddon:SaveGlobalData();
	print("MarkovAnalyser: Data erased");
end











Link = {}
Link.__index = Link;

function Link:GetEvent()
	return self.event;
end

function Link:GetCount()
	return self.count;
end

function Link:SetCount(amount)
	--self.count = amount;-- Note that previously this added count to self.total, I don't think this was actually necessary...
	self.count = self.count + amount;
end

function Link.Init(e, c)
	local l = {};
	setmetatable(l, Link);
	l.event = e;
	if c then l.count = c; else l.count = 1; end
	return l;
end

Chain = {}
Chain.__index = Chain;

function Chain:AddEvent(event, count)	-- count is only defined if this event is being rebuilt from saved data
	if not count then count = 1 end;
	--self.total =  count;	-- Note that previously this added count to self.total, I don't think this was actually necessary...
	self.total = self.total + count;
	--if count then self.total = count else self.count = self.count + 1 end;
	--print(self.prefix .. ": Add event: " .. event);
	found = false;
	for i=1,# self.links do
		link = self.links[i];
		--print(link);
		if Link.GetEvent(link) == event then
			--print ("found!");
			Link.SetCount(self.links[i],count);
			found = true;
			break;
		end
	end
	if not found then
		--newLink = Link:Init(event);
		--print(event);
		--print(Link:
		table.insert(self.links, Link.Init(event, count));
	end
end

function Chain:GetPrefix()
	return self.prefix;
end

function Chain:ToString()
	result = self.prefix .. "-->"
	for i=1,# self.links do
		link = self.links[i];
		result = result .. Link.GetEvent(link) .. "{" .. Link.GetCount(link) .. "}";
		if i < #self.links then
			result = result .. ",";
		end		
	end
	return result;
end

-- Take a string as input, turn it into a chain, then insert it into the dictionary
-- Format:
--		
function Chain:InitFromString(model, input)
	if a.DebugMode then print(input); end;
	spl = split(input, "-->");
	key = spl[1];	-- pre-sequence key
	post = spl[2];	-- comma separated post sequences
	--print(" -- MODEL: " .. model);
	--print(" -- PRE: " .. key);
	if not a.Models[model] then 
		a.Models[model] = {};
		a.Size[model] = a.Size[UnitName("player")];
	end;
	chain = a.Models[model][key]
	if not chain then 
		chain = Chain.Init(key)
		a.Models[model][key] = chain;
	end
	
	postsequences = split(post, ",");
	for i=1, #postsequences do
		postseq = postsequences[i];
		spl = split(postseq, "{");
		postseqval = spl[1];
		if not spl[2] then
			print("ERROR ADDING: " .. input);
			-- Shouldn't happen anymore.
			break;
		else
			postseqcount = spl[2]:gsub("}", "");
			--print(" -- POST: " .. postseqval .. "(" .. postseqcount .. ")");
			Chain.AddEvent(chain, postseqval);	-- leave the count out for now (will always just increment)...
		end
	end
	--PredictorAddon:SaveGlobalData();
end

function Chain.Init(pre)
	local ch = {}
	setmetatable(ch, Chain)
	ch.prefix = pre;
	ch.total = 0;
	ch.links = {};
	return ch;
end




-- Short buffer containing 'pre-sequences'
Queue = {
	Add = function(self, event)
		if # self.q == self.capacity then
			table.remove(self.q, 1);
		end
		table.insert(self.q,event);
		--print("Added event to queue: " .. event.. ". Queue is now: " .. Queue:GetString());		
	end,
	
	GetString = function(self)
		result = ""
		for i=1,#self.q do
			result = result .. self.q[i]
			if i < #self.q then
				result = result .. "#";	-- delimiter
			end
		end
		return result;
	end,
	
	GetContents = function(self)
		return self.q;
	end,
	
	Init = function(self, events, size)
		self.capacity = size
		self.q = {}
		--print("init queue with size " .. size)
		for i=1,size do
			Queue:Add(events[i]);
		end
	end
}




-- Utility function for splitting strings into a table of tokens separated by the provided delimiter
function split(str, delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( str, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( str, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( str, delimiter, from  )
  end
  table.insert( result, string.sub( str, from  ) )
  return result
end

-- Utility function to round a decimal 
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

if a.DebugMode then print("MarkovAnalyser loaded"); end