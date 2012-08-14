-- Predictor visualization
-- Scrolls visualization data horizontally as it is used.

local AddonName, a = ...

local frame, events = CreateFrame("Frame"), {};
local PredictListMax = 5;
local MatchLength = 0;	-- Keep track of the current maximum match sequence (a break in sequene causes this to reset).
local RankHistory = {}	-- Keeps previously cast spells along with their expected ranks (e.g. high expectation = 1)
local LikelihoodHistory = {}

local PredictListFrame = nil;
local LineFrame = nil;

PrVisScroll = {};

function PrVisScroll:InitAll()
	PrVisScroll:DeleteData();
	PrVisScroll:InitPredictListFrame();
	PrVisScroll:InitLineFrame();
	PrVisScroll:InitAccuracyInfo();
end

function PrVisScroll:DeleteData()
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
			PredictListFrame.textFields = {};
		end
		if PredictListFrame.textures then
			for i = 1,  # PredictListFrame.textures  do
				PredictListFrame.textures[i]:Hide();
			end
			PredictListFrame.textures = {}
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

function PrVisScroll:InitPredictListFrame()
	
	
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
	-- Positioning
	PredictListFrame:SetMovable(true);	-- Leave this on always, dragging still dependent upon config var
	PredictListFrame:SetPoint(a.VisPosAnchor, a.VisPosX, a.VisPosY)
	PredictListFrame:SetScript("OnMouseUp", function(self, elapsed)
		if a.VisDragEnabled then
			PredictListFrame:StopMovingOrSizing();
			a.VisPosAnchor, rt, rp, a.VisPosX, a.VisPosY = PredictListFrame:GetPoint();
			PredictorAddon:SaveGlobalData();
		end
	end);
	PredictListFrame:SetScript("OnMouseDOWN", function(self, elapsed)
		if a.VisDragEnabled then
			PredictListFrame:StartMoving();
		end
	end);
	
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

function PrVisScroll:InitLineFrame()
	LineFrame = CreateFrame("Frame", nil, PredictListFrame);
	LineFrame:ClearAllPoints()
	LineFrame:SetFrameStrata("LOW");
	LineFrame:SetHeight(250)
	LineFrame:SetWidth(650)
	p, rt, rp, x, y = PredictListFrame:GetPoint();
	LineFrame:SetPoint("TOPRIGHT", PredictListFrame, "TOPLEFT", -50, 0);
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

function PrVisScroll:InitAccuracyInfo()
	rankText = PredictListFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	rankText:SetPoint("TOPLEFT", 150, -10);
	likelihoodText = PredictListFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	likelihoodText:SetPoint("TOPLEFT", 150, -30);
end

function PrVisScroll:Update()
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

function PrVisScroll:UpdateAccuracyTextVisibility()
	if a.VisShowRankAccuracy then 
		rankText:Show();
	else
		rankText:Hide();
	end
	if a.VisShowPredAccuracy then 
		likelihoodText:Show();
	else
		likelihoodText:Hide();
	end
end
	
function PrVisScroll:SpellWasCast(spellName)
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
				likelihood = Predictor:GetLikelihoodForSpell(spellName);
				break;
			end
		end
		if spellFound then
			MatchLength = math.min(a.Size[a.ModelInUse], MatchLength + 1);	-- maxes at sequence length
		else 
			MatchLength = 0; 
			--PrVisScroll:UpdateRankHistory(#PredictListFrame.spells);
			--PrVisScroll:UpdateLikelihoodHistory(0);
		end
		if a.VisShowRankAccuracy then PrVisScroll:UpdateRankHistory(rank); end;
		if a.VisShowPredAccuracy then PrVisScroll:UpdateLikelihoodHistory(likelihood); end;
		if a.TrialMode then 
			PredictorTrialsAddon:LogSpellAccuracy(rank, likelihood, spellName, PredictListFrame.spells);
		end
		--dprint(rank .. " - " .. likelihood);
		
	end
end

function PrVisScroll:UpdateLikelihoodHistory(val)
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

function PrVisScroll:UpdateRankHistory(val)
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

