local AddonName, a = ...	-- WoW passes in the addon name + persistent addon table as arguments

PredictorAddon = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceComm-3.0", "AceConsole-3.0")

--UnitName("player") = UnitName("player")

function PredictorAddon:OnInitialize()
	PredictorAddon:LoadGlobalData();
	--MarkovAnalyser:refresh();
	--if not a.EvaluationMode then 
		PredictorAddon:setupOptions(); 
	--end
	PrVisScroll:InitAll();
	--Messenger.CheckOnline();
end

function PredictorAddon:OnEnable()
    -- Called when the addon is enabled
end

function PredictorAddon:OnDisable()
    -- Called when the addon is disabled
	PredictorAddon:SaveGlobalData();
end

function PredictorAddon:SetEvaluationMode(val)
	a.EvaluationMode = val;
end

function PredictorAddon:setupOptions() 
	options = {
		type = "group",
		args = {
			dataOptions = {
				type = "group",
				name = "Data",
				args = {
					infofield = {
						order = 0,
						type = "description",
						fontSize = "medium",
						name = function()
							entries = 0;
							for k,v in pairs(a.Models[a.ModelInUse]) do
								eventCodes = split(v["prefix"], "#");
								if #eventCodes == a.Size[a.ModelInUse] then
									entries = entries + 1;
								end
							end
							local eventCount = 0;
							local subs = split(a.ModelInUse, ",");
							for i=1, #subs do
								if a.EventLog[subs[i]] then eventCount = eventCount + #a.EventLog[subs[i]]; end;
							end
							return entries .. " unique sequences recognized from " .. eventCount .. " total events.";
						end
					},
					size = {
						order = 1,
						name = "Sequence length",
						desc = "Set the pre-sequence length for markov chains. Longer sequences result in less predictions with higher accuracy (generally).",
						type = "range",
						min = 1,
						max = 10,
						step = 1,
						get = function()
							return a.Size[a.ModelInUse];
						end,
						set = function(info, val) 
							a.Size[a.ModelInUse] = val;
							PredictorAddonConfig["Size"] = a.Size;
							MarkovAnalyser:fullRefresh(a.ModelInUse);
						end,
						width = "full"
					},
					-- simulateaccuracy = {
						-- order = 2,
						-- name = "Estimate accuracy",
						-- desc = "Run a simulation to estimate the accuracy of this model",
						-- type = "execute",
						-- func = function()
							-- MarkovAnalyser:Simulate();
						-- end
					-- },
					settimebetweenevents = {
						order = 3,
						name = "Max time between events",
						desc = "Set the maximum time (in seconds) to allow between linked events. If an event occurs after this threshold, it is counted as the beginning of a new sequence. Higher thresholds will have a less noticeable effect.",
						type = "range",
						min = 1,
						max = 30,
						step = 1,
						get = function()
							return a.MaxTimeBetweenEvents;
						end,
						set = function(info, val)
							a.MaxTimeBetweenEvents = val;
							MarkovAnalyser:fullRefresh(a.ModelInUse);
						end,
						width = "full"
					},
					-- selectmodel = {
						-- order = 4,
						-- name = "Select model",
						-- desc = "Select the model used for prediction.",
						-- type = "select",
						-- set = function(info, val)
							-- a.ModelInUse = val;
							-- PredictorAddon:SaveGlobalData();
						-- end,
						-- get = function()
							-- return a.ModelInUse;
						-- end,
						-- values = function()
							-- result = {};
							-- for k,v in pairs(a.Subscriptions) do
								-- name = k
								-- desc = k
								-- if k == UnitName("player") then
									-- desc = UnitName("player") .. " (Player)"
								-- end
								-- local info = a.Subscriptions[name]
								-- if info then
									-- if info[3] then	-- This is to check whether or not there are actually any talents specified.
										-- desc = desc .. " - Level " .. info[2] .. " " .. info[3] .. " " .. info[1] .. 
												-- " (" .. info[4] .. "/" .. info[5] .. "/" .. info[6] .. ")"
									-- end
								-- end
								-- result[name] = desc;
							-- end
							-- return result;
						-- end,
						-- style = "dropdown",
						-- width = "full"
					-- },
					selectmodels = {
						order = 4,
						name = "Select models",
						desc = "Select the models used for prediction. At least one model must be selected. Selecting multiple models will combine event data to create a single set of predictions.",
						type = "multiselect",
						--tristate = true,
						set = function(info, name, val)
							local subs = split(a.ModelInUse, ",");
							-- for i=1, #subs do
								-- if subs[i] == "" then
									-- print("EMPTY STRING FOUND");
									-- tremove(subs, i);
								-- end
							-- end
							if val then
								tinsert(subs, name);
							else
								for i=1, #subs do
									if subs[i] == name then
										tremove(subs, i);
										if #subs == 0 then
											local name = UnitName("player");
											tinsert(subs, name);
										end
										break;
									end
								end
							end
							table.sort(subs);	-- Now make it alphabetical (so the keys always match regardless of the order in which they were selected)
							a.ModelInUse = table.concat(subs, ",");
							PredictorAddon:SaveGlobalData();
							PredictorAddon:LoadGlobalData();
							MarkovAnalyser:fullRefresh(a.ModelInUse);
						end,
						get = function(info, val)
							--print(a.ModelInUse);
							local models = split(a.ModelInUse, ",");
							for i=1, #models do
								if models[i] == val then return true; end;
							end
							-- for k,v in pairs(a.Subscriptions) do
								-- print(k);
								-- if k == val then return nil; end;
							-- end
							return false;
						end,
						values = function()
							result = {};
							for k,v in pairs(a.Subscriptions) do
								name = k
								desc = k
								if k == UnitName("player") then
									desc = UnitName("player") .. " (Player)"
								end
								local info = a.Subscriptions[name]
								if info then
									if info[3] then	-- This is to check whether or not there are actually any talents specified.
										desc = desc .. " - Level " .. info[2] .. " " .. info[3] .. " " .. info[1] .. 
												" (" .. info[4] .. "/" .. info[5] .. "/" .. info[6] .. ")"
									end
								end
								--print(name);
								result[name] = desc;
							end
							return result;
						end,
						--style = "dropdown",
						width = "full"
					},
					subupdatefreq = {
						order = 5,
						name = "Model update frequency",
						desc = "How often broadcasters should be polled for event updates. Setting this close to 1 approximates real-time updates.",
						type = "range",
						min = 1,
						max = 300,
						step = 1,
						get = function()
							return a.SubscriptionUpdateFrequency;
						end,
						set = function(info, val)
							a.SubscriptionUpdateFrequency = val;
						end,
						width = "full"
					},
					subscribe = {
						order = 8,
						name = "Subscribe to new model",
						desc = "Subscribe to a subscription model. It may take a few seconds to establish a subscription.",
						type = "input",
						set = function(info, val) 
							Messenger.SubscribeToBroadcaster(UnitName("player"), val); 
						end,
						width = "full"
					},
					unsubscribe = {
						order = 6,
						name = "Unsubscribe",
						desc = "Remove subscription for current model. This will delete all existing data for this model.",
						type = "execute",
						confirm = true,
						func = function(info, val) 
							local models = split(a.ModelInUse, ",");
							for i=1, #models do
								if models[i] ~= UnitName("player") then
									a.EventLog[models[i]] = nil;
									a.Models[models[i]] = nil;
									a.Size[models[i]] = nil;
									a.Subscriptions[models[i]] = nil;
									a.ModelInUse = UnitName("player");
								end
							end
							PredictorAddon:SaveGlobalData();
							-- Now need to generate a model for the currently selected source
							MarkovAnalyser:fullRefresh(a.ModelInUse);							
						end
					},
					update = {
						order = 7,
						name = "Force update",
						desc = "Force an update of predictive data from the current broadcaster.",
						type = "execute",
						func = function() 
							if a.ModelInUse ~= UnitName("player") then
								local lastUpdate = 0;
								if a.EventLog[a.ModelInUse] and #a.EventLog[a.ModelInUse] > 0 then 
									lastUpdate = a.EventLog[a.ModelInUse][#a.EventLog[a.ModelInUse]][3] 
								end
								Messenger.RequestUpdate(lastUpdate, a.ModelInUse);
							else
								MarkovAnalyser:fullRefresh(a.ModelInUse); -- otherwise just refresh player model
							end
						end
					},
					dump = {
						name = "Print",
						desc = "Print details of event sequences to the chat frame",
						type = "execute",
						confirm = true,
						func = function() MarkovAnalyser:dump() end,
						width = "full"
					},
					debug = {
						name = "Debug mode",
						desc = "Toggle on to show debugging info.",
						type = "toggle",
						set = function(info, val)
							a.DebugMode = val;
							PredictorAddon:SaveGlobalData();
						end,
						get = function()
							return a.DebugMode;
						end,
						width = "full"
					},
					wipe = {
						order = -1,
						name = "Delete data",
						desc = "Delete all data (not just for the current model). Warning: This cannot be reverted. This will also reload the UI.",
						type = "execute",
						confirm = true;
						func = function() 
							--MarkovAnalyser:reset(); 
							--MarkovAnalyser:fullRefresh(a.ModelInUse)
							for k, _ in pairs(PredictorAddonConfig) do
								PredictorAddonConfig[k] = nil;
							end
							ReloadUI();
						end,
						width = "full"
					}
				}
			},
			visOptions = {
				type = "group",
				name = "Visualization",
				args = {
					setspeed = {
						name = "Movement speed",
						desc = "Set the movement speed",
						type = "range",
						min = 0.1,
						max = 5,
						step = 0.1,
						get = function()
							return a.VisMoveSpeed;
						end,
						set = function(info, val) 
							a.VisMoveSpeed = val;
							PredictorAddon:SaveGlobalData();
						end,
						width = "full"
					},
					setalphadecay = {
						name = "Alpha decay",
						desc = "The rate at which the opacity of previously cast spells decays.",
						type = "range",
						min = 0.1,
						max = 5,
						step = 0.1,
						get = function()
							return a.VisAlphaDecay * 100;
						end,
						set = function(info, val) 
							a.VisAlphaDecay = val / 100;
							PredictorAddon:SaveGlobalData();
						end,
						width = "full"
					},
					seticonsize = {
						name = "Icon size",
						desc = "Set the size of icons for predicted abilities",
						type = "range",
						min = 10,
						max = 50,
						step = 1,
						get = function()
							return a.VisIconSize;
						end,
						set = function(info, val)
							a.VisIconSize = val;
							PredictorAddon:SaveGlobalData();
							PrVisScroll:InitAll();
						end,
						width = "full"
					},
					enabledragging = {
						order = 1,
						name = "Enable dragging",
						desc = "Unlock the visualization frame to allow repositioning",
						type = "toggle",
						set = function(info, val) 
							a.VisDragEnabled = val;
						end,
						get = function()
							return a.VisDragEnabled;
						end,
						width = "full"
					},
					resetUI = {
						order = 2,
						name = "Reset defaults",
						desc = "Reset the UI to default positioning/scaling",
						type = "execute",
						func = function() 
								a.VisMoveSpeed = nil;
								a.VisAlphaDecay = nil;
								a.VisIconSize = nil;
								a.VisPosX = nil;
								a.VisPosY = nil;
								a.VisPosAnchor = nil;
								a.VisDragEnabled = nil;
								a.VisShowRankAccuracy = nil;
								a.VisShowPredAccuracy = nil;
								PredictorAddon:SaveGlobalData()
								PredictorAddon:LoadGlobalData()
								PredictorAddon:ResetVisualizations()
							end
					},
					showrankaccuracy = {
						name = "Show ranking accuracy",
						desc = "Accuracy rating for the previous [sequence size] actions, based on the rankings of the abilities used.",
						type = "toggle",
						set = function(info, val) 
							a.VisShowRankAccuracy = val;
							PrVisScroll:UpdateAccuracyTextVisibility();
							PredictorAddon:SaveGlobalData();
						end,
						get = function()
							return a.VisShowRankAccuracy;
						end
					},
					showpredaccuracy = {
						name = "Show prediction % accuracy",
						desc = "Accuracy rating for the previous [sequence size] actions, based on the predicted likelihood (%) of the abilities used.",
						type = "toggle",
						set = function(info, val) 
							a.VisShowPredAccuracy = val;
							PrVisScroll:UpdateAccuracyTextVisibility();
							PredictorAddon:SaveGlobalData();
						end,
						get = function()
							return a.VisShowPredAccuracy;
						end
					}
				}
			}
		}
	}
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, options);
	--PredictorAddon:RegisterChatCommand("mychat", "ChatCommand")
	OptionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName)
	--LibStub("AceConfig-3.0"):RegisterOptionsTable("PredictorOptions", self.options, {"/predictor", "/prd"});
	--print("2");


	-- elseif msg:find("subscribe") then
		-- subscriber = msg:gsub("subscribe ", "");
		-- m.SubscribeToBroadcaster(UnitName("player"), subscriber);
	-- elseif msg:find("unsubscribe") then
		-- subscriber = msg:gsub("unsubscribe ", "");
		-- m.UnSubscribeToBroadcaster(UnitName("player"), subscriber);

