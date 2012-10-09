local AddonName, a = ...

PrStateManager = {}

local current = {};
local targets = {"player", "target"};

local TRUE = 1;
local FALSE = 2;

function PrStateManager:UpdateState()
	current["player"] = {};
	current["target"] = {};
	
	local hpPercent = (UnitHealth("player") / UnitHealthMax("player")) * 100
	current["player"]["healthOver75"] = hpPercent > 75 and 1 or 0;
	current["player"]["healthOver50"] = hpPercent > 50 and 1 or 0;
	current["player"]["healthOver25"] = hpPercent > 25 and 1 or 0;
	current["player"]["healthOver0"] = hpPercent > 0 and 1 or 0;
	current["player"]["inCombat"] = InCombatLockdown() and 1 or 0;
	current["player"]["inParty"] = UnitInParty("player") and 1 or 0;
	current["player"]["inRaid"] = UnitInRaid("player") and 1 or 0;
	current["player"]["inBattleground"] = UnitInBattleground("player") and 1 or 0;
	
	hpPercent = UnitHealth("target") / UnitHealthMax("target")
	current["target"]["healthOver75"] = hpPercent > 0.75 and 1 or 0;
	current["target"]["healthOver50"] = hpPercent > 0.50 and 1 or 0;
	current["target"]["healthOver25"] = hpPercent > 0.25 and 1 or 0;
	current["target"]["healthOver0"] = hpPercent > 0.0 and 1 or 0;
	current["target"]["isFriendly"] = UnitIsFriend("target", "player") and 1 or 0;
	--TODO: Add mana values
end

function PrStateManager:DumpCurrentState()
	PrStateManager:UpdateState();
	for k,v in pairs(current["player"]) do
		local out = 0;
		if v then out = 1; end;
		print("player -- " .. k .. " : " .. v);
	end
	for k,v in pairs(current["target"]) do
		local out = 0;
		if v then out = 1; end;
		print("target -- " .. k .. " : " .. v);
	end
end

function PrStateManager:GetCurrentState()
	PrStateManager:UpdateState();
	return current;
end

function PrStateManager:UpdateStateLog(eventName)
	PrStateManager:UpdateState();
	
	local saveState = a.StateLog[eventName];
	if not saveState then
		saveState = {};
		saveState["player"] = {};
		saveState["target"] = {};
		for i,targ in ipairs(targets) do
			for k,v in pairs(current[targ]) do
				saveState[targ][k] = {};
				saveState[targ][k][FALSE] = 0;	
				saveState[targ][k][TRUE] = 0;				
			end
		end
	end
	for i,targ in ipairs(targets) do
		for k,v in pairs(current[targ]) do
			local ind = FALSE;
			if current[targ][k] == 1 then
				ind = TRUE
			end
			saveState[targ][k][ind] = saveState[targ][k][ind] + 1;
		end
	end
	a.StateLog[eventName] = saveState;
end

function PrStateManager:GetLikelihoodForSpell(spellName)
	local history = a.StateLog[spellName];
	if not history then return 1;
	else return PrStateManager:Compare(history);
	end
end

-- Compares a historical state object with the current state
-- Returns a value representing the difference between the current and historical state (lower value = higher disparity)
-- TODO: Need to think about the best way to utilize these numbers in a way that assists prediction
-- Current approach is definitely NOT ideal. e.g. If a state attribute has a 10:100 True:False ratio, and the current state is TRUE, it should drastically increase the certainty of this event occurring...
function PrStateManager:Compare(historyState)
	PrStateManager:UpdateState();
	local total = 0;
	local match = 0;
	for i,targ in ipairs(targets) do
		for k,v in pairs(historyState[targ]) do
			local t = historyState[targ][k][TRUE]
			local f = historyState[targ][k][FALSE]
			if current[targ][k] == 1 then
				print(targ .. "::: " .. k .. " TRUE -- (" .. t .. "-" .. f .. ")");
				match = match + t;
			else
				print(targ .. "::: " .. k .. " FALSE --(" .. t .. "-" .. f .. ")");
				match = match + f;
			end;
			total = total + t + f;
		end
	end
	--print(match / total);
	return (match / total);
end

if a.DebugMode then print("StateManager loaded"); end;