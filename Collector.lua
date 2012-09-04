local AddonName, a = ...

-- Need a frame to catch events
local frame, events = CreateFrame("Frame"), {};

EventBuffer = {}

---------------------------------------------------------------------------------
-- This section handles tracking of new actions, as they occur
---------------------------------------------------------------------------------
-- Combat
function events:PLAYER_ENTER_COMBAT(...)	ColLogEvent("PLAYER_ENTER_COMBAT", ...)end
function events:PLAYER_LEAVE_COMBAT(...)	ColLogEvent("PLAYER_LEAVE_COMBAT", ...)end
function events:PLAYER_TARGET_CHANGED(...)	ColLogEvent("PLAYER_TARGET_CHANGED", ...)end


-- Spell
--function events:SPELL_UPDATE_USABLE(...)	LogEvent("SPELL_UPDATE_USABLE", ...) end
-- Some of these are questionable, and might be better to filter them (e.g. only log player/target actions)
function events:UNIT_SPELLCAST_CHANNEL_START(...)	ColLogEvent("UNIT_SPELLCAST_CHANNEL_START", ...) end
function events:UNIT_SPELLCAST_CHANNEL_STOP(...)	ColLogEvent("UNIT_SPELLCAST_CHANNEL_STOP", ...) end
function events:UNIT_SPELLCAST_CHANNEL_UPDATE(...)	ColLogEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", ...) end
function events:UNIT_SPELLCAST_DELAYED(...)	ColLogEvent("UNIT_SPELLCAST_DELAYED", ...) end
function events:UNIT_SPELLCAST_INTERRUPTED(...)	ColLogEvent("UNIT_SPELLCAST_INTERRUPTED", ...) end

function events:UNIT_SPELLCAST_START(...)	ColHandleUnitSpellCast("UNIT_SPELLCAST_START", ...) end
function events:UNIT_SPELLCAST_STOP(...)	ColHandleUnitSpellCast("UNIT_SPELLCAST_STOP", ...) end
function events:UNIT_SPELLCAST_SUCCEEDED(...)	ColHandleUnitSpellCast("UNIT_SPELLCAST_SUCCEEDED", ...) end
-- Vehicle
function events:UNIT_ENTERED_VEHICLE(...)	ColLogEvent("UNIT_ENTERED_VEHICLE", ...) end
function events:UNIT_EXITED_VEHICLE(...)	ColLogEvent("UNIT_EXITED_VEHICLE", ...) end

function ColHandleUnitSpellCast(desc, ...)
	if ... ~= nil then 
		unit = ({...})[1]	-- first param is the unit being referenced
		if unit == "player" or unit == "target" then
			ColLogEvent(desc, ...)
		end
	end
end

frame:SetScript("OnEvent", function(self, event, ...)
 events[event](self, ...); -- call one of the functions above
end);
for k, v in pairs(events) do
 frame:RegisterEvent(k); -- Register all events for which handlers have been defined
end


---------------------------------------------------------------------------------
-- Log events for processing.
---------------------------------------------------------------------------------

--- Log an event to the global event log.
-- Also handles all formatting.
function ColLogEvent(desc, ...)
	entry = {desc, {...}, time()}	
	table.insert(EventBuffer, entry)
	UpdateBuffLog(entry);
	if not a.PauseEventTracking then
		table.insert(a.EventLog[UnitName("player")], entry)
	end
end

function UpdateBuffLog(entry)
	if entry[1] == "UNIT_SPELLCAST_SUCCEEDED" then
		local ability = a.BuffLog[entry[2][2]];
		if not ability then
			ability = {};
			--print("--new");
		end
		--print(entry[2][2] .. ": ");
		
		local i = 1;
		local buff = UnitBuff("player", i);
		while buff do
			if not ability[buff] then
				ability[buff] = 1;
			else
				ability[buff] = ability[buff] + 1;
			end
			--print("     " .. buff .. " (" .. ability[buff] .. ")");		
			i = i + 1;
			buff = UnitBuff("player", i);
		end
		
		a.BuffLog[entry[2][2]] = ability;
	end
end


if a.DebugMode then print("Collector loaded"); end;