end

function PredictorAddon:LoadGlobalData()
	dprint("PredictorCore: Loading data");
	if not PredictorAddonConfig then PredictorAddonConfig = {} end
	
	-- Models contains all models, indexed by player name
	a.Models = loadFromConfig("Models");		
	a.DebugMode = loadFromConfig("DebugMode");	
	a.ModelInUse = loadFromConfig("ModelInUse", UnitName("player"));
	a.Size = loadFromConfig("Size");
	a.Subscriptions = loadFromConfig("Subscriptions");
	a.EventLog = loadFromConfig("SEventLog", nil, true);
	a.ProcessEvents = loadFromConfig("ProcessEvents", true);
	a.MaxTimeBetweenEvents = loadFromConfig("MaxTimeBetweenEvents", 10);
	a.SubscriptionUpdateFrequency = loadFromConfig("SubscriptionUpdateFrequency", 60);
	
	a.VisMoveSpeed = loadFromConfig("VisMoveSpeed", 0.6);
	a.VisAlphaDecay = loadFromConfig("VisAlphaDecay", 0.002);
	a.VisIconSize = loadFromConfig("VisIconSize", 30);
	a.VisPosX = loadFromConfig("VisPosX", -200);
	a.VisPosY = loadFromConfig("VisPosY", -275);
	a.VisPosAnchor = loadFromConfig("VisPosAnchor", "RIGHT");
	a.VisDragEnabled = loadFromConfig("VisDragEnabled", false);
	a.VisShowRankAccuracy = loadFromConfig("VisShowRankAccuracy", false);
	a.VisShowPredAccuracy = loadFromConfig("VisShowPredAccuracy", false);
	--a.SelectedVis = loadFromConfig("SelectedVis", "PrVisScroll");
	
	a.EvaluationMode = loadFromConfig("EvaluationMode", false);
	
	
	if not a.Size[a.ModelInUse] then a.Size[a.ModelInUse] = 2; end;
	if not a.Size[UnitName("player")] then a.Size[UnitName("player")] = 2; end;
	-- Also ensure that we have initialized the active model
	-- if not a.Models[UnitName("player")] then 
		-- a.Models[UnitName("player")] = {}; 
		-- dprint("PredictorCore: creating new dictionary for " ..  UnitName("player"));
	-- end
	if not a.Models[a.ModelInUse] then 
		a.Models[a.ModelInUse] = {}; 
		dprint("PredictorCore: creating new dictionary for " ..  a.ModelInUse);
	end
	if not a.EventLog[a.ModelInUse] then
		a.EventLog[a.ModelInUse] = {};
		dprint("PredictorCore: creating new event log for " .. a.ModelInUse);
	end
	-- Subscription info	
	if not a.Subscriptions[UnitName("player")] then 
		local class, level, primarytalent, talent1, talent2, talent3 = PredictorAddon:PlayerInfo();
		a.Subscriptions[UnitName("player")] = {class, level, primarytalent, talent1, talent2, talent3};
	end;
	
	-- May not be necessary, but just in case
	PredictorAddon:SaveGlobalData();
