local AddonName, a = ...

local frame, events = CreateFrame("Frame"), {};
local SFHistory = {}
a.PredictedEvents = {}	-- queue of predicted upcoming actions

Predictor = {};

function Predictor:AddEventForPrediction(event)	-- TODO: Refactor, global for now
	if # SFHistory >= a.Size[a.ModelInUse] then
		table.remove(SFHistory, 1)	-- queue with a max length
	end
	table.insert(SFHistory, event)
	spellName = event[2][2];
	--need to think about this more
	PrVisScroll:SpellWasCast(spellName);
	if not a.HideVisualizations then Predictor:PredictActions(); end
end

function Predictor:Break()
	-- if PredictListFrame.textFields then
		-- for i = 1,  # PredictListFrame.textFields  do
			-- PredictListFrame.textFields[i]:Hide();
		-- end
	-- end
	-- if PredictListFrame.textures then
		-- for i = 1,  # PredictListFrame.textFields  do
			-- PredictListFrame.textures[i]:Hide();
		-- end
	-- end
	-- PredictListFrame.spells = {};
end


function Predictor:GetLikelihoodForSpell(spellName)
	local result = 0;
	for i=1, #a.PredictedEvents do
		local ev = a.PredictedEvents[i];
		if ev[1] == spellName then
			result = ev[2];
			break;
		end
	end
	return result / 100;
end

-- Prediction logic - maintains a.PredictedEvents, so that other classes can always access and find the next expected events
function Predictor:PredictActions()
	a.PredictedEvents = {}
	if # SFHistory == a.Size[a.ModelInUse] then	-- don't try and predict anything unless we have a full queue
		for i,v in ipairs(SFHistory) do 
			desc = v[1]
			args = v[2]
		end
		
		-- step through logged events
		matchString = ""
		--for j=1, # a.MarkovChains do
		for k,v in pairs(a.Models[a.ModelInUse]) do
			match = true
			eventCodes = split(v["prefix"], "#");
			hArgTable = {}
			if # eventCodes == a.Size[a.ModelInUse] then	-- restrict comparisons to sequences of the same length only
				for i=1, a.Size[a.ModelInUse] do
					lArgs = split(eventCodes[i], "&");
					hEvent = SFHistory[i]
					hArgs = {hEvent[2][1], hEvent[2][2]}
					if hArgs[1] ~= lArgs[1] or hArgs[2] ~= lArgs[2] then
						match = false
						break
					end
				end
				if match then
					matchString = v["prefix"]
					break
				end
			end
			matchString = ""
		end
		if matchString ~= "" then
			p = a.Models[a.ModelInUse][matchString];
			if p then
				-- get each link and add it to a nice table for processing by clients
				-- table should look like {{eventname,probability},{eventname,probability},...}
				total = p["total"]
				for i=1,#p["links"] do	
					spell = p["links"][i]["event"];
					-- cut off the first part of the id ("player" or "target", usually)
					splitter = string.find(spell, "&");
					spell = string.sub(spell, splitter+1);
					count = round((p["links"][i]["count"] / total) * 100);
					--print ("Adding to predictor: " .. spell .. ", " .. count);
					if iconInSpellbook(spell) then
						table.insert(a.PredictedEvents, {spell, count});
					else
						--if a.DebugMode then print("Ability not found in spellbook: " .. spell) end;
					end
				end
				-- finally, sort the table to show most likely first
				table.sort(a.PredictedEvents, function(a,b) return a[2] > b[2] end)
			end
		end
		PrVisScroll:UpdateContents();
	end
end

function iconInSpellbook(spell)
	name, rank, icon = GetSpellInfo(spell);
	return icon;
end

-- Utility function to round a decimal 
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

if a.DebugMode then print("Predictor loaded"); end
