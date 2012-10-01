local AddonName, a = ...

--local frame, events = CreateFrame("Frame"), {};
local UsageHistory = {}
a.PredictedEvents = {}	-- queue of predicted upcoming actions

Predictor = {};

function Predictor:AddEventForPrediction(event)	-- TODO: Refactor, global for now
	while # UsageHistory >= a.Size[a.ModelInUse] do
		table.remove(UsageHistory, 1)	-- queue with a max length
	end
	table.insert(UsageHistory, event)
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
	if #UsageHistory == a.Size[a.ModelInUse] then	-- don't try and predict anything unless we have a full queue
		for i,v in ipairs(UsageHistory) do 
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
					hEvent = UsageHistory[i]
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
		--print("Match string: " .. matchString);
		if matchString ~= "" then
			local p = a.Models[a.ModelInUse][matchString];
			if p then
				-- get each link and add it to a nice table for processing by clients
				-- table should look like {{eventname,probability},{eventname,probability},...}
				local total = p["total"]
				for i=1,#p["links"] do	
					local spell = p["links"][i]["event"];
					local weightSum = (a.WeightingEvents + a.WeightingBuffs + a.WeightingState);
					--print("Predicted: " .. spell);
					-- cut off the first part of the id ("player" or "target" usually)
					splitter = string.find(spell, "&");
					spell = string.sub(spell, splitter+1);
					if iconInSpellbook(spell) then
						local eventWeight = (p["links"][i]["count"] / total) * a.WeightingEvents;
						--print("Event weight: " .. eventWeight);
						local buffWeight = Predictor:GetBuffWeighting(spell);
						local stateWeight = Predictor:GetStateWeighting(spell);
						-- print("Buff weight: " .. buffWeight);
						-- print("State weight: " .. stateWeight);
						-- print("Event weight: " .. eventWeight);
						-- print("Weight sum: " .. weightSum);
						local predictedWeight = round(((eventWeight + buffWeight + stateWeight) / weightSum) * 100);
						--print("Predicted weight: " .. predictedWeight);
						if predictedWeight >= a.MinLikelihoodThreshold then
							table.insert(a.PredictedEvents, {spell, predictedWeight});
						end
					--else
					--	print(spell);
					end
				end
				--Predictor:ApplyBuffWeightings();
				-- finally, sort the table to show most likely first
				table.sort(a.PredictedEvents, function(a,b) return a[2] > b[2] end)
			end
		end
		PrVisScroll:Update();
	end
end

function Predictor:GetBuffWeighting(spell)
	if a.WeightingBuffs == 0 then
		return 0;	-- Just to cut down on any additional processing if it's not needed
	else 
		local currentBuffs = {};
		local i = 1;
		local buff = UnitBuff("player", i);
		while buff do
			tinsert(currentBuffs, buff);		
			i = i + 1;
			buff = UnitBuff("player", i);
		end
		local sum = 0;
		local totalPredicted = 0;
		local historyBuffs = a.BuffLog[spell];
		if historyBuffs then
			--print(" -- ");
			for k,v in pairs(historyBuffs) do
				totalPredicted = totalPredicted + v;
				for j=1, #currentBuffs do
					if currentBuffs[j] == k then
						sum = sum + v;
						break;
					end
				end
			end
		end
		return (sum / totalPredicted) * a.WeightingBuffs;
	end
end

function Predictor:GetStateWeighting(spell)
	return PrStateManager:GetLikelihoodForSpell(spell) * a.WeightingState;
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
