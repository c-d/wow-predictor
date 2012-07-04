AddonName, a = ...	-- WoW passes in the addon name + persistent addon table as arguments

PredictorAddon = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceComm-3.0", "AceConsole-3.0")
PlayerName = UnitName("player")
local OptionsFrame = nil

function PredictorAddon:OnInitialize()
	PredictorAddon:LoadGlobalData();
	--MarkovAnalyser:refresh();
	--if not a.EvaluationMode then 
		PredictorAddon:setupOptions(); 
	--end
	Predictor:InitAll();
	Messenger.CheckOnline();
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
							if PlayerName == a.ModelInUse then
								return entries .. " unique sequences recognized from " .. #a.EventLog .. " total events.";
							else return "Using external model, " .. entries .. " sequences recognized.";
							end
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
							MarkovAnalyser:fullRefresh();
						end,
						width = "full"
					},
					simulateaccuracy = {
						order = 2,
						name = "Estimate accuracy",
						desc = "Run a simulation to estimate the accuracy of this model",
						type = "execute",
						func = function()
							MarkovAnalyser:Simulate();
						end
					},
					selectmodel = {
						order = 3,
						name = "Select model",
						desc = "Select the model used for prediction.",
						type = "select",
						set = function(info, val)
							a.ModelInUse = val;
							PredictorAddon:SaveGlobalData();
						end,
						get = function()
							return a.ModelInUse;
						end,
						values = function()
							result = {};
							for k,v in pairs(a.Models) do
								name = k
								desc = k
								if k == PlayerName then
									desc = PlayerName .. " (Player)"
								end
								local info = a.SourceInfo[name]
								if info then
									if info[3] then	-- This is to check whether or not there are actually any talents specified.
										desc = desc .. " - Level " .. info[2] .. " " .. info[3] .. " " .. info[1] .. 
												" (" .. info[4] .. "/" .. info[5] .. "/" .. info[6] .. ")"
									end
								end
								result[name] = desc;
							end
							return result;
						end,
						style = "dropdown",
						width = "full"
					},
					subscribe = {
						order = 5,
						name = "Subscribe to new model",
						desc = "Subscribe to a subscription model",
						type = "input",
						set = function(info, val) 
							Messenger.SubscribeToBroadcaster(PlayerName, val); 
						end,
						width = "full"
					},
					unsubscribe = {
						order = 4,
						name = "Unsubscribe",
						desc = "Remove subscription for current model. This will delete all existing data for this model.",
						type = "execute",
						confirm = true,
						func = function(info, val) 
							Messenger.UnSubscribeToBroadcaster(PlayerName, a.ModelInUse); 
							a.Models[a.ModelInUse] = nil;
							a.Size[a.ModelInUse] = nil;
							a.SourceInfo[a.ModelInUse] = nil;
							a.ModelInUse = PlayerName;
							PredictorAddon:SaveGlobalData();
						end,
					},
					refresh = {
						name = "Force refresh",
						desc = "Force an update of predictive data, and checks for changes in online status of subscribers.",
						type = "execute",
						func = function() 
							MarkovAnalyser:fullRefresh(); 
							Messenger.CheckOnline(); 
						end,
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
						desc = "Delete all data. Warning: This cannot be reverted.",
						type = "execute",
						confirm = true;
						func = function() MarkovAnalyser:reset(); MarkovAnalyser:fullRefresh() end,
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
							Predictor:InitAll();
						end,
						width = "full"
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
		-- m.SubscribeToBroadcaster(PlayerName, subscriber);
	-- elseif msg:find("unsubscribe") then
		-- subscriber = msg:gsub("unsubscribe ", "");
		-- m.UnSubscribeToBroadcaster(PlayerName, subscriber);

end

function PredictorAddon:LoadGlobalData()
	dprint("PredictorCore: Loading data");
	if not PredictorAddonConfig then PredictorAddonConfig = {} end
	
	-- Models contains all models, indexed by player name
	a.Models = loadFromConfig("Models");		
	a.DebugMode = loadFromConfig("DebugMode");	
	a.ModelInUse = loadFromConfig("ModelInUse", PlayerName);
	a.Size = loadFromConfig("Size");
	a.Subscribers = loadFromConfig("Subscribers");
	a.SourceInfo = loadFromConfig("SourceInfo");
	a.EventLog = loadFromConfig("EventLog");
	
	a.VisMoveSpeed = loadFromConfig("VisMoveSpeed", 0.6);
	a.VisAlphaDecay = loadFromConfig("VisAlphaDecay", 0.002);
	a.VisIconSize = loadFromConfig("VisIconSize", 30);
	
	a.EvaluationMode = loadFromConfig("EvaluationMode", false);
	
	-- Note that it should not be necessary to set the size of the model in use
	if not a.Size[PlayerName] then a.Size[PlayerName] = 2; end;
	-- Also ensure that we have initialized the active model
	if not a.Models[a.ModelInUse] then 
		a.Models[a.ModelInUse] = {}; 
		dprint("PredictorCore: creating new dictionary for " ..  a.ModelInUse);
	end
	-- Subscription info	
	if not a.SourceInfo[PlayerName] then 
		a.SourceInfo[PlayerName] = PredictorAddon:PlayerInfo(); 
	end;
	
	-- May not be necessary, but just in case
	PredictorAddon:SaveGlobalData();
end

-- Loads an object from the saved addon config.
-- If the object does not exist, it is initialized and returned.
-- Default init value is {}, unless explicitly provided.
function loadFromConfig(id, default)
	result = PredictorAddonConfig[id]
	if not result then
		if default then
			result = default;
		else
			result = {};
		end
	end
	return result;
end

function PredictorAddon:SaveGlobalData()
	dprint("PredictorCore: Saving data");
	PredictorAddonConfig["Models"] = a.Models;
	PredictorAddonConfig["DebugMode"] = a.DebugMode;
	PredictorAddonConfig["ModelInUse"] = a.ModelInUse;
	PredictorAddonConfig["Size"] = a.Size;
	PredictorAddonConfig["Subscribers"] = a.Subscribers;
	PredictorAddonConfig["SourceInfo"] = a.SourceInfo;
	PredictorAddonConfig["EventLog"] = a.EventLog;
	PredictorAddonConfig["VisMoveSpeed"] = a.VisMoveSpeed;
	PredictorAddonConfig["VisAlphaDecay"] = a.VisAlphaDecay;
	PredictorAddonConfig["VisIconSize"] = a.VisIconSize;
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
	 MarkovAnalyser:fullRefresh()
	 Predictor:InitAll();
end

function PredictorAddon:ResetVisualizations()
	 Predictor:InitAll();
end

function PredictorAddon:HideVisualizations(val)
	a.HideVisualizations = val;	-- This isn't saved between sessions
end

function PredictorAddon:SetTrialMode(val)
	a.TrialMode = val;	-- This isn't saved between sessions
end

function PredictorAddon:GetEventCount()
	return #a.EventLog
end

function PredictorAddon:SetDebugMode(val)
	a.DebugMode = val;
end