end

-- Loads an object from the saved addon config.
-- If the object does not exist, it is initialized and returned.
-- Default init value is {}, unless explicitly provided.
function loadFromConfig(id, default, serialized)
	result = PredictorAddonConfig[id]
	-- Can't use "not result", because the value may actually be false, check for nil instead.
	if result == nil then
		if default ~= nil then
			result = default;
		else
			result = {};
		end
	else
		if serialized then 
			success, result = AceSerializer:Deserialize(result);
		end
	end
	return result;
end

function PredictorAddon:SaveGlobalData()
	dprint("PredictorCore: Saving data");
	--PredictorAddonConfig["Models"] = a.Models;
	PredictorAddonConfig["DebugMode"] = a.DebugMode;
	PredictorAddonConfig["ModelInUse"] = a.ModelInUse;
	PredictorAddonConfig["Size"] = a.Size;
	PredictorAddonConfig["Subscriptions"] = a.Subscriptions;
	PredictorAddonConfig["ProcessEvents"] = a.ProcessEvents;
	PredictorAddonConfig["MaxTimeBetweenEvents"] = a.MaxTimeBetweenEvents;
	PredictorAddonConfig["SubscriptionUpdateFrequency"] = a.SubscriptionUpdateFrequency;
	
	PredictorAddonConfig["SEventLog"] = AceSerializer:Serialize(a.EventLog);
	-- Uncomment this line for more readable config files (copies contents of SEventLog, so wasted file size)
	--PredictorAddonConfig["EventLog"] = a.EventLog;
	
	--PredictorAddonConfig["SelectedVis"] = a.SelectedVis;
	
	PredictorAddonConfig["VisMoveSpeed"] = a.VisMoveSpeed;
	PredictorAddonConfig["VisAlphaDecay"] = a.VisAlphaDecay;
	PredictorAddonConfig["VisIconSize"] = a.VisIconSize;
	PredictorAddonConfig["VisPosX"] = a.VisPosX;
	PredictorAddonConfig["VisPosY"] = a.VisPosY;
	PredictorAddonConfig["VisPosAnchor"] = a.VisPosAnchor;
	PredictorAddonConfig["VisDragEnabled"] = a.VisDragEnabled;
	PredictorAddonConfig["VisShowRankAccuracy"] = a.VisShowRankAccuracy;
	PredictorAddonConfig["VisShowPredAccuracy"] = a.VisShowPredAccuracy;
	
	PredictorAddonConfig["EvaluationMode"] = a.EvaluationMode;
