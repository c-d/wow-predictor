local AddonName, a = ...

local ignoreList = {}
local frame, events = CreateFrame("Frame"), {};
local SFHistory = {}
local PredictListMax = 5;
local MatchLength = 0;	-- Keep track of the current maximum match sequence (a break in sequene causes this to reset).
local RankHistory = {}	-- Keeps previously cast spells along with their expected ranks (e.g. high expectation = 1)
local LikelihoodHistory = {}
a.PredictedEvents = {}	-- queue of predicted upcoming actions

local PredictListFrame = nil;
local LineFrame = nil;

Predictor = {};

function Predictor:AddEventForPrediction(event)	-- TODO: Refactor, global for now
	if # SFHistory >= a.Size[a.ModelInUse] then
		table.remove(SFHistory, 1)	-- queue with a max length
	end
	table.insert(SFHistory, event)
	spellName = event[2][2];
	--need to think about this more
	PredictListFrame_SpellWasCast(spellName);
	if not a.HideVisualizations then predictActions(); end
end

function Predictor:InitAll()
	Predictor:deleteData();
	Predictor:initPredictListFrame();
	Predictor:initLineFrame();
	Predictor:initAccuracyInfo();
end

function Predictor:deleteData()
	if PredictListFrame then
		PredictListFrame:SetScript("OnUpdate", nil);
		if PredictListFrame.HistoryTextures then
			for i = 1,  # PredictListFrame.HistoryTextures  do
				PredictListFrame.HistoryTextures[i]:Hide();
			end
			PredictListFrame.HistoryTextures = {};
		end
		if PredictListFrame.textFields then
			for i = 1,  # PredictListFrame.textFields  do
				PredictListFrame.textFields[i]:Hide();
			end
			PredictListFrame.HistoryTextures = {};
		end
		if PredictListFrame.textures then
			for i = 1,  # PredictListFrame.textFields  do
				PredictListFrame.textures[i]:Hide();
			end
			PredictListFrame.HistoryTextures = {}
		end
	end
	if LineFrame then 
		if LineFrame.Lines then
			for i = 1, # LineFrame.Lines do
				LineFrame.Lines[i]:Hide();
			end
			LineFrame.Lines = {};
		end
	end
	
	if rankText then
		rankText:Hide();
		rankText = nil;
	end
	if likelihoodText then
		likelihoodText:Hide();
		likelihoodText = nil;
	end
end

