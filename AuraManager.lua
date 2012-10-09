local AddonName, a = ...

PrAuraManager = {}

local history = {}
 
-- This is all necessary in order to track active auras at the time that an ability is used.
-- If we check when the UNIT_SPELLCAST_SUCCEEDED event is caught, the auras have already updated.
-- So instead we keep track of historical aura data, and check THAT, rather than the current aura info.
function PrAuraManager:AurasChanged(unitID)
	--print("Auras changed at " .. time());
	if unitID == "player" then
		history = {};			-- reset
		local i = 1;
		local buff = UnitBuff("player", i);
		while buff do
			--print("     " .. buff);		
			tinsert(history, buff);
			i = i + 1;
			buff = UnitBuff("player", i);
		end
	end
end

function PrAuraManager:UpdateBuffLog(entry)
	if entry[1] == "UNIT_SPELLCAST_SUCCEEDED" then
		if history then			
			local ability = a.BuffLog[entry[2][2]];
			if not ability then
				ability = {};
			end
			
			for i,buff in ipairs(history) do
				if not ability[buff] then
					ability[buff] = 1;
				else
					ability[buff] = ability[buff] + 1;
				end
				--print("     " .. buff .. " (" .. ability[buff] .. ")");		
			end
			a.BuffLog[entry[2][2]] = ability;
		end
	end
end