end

-- Returns class, level, and spec information
-- {class, level, primarytalent, {talent1, talent2, talent3}}
function PredictorAddon:PlayerInfo()
	class = UnitClass("player");
	level = UnitLevel("player");
	-- Get talent spec and main tree description (e.g. Holy - 41,20,0)
	local _,t1name,_,_,t1points = GetTalentTabInfo(1)
	local _,t2name,_,_,t2points = GetTalentTabInfo(2)
	local _,t3name,_,_,t3points = GetTalentTabInfo(3)	
	
	bigger = math.max(t1points, t2points, t3points);
	if t1points == bigger then mainspec = t1name;
	elseif t2points == bigger then mainspec = t2name;
	else mainspec = t3name;
	end
	
	--result = {class, level, mainspec, talents};
	return class, level, mainspec, t1points, t2points, t3points;
end

function dprint(str)
	if a.DebugMode then print(str); end;
end

-- *******************************************************************
-- The functions below are provided for user evaluation functionality.
-- *******************************************************************

function PredictorAddon:ResetData()
	 MarkovAnalyser:reset(); 
	 MarkovAnalyser:fullRefresh(a.ModelInUse)
	 PrVisScroll:InitAll();
end

function PredictorAddon:ResetVisualizations()
	 PrVisScroll:InitAll();
end


function PredictorAddon:ResetVisualizationPosition()
	a.VisPosX = nil;
	a.VisPosY = nil;
	a.VisPosAnchor = nil;
	PredictorAddon:SaveGlobalData();
	PredictorAddon:LoadGlobalData();
	--PredictorAddon:ResetVisualizations();
end

function PredictorAddon:GetEventCount()
	return #a.EventLog[a.ModelInUse];
end

-- The following settings are specific to individual trial sessions, so they are not saved.

function PredictorAddon:SetSequenceLength(val)
	a.Size[a.ModelInUse] = val;
	a.PredictedEvents = {}	-- flush the prediction buffer
	MarkovAnalyser:fullRefresh(a.ModelInUse);
end

function PredictorAddon:HideVisualizations(val)
	a.HideVisualizations = val;
end

-- Trial mode causes additional logging to take place, sent to PredictorTrialAddon
function PredictorAddon:SetTrialMode(val)
	a.TrialMode = val;
end

function PredictorAddon:SetTrackEvents(val)
	a.PauseEventTracking = not val;
end

function PredictorAddon:SetDebugMode(val)
	a.DebugMode = val;
end