function Predictor:initPredictListFrame()
	
	
	-- Predictor frame that lists all predictions
	PredictListFrame = CreateFrame("Frame")
	PredictListFrame:ClearAllPoints()
	--PredictListFrame:SetBackdrop(StaticPopup1:GetBackdrop())
	PredictListFrame:SetHeight(250)
	PredictListFrame:SetWidth(150)

	PredictListFrame.HLTexture = PredictListFrame:CreateTexture();
	PredictListFrame.HLTexture:SetTexture(0.4, 0.8, 0.4);
	PredictListFrame.HLTexture:SetWidth(5);
	PredictListFrame.HLTexture:SetHeight(a.VisIconSize);
	PredictListFrame.timer = 0;

	PredictListFrame.FocusTexture = PredictListFrame:CreateTexture();
	PredictListFrame.FocusTexture:SetWidth(a.VisIconSize);
	PredictListFrame.FocusTexture:SetHeight(a.VisIconSize);

	PredictListFrame.HistoryTextures = {};
	 
	PredictListFrame.textFields = {}
	PredictListFrame.textures = {}
	PredictListFrame.spells = {}
	textY = 0 - a.VisIconSize / 3.2;
	texturesY = 0;
	for i = 1, PredictListMax do
		texture = PredictListFrame:CreateTexture();
		texture:SetPoint("TOPLEFT", 0, texturesY);
		texture:SetWidth(a.VisIconSize);
		texture:SetHeight(a.VisIconSize);
		table.insert(PredictListFrame.textures, texture);
		texturesY = texturesY - a.VisIconSize - 1;
		
		text = PredictListFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		text:SetPoint("TOPLEFT", a.VisIconSize + 5, textY);
		text:SetText("")
		table.insert(PredictListFrame.textFields, text);
		textY = textY - a.VisIconSize - 1;
	end
	PredictListFrame:SetPoint("RIGHT", -200, -275)
	
	PredictListFrame:SetScript("OnUpdate", function(self, elapsed)
		PredictListFrame.timer = PredictListFrame.timer + elapsed
		if PredictListFrame.timer >= 0.001 then
			toremove = {};
			for i = 1,  # PredictListFrame.HistoryTextures  do
				texture = PredictListFrame.HistoryTextures[i];
				alpha = texture:GetAlpha();
				p, rt, rp, x, y = texture:GetPoint();
				if alpha <= 0 or x < -650 then
					removeTexture(texture);
					tinsert(toremove, i);
				else
					texture:SetPoint("TOPLEFT", x - a.VisMoveSpeed, y);
					if round(x) % 5 == 0 then
					--0.002
						texture:SetAlpha(alpha - a.VisAlphaDecay);
					end	
				end
			end
			-- Now remove all hidden textures from the history
			for i=1, #toremove do
				tremove(PredictListFrame.HistoryTextures, toremove[i]);
			end
			LineFrame:UpdateLines();
		
			-- alpha = PredictListFrame.FocusTexture:GetAlpha();		
			-- if alpha == 0 then
				-- PredictListFrame.FocusTexture:Hide();
			-- else
				-- if PredictListFrame.FocusTexture:GetTexture() then
					-- p, rt, rp, x, y = PredictListFrame.FocusTexture:GetPoint();
					-- PredictListFrame.FocusTexture:SetPoint("TOPLEFT", x - 2, y);
					-- PredictListFrame.FocusTexture:SetAlpha(alpha - 0.02);
				-- end
			-- end
			-- PredictListFrame.timer = 0
		end
	end);
	
	-- keeps track of textures, to avoid wasting memory on repeatedly created textures
	texturePool = {}
	function removeTexture(t)
		t:Hide();
		tinsert(texturePool, t);
	end

	function getNewTexture()
		t = tremove(texturePool);
		if not t then 
			t = PredictListFrame:CreateTexture();
		end
		return t;
	end
end

