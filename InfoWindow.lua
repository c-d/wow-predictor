local AddonName, a = ...

PredictorInfoWindow = {};

local AceGUI = LibStub("AceGUI-3.0")
local defaultStatus = AddonName .. " -- Known Sequences";
local listFrame;
local scrollcontainer
local iconGroupWidth = 500;
local currentKey = "";

local frame = AceGUI:Create("Frame");
frame:SetTitle(AddonName .. " -- Known Sequences");
frame:SetStatusText(defaultStatus);
frame:SetLayout("Flow");
frame:EnableResize(false);


local mainframe = AceGUI:Create("SimpleGroup");
mainframe:ClearAllPoints();
mainframe:SetFullHeight(true);
--mainframe:SetFullWidth(true);
mainframe:SetLayout("Fill");
mainframe:SetHeight(400);
--frame:AddChild(mainframe);

scrollcontainer = AceGUI:Create("SimpleGroup") -- "InlineGroup" is also good
--scrollcontainer:SetFullWidth(false)
scrollcontainer:SetFullHeight(true) -- probably?
scrollcontainer:SetLayout("Fill") -- important!
frame:AddChild(scrollcontainer)
listFrame = AceGUI:Create("ScrollFrame")
listFrame:SetLayout("List") -- probably?
--listFrame:SetHeight(400);
--listFrame:SetFullHeight(true) -- probably?
scrollcontainer:AddChild(listFrame)

local infoContainer = AceGUI:Create("SimpleGroup");
infoContainer:SetFullHeight(true);
infoContainer:SetLayout("Flow");
--infoContainer:SetWidth(400);
frame:AddChild(infoContainer);

function PredictorInfoWindow:Show()
	PredictorInfoWindow:Update();
	frame:Show();
end

function PredictorInfoWindow:Hide()
	frame:Hide();
end

function PredictorInfoWindow:Update()
	if frame:IsVisible() then
		listFrame:ReleaseChildren();
		if a.Models then
			iconGroupWidth = (a.Size[a.ModelInUse] + 1) * 45;
			scrollcontainer:SetWidth(iconGroupWidth + 30);
			local model = PredictorInfoWindow:GetSortedModel();
			for j=1, #model do
				local k = model[j][1];
				local v = model[j][2];
				local iconGroup = AceGUI:Create("SimpleGroup");
				iconGroup:SetLayout("Flow");
				iconGroup:SetWidth(iconGroupWidth);
				iconGroup:SetHeight(60);
				--iconGroup:SetAutoAdjustHeight(false);
				local iLabel = AceGUI:Create("InteractiveLabel");
				iLabel:SetText(v["total"]);
				iLabel:SetWidth(25);
				iconGroup:AddChild(iLabel);
				--print(k);
				local text = gsub(k, "player&", "");
				local abilities = split(text, "#");		
				for i=1, #abilities do
					local name, rank, iconPath = GetSpellInfo(abilities[i]);
					if iconPath then
						local icon = AceGUI:Create("InteractiveLabel");
						--local icon = AceGUI:Create("InteractiveLabel");
						icon:SetImageSize(40,40);
						icon:SetImage(iconPath);
						--icon:SetLabel(name);
						--icon:SetText(name);
						icon:SetWidth(45);
						--icon:SetHighlight(0.3, 0.3, 0.3, 1);
						--icon:SetFont("Fonts\\ARIALN.ttf", 15);
						icon:SetCallback("OnEnter", function() 
							PredictorInfoWindow:ShowInfoForKey(k); 
						end);
						iconGroup:AddChild(icon);
						--iconGroup:AddChild(iLabel);
					end
				end
				listFrame:AddChild(iconGroup);
			end
		end
	end
end

function PredictorInfoWindow:ShowInfoForKey(k)
	if k ~= currentKey then
		currentKey = k;
		local p = a.Models[a.ModelInUse][k];
		if p then
			infoContainer:ReleaseChildren();
			
			local sequenceLabel = AceGUI:Create("InteractiveLabel");
			sequenceLabel:SetFont("Fonts\\ARIALN.ttf", 15);
			sequenceLabel:SetWidth(900);
			sequenceLabel:SetText(k:gsub("player&", ""):gsub("#", " -> "));
			infoContainer:AddChild(sequenceLabel);
			
			total = p["total"]
			for i=1,#p["links"] do	
				spell = p["links"][i]["event"];
				--print("Predicted: " .. spell);
				-- cut off the first part of the id ("player" or "target" usually)
				splitter = string.find(spell, "&");
				spell = string.sub(spell, splitter+1);
				count = round((p["links"][i]["count"] / total) * 100);
				--table.insert(a.PredictedEvents, {spell, count});
				local name, rank, iconPath = GetSpellInfo(spell);
				if iconPath then
					local icon = AceGUI:Create("Icon");
					icon:SetImageSize(40,40);
					icon:SetImage(iconPath);
					icon:SetWidth(45);
					infoContainer:AddChild(icon);
					
					local label = AceGUI:Create("InteractiveLabel");
					label:SetFont("Fonts\\ARIALN.ttf", 15);
					label:SetText(name);
					infoContainer:AddChild(label);
					
					local info = AceGUI:Create("InteractiveLabel");
					info:SetFont("Fonts\\ARIALN.ttf", 14);
					info:SetText("             " .. count .. "% (" .. p["links"][i]["count"] .. "/" .. total .. " observed)");
					info:SetWidth(900);
					infoContainer:AddChild(info);
				end
			end
			if a.ApplyBuffWeighting then
				--Predictor:ApplyBuffWeightings();
			end
			-- finally, sort the table to show most likely first
			--table.sort(a.PredictedEvents, function(a,b) return a[2] > b[2] end)
		else 
			print("No prediction found");
		end
		--infoContainer:AddChild(refreshButton);
	end
end

function PredictorInfoWindow:GetSortedModel()
	local result = {};
	for k, v in pairs(a.Models[a.ModelInUse]) do
		tinsert(result, {k, v});
	end
	table.sort(result, function(a,b) return a[2]["total"] > b[2]["total"]  end)
	return result;
end

frame:Hide();
--PredictorInfoWindow:Update();