function Predictor:initLineFrame()
	LineFrame = CreateFrame("Frame", nil, PredictListFrame);
	LineFrame:ClearAllPoints()
	LineFrame:SetFrameStrata("LOW");
	--PredictListFrame:SetBackdrop(StaticPopup1:GetBackdrop())
	LineFrame:SetHeight(250)
	LineFrame:SetWidth(650)
	p, rt, rp, x, y = PredictListFrame:GetPoint();
	LineFrame:SetPoint("TOPRIGHT", x, 0);
	LineFrame.Lines = {}
	p, rt, rp, x, y = PredictListFrame:GetPoint();
	LineFrame.xAnchor = x
	
	linePool = {}
	function LineFrame:removeLine(l)
		l:Hide();
		tinsert(linePool, l);
	end

	function LineFrame:getNewLine()
		l = tremove(linePool);
		if not l then
			l = LineFrame:CreateTexture();
			l:SetTexture(0.3,0.5,0.5,1);
			l.from = {-1,-1};
			l.to = {-1,-1};
		end
		return l;
	end
	
	function LineFrame:UpdateLines()
		for i=1,#LineFrame.Lines do
		-- Start by hiding everything
			--print("removing " .. i);
			LineFrame:removeLine(LineFrame.Lines[i]);
			--LineFrame.Lines[i]:SetTexture(0.4, 0.4, 0.4,0);
		end
		LineFrame.Lines = {};
		local size = math.min(MatchLength, #PredictListFrame.HistoryTextures);
			--print(a.Size[a.ModelInUse] .. "/" ..  #PredictListFrame.HistoryTextures);
		--for i=size, 2, -1 do
		for i=#PredictListFrame.HistoryTextures, #PredictListFrame.HistoryTextures - (size - 2), -1 do 
			--print(i .. "/" .. size);
			local hline = LineFrame:getNewLine();
			local vline = LineFrame:getNewLine();
			p, rt, rp, x, y = PredictListFrame.HistoryTextures[i]:GetPoint();
			hline.from = {x, y};
			vline.from = {x, y};
			p, rt, rp, x, y = PredictListFrame.HistoryTextures[i - 1]:GetPoint();
			hline.to = {x, y};
			vline.to = {x, y};
			
			--print(hline.to[1] - hline.from[1]);
			
			
			-- TODO: Very hacky
			local textWidth = a.VisIconSize;
			local offset = 25 - (a.VisIconSize - 25);	-- actually offset / 2
			local hwidth = hline.from[1] - hline.to[1] - textWidth
			local hx = hline.from[1] + textWidth + offset;
			local hy = hline.from[2] - textWidth / 2;
			local alpha = PredictListFrame.HistoryTextures[i - 1]:GetAlpha();
			
			if vline.from[2] == vline.to[2] then
			else
				hwidth = hline.from[1] - hline.to[1] - textWidth / 2
				hx = hline.from[1] + textWidth + offset;
				vline:SetHeight(math.abs(vline.from[2] - vline.to[2]) - textWidth / 2 + 2);
				vline:SetWidth(2);
				local posY = vline.from[2];
				if vline.to[2] - vline.from[2] > 0 then posY = vline.to[2] - textWidth / 2; end;
				vline:SetPoint('TOPRIGHT', vline.to[1] + textWidth + textWidth / 2 + offset, posY - textWidth / 2);
				vline:SetAlpha(alpha);
				vline:Show();			
				tinsert(LineFrame.Lines, vline);			
			end
			
			hline:SetHeight(2);
			hline:SetPoint('TOPRIGHT', hx, hy);
			hline:SetWidth(hwidth);
			hline:SetAlpha(alpha);
			hline:Show();

			--l:Show();
			tinsert(LineFrame.Lines, hline);
		end
	end
end

function Predictor:initAccuracyInfo()
	rankText = PredictListFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	rankText:SetPoint("TOPLEFT", 150, -10);
	likelihoodText = PredictListFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	likelihoodText:SetPoint("TOPLEFT", 150, -30);
end

function PredictListFrame_UpdateContents()
	PredictListFrame.spells = {};
	for i = 1, # PredictListFrame.textFields do
	-- should be exactly as many text fields as textures
		field = PredictListFrame.textFields[i];
		field:Hide();
		texture = PredictListFrame.textures[i];
		texture:Hide();
	end
	if #a.PredictedEvents > 0 then
		local i = 1;
		for i=1, math.min(#PredictListFrame.textFields, #a.PredictedEvents) do
			name, rank, icon = GetSpellInfo(a.PredictedEvents[i][1]);
			table.insert(PredictListFrame.spells, name);
			alpha = a.PredictedEvents[i][2] / 100.0;
			texture = PredictListFrame.textures[i];
			texture:SetTexture(icon, false);
			--texture:SetAlpha(alpha);
			texture:Show();
			field = PredictListFrame.textFields[i];	
			--field:SetAlpha(alpha);
			field:SetText(a.PredictedEvents[i][1]);
			field:SetText(a.PredictedEvents[i][1] .. " (" .. a.PredictedEvents[i][2] .. "%)");
			field:Show();
		end	
	end
	
end
	
function PredictListFrame_SpellWasCast(spellName)
	if not a.HideVisualizations then 
		local spellFound = false;
		local rank = 0;
		local likelihood = 0;
		for i = 1, # PredictListFrame.spells do
			if PredictListFrame.spells[i] == spellName then
				spellFound = true;
				-- get details of texture and position
				texture = PredictListFrame.textures[i];
				p, rt, rp, x, y = texture:GetPoint();
				
				h = getNewTexture();
				h:SetWidth(texture:GetWidth());
				h:SetHeight(texture:GetHeight());
				h:SetTexture(texture:GetTexture());
				h:SetAlpha(1 - (1.0 / (a.Size[a.ModelInUse] + 1)));
				h:SetPoint("TOPLEFT", x - a.VisIconSize, y);
				h:Show();
				table.insert(PredictListFrame.HistoryTextures, h);
				
				-- PredictListFrame.FocusTexture:SetTexture(texture:GetTexture());
				-- PredictListFrame.FocusTexture:SetAlpha(1);
				-- p, rt, rp, x, y = texture:GetPoint();
				-- PredictListFrame.FocusTexture:SetPoint("TOPLEFT", x - 1, y);
				-- PredictListFrame.FocusTexture:Show();
				
				rank = i;
				likelihood = GetLikelihoodForSpell(spellName);
				break;
			end
		end
		if spellFound then
			MatchLength = math.min(a.Size[a.ModelInUse], MatchLength + 1);	-- maxes at sequence length
		else 
			MatchLength = 0; 
			UpdateRankHistory(#PredictListFrame.spells);
			UpdateLikelihoodHistory(0);
		end
		UpdateRankHistory(rank);
		UpdateLikelihoodHistory(likelihood);
		if a.TrialMode then 
			PredictorTrialsAddon:LogSpellAccuracy(rank, likelihood);
		end
		--dprint(rank .. " - " .. likelihood);
	end
end

function GetLikelihoodForSpell(spellName)
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

function UpdateLikelihoodHistory(val)
	if #LikelihoodHistory >= a.Size[a.ModelInUse] then
		tremove(LikelihoodHistory, 1);
	end
	tinsert(LikelihoodHistory, val);
	local sum = 0
	for i=1,#LikelihoodHistory do
		sum = sum + LikelihoodHistory[i];
	end
	if sum > 0 then
		local result = round(sum / #LikelihoodHistory, 2);
		likelihoodText:SetText("Likelihood accuracy: " .. result);
		-- Note different colour values - lower accuracy is marked as 'green'
		if result >= 0.5 then
			likelihoodText:SetTextColor(0, 1.0, 0.0);
		elseif result < 0.25 then
			likelihoodText:SetTextColor(1.0, 0, 0);
		else
			likelihoodText:SetTextColor(1.0, 1.0, 0);
		end
		likelihoodText:Show();
	end
end

function UpdateRankHistory(val)	-- TODO: Should not be global
	if #RankHistory >= a.Size[a.ModelInUse] then
		tremove(RankHistory, 1);
	end
	tinsert(RankHistory, val);
	local sum = 0
	for i=1,#RankHistory do
		sum = sum + RankHistory[i];
	end
	local result = 0;
	if sum > 0 then
		result = round(#RankHistory / sum, 2);
	else result = 0;
	end;
	rankText:SetText("Rank accuracy: " .. result);
	if result >= 0.75 then
		rankText:SetTextColor(0, 1.0, 0.0);
	elseif result <= 0.4 then
		rankText:SetTextColor(1.0, 0, 0);
	else
		rankText:SetTextColor(1.0, 1.0, 0);
	end
	rankText:Show();
	--print("Historical accuracy: " .. sum .. " --> " .. result);
end



-- Prediction logic - maintains a.PredictedEvents, so that other classes can always access and find the next expected events
function predictActions()
	a.PredictedEvents = {}
	-- TODO: After deleting data, prediction isn't working. Not sure what the issue is yet.
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
		PredictListFrame_UpdateContents();
		--IconFrame_UpdateContents();
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
