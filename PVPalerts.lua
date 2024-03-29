-- // the code needs quite a bit of refactoring, which most likely will never happen:( //

local PVP = PVP_Alerts_Main_Table

PVP.version=1.01
PVP.textVersion="3.77"
PVP.name = "PVPalerts"

local LCM = LibChatMessage
local chat = LCM.Create('PVPalerts', 'PVP')
PVP.CHAT = chat

-- // initialization of global variables for this file //

local GetFrameTimeMilliseconds = GetFrameTimeMilliseconds
local PVP_NAME_FONT = PVP:GetGlobal('PVP_NAME_FONT')
local PVP_NUMBER_FONT = PVP:GetGlobal('PVP_NUMBER_FONT')

local PVP_ICON_MISSING = PVP:GetGlobal('PVP_ICON_MISSING')
local PVP_KILLING_BLOW = PVP:GetGlobal('PVP_KILLING_BLOW')
local PVP_AP = PVP:GetGlobal('PVP_AP')

local PVP_CONTINUOUS_ATTACK_ID_1 = PVP:GetGlobal('PVP_CONTINUOUS_ATTACK_ID_1')
local PVP_CONTINUOUS_ATTACK_ID_2 = PVP:GetGlobal('PVP_CONTINUOUS_ATTACK_ID_2')
local PVP_AYLEID_WELL_ID = PVP:GetGlobal('PVP_AYLEID_WELL_ID')
local PVP_BLESSING_OF_WAR_ID = PVP:GetGlobal('PVP_BLESSING_OF_WAR_ID')

local PVP_SET_SCALE_FROM_SV = true

local PVP_ID_RETAIN_TIME=15000
local PVP_BATTLE_INTERVAL=20000
local PVP_FRAME_DISPLAY_TIME=1800

local PVP_BRIGHT_AD_COLOR = PVP:GetGlobal('PVP_BRIGHT_AD_COLOR')
local PVP_BRIGHT_EP_COLOR = PVP:GetGlobal('PVP_BRIGHT_EP_COLOR')
local PVP_BRIGHT_DC_COLOR = PVP:GetGlobal('PVP_BRIGHT_DC_COLOR')


function PVP:RemoveDuplicateNames() -- // a clean-up function for various arrays containing information about players nearby //
	local function ClearId(id)
		PVP.playerSpec[PVP.idToName[id]]=nil
		PVP.miscAbilities[PVP.idToName[id]]=nil
		PVP.playerAlliance[id]=nil
		PVP.idToName[id]=nil
		PVP.totalPlayers[id]=nil
	end

	if next(PVP.idToName)~=nil then
		local foundNames={}
		for k,v in pairs (PVP.idToName) do
			if not foundNames[v] then foundNames[v]= k
			else
				if PVP.totalPlayers[k]>PVP.totalPlayers[foundNames[v]] then
					ClearId(foundNames[v]) foundNames[v]=k
				else
					ClearId(k)
				end
			end
		end
	end
end


function PVP.OnUpdate() -- // main loop of the addon, is called each 250ms //
	if not PVP.SV.enabled or not PVP:IsInPVPZone() then return end

	if not PVP.playerName then PVP.playerName = GetRawUnitName('player') end

	if PVP:IsMalformedName(PVP.playerName) and PVP.bgNames then  -- // band-aid attempt to work around zos glitch in bgs //
		if PVP.bgNames[PVP.playerName..'^Mx'] then PVP.playerName = PVP.playerName..'^Mx' end
		if PVP.bgNames[PVP.playerName..'^Fx'] then PVP.playerName = PVP.playerName..'^Fx' end
	end


	local currentTime=GetFrameTimeMilliseconds()
	if PVP.SV.reportSavedInfo and (not PVP.reportTimer or PVP.reportTimer==0 or (currentTime-PVP.reportTimer)>=300000) then -- // output of the number of stored accounts/players //
		PVP:RefreshStoredNumbers(currentTime)
	end

	if not PVP.killFeedDelay or (PVP.killFeedDelay>0 and (currentTime-PVP.killFeedDelay)>=10000) then -- // kill feed maintenance //
		PVP.killFeedDelay=0
		PVP_KillFeed_Text:Clear()
		PVP_KillFeed_Ratio:SetHidden(true)
	end

	if not PVP.killFeedRatioDelay or (PVP.killFeedRatioDelay>0 and (currentTime-PVP.killFeedRatioDelay)>=PVP_BATTLE_INTERVAL) then -- // battle report maintenance //
		if PVP.SV.showKillFeedFrame and not IsActiveWorldBattleground() then
			PVP:BattleReport()
		end
		PVP.killFeedRatioDelay = 0
	end
	local start_refresh = GetGameTimeMilliseconds()
	PVP:MainRefresh(currentTime) -- // main loop for pvpalerts.lua functions //
	local end_refresh = GetGameTimeMilliseconds()
	PVP:ProcessDistrictNamePrompt() -- // a tiny feature to check if you mousever a district ladder, while in an ic lobby //
	local start3d = GetGameTimeMilliseconds()
	PVP:UpdateNearbyKeepsAndPOIs() -- // 3d icons main loop //
	-- PVP:TestThisScale()
end

local lastcount, lastcountAcc
function PVP:RefreshStoredNumbers(currentTime) -- // output of the number of stored accounts/players //
	PVP.reportTimer=currentTime

	local count=0
	local countAcc=0
	local accountsDB={}
	for k,v in pairs (PVP.SV.playersDB) do
		if not accountsDB[v.unitAccName] then accountsDB[v.unitAccName]=true countAcc=countAcc+1 end
		count=count+1
	end
	if count ~= lastcount or countAcc ~= lastcountAcc then
	    local diff, diffAcc
	    if lastcount == nil then
		diff = 0
		diffAcc = 0
	    else
		diff = count - lastcount
		diffAcc = countAcc - lastcountAcc
	    end
	    lastcount = count
	    lastcountAcc = countAcc
	    chat:Print('************************')
	    chat:Printf('Stored players: %d (%d)',count, diff)
	    chat:Printf('Stored accounts: %d (%d)',countAcc, diffAcc)
	    chat:Print('************************')
	end
end

function PVP_test_SV()
	local function Getmean( t )
		local sum = 0
		local count= 0

		for k,v in pairs(t) do
		if type(v) == 'number' then
		  sum = sum + v
		  count = count + 1
		end
		end

		return (sum / count)
	end

	local function GetMedian( t )
	  local temp={}

	  -- deep copy table so that when we sort it, the original is unchanged
	  -- also weed out any non numbers
	  for k,v in pairs(t) do
		if type(v) == 'number' then
		  table.insert( temp, v )
		end
	  end

	  table.sort( temp )

	  -- If we have an even number of table elements or odd.
	  if math.fmod(#temp,2) == 0 then
		-- return mean value of middle two elements
		return ( temp[#temp/2] + temp[(#temp/2)+1] ) / 2
	  else
		-- return middle element
		return temp[math.ceil(#temp/2)]
	  end
	end


	local function GetStd( t )
	  local m
	  local vm
	  local sum = 0
	  local count = 0
	  local result

	  m = Getmean( t )

	  for k,v in pairs(t) do
		if type(v) == 'number' then
		  vm = v - m
		  sum = sum + (vm * vm)
		  count = count + 1
		end
	  end

	  result = math.sqrt(sum / (count-1))

	  return result
	end



	local playerCountOriginal = 0
	local accountCountOriginal = 0
	local accountCountWithCP = 0
	local playerCountWithCP = 0
	local accountsDB= {}

	for k,v in pairs (PVP.SV.playersDB) do
		if not accountsDB[v.unitAccName] then
			accountCountOriginal = accountCountOriginal + 1
			if PVP.SV.CP[v.unitAccName] then
				accountsDB[v.unitAccName] = {}
				accountsDB[v.unitAccName].CP = PVP.SV.CP[v.unitAccName]
				accountsDB[v.unitAccName].players = {}
				accountsDB[v.unitAccName].players.k = v

				accountCountWithCP = accountCountWithCP + 1
				playerCountWithCP = playerCountWithCP + 1
			end
		else
			accountsDB[v.unitAccName].players[k] = v
			playerCountWithCP = playerCountWithCP + 1
		end
		playerCountOriginal = playerCountOriginal + 1
	end

	d('***********')
	d('Stored players: '..tostring(playerCountOriginal))
	d('Stored accounts: '..tostring(accountCountOriginal))
	d('CP players: '..tostring(playerCountWithCP))
	d('CP accounts: '..tostring(accountCountWithCP))


	local averageCP = 0
	local medianCP = GetMedian(PVP.SV.CP)
	local stdCP = GetStd(PVP.SV.CP)
	local aboveCPcap = 0
	local totalWithSpec = 0
	local totalMag = 0
	local totalStam = 0

	local race = {}
	local class = {}
	local classrace = {}
	local totalAD = 0
	local totalDC = 0
	local totalEP = 0

	for k,v in pairs (accountsDB) do
		averageCP = averageCP + v.CP
		if v.CP >= 720 then
			aboveCPcap = aboveCPcap + 1
		end
		for i,j in pairs (v.players) do
			if j.unitSpec then
				totalWithSpec = totalWithSpec + 1
				if j.unitSpec == 'stam' then
					totalStam = totalStam + 1
				elseif j.unitSpec == 'mag' then
					totalMag = totalMag + 1
				end
			end

			-- if v.CP >= 720 and j.unitSpec and j.unitSpec == 'mag' then
			if v.CP >= 720 and j.unitSpec then
				if not race[j.unitRace] then
					race[j.unitRace] = 0
				end

				race[j.unitRace] = race[j.unitRace] + 1

				if not class[j.unitClass] then
					class[j.unitClass] = 0
				end

				class[j.unitClass] = class[j.unitClass] + 1

				if not classrace[j.unitClass] then classrace[j.unitClass] = {} end
				if not classrace[j.unitClass][j.unitRace] then classrace[j.unitClass][j.unitRace] = 0 end
				classrace[j.unitClass][j.unitRace] = classrace[j.unitClass][j.unitRace] + 1


				if j.unitAlliance == 1 then
					totalAD = totalAD + 1
				elseif j.unitAlliance == 2 then
					totalEP = totalEP + 1
				elseif j.unitAlliance == 3 then
					totalDC = totalDC + 1
				end
			end
		end
	end

	local totalOther = totalWithSpec - totalMag - totalStam

	averageCP = averageCP/accountCountWithCP
	d('CP average: '..tostring(averageCP))
	d('CP median: '..tostring(medianCP))
	d('CP std: '..tostring(stdCP))
	d('Above CP cap: '..tostring(aboveCPcap))
	d('Below CP cap: '..tostring(accountCountWithCP - aboveCPcap))
	d('Percent above CP cap: '..tostring(100*aboveCPcap/accountCountWithCP))
	d('Percent below CP cap: '..tostring(100*(accountCountWithCP - aboveCPcap)/accountCountWithCP))
	d('Total with Spec: '..tostring(totalWithSpec))
	d('Total mag: '..tostring(totalMag))
	d('Total stam: '..tostring(totalStam))
	d('Total other: '..tostring(totalOther))
	d('Percent mag: '..tostring(100*totalMag/totalWithSpec))
	d('Percent stam: '..tostring(100*totalStam/totalWithSpec))
	d('Percent other: '..tostring(100*totalOther/totalWithSpec))


	d('Nightblades: '..tostring(class[3]))
	d('Templars: '..tostring(class[6]))
	d('Wardens: '..tostring(class[4]))
	d('Sorcs: '..tostring(class[2]))
	d('DKs: '..tostring(class[1]))
	d('Necros: '..tostring(class[5]))
	d('TotalAD: '..tostring(totalAD))
	d('TotalDC: '..tostring(totalDC))
	d('TotalEP: '..tostring(totalEP))

	for k,v in pairs (race) do
		d(GetRaceName(0, k)..'s: '..tostring(v))
	end

	for iClass,v in pairs (classrace) do
		for iRace,numb in pairs (v) do
			d(GetClassName(0, iClass)..'/'..GetRaceName(0, iRace)..': '..tostring(numb))
		end
	end

	d('************')
end

function PVP:CountTotal(currentTime)
	local count=0
	for k,v in pairs (self.totalPlayers) do
		if (currentTime-v)>PVP_ID_RETAIN_TIME then
			self.totalPlayers[k]=nil
			self.playerSpec[self.idToName[k]]=nil
			self.miscAbilities[self.idToName[k]]=nil
			self.playerAlliance[k]=nil
			self.idToName[k]=nil
		end
	end

	for k, v in pairs (self.playerNames) do
		if (currentTime-v)>=PVP_ID_RETAIN_TIME then
			self.playerNames[k]=nil
		end
	end

	local wasRemoved
	for i=#self.namesToDisplay, 1, -1 do
		if (currentTime-self.namesToDisplay[i].currentTime)>=PVP_ID_RETAIN_TIME then
			table.remove(self.namesToDisplay, i)
			wasRemoved = true
		end
	end

	if wasRemoved then
		self:PopulateReticleOverNamesBuffer()
	end

	for _, v in ipairs (self.namesToDisplay) do
		if not v.isDead and not v.isResurrect then
			count = count + 1
		end
	end

	for k,v in pairs (self.currentlyDead) do
		if (currentTime-v.currentTime)>PVP_ID_RETAIN_TIME then self.currentlyDead[k]=nil end
	end

	return count
end

function PVP:ProcessNpcs(currentTime)
	for k,v in pairs (self.npcExclude) do
		if (currentTime-v)>PVP_ID_RETAIN_TIME then self.npcExclude[k]=nil end
	end
end

function PVP:MainRefresh(currentTime)
	PVP.startR = GetGameTimeMilliseconds()
	self:RemoveDuplicateNames()
	PVP.endD = GetGameTimeMilliseconds()
	local totalCount=self:CountTotal(currentTime)
	PVP.endC = GetGameTimeMilliseconds()
	self:ProcessNpcs(currentTime)
	PVP.endN = GetGameTimeMilliseconds()
	if self:ShouldShowCampFrame() then self:ManageCampFrame() end
	PVP.endCamp = GetGameTimeMilliseconds()
	if self.SV.showCounterFrame then

		PVP.beforeC = GetGameTimeMilliseconds()
		local numberAD, numberDC, numberEP, tableAD, tableDC, tableEP, maxAD, maxDC, maxEP = PVP:GetAllianceCountPlayers()
		PVP.afterC = GetGameTimeMilliseconds()

		-- numberAD = 35
		-- numberDC = 90
		-- numberEP = 43

		local divider = PVP:Colorize("/", "FFFFFF")
		local containerControl = PVP_Counter:GetNamedChild('_CountContainer')
		local labelControl = PVP_Counter:GetNamedChild('_Label')
		local bgControl = PVP_Counter:GetNamedChild('_Backdrop')
		local adControl = containerControl:GetNamedChild('_CountAD')
		local dcControl = containerControl:GetNamedChild('_CountDC')
		local epControl = containerControl:GetNamedChild('_CountEP')

		adControl:SetText(tostring(numberAD)..divider)
		dcControl:SetText(tostring(numberDC)..divider)
		epControl:SetText(tostring(numberEP))

		local targetWidth = containerControl:GetWidth()
		local labelWidth = labelControl:GetWidth()
		bgControl:SetWidth(math.max(targetWidth, labelWidth)*1.1)



		if numberAD>0 then
			self.SetToolTip(adControl, self:ProcessLengths(tableAD, maxAD), true, unpack(tableAD))
		else
			self.ReleaseToolTip(adControl)
		end
		if numberDC>0 then
			self.SetToolTip(dcControl, self:ProcessLengths(tableDC, maxDC), true, unpack(tableDC))
		else
			self.ReleaseToolTip(dcControl)
		end
		if numberEP>0 then
			self.SetToolTip(epControl, self:ProcessLengths(tableEP, maxEP), true, unpack(tableEP))
		else
			self.ReleaseToolTip(epControl)
		end
	end
	PVP.endCounter = GetGameTimeMilliseconds()
	PVP.Timer=currentTime

	if self.SV.showKOSFrame and (SCENE_MANAGER:GetCurrentScene() == HUD_SCENE or SCENE_MANAGER:GetCurrentScene() == LOOT_SCENE) then PVP:PopulateKOSBuffer() end
	PVP.endKos = GetGameTimeMilliseconds()
end

local function FillCurrentTooltip (control)
	if not PVP.SV.enabled or not PVP.SV.showCounterFrame or not PVP:IsInPVPZone() then return end

	local numberAD, numberDC, numberEP, tableAD, tableDC, tableEP, maxAD, maxDC, maxEP = PVP:GetAllianceCountPlayers()

	local currentTable, currentNumber, currentLength

	if control == PVP_Counter_CountContainer_CountAD then
		currentTable = tableAD
		currentNumber = numberAD
		currentLength = maxAD
	elseif control == PVP_Counter_CountContainer_CountDC then
		currentTable = tableDC
		currentNumber = numberDC
		currentLength = maxDC
	elseif control == PVP_Counter_CountContainer_CountEP then
		currentTable = tableEP
		currentNumber = numberEP
		currentLength = maxEP
	else return
	end

	ClearTooltip(PVP_Tooltip)
	local side = TOP
	local _, centerY = PVP_Counter:GetCenter()

	if centerY<(GuiRoot:GetHeight()/2) then side = BOTTOM end

	if currentNumber>0 then PVP.Tooltips_ShowTextTooltip(control, side, PVP:ProcessLengths(currentTable, currentLength), true, unpack(currentTable)) end
end

local function HandleTooltipFilling(control)
	local tooltipTimeDelay = GetFrameTimeMilliseconds()
	control:SetHandler("OnUpdate", function()
		local currentTime = GetFrameTimeMilliseconds()
		if (currentTime - tooltipTimeDelay) >= 50 then
			-- d(tooltipTimeDelay)
			tooltipTimeDelay = currentTime
			FillCurrentTooltip(control)
		end
	end)
end

function PVP_FillAllianceTooltip(control)
	HandleTooltipFilling(control)
end

function PVP.SetToolTip(control, maxLength, isCounter, ...)
	local function TooltipOnUpdate(control)
		local currentTime = GetFrameTimeMilliseconds()
		if control.timeLeft and (currentTime - control.lastTooltipUpdate) >= 50 then
			InitializeTooltip(PVP_Tooltip)
			local args = control.timeLeft
			PVP_Tooltip:AddLine(args[1], "", 1,1,1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
			PVP_Tooltip:AddLine(args[2], "", 1,1,1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
			control.lastTooltipUpdate = currentTime
		end
	end

	local args = {...}
    control:SetHandler("OnMouseEnter", function(self)
		local side = TOP
		local relativeControl = isCounter and PVP_Counter or PVP_ForwardCamp
		local _, centerY = relativeControl:GetCenter()

		if centerY<(GuiRoot:GetHeight()/2) then side = BOTTOM end

		PVP.Tooltips_ShowTextTooltip(self, side, maxLength, isCounter, unpack(args))
		if not isCounter then
			control.lastTooltipUpdate = GetFrameTimeMilliseconds()
			control:SetHandler("OnUpdate", function() TooltipOnUpdate(control) end)
			 -- control:SetHandler("OnUpdate", function(self)
				-- if control.timeLeft then
					-- InitializeTooltip(PVP_Tooltip)
					-- local args = control.timeLeft
					-- PVP_Tooltip:AddLine(args[1], "", 1,1,1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
					-- PVP_Tooltip:AddLine(args[2], "", 1,1,1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
				-- end
			 -- end)
		else
			HandleTooltipFilling(control)
		end
    end)
    control:SetHandler("OnMouseExit", function(self)
		ClearTooltip(PVP_Tooltip)
		control:SetHandler("OnUpdate", nil)
		control.lastTooltipUpdate = nil
    end)
end

function PVP.ReleaseToolTip(control)
    control:SetHandler("OnMouseEnter", nil)
    control:SetHandler("OnMouseExit", nil)
    control:SetHandler("OnUpdate", nil)
end

function PVP.Tooltips_ShowTextTooltip(control, side, maxLength, isCounter, ...)
	local OFFSET_DISTANCE = 5
	local OFFSETS_X =
	{
		[TOP] = 0,
		[BOTTOM] = 0,
		[LEFT] = -OFFSET_DISTANCE,
		[RIGHT] = OFFSET_DISTANCE,
	}
local OFFSETS_Y =
	{
		[TOP] = -OFFSET_DISTANCE,
		[BOTTOM] = OFFSET_DISTANCE,
		[LEFT] = 0,
		[RIGHT] = 0,
	}
local SIDE_TO_TOOLTIP_SIDE =
	{
		[TOP] = BOTTOM,
		[BOTTOM] = TOP,
		[LEFT] = RIGHT,
		[RIGHT] = LEFT,
	}
    if side == nil then
	InitializeTooltip(PVP_Tooltip)
	ZO_Tooltips_SetupDynamicTooltipAnchors(PVP_Tooltip, control)
    else
	InitializeTooltip(PVP_Tooltip, control, SIDE_TO_TOOLTIP_SIDE[side], OFFSETS_X[side], OFFSETS_Y[side])
    end
	PVP_Tooltip:SetDimensionConstraints(0,0,maxLength,0)

	PVP_Tooltip:SetFont("ZoFontWinH5")
    for i = 1, select("#", ...) do
	local line = select(i, ...)
		if isCounter then
			PVP_Tooltip:AddLine(line, "", 1,1,1, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
		else
			PVP_Tooltip:AddLine(line, "", 1,1,1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
		end
    end
end


function PVP:OnZoneChange(_,zoneName,newZone)
	local zoneText

	zoneText = zoneName=="" and GetPlayerLocationName() or zoneName

	if not self.SV.unlocked and self.SV.showCaptureFrame then PVP:SetupCurrentObjective(zoneText) end

	PVP:UpdateNearbyKeepsAndPOIs(nil, true)
end


function PVP:OnOwnerOrUnderAttackChanged(zoneText, keepIdToUpdate, updateType)
	if self.SV.unlocked or not self.SV.showCaptureFrame then return end
	local keepId, foundObjectives = self:FindAVAIds(zoneText)
	if keepId and ((self.SV.showNeighbourCaptureFrame and keepId[keepIdToUpdate]) or (not self.SV.showNeighbourCaptureFrame and keepId ~= 0 and keepId == keepIdToUpdate)) then
		PVP:SetupCurrentObjective(nil, keepId, foundObjectives, keepIdToUpdate, updateType)
	end
end


function PVP:OnControlState(eventCode, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, objectiveControlState, objectiveParam1, objectiveParam2)
	if self.SV.unlocked or not self.SV.showCaptureFrame or not self:IsValidBattlegroundContext(battlegroundContext) or not keepId or keepId == 0 then return end

	local zoneName=GetPlayerLocationName()
	if not zoneName or zoneName == "" then return end

	local allianceIdToName = {
		[0] = 'None',
		[1] = 'AD',
		[2] = 'EP',
		[3] = 'DC',
	}

	local keepName = GetKeepName(keepId)

	local foundInArray
	if self.SV.showNeighbourCaptureFrame and self.currentKeepIdArray then
		for k,v in pairs (PVP.currentKeepIdArray) do
			if k == keepId then foundInArray = true break end
		end
	end


	if foundInArray or (zoneName == keepName) then
		local isCurrent = zoneName == keepName
		local foundObjectives = {isCaptureStatus = false, isCurrent = isCurrent, keepId = keepId, objectiveName = objectiveName, objectiveId = objectiveId, objectiveState = objectiveControlState, allianceParam1 = objectiveParam1, allianceParam2 = objectiveParam2, objectiveEvent = objectiveControlEvent}
		PVP:UpdateCaptureMeter(keepId, foundObjectives, "control")

	end


end

function PVP:OnCaptureStatus(eventCode, keepId,	 objectiveId,  battlegroundContext,  capturePoolValue,	capturePoolMax,	 capturingPlayers,  contestingPlayers,	owningAlliance)
	if self.SV.unlocked or not self.SV.showCaptureFrame or not self:IsValidBattlegroundContext(battlegroundContext) or not keepId or keepId == 0 then return end
	local zoneName=GetPlayerLocationName()
	if not zoneName or zoneName == "" then return end


	local objectiveName = GetAvAObjectiveInfo(keepId, objectiveId, battlegroundContext)

	local foundObjectives = {isCaptureStatus = GetFrameTimeMilliseconds(), isCurrent = true, keepId = keepId, objectiveName = objectiveName, objectiveId = objectiveId, allianceParam1 = owningAlliance, capturePoolValue = capturePoolValue, capturingPlayers = capturingPlayers, contestingPlayers = contestingPlayers}

	PVP:UpdateCaptureMeter(keepId, foundObjectives, "capture")
end

function PVP:IsCurrentlyDead(unitName)
	if not unitName or unitName=="" then return false end
	for k,v in pairs (self.currentlyDead) do
		if v.playerName == unitName then return true end
	end
	return false
end

function PVP:OnEffect(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId)
	if not PVP:IsInPVPZone() then return end

	if IsActiveWorldBattleground() then
		PVP.bgNames = PVP.bgNames or {}
		if unitName and unitName~='' and not PVP.bgNames[unitName] then PVP.bgNames[unitName] = 0 end
	end

	-- d(self.currentlyDead)

	if unitName=="" or self.currentlyDead[unitId] or self.IsCurrentlyDead(unitName) then return end

	local currentTime=GetFrameTimeMilliseconds()

	if self.npcExclude[unitId] then self.npcExclude[unitId]=currentTime return end

	if self.totalPlayers[unitId] and unitName~="" then
		if self:CheckName(unitName) then
			self.idToName[unitId]=unitName
			self.totalPlayers[unitId]=currentTime
			self:DetectSpec(nil, abilityId, nil, unitName, true)
			if self.SV.playersDB[unitName] then
				self.playerAlliance[unitId]=self.SV.playersDB[unitName].unitAlliance
			end
		else
			self.totalPlayers[unitId]=nil
			self.playerAlliance[unitId]=nil
			self.playerSpec[self.idToName[unitId]]=nil
			self.miscAbilities[self.idToName[unitId]]=nil
			self.idToName[unitId]=nil
			self.npcExclude[unitId]=currentTime
		end
	end
end

function PVP:KillFeedRatio_Add(targetUnitId)
	local alliance = self.playerAlliance[targetUnitId]

	if not alliance then return end

	if not PVP.killFeedRatio then PVP.killFeedRatio={AD=0, DC=0, EP=0, zone={}, startTime=GetFrameTimeSeconds(), startAP = GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS), earnedAP = 0} end

	-- local ratio = PVP.killFeedRatio
	local AD = PVP.killFeedRatio.AD
	local DC = PVP.killFeedRatio.DC
	local EP = PVP.killFeedRatio.EP
	local zone = PVP.killFeedRatio.zone

	table.insert(zone, GetPlayerActiveSubzoneName())

	if alliance==1 then PVP.killFeedRatio.AD = PVP.killFeedRatio.AD+1
	elseif alliance==2 then PVP.killFeedRatio.EP = PVP.killFeedRatio.EP+1
	elseif alliance==3 then PVP.killFeedRatio.DC = PVP.killFeedRatio.DC+1
	end

	local ADlabel = PVP_KillFeed_Ratio_AD_Label
	local DClabel = PVP_KillFeed_Ratio_DC_Label
	local EPlabel = PVP_KillFeed_Ratio_EP_Label
	local ADframe = PVP_KillFeed_Ratio_AD
	local DCframe = PVP_KillFeed_Ratio_DC
	local EPframe = PVP_KillFeed_Ratio_EP

	local frame = PVP_KillFeed_Ratio

	local frameWidth = frame:GetWidth()

	local unitPixel = frameWidth/(PVP.killFeedRatio.AD+PVP.killFeedRatio.DC+PVP.killFeedRatio.EP)

	ADframe:SetWidth(PVP.killFeedRatio.AD*unitPixel)
	DCframe:SetWidth(PVP.killFeedRatio.DC*unitPixel)
	EPframe:SetWidth(PVP.killFeedRatio.EP*unitPixel)

	if PVP.killFeedRatio.AD>0 then ADlabel:SetText(tostring(PVP.killFeedRatio.AD)) else ADlabel:SetText("") end
	if PVP.killFeedRatio.DC>0 then DClabel:SetText(tostring(PVP.killFeedRatio.DC)) else DClabel:SetText("") end
	if PVP.killFeedRatio.EP>0 then EPlabel:SetText(tostring(PVP.killFeedRatio.EP)) else EPlabel:SetText("") end
end

function PVP:KillFeedRatio_Reset()
	self.killFeedRatio=nil
	PVP_KillFeed_Ratio:SetHidden(true)
end

function PVP:SecondsToClock(seconds)
	local seconds = tonumber(seconds)

	if seconds <= 0 then
		return "0sec";
	else
		hours = string.format("%2.f", math.floor(seconds/3600));
		mins = string.format("%2.f", math.floor(seconds/60 - (hours*60)));
		secs = string.format("%2.f", math.floor(seconds - hours*3600 - mins *60));
		return (tonumber(hours)>0 and hours.." hours, " or "")..(((tonumber(mins)>0 or tonumber(hours)>0))  and mins.." min, " or "")..secs.." sec"
	end
end


function PVP:BattleReport()
	local data = self.killFeedRatio
	if data and (data.AD+data.DC+data.EP)>=5 then
		local zone = data.zone
		local uniqueZones, maxZoneName = {}, ""

		for k, v in ipairs(zone) do
			if v~="" then
				uniqueZones[v] = uniqueZones[v] and uniqueZones[v]+1 or 1

				if maxZoneName=="" or uniqueZones[v]>uniqueZones[maxZoneName] then maxZoneName=v end
			end
		end

		local battleTime = self:Colorize(" lasted ", "BBBBBB")..self:Colorize(self:SecondsToClock(math.ceil(GetFrameTimeSeconds()-data.startTime-math.floor(PVP_BATTLE_INTERVAL/1000))), "AF7500")..self:Colorize(".", "BBBBBB")

		local outputTitle = self:Colorize(" *** Battle "..(maxZoneName=="" and "" or "at "..self:Colorize(maxZoneName, "AF7500")), "BBBBBB")--..self:Colorize(" ***", "BBBBBB")

		local outputCasualties = " Casualties: "..(data.AD>0 and (self:Colorize(tostring(data.AD).." AD", PVP_BRIGHT_AD_COLOR)) or "")

		outputCasualties = outputCasualties..(data.DC>0 and (" "..self:Colorize(tostring(data.DC).." DC", PVP_BRIGHT_DC_COLOR)) or "")
		outputCasualties = outputCasualties..(data.EP>0 and (" "..self:Colorize(tostring(data.EP).." EP", PVP_BRIGHT_EP_COLOR)) or "")
		outputCasualties = self:Colorize(outputCasualties, "BBBBBB")

		outputAP = self:Colorize(". Earned", "BBBBBB")..self:Colorize(" "..zo_iconFormat(PVP_AP, 24, 24)..tostring(data.earnedAP), "00cc00")

		local finalReport = outputTitle..battleTime..outputCasualties..outputAP..self:Colorize(". ***", "BBBBBB")


		if self.SV.showKillFeedFrame then PVP_KillFeed_Text:AddMessage(finalReport) end

		if self.SV.showKillFeedChat and self.ChatContainer and self.ChatWindow then
			self.ChatContainer:AddMessageToWindow(self.ChatWindow, finalReport)
		end

		if self.SV.showKillFeedInMainChat then
			chat:Print(finalReport)
		end

	end
end

function PVP:UpdateNamesToDisplay(unitName, currentTime, updateOnly, attackType, abilityId, result)
	-- if not (self.SV.showNamesFrame and self.SV.playersDB[unitName]) then return end
	if not self.SV.playersDB[unitName] then return end

	local isInBG = IsActiveWorldBattleground()
	local isValidBGNameToDisplay = isInBG and PVP.bgNames and PVP.bgNames[unitName] and PVP.bgNames[unitName]~=0 and PVP.bgNames[unitName]~=GetUnitBattlegroundAlliance('player')
	local isValidCyroNameToDisplay = not isInBG and self.SV.playersDB[unitName].unitAlliance~=self.allianceOfPlayer


	if isValidBGNameToDisplay or isValidCyroNameToDisplay then
		local found
		for i=1,#self.namesToDisplay do
			if self.namesToDisplay[i].unitName == unitName then found = i break end
		end
		if found then
			self.namesToDisplay[found].currentTime = currentTime

			if updateOnly and PVP:GetValidName(GetRawUnitName('reticleover')) == unitName then
				if IsUnitDead('reticleover') then
					self.namesToDisplay[found].isDead = true
				else
					self.namesToDisplay[found].isResurrect = nil
				end
			end

			if not updateOnly and self.namesToDisplay[found].isDead then
				self.namesToDisplay[found].isDead = nil
				if not self.namesToDisplay[found].isResurrect then
					self.namesToDisplay[found].isResurrect = currentTime
				end
			end


			if attackType=='source' then
				self.namesToDisplay[found].isAttacker = true
			elseif attackType=='target' then
				self.namesToDisplay[found].isTarget = true
			end

			if attackType == 'source' then
				local playerToUpdate = self.namesToDisplay[found]

				table.remove(self.namesToDisplay, found)

				table.insert(self.namesToDisplay, playerToUpdate)
			end

		else
			if not updateOnly then
				local isAttacker, isTarget, isResurrect
				if attackType == 'source' then
					isAttacker = true
					if self.SV.playNewAttackerSound and not IsActiveWorldBattleground() then
						PVP:PlayLoudSound('DUEL_BOUNDARY_WARNING')
						-- d('New attacker!')
						-- d('unitName: '..unitName)
						-- d('abilityId: '..abilityId)
						-- d('abilityName: '..GetAbilityName(abilityId))
					end
					if PVP.SV.showNamesFrame and PVP.SV.showNewAttackerFrame then
						PVP:UpdateNewAttacker(unitName)
					end
				elseif attackType == 'target' then
					isTarget = true
				end
				if abilityId == 0 and result == 2265 and isTarget then
					isResurrect = currentTime
				end
				table.insert(self.namesToDisplay, {unitName = unitName, currentTime = currentTime, isAttacker = isAttacker, isTarget = isTarget, isResurrect = isResurrect})
			end
		end
		self:PopulateReticleOverNamesBuffer()
	end
end

function PVP:OnCombat(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, combat_log, sourceUnitId, targetUnitId, abilityId)
	if not PVP:IsInPVPZone() then return end

	if IsActiveWorldBattleground() then
		PVP.bgNames = PVP.bgNames or {}
		if sourceName and sourceName~='' and not PVP.bgNames[sourceName] then PVP.bgNames[sourceName] = 0 end
		if targetName and targetName~='' and not PVP.bgNames[targetName] then PVP.bgNames[targetName] = 0 end
	end

	local KILLING_BLOW_ACTION_RESULTS = {
		[ACTION_RESULT_KILLING_BLOW]	=	true,
		[ACTION_RESULT_DIED_XP]			=	true,
	}

	local DEAD_ACTION_RESULTS = {
		[ACTION_RESULT_KILLING_BLOW]	=	true,
		[ACTION_RESULT_TARGET_DEAD]		=	true,
		[ACTION_RESULT_DIED]			=	true,
		[ACTION_RESULT_DIED_XP]			=	true,
		[ACTION_RESULT_REINCARNATING]	=	true,
		[ACTION_RESULT_RESURRECT]		=	true,
		[ACTION_RESULT_CASTER_DEAD]		=	true,
	}

	local shadowReturnIds = {
		[35451] = true,
		[36290] = true,
		[36295] = true,
		[36300] = true,
	}

	local shadowSetupIds = {
		[38528] = true,
		[38529] = true,
		[38530] = true,
		[38531] = true,
		[88696] = true,
		[88697] = true,
		[88699] = true,
		[88700] = true,
		[88702] = true,
		[88703] = true,
		[88705] = true,
		[88706] = true,
	}

	-- if GetUnitClassId('player') == 3 and self.SV.show3DIcons and self.SV.shadowImage3d and targetType == 1 and shadowReturnIds[abilityId] then
	if GetUnitClassId('player') == 3 and self.SV.show3DIcons and self.SV.shadowImage3d then
		if shadowSetupIds[abilityId] and result == 2245 then
			self.shadowTime = hitValue
		end
		if shadowReturnIds[abilityId] then
			if result == 2245 then
				if not self.eventCounter then self.eventCounter = 0 end
				self.eventCounter = self.eventCounter + 1
				self:SetupShadow(self.shadowTime)
			elseif result == 2250 then
				if not self.eventCounter then self.eventCounter = 1 end
				self.eventCounter = self.eventCounter - 1
				if self.eventCounter == 0 then
					self:ResetShadow()
				end
			end
		end
	end


	local currentTime=GetFrameTimeMilliseconds()
	local isHeavyAttack=self.SV.showHeavyAttacks and self.heavyAttackId[abilityId]
	local isSnipe=self.SV.showSnipes and (self.snipeId[abilityId] or self.snipeNames[abilityName])

	local function ProcessKillingBlows()
		if KILLING_BLOW_ACTION_RESULTS[result] and targetUnitId and targetUnitId~=0 and (self.totalPlayers[targetUnitId] or targetName==self.playerName) and GetAbilityName(abilityId) and GetAbilityName(abilityId)~="" then
			local allianceColor=self:IdToAllianceColor(targetUnitId)
			-- local abilityIcon=GetAbilityIcon(abilityId)
			-- local abilityOut=self:Colorize(GetAbilityName(abilityId), "CCCCCC")
			-- local playerOut
			local targetNameFromId=self.idToName[targetUnitId]
			-- local importantIcon=""
			-- local killedBy=""
			-- local diedFrom=self:Colorize(" died from ", "AF7500")
			-- local exclamation=self:Colorize("!", "AF7500")
			-- local isTargetKOS


			local function GetAccName(playerName)
				if self.SV.playersDB[playerName] then return self.SV.playersDB[playerName].unitAccName end
			end

			local function GetSpacedOutString(...)
				local text = ""
				local numArgs = select("#", ...)
				for i = 1, numArgs do
					text = text..select(i, ...)
					if i ~= numArgs then
						text = text.." "
					end
				end
				return text
			end

			local function GetImportantIcon(playerName)
				local KOSOrFriend = self:IsKOSOrFriend(playerName)
				if KOSOrFriend then
					if KOSOrFriend=="KOS" then
						return self:GetKOSIcon(32, self.SV.playersDB[playerName].unitAlliance == self.allianceOfPlayer and "FFFFFF" or nil), true
					elseif KOSOrFriend=="friend" then
						return self:GetFriendIcon(24)..self.Colorize(GetAccName(playerName), "40BB40"), false
					elseif KOSOrFriend=="cool" then
						return self:GetCoolIcon(24)..self.Colorize(GetAccName(playerName), "40BB40"), false
					elseif KOSOrFriend=="groupleader" then
						return self:GetGroupLeaderIcon(32), false
					elseif KOSOrFriend=="group" then
						return self:GetGroupIcon(32), false
					end
				else
					return ""
				end
			end

			local function GetFormattedAbilityName(abilityId, color)
				local abilityName = self:Colorize(GetAbilityName(abilityId), color)
				local abilityIcon = GetAbilityIcon(abilityId)
				local textAbilityIcon

				if abilityIcon:find(PVP_ICON_MISSING) then
					textAbilityIcon = ""
				else
					textAbilityIcon = zo_iconFormat(abilityIcon, 18, 18)
				end

				return textAbilityIcon..abilityName
			end

			local function GetColoredMessage(text, color)
				return PVP:Colorize(text, color)
			end

			local function GetOwnKbString(targetNameFromId, targetPlayer, abilityId)
				local playerToken = "You"
				local bracketsToken
				local actionToken
				local prepToken = "with"
				local suffixToken = "!"
				local messageColor = "40BB40"
				local kbIconToken = zo_iconFormat(PVP_KILLING_BLOW, 38, 38)
				local abilityToken = GetFormattedAbilityName(abilityId, messageColor)

				actionToken = "killed"
				bracketsToken = "***"

				playerToken = GetColoredMessage(playerToken, messageColor)
				actionToken = GetColoredMessage(actionToken, messageColor)
				bracketsToken = GetColoredMessage(bracketsToken, messageColor)
				prepToken = GetColoredMessage(prepToken, messageColor)
				suffixToken = GetColoredMessage(suffixToken, messageColor)

				local importantToken, isKOS = GetImportantIcon(targetNameFromId)

				local text = GetSpacedOutString(bracketsToken, playerToken, actionToken..targetPlayer, prepToken, abilityToken..suffixToken..importantToken..kbIconToken)

				return text, isKOS, bracketsToken
			end

			local function GetKbStringTarget(targetNameFromId, targetPlayer, abilityId)
				local importantToken = GetImportantIcon(targetNameFromId)
				local suffixToken = "!"
				local actionToken
				local messageColor = "AF7500"
				local abilityToken = GetFormattedAbilityName(abilityId, 'CCCCCC')

				actionToken = PVP:Colorize("died from", messageColor)
				abilityToken = GetFormattedAbilityName(abilityId, 'CCCCCC')

				suffixToken = PVP:Colorize(suffixToken, messageColor)


				local endingToken = abilityToken..suffixToken..importantToken
				local text = GetSpacedOutString(targetPlayer, actionToken, endingToken)
				return text
			end

			local function GetKbStringPlayer(abilityId, sourceUnitId, sourceName)
				local playerToken = "You"
				local actionToken
				local attackerToken = "Killed with"
				local suffixToken = "!"
				local messageColor = "BB4040"
				local bracketsToken = "***"
				local killedByToken
				local sourceNameFromId = PVP.idToName[sourceUnitId]
				local sourceAllianceColor = PVP:IdToAllianceColor(sourceUnitId)
				local importantToken = GetImportantIcon(sourceName)
				local abilityToken = GetFormattedAbilityName(abilityId, 'CCCCCC')

				suffixToken = PVP:Colorize(suffixToken, messageColor)

				actionToken = PVP:Colorize("died from", messageColor)
				killedByToken = "Killed by"
				abilityToken = GetFormattedAbilityName(abilityId, 'CCCCCC')..suffixToken

				playerToken = PVP:Colorize(playerToken, messageColor)

				attackerToken = PVP:Colorize(attackerToken, messageColor)
				bracketsToken = PVP:Colorize(bracketsToken, messageColor)
				killedByToken = PVP:Colorize(killedByToken, messageColor)

				local killedByNameToken
				if sourceNameFromId and sourceAllianceColor then
					killedByNameToken = PVP:GetFormattedClassNameLink(sourceNameFromId, sourceAllianceColor)
				else
					killedByNameToken = " "..PVP:Colorize(PVP:GetFormattedCharNameLink(sourceName), "FFFFFF")
				end

				killedByToken = killedByToken..killedByNameToken..suffixToken

				local text = GetSpacedOutString(bracketsToken, playerToken, actionToken, abilityToken, killedByToken, importantToken)
				return text, bracketsToken
			end

			local function GetKbStringUnknown(abilityId)
				local abilityToken = GetFormattedAbilityName(abilityId, 'CCCCCC')
				return self:Colorize("Somebody died from ", "AF7500")..abilityToken
			end


			if self.killFeedDelay == 0 then	PVP_KillFeed_Text:Clear() end
			if self.killFeedRatioDelay == 0 then self:KillFeedRatio_Reset() end

			self.killFeedDelay=currentTime
			if self.SV.showKillFeedFrame then self.killFeedRatioDelay = currentTime end

			local isOwnKillingBlow = sourceName == self.playerName
			local kbOnPlayer = targetName==self.playerName

			local outputText
			local endingBrackets = ""


			if targetNameFromId and allianceColor then
				if self.SV.showKillFeedFrame then self:KillFeedRatio_Add(targetUnitId) end
				local targetPlayer = PVP:GetFormattedClassNameLink(targetNameFromId, allianceColor)
				if isOwnKillingBlow then
					local isKOS
					outputText, isKOS, endingBrackets = GetOwnKbString(targetNameFromId, targetPlayer, abilityId)
					if PVP.SV.playKillingBlowSound then
						PVP:PlayLoudSound('DUEL_WON')
						if isKOS then
							zo_callLater(function()
								PVP:PlayLoudSound('ACHIEVEMENT_AWARDED')
							end, 3000)
						end
					end
				else
					outputText = GetKbStringTarget(targetNameFromId, targetPlayer, abilityId)
				end
			elseif kbOnPlayer then
				outputText, endingBrackets = GetKbStringPlayer(abilityId, sourceUnitId, sourceName)
			else
				outputText = GetKbStringUnknown(abilityId)
			end

			if self.killingBlowsInfo and PVP:GetUnitAllianceFromDb(targetUnitId) and PVP:GetUnitAllianceFromDb(targetUnitId) ~= PVP.allianceOfPlayer then
				outputText = GetSpacedOutString(outputText..self.killingBlowsInfo.message)
				self.killingBlowsInfo = nil
			end

			outputText = outputText.." "..endingBrackets

			if self.SV.showKillFeedFrame then PVP_KillFeed_Text:AddMessage(outputText) end

			if not self.SV.showOnlyOwnKillingBlows or isOwnKillingBlow then

				if self.SV.showKillFeedChat and self.ChatContainer and self.ChatWindow then
					self.ChatContainer:AddMessageToWindow(self.ChatWindow, self:Colorize("["..GetTimeString().."]", "A0A0A0")..outputText)
				end

				if self.SV.showKillFeedInMainChat then
					chat:Print(outputText)
				end
			end
		end
	end

	local function OnKillingBlow()
		if KILLING_BLOW_ACTION_RESULTS[result] and self.totalPlayers[targetUnitId] then
			if self.idToName[targetUnitId] then
				self.currentlyDead[targetUnitId]={currentTime=currentTime, playerName = self.idToName[targetUnitId]}
			else
				self.currentlyDead[targetUnitId]={currentTime=currentTime, playerName = ""}
			end

			local deadName = self.idToName[targetUnitId] or targetName

			if deadName and #self.namesToDisplay>0 then
				for i=1,#self.namesToDisplay do
					if self.namesToDisplay[i].unitName == deadName and not self.namesToDisplay[i].isDead then
						self.namesToDisplay[i].isDead = true
						self.namesToDisplay[i].currentTime = currentTime
						self:PopulateReticleOverNamesBuffer()
						break
					end
				end
			end

			self.totalPlayers[targetUnitId]=nil
			self.playerSpec[self.idToName[targetUnitId]]=nil
			self.miscAbilities[self.idToName[targetUnitId]]=nil
			self.idToName[targetUnitId]=nil
			self.playerAlliance[targetUnitId]=nil
		end
	end

	local function ProcessAnonymousEvents()
		if sourceName=="" and targetName=="" and (not self.npcExclude[targetUnitId]) and (not self.currentlyDead[targetUnitId]) and not DEAD_ACTION_RESULTS[result] then
			if self:IsNPCAbility(abilityId) then
				self.npcExclude[targetUnitId]=currentTime
				if self.totalPlayers[targetUnitId] then
					self.totalPlayers[targetUnitId]=nil
					self.playerSpec[self.idToName[targetUnitId]]=nil
					self.miscAbilities[self.idToName[targetUnitId]]=nil
					self.idToName[targetUnitId]=nil
					self.playerAlliance[targetUnitId]=nil
				end
			else
				self.totalPlayers[targetUnitId]=currentTime
				if self.idToName[targetUnitId] then
					self:DetectSpec(targetUnitId, abilityId, result, nil, true)
				end
			end
		end
	end

	local function ProcessSources()
		if sourceName~="" and sourceName~=self.playerName and not (self.currentlyDead[sourceUnitId]) or self.IsCurrentlyDead(sourceName) then
			if not self:CheckName(sourceName) then
				self.npcExclude[sourceUnitId]=currentTime
				if self.totalPlayers[sourceUnitId] then
					self.totalPlayers[sourceUnitId]=nil
					self.playerSpec[self.idToName[sourceUnitId]]=nil
					self.miscAbilities[self.idToName[sourceUnitId]]=nil
					self.idToName[sourceUnitId]=nil
					self.playerAlliance[sourceUnitId]=nil
				end
			elseif self.SV.playersDB[sourceName] then
				self.playerAlliance[sourceUnitId]=self.SV.playersDB[sourceName].unitAlliance
				self.idToName[sourceUnitId]=sourceName
				self:DetectSpec(sourceUnitId, abilityId, result, sourceName, false)
				self.totalPlayers[sourceUnitId]=currentTime
				if targetName == self.playerName then
					if self.SV.showImportant and self.chargeSnareId[abilityId] then
						self.miscAbilities[sourceName] = self.miscAbilities[sourceName] or {}
						self.miscAbilities[sourceName].chargeId = abilityId
					end
					self:UpdateNamesToDisplay(sourceName, currentTime, false, 'source', abilityId, result)
				end
			end
		end
	end

	local function ProcessTargets()
		if targetName~="" and targetName~=self.playerName and sourceName==self.playerName and not (self.currentlyDead[targetUnitId]) or self.IsCurrentlyDead(targetName) then
			if not self:CheckName(targetName) then
				self.npcExclude[targetUnitId]=currentTime
				if self.totalPlayers[targetUnitId] then
					self.totalPlayers[targetUnitId]=nil
					self.playerSpec[self.idToName[targetUnitId]]=nil
					self.miscAbilities[self.idToName[targetUnitId]]=nil
					self.idToName[targetUnitId]=nil
					self.playerAlliance[targetUnitId]=nil
				end
			elseif self.SV.playersDB[targetName] then
				self.playerAlliance[targetUnitId]=self.SV.playersDB[targetName].unitAlliance
				self.idToName[targetUnitId]=targetName
				self.totalPlayers[targetUnitId]=currentTime
				self:UpdateNamesToDisplay(targetName, currentTime, false, 'target', abilityId, result)

				if result == ACTION_RESULT_REFLECTED then
					self.miscAbilities[targetName] = self.miscAbilities[targetName] or {}
					if not self.miscAbilities[targetName].reflects then self.miscAbilities[targetName].reflects = {} end
					self.miscAbilities[targetName].reflects[abilityName] = true
				end
			end
		end
	end

	local function ProcessPVPBuffs()
		if self:ShouldShowCampFrame() and targetName==self.playerName and result == ACTION_RESULT_EFFECT_GAINED_DURATION then
			if abilityId == PVP_CONTINUOUS_ATTACK_ID_1 or abilityId == PVP_CONTINUOUS_ATTACK_ID_2 then
				-- if PVP.keepTickPending then
					-- PVP:ProcessKeepTicks(PVP.keepTickPending, true)
					-- PVP.keepTickPending = nil
				-- end

				self:StartAnimation(PVP_ForwardCamp_IconContinuous, 'camp')
				if self.SV.playBuffsSound then
					PVP:PlayLoudSound('JUSTICE_NOW_KOS')
				end
			elseif abilityId == PVP_AYLEID_WELL_ID then
				self:StartAnimation(PVP_ForwardCamp_IconAyleid, 'camp')
				if self.SV.playBuffsSound then
					PVP:PlayLoudSound('JUSTICE_NOW_KOS')
				end
			elseif abilityId == PVP_BLESSING_OF_WAR_ID then
				self:StartAnimation(PVP_ForwardCamp_IconBlessing, 'camp')
				if self.SV.playBuffsSound then
					PVP:PlayLoudSound('JUSTICE_NOW_KOS')
				end
			end
		end
	end

	local function ProcessImportantAttacks()
		if self.SV.showImportant and ((result == ACTION_RESULT_EFFECT_GAINED and (self.importantAbilitiesId[abilityId] or self.smallImportantAbilitiesNames[abilityName])) or (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityName == "Charge Snare" and self.miscAbilities[sourceName] and self.miscAbilities[sourceName].chargeId)) then
			local CC_IMMUNITY_GRACE_TIME = 1
			local ccImmune = self:IsPlayerCCImmune(CC_IMMUNITY_GRACE_TIME)
			if (not ccImmune) or self.majorImportantAbilitiesId[abilityId] or self.smallImportantAbilitiesNames[abilityName] then

				if self.smallImportantAbilitiesNames[abilityName] then
					local abilityIcon = GetAbilityIcon(abilityId)
					-- PVP_Main.currentChannel = nil
					-- self:OnDraw(false, sourceUnitId, abilityIcon, sourceName, false, false)

					self:OnDraw(false, sourceUnitId, abilityIcon, sourceName, false, false, false, 1450)
					PVP_Main.currentChannel = {abilityId = abilityId, sourceUnitId = sourceUnitId, isHA = false, coolDownStartTime = currentTime}
				else
					if currentTime-self.attackSoundDelay>2000 then
						PlaySound(SOUNDS.CONSOLE_GAME_ENTER)
					end
					PlaySound(SOUNDS.CONSOLE_GAME_ENTER)
					zo_callLater(function()
						if currentTime-self.attackSoundDelay>2000 then
							PlaySound(SOUNDS.CONSOLE_GAME_ENTER)
						end
						PlaySound(SOUNDS.CONSOLE_GAME_ENTER)
					end, 250)
					self.attackSoundDelay=currentTime
					local abilityIcon

					if abilityName == "Charge Snare" then
						abilityIcon = GetAbilityIcon(self.miscAbilities[sourceName].chargeId)
					else
						abilityIcon = GetAbilityIcon(abilityId)
					end
					FlashHealthWarningStage(1, 150)
					PVP_Main.currentChannel = nil
					self:OnDraw(false, sourceUnitId, abilityIcon, sourceName, true, false)
				end
			end
		end
	end

	local function ProcessChanneledAttacks()
		if result==ACTION_RESULT_BEGIN and (isHeavyAttack or isSnipe or self.ambushId[abilityId]) then
			local abilityIcon = isHeavyAttack and self.heavyAttackId[abilityId] or GetAbilityIcon(abilityId)
			self:OnDraw(isHeavyAttack, sourceUnitId, abilityIcon, sourceName, false, false, false, hitValue)
			PVP_Main.currentChannel = {abilityId = abilityId, sourceUnitId = sourceUnitId, isHA = isHeavyAttack, coolDownStartTime = currentTime}
		end
	end

	local function ProcessPiercingMarks()
		if result==ACTION_RESULT_EFFECT_GAINED_DURATION and abilityName=="Piercing Mark" and not self.piercingDelay then
			self.piercingDelay=true
			local iconAbility = GetAbilityIcon(abilityId)
			PVP_Main.currentChannel = nil
			self:OnDraw(false, sourceUnitId, iconAbility, sourceName, false, true)
			zo_callLater(function() self.piercingDelay=false end, 50)
		end
	end

	local function ProcessChanneledHits()
		if not PVP_Main:IsHidden() and PVP_Main:GetAlpha()>0 and PVP_Main.currentChannel and PVP_Main.currentChannel.abilityId == abilityId and PVP_Main.currentChannel.sourceUnitId == sourceUnitId and PVP.hitTypes[result] then
			if not PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon.animData:IsPlaying() and not PVP_MainAbilityIconFrameLeftGlow.animData:IsPlaying() then
				PVP:PlayHighlightAnimation(PVP_Main.currentChannel.isHA, true)
				-- PVP_Main.currentChannel = nil
			end
		end
	end

	ProcessKillingBlows()
	OnKillingBlow()
	ProcessAnonymousEvents()
	ProcessSources()
	ProcessTargets()
	ProcessPVPBuffs()

	if self.SV.showAttacks and targetName==self.playerName and sourceName~=self.playerName then
		ProcessImportantAttacks()
		ProcessChanneledAttacks()
		ProcessPiercingMarks()
		ProcessChanneledHits()
	end
end

function PVP:ResetMainFrame()
	PVP_MainLabel:SetText("")

	PVP_MainAbilityIconFrameLeftGlow.animData:Stop()
	PVP_MainAbilityIconFrameLeftGlow:SetAlpha(0)
	PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon.animData:Stop()
	PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon:SetAlpha(0)
	PVP_MainAbilityIconFrameLeftCooldown:ResetCooldown()
	-- PVP_MainAbilityIconFrameLeftCooldownMark:ResetCooldown()

	PVP_MainAbilityIconFrameRightGlow.animData:Stop()
	PVP_MainAbilityIconFrameRightGlow:SetAlpha(0)
	PVP_MainAbilityIconFrameRightHeavyAttackHighlightIcon.animData:Stop()
	PVP_MainAbilityIconFrameRightHeavyAttackHighlightIcon:SetAlpha(0)
	PVP_MainAbilityIconFrameRightCooldown:ResetCooldown()
	-- PVP_MainAbilityIconFrameRightCooldownMark:ResetCooldown()


	PVP_MainAbilityIconFrameLeftIcon:SetColor(1,1,1,1)
	PVP_MainAbilityIconFrameRightIcon:SetColor(1,1,1,1)

	PVP_Main.isHA = false

	PVP_MainAbilityIconFrameRight:SetHidden(false)
	if PVP_MainAbilityIconFrameLeftLeadingEdge.animData and PVP_MainAbilityIconFrameLeftLeadingEdge.animData:IsPlaying() then PVP_MainAbilityIconFrameLeftLeadingEdge.animData:Stop() end
	PVP_Main:SetHidden(true)
end

function PVP:PlayLeadingEdgeAnimation(control, hitValue)
	if control.animData then control.animData:Stop() end

	local timeline = ANIMATION_MANAGER:CreateTimeline()
	local iconControl = control:GetParent():GetNamedChild('Icon')
	local _, offsetY = iconControl:GetDimensions()

	control:ClearAnchors()
	control:SetAnchor(CENTER, iconControl, BOTTOM, 0, 4)

	PVP:InsertAnimationType(timeline, ANIMATION_TRANSLATE, control, hitValue, 0, ZO_LinearEase, 0, 4, 0, -(offsetY))


    timeline:SetHandler('OnStop', function()
		control:SetHidden(true)
	end)

	control:SetHidden(false)
    timeline:PlayFromStart()
	return timeline
end

function PVP:SetupMainFrame(text, isImportant, texture, isHA)
	PVP:ResetMainFrame()

	PVP_MainLabel:SetText(text)

	PVP_MainAbilityIconFrameLeftIcon:SetTexture(texture)
	PVP_MainAbilityIconFrameLeftCooldown:SetTexture(texture)


	PVP_MainAbilityIconFrameRightIcon:SetTexture(texture)
	PVP_MainAbilityIconFrameRightCooldown:SetTexture(texture)

	if isHA then
		PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon:SetTexture(texture)
		PVP_MainAbilityIconFrameRightHeavyAttackHighlightIcon:SetTexture(texture)
	end

	PVP_MainAbilityIconFrameLeftLeadingEdge:SetHidden(true)
	PVP_MainAbilityIconFrameRight:SetHidden(not isImportant)
	PVP_Main.isHA = isHA
end

function PVP:PlayHighlightAnimation(isHA, isChannel)
	local leadingEdgeControl = PVP_MainAbilityIconFrameLeftLeadingEdge
	local function PingPong (control, duration)
		duration = duration or 250
		control.animData:PingPong(0, 1, duration, 1)
	end
	local function FadeOut (control)
		control.animData:FadeOut(0, 175, ZO_ALPHA_ANIMATION_OPTION_FORCE_ALPHA)
	end
	local function StartAnim (control, isChannel)
		PingPong (control)
	end

	if leadingEdgeControl.animData and leadingEdgeControl.animData:IsPlaying() then leadingEdgeControl.animData:Stop() end

	if isHA then
		StartAnim (PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon, isChannel)
		StartAnim (PVP_MainAbilityIconFrameRightHeavyAttackHighlightIcon, isChannel)
		-- PVP_MainAbilityIconFrameLeftHeavyAttackHighlightIcon.animData:PingPong(0, 1, 250, 1)
		-- PVP_MainAbilityIconFrameRightHeavyAttackHighlightIcon.animData:PingPong(0, 1, 250, 1)
	else
		StartAnim (PVP_MainAbilityIconFrameLeftGlow, isChannel)
		StartAnim (PVP_MainAbilityIconFrameRightGlow, isChannel)
		-- PVP_MainAbilityIconFrameLeftGlow.animData:PingPong(0, 1, 250, 1)
		-- PVP_MainAbilityIconFrameRightGlow.animData:PingPong(0, 1, 250, 1)
	end

	local cooldownDuration = PVP_MainAbilityIconFrameLeftCooldown:GetDuration()

	if PVP_Main.currentChannel and PVP_Main.currentChannel.coolDownStartTime and cooldownDuration ~= 0 then
		PVP_Main.currentChannel = nil
	end
end

function PVP_SetupHighlightAnimation(control)
	local function SetAnimData(control)
		control.animData = ZO_AlphaAnimation:New(control)
		control.animData:SetMinMaxAlpha(0, 1)
	end

	local glowLeft = control:GetNamedChild('AbilityIconFrameLeft'):GetNamedChild('Glow')
	local glowRight = PVP_MainAbilityIconFrameRight:GetNamedChild('Glow')
	local iconHighlightLeft = control:GetNamedChild('AbilityIconFrameLeft'):GetNamedChild('HeavyAttackHighlightIcon')
	local iconHighlightRight = PVP_MainAbilityIconFrameRight:GetNamedChild('HeavyAttackHighlightIcon')

	SetAnimData(glowLeft)
	SetAnimData(glowRight)
	SetAnimData(iconHighlightLeft)
	SetAnimData(iconHighlightRight)
end

function PVP:OnDraw(isHeavyAttack, sourceUnitId, abilityIcon, sourceName, isImportant, isPiercingMark, isDebuff, hitValue)
	local playerAlliance, nameFromDB, classIcon, nameColor, nameFont, enemyName, formattedName, pureNameWidth
	local importantMode = isImportant and not isPiercingMark
	local heavyAttackSpacer = isHeavyAttack and "" or " "
	local abilityIconSize = isHeavyAttack and 75 or 50
	-- local nameWidth = abilityIconSize
	local nameWidth = 0
	local classIconSize = 45
	-- local abilityIcon = self:GetIcon(abilityIcon, abilityIconSize)..heavyAttackSpacer
	-- local importantIcon = importantMode and " "..abilityIcon or ""

	if sourceUnitId == "unlock" then
		playerAlliance="BBBBBB"
		nameFromDB = sourceName
		classIcon = playerAlliance and self:Colorize(zo_iconFormatInheritColor(self.classIcons[3], classIconSize, classIconSize), playerAlliance) or heavyAttackSpacer
	elseif not isDebuff then
		nameFromDB = self.idToName[sourceUnitId]
		playerAlliance=self:IdToAllianceColor(sourceUnitId)
		classIcon = playerAlliance and self:GetFormattedClassIcon(nameFromDB, classIconSize, playerAlliance) or heavyAttackSpacer
	else
		classIcon = ""
	end

	enemyName = isDebuff and sourceName or self:GetFormattedName(sourceName)

	if importantMode then
		nameColor=self.SV.colors.stealthed
		PVP_MainBackdrop:SetHidden(false)
		PVP_MainBackdrop_Add:SetHidden(false)
	else
		PVP_MainBackdrop:SetHidden(true)
		if isPiercingMark then
			PVP_MainBackdrop_Add:SetHidden(false)
			nameColor=self.SV.colors.piercing
		else
			PVP_MainBackdrop_Add:SetHidden(true)
			nameColor=self.SV.colors.normal
		end
	end

	if self.isPlaying then self.isPlaying:Stop() end

	nameWidth = PVP_MainLabel:GetStringWidth(enemyName) + 60
	local scale = PVP_MainLabel:GetScale()
	local weirdScale = scale


	PVP_MainLabel:SetWidth(nameWidth/weirdScale)

	formattedName = self:Colorize(enemyName, playerAlliance and playerAlliance or nameColor)

	PVP:SetupMainFrame(classIcon..formattedName, importantMode, abilityIcon, isHeavyAttack)

	if hitValue then
		PVP_MainAbilityIconFrameLeftCooldown:StartCooldown(hitValue, hitValue, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL, false)
		if not isHeavyAttack then
			PVP_MainAbilityIconFrameLeftLeadingEdge.animData = PVP:PlayLeadingEdgeAnimation(PVP_MainAbilityIconFrameLeftLeadingEdge, hitValue)
		end
		-- PVP_MainAbilityIconFrameLeftCooldownMark:StartCooldown(hitValue, hitValue, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL, not isHeavyAttack)
	end

	if isImportant then
		PVP:PlayHighlightAnimation()
	end

	PVP_Main:SetHidden(false)

	if isPiercingMark then
		self.isPlaying=self:StartAnimation(PVP_Main, 'main piercing')
	elseif isImportant then
		self.isPlaying=self:StartAnimation(PVP_Main, 'main important')
	else
		self.isPlaying=self:StartAnimation(PVP_Main, 'main stealthed')
	end
end

function PVP:StartAnimation(control, animationType, targetParameter)
	if animationType ~= 'camp' and animationType ~= 'fadeOut' and self.isPlaying then self.isPlaying:Stop() end

	local _, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor()
	local scale

	if animationType == 'camp' then
		scale=self.SV.campControlScale
	elseif animationType == 'fadeOut' then
		scale=self.SV.targetNameFrameScale
	elseif animationType == 'medal' then
		scale=1
	else
		scale=self.SV.controlScale
	end

	control:ClearAnchors()
	control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)

    local timeline = ANIMATION_MANAGER:CreateTimeline()

	if animationType=='main stealthed' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 100,	0,						ZO_EaseOutQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,   0,						ZO_EaseOutQuadratic,	1,				1.5,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,	100,					ZO_EaseInQuadratic,		1.5,			1,		PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 250,	PVP_FRAME_DISPLAY_TIME, ZO_EaseInQuintic,		1,			0,		PVP_SET_SCALE_FROM_SV)
	elseif animationType=='main piercing' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 50,	0,						ZO_EaseOutQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,   0,						ZO_EaseOutQuadratic,	1,				1.2,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 250,	350,					ZO_EaseInQuadratic,	1.2,			1,		PVP_SET_SCALE_FROM_SV)
		local currentAlpha=control:GetAlpha()
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 150,	1600,					ZO_EaseOutQuadratic,	currentAlpha,	0)
	elseif animationType=='medal' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 250,	0,						ZO_EaseInQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 1000,	2000,					ZO_EaseOutQuadratic,	1,			0)
	elseif animationType=='main important' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 100,	0,						ZO_EaseOutQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,   0,						ZO_EaseOutQuadratic,	1,				1.75,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,	200,					ZO_EaseInQuadratic,	1.75,			1,		PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 250,	500,					ZO_EaseInQuadratic,	1,			0,		PVP_SET_SCALE_FROM_SV)
	elseif animationType == 'camp' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 100,	0,						ZO_EaseOutQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 300,   0,						ZO_EaseOutQuadratic,	1,				1.6,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 300,	400,					ZO_EaseInQuadratic,	1.6,			1,		PVP_SET_SCALE_FROM_SV)
	elseif animationType == 'attackerFrame' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 100,	0,						ZO_EaseOutQuadratic,	0,				targetParameter)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 200,   0,						ZO_EaseOutQuadratic,	self.SV.newAttackerFrameScale,				self.SV.newAttackerFrameScale*1.6,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 200,	250,					ZO_EaseInQuadratic,	self.SV.newAttackerFrameScale*1.6,			self.SV.newAttackerFrameScale,		PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 1500,	self.SV.newAttackerFrameDelayBeforeFadeout,					ZO_EaseOutQuadratic,	targetParameter, 0)
	elseif animationType == 'fadeOut' then
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, self.SV.targetNameFrameFadeoutTime, self.SV.targetNameFrameDelayBeforeFadeout, ZO_EaseOutQuadratic, control:GetAlpha(), 0)
	else
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 50,	0,						ZO_EaseOutQuadratic,	0,				1)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 150,   0,						ZO_EaseOutQuadratic,	1,				1.4,	PVP_SET_SCALE_FROM_SV)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 250,	250,					ZO_EaseInQuadratic,	1.4,			1,		PVP_SET_SCALE_FROM_SV)
		local currentAlpha=control:GetAlpha()
		self:InsertAnimationType(timeline, ANIMATION_ALPHA, control, 150,	1200,					ZO_EaseOutQuadratic,	currentAlpha,	0)
	end


    timeline:SetHandler('OnStop', function()
		control:ClearAnchors()
		control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
		control:SetScale(scale)
		if animationType == 'fadeOut' then PVP_TargetNameLabel:SetText("") end
		if animationType == 'attackerFrame' then
			PVP_NewAttackerNumber:SetText("")
			PVP_NewAttackerLabel:SetText("")
		end
		if animationType == 'medal' or animationType == 'main important' or animationType == 'main piercing' or animationType == 'main stealthed' then control:SetAlpha(0) end
		if self.SV.unlocked then PVP_Main:SetAlpha(1) end
	end)

    timeline:PlayFromStart()
	return timeline
end

function PVP:GetTargetChar(playerName, isTargetFrame)
	if not self.SV.playersDB[playerName] then return nil end

	local function FindInNames(playerName)
		local isDeadOrResurrect
		local statusIcon = ""
		if #self.namesToDisplay ~= 0 then
			for _,v in ipairs(self.namesToDisplay) do
				if v.unitName == playerName then
					if v.isDead then
						statusIcon = self:GetDeathIcon(not isTargetFrame and 40 or nil)
						isDeadOrResurrect = true
					elseif v.isTarget then
						if IsActiveWorldBattleground() then
							statusIcon = self:GetAttackerIcon(not isTargetFrame and 55 or nil)
						else
							statusIcon = self:GetFightIcon(not isTargetFrame and 35 or nil, nil, self.SV.playersDB[playerName].unitAlliance)
						end
					elseif v.isAttacker then
						statusIcon = self:GetAttackerIcon(not isTargetFrame and 55 or nil)
					end
					break
				end
			end
		end

		return statusIcon, isDeadOrResurrect
	end

	local formattedName
	local KOSOrFriend = self:IsKOSOrFriend(playerName)

	local statusIcon, isDeadOrResurrect  = FindInNames(playerName)

	if PVP:GetValidName(GetRawUnitName('reticleover')) == playerName and IsUnitDead('reticleover') then
		statusIcon = self:GetDeathIcon(not isTargetFrame and 40 or nil)
		isDeadOrResurrect = true
	end

	local nameColor

	if isTargetFrame then
		nameColor = 'FFFFFF'
	else
		if IsActiveWorldBattleground() then
			if PVP.bgNames and PVP.bgNames[playerName] and PVP.bgNames[playerName]~=0 then
				nameColor = PVP:BgAllianceToHexColor(PVP.bgNames[playerName])
			else
				nameColor = 'FFFFFF'
			end
		else
			nameColor = self:NameToAllianceColor(playerName, isDeadOrResurrect)
		end
	end


	if isDeadOrResurrect then
		formattedName = self:GetFormattedClassNameLink(playerName, nameColor, false, isDeadOrResurrect, true, not isTargetFrame)
	else
		formattedName = self:GetFormattedClassNameLink(playerName, nameColor, nil, nil, true, not isTargetFrame)
	end

	-- if KOSOrFriend then
	if KOSOrFriend=="KOS" then
		formattedName=formattedName..self:GetKOSIcon(not isTargetFrame and 45 or nil)
	elseif KOSOrFriend=="friend" then
		formattedName=formattedName..self:GetFriendIcon(not isTargetFrame and 35 or 19)
	elseif KOSOrFriend=="cool" then
		formattedName=formattedName..self:GetCoolIcon(not isTargetFrame and 35 or 19)
	elseif KOSOrFriend=="groupleader" then
		formattedName=formattedName..self:GetGroupLeaderIcon(not isTargetFrame and 45 or nil)
	elseif KOSOrFriend=="group" then
		formattedName=formattedName..self:GetGroupIcon(not isTargetFrame and 45 or nil)
	end

	if isTargetFrame then
		formattedName=formattedName..statusIcon
	elseif isDeadOrResurrect then
		formattedName=formattedName.." "..statusIcon
	else
		formattedName=statusIcon..formattedName.." "..statusIcon
	end

	return formattedName
end

function PVP:OnMapPing(eventCode, pingEventType, pingType, pingTag, offsetX, offsetY, isLocalPlayerOwner)
	if not PVP:Should3DSystemBeOn() then return end

	local playerGroupTag = GetGroupUnitTagByIndex(GetGroupIndexByUnitTag("player"))

	self.currentMapPings = self.currentMapPings or {}

	if pingEventType == PING_EVENT_ADDED then
		if self.SV.pingWaypoint and IsUnitGrouped('player') and isLocalPlayerOwner and pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT then
			self.suppressTest = {playerGroupTag = playerGroupTag, currentTime = GetFrameTimeMilliseconds()}
			if not self.LMP:IsPingSuppressed(MAP_PIN_TYPE_PING, self.suppressTest.playerGroupTag) then self.LMP:SuppressPing(MAP_PIN_TYPE_PING, self.suppressTest.playerGroupTag) end
			self.LMP:SetMapPing(MAP_PIN_TYPE_PING, MAP_TYPE_LOCATION_CENTERED, offsetX, offsetY)
			self.pingSuppressionStarted = zo_callLater (function() self.pingSuppressionStarted = nil end, 25)
		end
		if not (self.suppressTest and isLocalPlayerOwner and pingType == MAP_PIN_TYPE_PING) then
			local pingObject
			if (pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT or pingType == MAP_PIN_TYPE_RALLY_POINT) and PVP.currentTooltip then
				pingObject = PVP.currentTooltip
				if pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT then
					PVP.currentTooltip.params.hasWaypoint = true
				else
					PVP.currentTooltip.params.hasRally = true
				end
			end

			table.insert (self.currentMapPings,{pinType = pingType, pingTag = pingTag, targetX = offsetX, targetY = offsetY, isLocalPlayerOwner = isLocalPlayerOwner, pingObject = pingObject})
		end
	elseif pingEventType == PING_EVENT_REMOVED then
		if self.suppressTest and not self.pingSuppressionStarted and pingType == MAP_PIN_TYPE_PING and isLocalPlayerOwner then
			if self.LMP:IsPingSuppressed(MAP_PIN_TYPE_PING, self.suppressTest.playerGroupTag) then self.LMP:UnsuppressPing(MAP_PIN_TYPE_PING, self.suppressTest.playerGroupTag) end
			self.suppressTest = nil
		end

		for k, v in ipairs (self.currentMapPings) do
			if v.pinType == pingType and v.pingTag == pingTag and v.isLocalPlayerOwner == isLocalPlayerOwner then
				if v.pingObject then
					v.pingObject.params.hasWaypoint = nil
					v.pingObject.params.hasRally = nil
				end
				table.remove(self.currentMapPings, k)
				break
			end
		end
	end
end

local function SetupDeathButtons()
		HUD_SCENE:AddFragment(PVP_DEATH_FRAGMENT)
		HUD_UI_SCENE:AddFragment(PVP_DEATH_FRAGMENT)
		PVP_DEATH_FRAGMENT:Show()

		local color

		if PVP.allianceOfPlayer == 1 then
			color = PVP_BRIGHT_AD_COLOR
		elseif PVP.allianceOfPlayer == 2 then
			color = PVP_BRIGHT_EP_COLOR
		elseif PVP.allianceOfPlayer == 3 then
			color = PVP_BRIGHT_DC_COLOR
		end

		local campIndex = PVP:FindNearbyCampToRespawn(true)

		if campIndex then
			PVP_Death_ButtonsButton1:SetKeybind('PVP_ALERTS_RESPAWN_AT_CAMP')
			PVP_Death_ButtonsButton1NameLabel:SetText('Respawn at '..PVP:Colorize('Forward Camp', color))
			PVP_Death_ButtonsButton1:SetCallback(function()
				PVP:RespawnAtNearbyCamp()
			end)
		else
			PVP_Death_ButtonsButton1:SetKeybind(nil)
			PVP_Death_ButtonsButton1NameLabel:SetText('')
			PVP_Death_ButtonsButton1:SetCallback(nil)
		end
		local keepId = PVP:FindNearbyKeepToRespawn()
		if keepId then
			local keepName = GetKeepName(keepId)
			if campIndex then
				PVP_Death_ButtonsButton2:SetKeybind('PVP_ALERTS_RESPAWN_AT_KEEP')
				PVP_Death_ButtonsButton2NameLabel:SetText('Respawn at '..PVP:Colorize(keepName, color))
				PVP_Death_ButtonsButton2:SetCallback(function()
					PVP:RespawnAtNearbyKeep()
				end)
			else
				PVP_Death_ButtonsButton1:SetKeybind('PVP_ALERTS_RESPAWN_AT_CAMP')
				PVP_Death_ButtonsButton1NameLabel:SetText('Respawn at '..PVP:Colorize(keepName, color))
				PVP_Death_ButtonsButton1:SetCallback(function()
					PVP:RespawnAtNearbyKeep()
				end)
				PVP_Death_ButtonsButton2:SetKeybind(nil)
				PVP_Death_ButtonsButton2NameLabel:SetText('')
				PVP_Death_ButtonsButton2:SetCallback(nil)
			end
		else
			if not campIndex then
				PVP_Death_ButtonsButton1:SetKeybind(nil)
				PVP_Death_ButtonsButton1NameLabel:SetText('')
				PVP_Death_ButtonsButton1:SetCallback(nil)
			end
			PVP_Death_ButtonsButton2:SetKeybind(nil)
			PVP_Death_ButtonsButton2NameLabel:SetText('')
			PVP_Death_ButtonsButton2:SetCallback(nil)
		end
end

function PVP:ProcessKeepTicks(difference, isOffensiveTick)
	local text
	local currentTime = GetFrameTimeMilliseconds()
	local tickType = isOffensiveTick and " offensive tick" or " defensive tick"

	tickType = self:Colorize(tickType, "F878F8")

	local keepId = self:FindAVAIds(GetPlayerLocationName(), true)

	if not keepId or keepId == 0 then return end

	text = zo_iconFormat(PVP:GetObjectiveIcon(GetKeepType(keepId), GetKeepAlliance(keepId, 1)), 27,27)..self:Colorize(GetKeepName(keepId), PVP:AllianceToColor(GetKeepAlliance(keepId, 1)))

	if not text or text == "" then return end

	text = self:Colorize('+++ You got', "F878F8")..text..tickType..self:Colorize(' for ', "F878F8")

	text = self:Colorize(text, "F878F8")..self:Colorize(zo_iconFormat(PVP_AP, 24, 24)..tostring(difference), "00cc00")..self:Colorize(' +++', "F878F8")

	if self.killFeedDelay==0 then
		PVP_KillFeed_Text:Clear()
	end
	if self.killFeedRatioDelay==0 then
		self:KillFeedRatio_Reset()
	end
	self.killFeedDelay=currentTime

	if self.SV.showKillFeedFrame then PVP_KillFeed_Text:AddMessage(text) end

	if self.SV.showKillFeedChat and self.ChatContainer and self.ChatWindow then
		self.ChatContainer:AddMessageToWindow(self.ChatWindow, self:Colorize("["..GetTimeString().."] ", "A0A0A0")..text)
	end

	if self.SV.showKillFeedInMainChat then
		chat:Print(self:Colorize("["..GetTimeString().."]", "A0A0A0")..text)
	end

	if self.SV.playBattleReportSound then
		PVP:PlayLoudSound('BOOK_COLLECTION_COMPLETED')
	end
end

function PVP:OnAlliancePointUpdate(eventCode, alliancePoints, playSound, difference, reason)
	-- if PVP.killFeedRatio and reason == CURRENCY_CHANGE_REASON_KILL then
		-- PVP.killFeedRatio.earnedAP = PVP.killFeedRatio.earnedAP + difference
	-- end

	-- local isTick = reason == CURRENCY_CHANGE_REASON_KEEP_REWARD and IsInCyrodiil()
	-- local isKB = reason == CURRENCY_CHANGE_REASON_KILL and not IsActiveWorldBattleground()


	-- if not isTick and not isKB then return end

	local currentTime = GetFrameTimeMilliseconds()

	if reason == CURRENCY_CHANGE_REASON_KILL then
		if PVP.killFeedRatio then
			PVP.killFeedRatio.earnedAP = PVP.killFeedRatio.earnedAP + difference
		end
		if not IsActiveWorldBattleground() then
			self.killingBlowsInfo = {message = self:Colorize(" "..zo_iconFormat(PVP_AP, 24, 24)..tostring(difference), "00cc00"), timestamp = currentTime}
		end
	elseif IsInCyrodiil() then
		if reason == CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD then
			PVP:ProcessKeepTicks(difference, true)
		elseif reason == CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD then
			PVP:ProcessKeepTicks(difference, false)
		end
	end

	-- if isTick then
		-- PVP.keepTickPending = difference

		-- zo_callLater(function()
			-- if PVP.keepTickPending then
				-- PVP:ProcessKeepTicks(PVP.keepTickPending, false)
				-- PVP.keepTickPending = nil
			-- end
		-- end, 100)

	-- else

	-- end

end

function PVP:OnMedalAwarded(eventCode, medalId, medalName, medalIcon, medalPoints)
	if not PVP.SV.showMedalsFrame or PVP.SV.unlocked then return end
	local alliance = GetUnitBattlegroundAlliance('player')

	local medalCount = GetScoreboardEntryNumEarnedMedalsById(GetScoreboardPlayerEntryIndex(), medalId) + 1

	if medalCount>1 then
		PVP_MedalsScore:SetText('x'..tostring(medalCount))
	else
		PVP_MedalsScore:SetText('')
	end

	PVP_MedalsIcon:SetTexture(medalIcon)

	PVP_MedalsName:SetText(medalName)
	local x, y = PVP_Medals:GetDimensions()

	PVP_Medals:SetHidden(false)
	if PVP.medalAnimation and PVP.medalAnimation:IsPlaying() then PVP.medalAnimation:Stop() end
	PVP.medalAnimation = PVP:StartAnimation(PVP_Medals, 'medal')
	PVP_PlaySparkleAnimation(PVP_Medals)
	PlaySound(SOUNDS.MARKET_CROWN_GEMS_SPENT)
end

function PVP:OnOff()

	local function OnWorldMapChangedCallback()
		PVP:OnWorldMapChangedCallback()
	end

	local function ScoreboardFragmentCallback (oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			PVP.bgScoreboard.list:RefreshData()
		end
	end

	local function OnDeathFragmentStateChange(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			local _, _, _, _, _, isAVADeath = GetDeathInfo()
			if isAVADeath then
				SetupDeathButtons()
				PVP_Death_Buttons:SetHandler("OnUpdate", function() SetupDeathButtons() end)
			else
				PVP_Death_ButtonsButton1:SetCallback(nil)
				PVP_Death_ButtonsButton2:SetCallback(nil)
				PVP_Death_Buttons:SetHandler("OnUpdate", nil)
				HUD_SCENE:RemoveFragment(PVP_DEATH_FRAGMENT)
				HUD_UI_SCENE:RemoveFragment(PVP_DEATH_FRAGMENT)
				PVP_DEATH_FRAGMENT:Hide()
			end
		elseif newState == SCENE_FRAGMENT_HIDING then
			PVP_Death_ButtonsButton1:SetCallback(nil)
			PVP_Death_ButtonsButton2:SetCallback(nil)
			PVP_Death_Buttons:SetHandler("OnUpdate", nil)
			HUD_SCENE:RemoveFragment(PVP_DEATH_FRAGMENT)
			HUD_UI_SCENE:RemoveFragment(PVP_DEATH_FRAGMENT)
			PVP_DEATH_FRAGMENT:Hide()
		end
	end

	if self.SV.enabled and PVP:IsInPVPZone() then
		if not self.addonEnabled then
			self.addonEnabled=true
			SLASH_COMMANDS["/who"] = function(name) PVP.Who(self, name, true) end
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, function(...) self:OnCombat(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_EFFECT_CHANGED, function(...) self:OnEffect(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_TARGET_PLAYER_CHANGED, self.OnTargetChanged)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_RETICLE_TARGET_CHANGED, self.OnTargetChanged)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OBJECTIVE_CONTROL_STATE, function(...) self:OnControlState(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CAPTURE_AREA_STATUS , function(...) self:OnCaptureStatus(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_KEEP_ALLIANCE_OWNER_CHANGED, function (eventCode, keepId, battlegroundContext, owningAlliance, oldOwningAlliance) if PVP:IsValidBattlegroundContext(battlegroundContext) then PVP:OnOwnerOrUnderAttackChanged(GetPlayerLocationName(), keepId, true) end end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_KEEP_UNDER_ATTACK_CHANGED, function (eventCode, keepId, battlegroundContext, underAttack) if PVP:IsValidBattlegroundContext(battlegroundContext) then self:OnOwnerOrUnderAttackChanged(GetPlayerLocationName(), keepId, not underAttack) end end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_CHANGED, function(...) self:OnZoneChange(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MAP_PING, function(...) self:OnMapPing(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_MEDAL_AWARDED, function(...) self:OnMedalAwarded(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ALLIANCE_POINT_UPDATE, function(...) self:OnAlliancePointUpdate(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ACTION_SLOT_ABILITY_USED, function(...) self:OnAbilityUsed(...) end)
			EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LEADER_UPDATE, function () PVP:InitControls() end)
			EVENT_MANAGER:RegisterForUpdate(self.name, 1000, PVP.OnUpdate)
			DEATH_FRAGMENT:RegisterCallback("StateChange", OnDeathFragmentStateChange)
			PVP_SCOREBOARD_FRAGMENT:RegisterCallback("StateChange", ScoreboardFragmentCallback)
			CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", OnWorldMapChangedCallback)
		end
		self:InitEnabledAddon()
	else
		if self.addonEnabled then
			self.addonEnabled=nil
			SLASH_COMMANDS["/who"] = nil
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_COMBAT_EVENT)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_EFFECT_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_RETICLE_TARGET_PLAYER_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_RETICLE_TARGET_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ZONE_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_OBJECTIVE_CONTROL_STATE)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_CAPTURE_AREA_STATUS)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_KEEP_ALLIANCE_OWNER_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_KEEP_UNDER_ATTACK_CHANGED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_MAP_PING)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_MEDAL_AWARDED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ALLIANCE_POINT_UPDATE)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ACTION_SLOT_ABILITY_USED)
			EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_LEADER_UPDATE)
			EVENT_MANAGER:UnregisterForUpdate(self.name)
			DEATH_FRAGMENT:UnregisterCallback("StateChange", OnDeathFragmentStateChange)
			PVP_SCOREBOARD_FRAGMENT:UnregisterCallback("StateChange", ScoreboardFragmentCallback)
			CALLBACK_MANAGER:UnregisterCallback("OnWorldMapChanged", OnWorldMapChangedCallback)
		end
		PVP.delayedInitControls = true
		PVP:InitControls()
		PVP:FullReset3DIcons()

		if not (self.SV.enabled and self.SV.unlocked) then
			PVP_TargetName:SetAlpha(0)
			PVP:ResetMainFrame()
			PVP_Counter:SetHidden(true)
			PVP_Names:SetHidden(true)
			PVP_KOS:SetHidden(true)
			PVP_KillFeed:SetHidden(true)
			PVP_Capture:SetHidden(true)
			PVP_ForwardCamp:SetHidden(true)
		end
	end
end


function PVP:FullReset()
	if self.isPlaying then self.isPlaying:Stop() end

	self.bgScoreBoardFirstRunDone = false
	self.piercingDelay=false
	self.bgScoreBoardData = {}
	self.totalPlayers={}
	self.npcExclude={}
	self.playerSpec = {}
	self.miscAbilities = {}
	self.playerNames = {}
	self.idToName={}
	self.playerAlliance={}
	self.currentlyDead={}
	self.KOSNamesList={}
	self.namesToDisplay={}

	self.friends = {}

	self.attackSoundDelay=0
	self.friendSoundDelay=0
	self.kosSoundDelay=0
	self.reportTimer=0
	self.killFeedDelay=0
	self.killFeedRatioDelay=0

	self:KillFeedRatio_Reset()
	self:InitControls()
	if self.SV.showKOSFrame then self:PopulateKOSBuffer() end
end

function PVP:GetAllianceCountPlayers()
	local numberAD, numberDC, numberEP = 0,0,0
	local tableAD, tableDC, tableEP, foundNames = {}, {}, {}, {}
	local tableNameToIndexAD, tableNameToIndexDC, tableNameToIndexEP = {}, {}, {}
	local maxLengthAD, maxLengthDC, maxLengthEP = 0,0,0
	local groupLeaderTable, groupMembersTable, kosTableAD, kosTableDC, kosTableEP, friendsTableAD, friendsTableDC, friendsTableEP, othersTableAD, othersTableDC, othersTableEP = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}


	local function FindInNames(playerName)
		local isResurrect, isDead
		local statusIcon = ""
		if #self.namesToDisplay ~= 0 then
			for i=1,#self.namesToDisplay do
				if self.namesToDisplay[i].unitName == playerName then
					if self.namesToDisplay[i].isResurrect then
						statusIcon = self:GetResurrectIcon()
						isResurrect = true
					elseif self.namesToDisplay[i].isDead then
						statusIcon = self:GetDeathIcon()
						isDead = true
					elseif self.namesToDisplay[i].isTarget then
						statusIcon = self:GetFightIcon(nil, nil, self.SV.playersDB[playerName].unitAlliance)
					elseif self.namesToDisplay[i].isAttacker then
						statusIcon = self:GetAttackerIcon()
					end
					break
				end
			end
		end

		return statusIcon, isResurrect, isDead
	end

	local function PopulateFromBGScoreboard()
		-- {class = 3, name = "Test^Fx" , kills = 30, deaths = 20, assists = 100, damage = 10000000, healing = 3000000, points = 800, alliance = 3},
		PVP.scoreboardListData = {}

		PVP.bgNames = PVP.bgNames or {}
		PVP.bgScoreBoardData = PVP.bgScoreBoardData or {}

		local battlegroundId = GetCurrentBattlegroundId()
		local battlegroundGameType = GetBattlegroundGameType(battlegroundId)
		local battlegroundLeaderboardType
		local battlegroundSpecialsType

		if battlegroundGameType == BATTLEGROUND_GAME_TYPE_DEATHMATCH then
			battlegroundLeaderboardType = 1
			battlegroundSpecialsType = SCORE_TRACKER_TYPE_KILL_STREAK
		elseif battlegroundGameType == BATTLEGROUND_GAME_TYPE_DOMINATION then
			battlegroundLeaderboardType = 2
			battlegroundSpecialsType = SCORE_TRACKER_TYPE_FLAG_CAPTURED
		elseif battlegroundGameType == BATTLEGROUND_GAME_TYPE_CAPTURE_THE_FLAG then
			battlegroundLeaderboardType = 3
			battlegroundSpecialsType = SCORE_TRACKER_TYPE_FLAG_CAPTURED
		end

		if GetNumBattlegroundLeaderboardEntries(battlegroundLeaderboardType) == 0 then
			QueryBattlegroundLeaderboardData()
		end

		local currentBgPlayers = {}
		for i = 1, GetNumScoreboardEntries() do
			local playerName, accName, bgAlliance = GetScoreboardEntryInfo(i)
			local entryClass = GetScoreboardEntryClassId(i)
			local entryKills = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_KILL)
			local entryDeaths = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_DEATH)
			local entryAssists = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_ASSISTS)
			local entryDamage = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_DAMAGE_DONE)
			local entryHealing = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_HEALING_DONE)
			local entryPoints = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_SCORE)
			local entrySpecials = GetScoreboardEntryScoreByType(i, battlegroundSpecialsType)

			local bgColor = PVP:BgAllianceToHexColor(bgAlliance)

			local entryRank
			if battlegroundLeaderboardType then
				for i=1, GetNumBattlegroundLeaderboardEntries(battlegroundLeaderboardType) do
					local rank, displayName, characterName, score = GetBattlegroundLeaderboardEntryInfo(battlegroundLeaderboardType, i)
					if '@'..displayName == accName then
						entryRank = rank
						break
					end
				end
			end

			local medalIdTable = {}

			local medalId = GetNextScoreboardEntryMedalId(i)

			while medalId do
				local medalCount = GetScoreboardEntryNumEarnedMedalsById(i, medalId)
				local _, _, _, medalPoints = GetMedalInfo(medalId)
				table.insert(medalIdTable, {medalId = medalId, medalCount = medalCount, medalPoints = medalPoints})
				-- table.insert(medalIdTable, {medalId = medalId, medalCount = medalCount})
				medalId = GetNextScoreboardEntryMedalId(i, medalId)
			end


			if not entryRank then entryRank = 9999 end

			table.insert(PVP.scoreboardListData, {
				class = entryClass,
				name = playerName,
				kills = entryKills,
				deaths = entryDeaths,
				assists = entryAssists,
				damage = entryDamage,
				healing = entryHealing,
				points = entryPoints,
				alliance = bgAlliance,
				rank = entryRank,
				medals = medalIdTable,
				specials = entrySpecials
			})

			local bgAccName = ZO_ShouldPreferUserId() and ZO_GetPrimaryPlayerNameFromUnitTag('player') or ZO_GetSecondaryPlayerNameFromUnitTag('player')

			if accName == bgAccName and PVP:IsMalformedName(self.playerName) then
				self.playerName = playerName
			end

			currentBgPlayers[playerName] = true

			PVP.bgNames[playerName] = bgAlliance

			local formattedName = self:GetFormattedClassNameLink(playerName, bgColor, nil, nil, nil, nil, entryClass)
			local nameLength = string.len(zo_strformat(SI_UNIT_NAME, playerName))

			if not PVP.bgScoreBoardData[playerName] then
				PVP.bgScoreBoardData[playerName] = formattedName
				if PVP.bgScoreBoardFirstRunDone and PVP.SV.showJoinedPlayers then
					chat:Printf('%s joined battleground!', PVP.bgScoreBoardData[playerName])
				end
			end

			if playerName ~= self.playerName then

				local KOSOrFriend = self:IsKOSOrFriend(playerName)
				local statusIcon, isResurrect, isDead  = FindInNames(playerName)
				local addStatus
				if statusIcon == "" then addStatus = true end
				if KOSOrFriend then
					if KOSOrFriend=="KOS" then
						formattedName=formattedName..self:GetKOSIcon()..statusIcon.."%"
					elseif KOSOrFriend=="friend" then
						formattedName=formattedName..self:GetFriendIcon(19)..statusIcon.."+"
					elseif KOSOrFriend=="cool" then
						formattedName=formattedName..self:GetCoolIcon(19)..statusIcon.."+"
					elseif KOSOrFriend=="groupleader" then
						formattedName=formattedName..self:GetGroupLeaderIcon()..statusIcon.."%"
					elseif KOSOrFriend=="group" then
						formattedName=formattedName..self:GetGroupIcon()..statusIcon.."%"
					end
				else
					formattedName=formattedName..statusIcon
				end
			else
				formattedName = formattedName..self:Colorize(' - YOU', 'FFFFFF')
			end
			if addStatus then formattedName=formattedName.."**" end
			if bgAlliance==1 then
				if nameLength > maxLengthAD then maxLengthAD = nameLength end
				numberAD=numberAD+1
				table.insert (tableAD, formattedName)
				tableNameToIndexAD[playerName] = numberAD
				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableAD, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableAD, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableAD, playerName)
				else
					table.insert(othersTableAD, playerName)
				end
			elseif bgAlliance==2 then
				if nameLength > maxLengthEP then maxLengthEP = nameLength end
				numberEP = numberEP+1
				table.insert (tableEP, formattedName)
				tableNameToIndexEP[playerName] = numberEP

				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableEP, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableEP, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableEP, playerName)
				else
					table.insert(othersTableEP, playerName)
				end

			elseif bgAlliance==3 then
				if nameLength > maxLengthDC then maxLengthDC = nameLength end
				numberDC=numberDC+1
				table.insert (tableDC, formattedName)
				tableNameToIndexDC[playerName] = numberDC

				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableDC, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableDC, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableDC, playerName)
				else
					table.insert(othersTableDC, playerName)
				end
			end

		end

		for k,v in pairs (PVP.bgScoreBoardData) do
			if not currentBgPlayers[k] then
				if PVP.SV.showJoinedPlayers then
					chat:Printf('%s left battleground!', PVP.bgScoreBoardData[k])
				end
				PVP.bgScoreBoardData[k] = nil
			end
		end
		PVP.bgScoreBoardFirstRunDone = true

		if PVP.bgScoreboard and PVP.bgScoreboard.list then PVP.bgScoreboard.list:RefreshData() end
	end
	-- local countAllianceStart = GetGameTimeMilliseconds()



	if not IsActiveWorldBattleground() then

		for k,v in pairs (self.playerAlliance) do
			local playerName = self.idToName[k]
			local formattedName
			local KOSOrFriend = self:IsKOSOrFriend(playerName)

			local statusIcon, isResurrect, isDead  = FindInNames(playerName)
			local addStatus
			if statusIcon == "" then addStatus = true end
			if isDead or isResurrect then
				formattedName = self:GetFormattedClassNameLink(playerName, self:NameToAllianceColor(playerName, true), false, true)
			else
				formattedName = self:GetFormattedClassNameLink(playerName, self:NameToAllianceColor(playerName, false))
			end

			if KOSOrFriend then
				if KOSOrFriend=="KOS" then
					formattedName=formattedName..self:GetKOSIcon()..statusIcon.."%"
				elseif KOSOrFriend=="friend" then
					formattedName=formattedName..self:GetFriendIcon(19)..statusIcon.."+"
				elseif KOSOrFriend=="cool" then
					formattedName=formattedName..self:GetCoolIcon(19)..statusIcon.."+"
				elseif KOSOrFriend=="groupleader" then
					formattedName=formattedName..self:GetGroupLeaderIcon()..statusIcon.."%"
				elseif KOSOrFriend=="group" then
					formattedName=formattedName..self:GetGroupIcon()..statusIcon.."%"
				end
			else
				formattedName=formattedName..statusIcon
			end
			if addStatus then formattedName=formattedName.."**" end
			local nameLength = string.len(zo_strformat(SI_UNIT_NAME, playerName))

			if v==1 then
				if nameLength > maxLengthAD then maxLengthAD = nameLength end
				numberAD=numberAD+1
				table.insert (tableAD, formattedName)
				tableNameToIndexAD[playerName] = numberAD
				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableAD, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableAD, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableAD, playerName)
				else
					table.insert(othersTableAD, playerName)
				end
			elseif v==2 then
				if nameLength > maxLengthEP then maxLengthEP = nameLength end
				numberEP=numberEP+1
				table.insert (tableEP, formattedName)
				tableNameToIndexEP[playerName] = numberEP

				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableEP, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableEP, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableEP, playerName)
				else
					table.insert(othersTableEP, playerName)
				end

			elseif v==3 then
				if nameLength > maxLengthDC then maxLengthDC = nameLength end
				numberDC=numberDC+1
				table.insert (tableDC, formattedName)
				tableNameToIndexDC[playerName] = numberDC

				if KOSOrFriend=="groupleader" then
					table.insert(groupLeaderTable, playerName)
				elseif KOSOrFriend=="group" then
					table.insert(groupMembersTable, playerName)
				elseif KOSOrFriend=="KOS" then
					table.insert(kosTableDC, playerName)
				elseif KOSOrFriend=="friend" then
					table.insert(friendsTableDC, playerName)
				elseif KOSOrFriend=="cool" then
					table.insert(friendsTableDC, playerName)
				else
					table.insert(othersTableDC, playerName)
				end
			end
			foundNames[playerName] = true
		end

		for k,_ in pairs (self.playerNames) do
			if not foundNames[k] then
				local playerName = k
				local formattedName
				local nameLength = string.len(zo_strformat(SI_UNIT_NAME, playerName))
				local KOSOrFriend = self:IsKOSOrFriend(playerName)

				local statusIcon, isResurrect, isDead  = FindInNames(playerName)
				local addEye
				if statusIcon == "" then statusIcon = self:GetEyeIcon() addEye = true end

				if isDead or isResurrect then
					formattedName = self:GetFormattedClassNameLink(playerName, self:NameToAllianceColor(playerName, true), false, true)
				else
					formattedName = self:GetFormattedClassNameLink(playerName, self:NameToAllianceColor(playerName, false))
				end

				if KOSOrFriend then
					if KOSOrFriend=="KOS" then
						formattedName=formattedName..self:GetKOSIcon()..statusIcon.."%"
					elseif KOSOrFriend=="friend" then
						formattedName=formattedName..self:GetFriendIcon(19)..statusIcon.."+"
					elseif KOSOrFriend=="cool" then
						formattedName=formattedName..self:GetCoolIcon(19)..statusIcon.."+"
					elseif KOSOrFriend=="groupleader" then
						formattedName=formattedName..self:GetGroupLeaderIcon()..statusIcon.."%"
					elseif KOSOrFriend=="group" then
						formattedName=formattedName..self:GetGroupIcon()..statusIcon.."%"
					end
				else
					formattedName = formattedName..statusIcon
				end

				if addEye then
					formattedName = formattedName.."*"
				else
					formattedName = formattedName.."**"
				end


				if self.SV.playersDB[playerName].unitAlliance==1 then
					if nameLength > maxLengthAD then maxLengthAD = nameLength end
					numberAD=numberAD+1
					table.insert (tableAD, formattedName)
					tableNameToIndexAD[playerName] = numberAD

					if KOSOrFriend=="groupleader" then
						table.insert(groupLeaderTable, playerName)
					elseif KOSOrFriend=="group" then
						table.insert(groupMembersTable, playerName)
					elseif KOSOrFriend=="KOS" then
						table.insert(kosTableAD, playerName)
					elseif KOSOrFriend=="friend" then
						table.insert(friendsTableAD, playerName)
					elseif KOSOrFriend=="cool" then
						table.insert(friendsTableAD, playerName)
					else
						table.insert(othersTableAD, playerName)
					end
				elseif self.SV.playersDB[playerName].unitAlliance==2 then
					if nameLength > maxLengthEP then maxLengthEP = nameLength end
					numberEP=numberEP+1
					table.insert (tableEP, formattedName)
					tableNameToIndexEP[playerName] = numberEP
					if KOSOrFriend=="groupleader" then
						table.insert(groupLeaderTable, playerName)
					elseif KOSOrFriend=="group" then
						table.insert(groupMembersTable, playerName)
					elseif KOSOrFriend=="KOS" then
						table.insert(kosTableEP, playerName)
					elseif KOSOrFriend=="friend" then
						table.insert(friendsTableEP, playerName)
					elseif KOSOrFriend=="cool" then
						table.insert(friendsTableEP, playerName)
					else
						table.insert(othersTableEP, playerName)
					end
				elseif self.SV.playersDB[playerName].unitAlliance==3 then
					if nameLength > maxLengthDC then maxLengthDC = nameLength end
					numberDC=numberDC+1
					table.insert (tableDC, formattedName)
					tableNameToIndexDC[playerName] = numberDC
					if KOSOrFriend=="groupleader" then
						table.insert(groupLeaderTable, playerName)
					elseif KOSOrFriend=="group" then
						table.insert(groupMembersTable, playerName)
					elseif KOSOrFriend=="KOS" then
						table.insert(kosTableDC, playerName)
					elseif KOSOrFriend=="friend" then
						table.insert(friendsTableDC, playerName)
					elseif KOSOrFriend=="cool" then
						table.insert(friendsTableDC, playerName)
					else
						table.insert(othersTableDC, playerName)
					end
				end
			end
		end

	else
		PopulateFromBGScoreboard()
	end


	if #groupMembersTable>1 then table.sort(groupMembersTable) end
	if #kosTableAD>1 then table.sort(kosTableAD) end
	if #kosTableDC>1 then table.sort(kosTableDC) end
	if #kosTableEP>1 then table.sort(kosTableEP) end
	if #friendsTableAD>1 then table.sort(friendsTableAD) end
	if #friendsTableDC>1 then table.sort(friendsTableDC) end
	if #friendsTableEP>1 then table.sort(friendsTableEP) end

	if #othersTableAD>1 then table.sort(othersTableAD) end
	if #othersTableDC>1 then table.sort(othersTableDC) end
	if #othersTableEP>1 then table.sort(othersTableEP) end


	local function ArrayConversion(inputArray, indexArray, mainArray)
		local outputArray = {}
		for i = 1, #inputArray do
			local newValue = mainArray[indexArray[inputArray[i]]]
			outputArray[i] = newValue
		end
		return outputArray
	end

	local function SummaryConversion(inputArray, summaryType)
		local summary
		local outputArray = {}
		local numberInCategory = PVP:Colorize(tostring(#inputArray), 'FFFF00')
		if summaryType == 'group' then
			summary = ' --- Group ('..numberInCategory..') ---'
		elseif summaryType == 'friends' then
			summary = ' --- Friends ('..numberInCategory..') ---'
		elseif summaryType == 'kos' then
			summary = ' --- KOS ('..numberInCategory..') ---'
		elseif summaryType == 'others' then
			summary = ' --- Others ('..numberInCategory..') ---'
		end
		table.insert(outputArray, summary)
		for i = 1, #inputArray do
			table.insert(outputArray, inputArray[i])
		end
		return outputArray
	end

	local onlyOthersAD, onlyOthersDC, onlyOthersEP = true, true, true

	if self.allianceOfPlayer == 1 then
		groupLeaderTable = ArrayConversion(groupLeaderTable, tableNameToIndexAD, tableAD)
		groupMembersTable = ArrayConversion(groupMembersTable, tableNameToIndexAD, tableAD)

		if #groupLeaderTable ~= 0 or #groupMembersTable ~= 0 then onlyOthersAD = false end

	elseif self.allianceOfPlayer == 3 then
		groupLeaderTable = ArrayConversion(groupLeaderTable, tableNameToIndexDC, tableDC)
		groupMembersTable = ArrayConversion(groupMembersTable, tableNameToIndexDC, tableDC)

		if #groupLeaderTable ~= 0 or #groupMembersTable ~= 0 then onlyOthersDC = false end

	elseif self.allianceOfPlayer == 2 then
		groupLeaderTable = ArrayConversion(groupLeaderTable, tableNameToIndexEP, tableEP)
		groupMembersTable = ArrayConversion(groupMembersTable, tableNameToIndexEP, tableEP)

		if #groupLeaderTable ~= 0 or #groupMembersTable ~= 0 then onlyOthersEP = false end

	end


	kosTableAD = ArrayConversion(kosTableAD, tableNameToIndexAD, tableAD)
	kosTableDC = ArrayConversion(kosTableDC, tableNameToIndexDC, tableDC)
	kosTableEP = ArrayConversion(kosTableEP, tableNameToIndexEP, tableEP)
	friendsTableAD = ArrayConversion(friendsTableAD, tableNameToIndexAD, tableAD)
	friendsTableDC = ArrayConversion(friendsTableDC, tableNameToIndexDC, tableDC)
	friendsTableEP = ArrayConversion(friendsTableEP, tableNameToIndexEP, tableEP)
	othersTableAD = ArrayConversion(othersTableAD, tableNameToIndexAD, tableAD)
	othersTableDC = ArrayConversion(othersTableDC, tableNameToIndexDC, tableDC)
	othersTableEP = ArrayConversion(othersTableEP, tableNameToIndexEP, tableEP)

	if #groupLeaderTable ~= 0 then groupMembersTable = PVP:TableConcat(groupLeaderTable, groupMembersTable) end

	if #groupMembersTable ~= 0 then groupMembersTable = SummaryConversion(groupMembersTable, 'group') end

	if #kosTableAD ~= 0 then kosTableAD = SummaryConversion(kosTableAD, 'kos') end
	if #kosTableDC ~= 0 then kosTableDC = SummaryConversion(kosTableDC, 'kos') end
	if #kosTableEP ~= 0 then kosTableEP = SummaryConversion(kosTableEP, 'kos') end

	if #friendsTableAD ~= 0 then friendsTableAD = SummaryConversion(friendsTableAD, 'friends') end
	if #friendsTableDC ~= 0 then friendsTableDC = SummaryConversion(friendsTableDC, 'friends') end
	if #friendsTableEP ~= 0 then friendsTableEP = SummaryConversion(friendsTableEP, 'friends') end

	if #kosTableAD ~= 0 or #friendsTableAD ~= 0 then onlyOthersAD = false end
	if #kosTableDC ~= 0 or #friendsTableDC ~= 0 then onlyOthersDC = false end
	if #kosTableEP ~= 0 or #friendsTableEP ~= 0 then onlyOthersEP = false end


	if #othersTableAD ~= 0 and not onlyOthersAD then othersTableAD = SummaryConversion(othersTableAD, 'others') end
	if #othersTableDC ~= 0 and not onlyOthersDC then othersTableDC = SummaryConversion(othersTableDC, 'others') end
	if #othersTableEP ~= 0 and not onlyOthersEP then othersTableEP = SummaryConversion(othersTableEP, 'others') end


	tableAD, tableDC, tableEP = {}, {}, {}


	tableAD = PVP:TableConcat(tableAD, friendsTableAD)
	tableAD = PVP:TableConcat(tableAD, kosTableAD)
	tableAD = PVP:TableConcat(tableAD, othersTableAD)

	tableDC = PVP:TableConcat(tableDC, friendsTableDC)
	tableDC = PVP:TableConcat(tableDC, kosTableDC)
	tableDC = PVP:TableConcat(tableDC, othersTableDC)

	tableEP = PVP:TableConcat(tableEP, friendsTableEP)
	tableEP = PVP:TableConcat(tableEP, kosTableEP)
	tableEP = PVP:TableConcat(tableEP, othersTableEP)

	if self.allianceOfPlayer == 1 then
		tableAD = PVP:TableConcat(groupMembersTable, tableAD)
	elseif self.allianceOfPlayer == 3 then
		tableDC = PVP:TableConcat(groupMembersTable, tableDC)
	elseif self.allianceOfPlayer == 2 then
		tableEP = PVP:TableConcat(groupMembersTable, tableEP)
	end
	-- d('Damn table time: '..tostring(GetGameTimeMilliseconds() - countAllianceStart)..'ms')
	return numberAD, numberDC, numberEP, tableAD, tableDC, tableEP, maxLengthAD, maxLengthDC, maxLengthEP
end

function PVP:PopulateReticleOverNamesBuffer()
	if not self.SV.showNamesFrame or self.SV.unlocked then return end
	local currentTime = GetFrameTimeMilliseconds()
	PVP_Names_Text:Clear()
	if #self.namesToDisplay==0 then return end
	local KOSOrFriend

	-- for i=1, #self.namesToDisplay do
	for k,v in ipairs(self.namesToDisplay) do
		local playerName = v.unitName
		local isDead = v.isDead
		local isAttacker = v.isAttacker
		local isTarget = v.isTarget
		local isResurrect = v.isResurrect
		if isResurrect and (currentTime-isResurrect)>15000 then v.isResurrect = nil isResurrect = nil end
		if playerName then
			local iconsCount = 0
			local formattedName = ""
			KOSOrFriend = self:IsKOSOrFriend(playerName)
			if KOSOrFriend then
				iconsCount = iconsCount + 1
				if KOSOrFriend=="KOS" then
					formattedName=formattedName..self:GetKOSIcon()
				elseif KOSOrFriend=="friend" then
					formattedName=formattedName..self:GetFriendIcon()
				elseif KOSOrFriend=="cool" then
					formattedName=formattedName..self:GetCoolIcon()
				elseif KOSOrFriend=="groupleader" then
					formattedName=formattedName..self:GetGroupLeaderIcon()
				elseif KOSOrFriend=="group" then
					formattedName=formattedName..self:GetGroupIcon()
				end
			end
			local endIcon

			iconsCount = iconsCount + 1
			if isDead then
				endIcon = self:GetDeathIcon(nil, 'AAAAAA')
			elseif isResurrect then
				endIcon = self:GetResurrectIcon()
			else
				if IsActiveWorldBattleground() then
					if isAttacker or isTarget then
						endIcon = self:GetAttackerIcon()
					else
						iconsCount = iconsCount - 1
						endIcon = ""
					end
				else
					if isAttacker and isTarget then
						endIcon = self:GetFightIcon(nil, nil, self.SV.playersDB[playerName].unitAlliance)
					elseif isAttacker then
						endIcon = self:GetAttackerIcon()
					elseif isTarget then
						endIcon = self:GetFightIcon(nil, nil, self.SV.playersDB[playerName].unitAlliance)
					else
						iconsCount = iconsCount - 1
						endIcon = ""
					end
				end
			end

			if iconsCount == 0 then iconsCount = nil end

			local charName = self:GetFormattedClassNameLink(playerName, self:NameToAllianceColor(playerName, isDead or isResurrect), iconsCount, isDead or isResurrect)

			formattedName = charName..formattedName..endIcon
			PVP_Names_Text:AddMessage(formattedName)
		end
	end
end


function PVP:GetKillFeed()
	for k, v in ipairs(CHAT_SYSTEM.containers) do
		for i = 1, #v.windows do
			if v:GetTabName(i) == "PVPKillFeed" then
				return v, v.windows[i], i
			end
		end
	end

	local container = CHAT_SYSTEM.primaryContainer
	local window, key = container.windowPool:AcquireObject()
	window.key = key

	container:AddRawWindow(window, "PVPKillFeed")

	local tabIndex = window.tab.index

	container:SetInteractivity(tabIndex, true)
	container:SetLocked(tabIndex, true)
	container:SetTimestampsEnabled(tabIndex, true)

	for category = 1, GetNumChatCategories() do
		container:SetWindowFilterEnabled(tabIndex, category, false)
	end
	return container, window
end


function PVP:InitializeChat()
	if not self.SV.showKillFeedChat then return end
	if ZO_ChatWindowTabTemplate1 then
		self.ChatContainer, self.ChatWindow = self:GetKillFeed()
	else
		zo_callLater(function() PVP:InitializeChat() end, 200)
	end
end

function PVP:ProcessReticleOver(unitName, unitAccName, unitClass, unitAlliance, unitRace, isDead)
	if not self.SV.playersDB[unitName] then return end
	local currentTime = GetFrameTimeMilliseconds()
	local found, foundName

	self:UpdateNamesToDisplay(unitName, currentTime, true)

	if isDead and self.playerNames[unitName] then self.playerNames[unitName] = nil return end

	if unitAlliance == self.allianceOfPlayer then
		self:DetectSpecOnReticleOver(unitName)
	end

	for k, v in pairs (self.idToName) do
		if v == unitName then found = k break end
	end

	if found then self.totalPlayers[found] = currentTime end
	self.playerNames[unitName] = currentTime
end

function PVP.OnTargetChanged()
	if PVP.SV.unlocked or not PVP:IsInPVPZone() then return end
	local targetIcon
	if IsUnitPlayer('reticleover') then

		local unitName=PVP:GetValidName(GetRawUnitName('reticleover'))
		local unitAccName = ZO_ShouldPreferUserId() and ZO_GetPrimaryPlayerNameFromUnitTag('reticleover') or ZO_GetSecondaryPlayerNameFromUnitTag('reticleover')
		-- local unitAccName=ZO_GetSecondaryPlayerNameFromUnitTag('reticleover')
		local unitClass=GetUnitClassId('reticleover')
		local unitAlliance=GetUnitAlliance('reticleover')
		local unitRace=GetUnitRaceId('reticleover')
		local unitCP=GetUnitChampionPoints('reticleover')

		local unitSpec
		if PVP.SV.playersDB[unitName] then
			unitSpec = PVP.SV.playersDB[unitName].unitSpec
		end

		if unitName then
			PVP.SV.playersDB[unitName]={unitAccName=unitAccName, unitAlliance=unitAlliance, unitClass=unitClass, unitRace=unitRace, unitSpec=unitSpec}
			if IsActiveWorldBattleground() then
				PVP.bgNames = PVP.bgNames or {}
				PVP.bgNames[unitName] = GetUnitBattlegroundAlliance('reticleover')
			end
			if PVP.SV.showNewTargetInfo then
				ZO_TargetUnitFramereticleoverName:SetText(PVP:GetTargetChar(unitName, true))
			end

			if PVP.SV.showTargetIcon then
				local KOSOrFriend = PVP:IsKOSOrFriend(unitName)
				local iconSize = 48

				if KOSOrFriend=="KOS" then
					targetIcon=PVP:GetKOSIcon(iconSize*1.5)
				elseif KOSOrFriend=="friend" then
					targetIcon=PVP:GetFriendIcon(iconSize*1)
				elseif KOSOrFriend=="cool" then
					targetIcon=PVP:GetCoolIcon(iconSize*1)
				elseif KOSOrFriend=="groupleader" then
					targetIcon=PVP:GetGroupLeaderIcon(iconSize*1.3)
				elseif KOSOrFriend=="group" then
					targetIcon=PVP:GetGroupIcon(iconSize*1.3)
				end
			end
		end

		if unitCP>0 then
			PVP.SV.CP[unitAccName] = unitCP
			if PVP.SV.showMaxTargetCP then
				ZO_TargetUnitFramereticleoverChampionIcon:SetDimensions(20,20)
				ZO_TargetUnitFramereticleoverLevel:SetText(unitCP)
			end
		end

		PVP:ProcessReticleOver(unitName, unitAccName, unitClass, unitAlliance, unitRace, IsUnitDead('reticleover'))
	end

	PVP_TargetIconLabel:SetText(targetIcon)

	if PVP.SV.showTargetNameFrame then PVP:UpdateTargetName() end
end


function PVP:UpdateTargetName()
	local unitName = PVP:GetValidName(GetRawUnitName('reticleover'))

	if IsUnitPlayer('reticleover') and unitName then
		PVP_TargetNameLabel:SetText(PVP:GetTargetChar(unitName))
		if self.fadeOutIsPlaying and self.fadeOutIsPlaying:IsPlaying() then self.fadeOutIsPlaying:Stop() end
		PVP_TargetName:SetAlpha(self.SV.targetNameFrameAlpha)
	else
		if self.SV.targetNameFrameFadeoutTime > 0 and (not (self.fadeOutIsPlaying and self.fadeOutIsPlaying:IsPlaying())) and PVP_TargetName:GetAlpha() ~= 0 then
			self.fadeOutIsPlaying = PVP:StartAnimation(PVP_TargetName, 'fadeOut')
		end
	end
end

function PVP:UpdateNewAttacker(attackerName, test)
	local function CountNonDead()
		local count = 0
		if self.namesToDisplay and #self.namesToDisplay>0 then
			for k,v in ipairs(self.namesToDisplay) do
				if not v.isDead then
					count = count + 1
				end
			end
		end
		return count
	end

	local unitName
	local frame = PVP_NewAttacker

	if test then
		unitName = attackerName
	else
		unitName = PVP:GetValidName(attackerName)
	end

	if unitName then
		local formattedCharName

		if test then
			formattedCharName = unitName
		else
			formattedCharName = PVP:GetTargetChar(unitName)
		end

		if not formattedCharName then
			formattedCharName = zo_strformat(SI_UNIT_NAME, attackerName)
		end

		local outputText = string.upper(formattedCharName)

		local targetNumber = CountNonDead() + 1

		if frame.animation and frame.animation:IsPlaying() then frame.animation:Stop() end

		PVP_NewAttackerNumber:SetText(tostring(targetNumber))
		PVP_NewAttackerLabel:SetText(outputText)

		frame.animation = PVP:StartAnimation(frame, 'attackerFrame', self.SV.newAttackerFrameAlpha)
	end
end


local function DeathScreenOnLoadFix()
	if DEATH_FRAGMENT.state == 'shown' then
		local _, _, _, _, _, isAVADeath = GetDeathInfo()
		if isAVADeath then
			SetupDeathButtons()
			PVP_Death_Buttons:SetHandler("OnUpdate", function() SetupDeathButtons() end)
		end
	end
end

function PVP:InitEnabledAddon()
	if PVP.addonEnabled then
		EVENT_MANAGER:UnregisterForUpdate(self.name)
		EVENT_MANAGER:RegisterForUpdate(self.name, 1000, PVP.OnUpdate)
		PVP:Init3D()
		PVP:InitControls()
		PVP.playerName=GetRawUnitName('player')
		PVP.allianceOfPlayer=GetUnitAlliance('player')
		PVP_KOS_Text:SetHandler("OnLinkMouseUp", function(self, _, link, button) return ZO_LinkHandler_OnLinkMouseUp(link, button, self) end)
		PVP_Names_Text:SetHandler("OnLinkMouseUp", function(self, _, link, button) return ZO_LinkHandler_OnLinkMouseUp(link, button, self) end)
		PVP_KillFeed_Text:SetHandler("OnLinkMouseUp", function(self, _, link, button) return ZO_LinkHandler_OnLinkMouseUp(link, button, self) end)
		PVP:FullReset()
		-- if not PVP.SV.unlocked and PVP.SV.showCaptureFrame then PVP:SetupCurrentObjective(GetPlayerLocationName()) end
		if not PVP.deathScreenFixPending then
			PVP.deathScreenFixPending = zo_callLater(function() PVP.deathScreenFixPending = false DeathScreenOnLoadFix() end, 50)
		end
	end
end

function PVP.Activated()
	local function ConvertDatabaseRaceClass()
		if PVP.SV.raceClassConversionDone then return end

		local function ConvertRaceNameToId(raceName)
			if raceName == "" then return false end
			for i = 1, 20 do
				local nameFromId = GetRaceName(0,i)
				if raceName == nameFromId then
					return i
				end
			end
			return false
		end

		local function ConvertClassNameToId(className)
			if className == "" then return false end
			for i = 1, 20 do
				local nameFromId = GetClassName(0,i)
				if className == nameFromId then
					return i
				end
			end
			return false
		end

		for k,v in pairs (PVP.SV.playersDB) do
			if v.unitClass and v.unitClass ~= "" then
				local classId = ConvertClassNameToId(v.unitClass)
				if classId then v.unitClass = classId end
			end
			if v.unitRace and v.unitRace ~= "" then
				local raceId = ConvertRaceNameToId(v.unitRace)
				if raceId then v.unitRace = raceId end
			end
		end
		chat:Print('Race/Class names to Ids conversion done')
		PVP.SV.raceClassConversionDone = true
	end


	local function SyncSpecs()
		if PVP.SV.rememberedSpecs then
			local decisions = {
				["stam"] = true,
				["mag"] = true,
				["hybrid"] = true,
			}
			local counter = 0
			for k,v in pairs (PVP.SV.rememberedSpecs) do
				if v.spec_decision and decisions[v.spec_decision] and PVP.SV.playersDB and PVP.SV.playersDB[k] and not PVP.SV.playersDB[k].unitSpec then
					PVP.SV.playersDB[k].unitSpec = v.spec_decision
					counter = counter + 1
				end
			end
			if counter>0 then chat:Printf('Processed %d  previously recorded player specs!', counter) end
			PVP.SV.rememberedSpecs = nil
		end
	end

	ConvertDatabaseRaceClass()
	SyncSpecs()
	if PVP.SV.delayedStart then
		if not PVP.activatePending then	PVP.activatePending = zo_callLater(function() PVP:OnOff() PVP.activatePending = nil end, 25) end
	else
		PVP:OnOff()
	end
end

CALLBACK_MANAGER:RegisterCallback(PVP.name.."_OnAddOnLoaded", function()

    local ShowPlayerContextMenu = CHAT_SYSTEM.ShowPlayerContextMenu
    function CHAT_SYSTEM:ShowPlayerContextMenu(playerName, rawName)
	ShowPlayerContextMenu(self, playerName, rawName)

		local function IsAccInDB(accName)
			for k,v in ipairs(PVP.SV.KOSList) do
				if v.unitAccName==accName then return v.unitName end
			end

			for k,v in pairs (PVP.SV.playersDB) do
				if v.unitAccName == accName then return k end
			end
			return false
		end

		local function IsNameInDB(rawName)
			if PVP:CheckName(rawName) then
				if PVP.SV.playersDB[rawName] then return rawName else return false end
			end
			local maleName = rawName.."^Mx"
			local femaleName = rawName.."^Fx"
			if PVP.SV.playersDB[maleName] or PVP.SV.playersDB[femaleName] then
				if PVP.SV.playersDB[maleName] and not PVP.SV.playersDB[femaleName] then return maleName end
				if not PVP.SV.playersDB[maleName] and PVP.SV.playersDB[femaleName] then return femaleName end
				if PVP.SV.playersDB[maleName].unitAccName==PVP.SV.playersDB[femaleName].unitAccName then if math.random()>0.5 then return maleName else return femaleName end end
			end
			return false
		end

		if PVP:IsInPVPZone() then

			if IsDecoratedDisplayName(playerName) then
				rawName = IsAccInDB(playerName)
			else
				rawName = IsNameInDB(rawName)
			end

			if rawName then
				if PVP.SV.showKOSFrame then
					local index
					for i=1, #PVP.SV.KOSList do
						if PVP.SV.KOSList[i].unitAccName==PVP.SV.playersDB[rawName].unitAccName then index=i break end
					end
					if index then
						AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_REMOVE_FROM_KOS), function()
						    chat:Printf("Removed from KOS: %s%s!", PVP:GetFormattedName(PVP.SV.KOSList[index].unitName),
								PVP.SV.KOSList[index].unitAccName)
						    table.remove(PVP.SV.KOSList, index) PVP:PopulateKOSBuffer()
						end)
						local cool = PVP:FindInCOOL(rawName)
						if cool then
							PVP.SV.coolList[cool] = nil
							PVP:PopulateKOSBuffer()
							PVP:PopulateReticleOverNamesBuffer()
						end

						AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_TO_COOL), function()
							chat:Printf("Removed from KOS: %s%s!", PVP:GetFormattedName(PVP.SV.KOSList[index].unitName), PVP.SV.KOSList[index].unitAccName)
							table.remove(PVP.SV.KOSList, index)
							chat:Printf("Added to COOL: %s%s!", PVP:GetFormattedName(PVP.SV.playersDB[rawName].unitName), PVP.SV.playersDB[rawName].unitAccName)
							local cool = PVP:FindInCOOL(rawName)
							if not cool then PVP.SV.coolList[rawName] = PVP.SV.playersDB[rawName].unitAccName end
							PVP:PopulateKOSBuffer()
							PVP:PopulateReticleOverNamesBuffer()
						end)
					else
						local unitId=0
						if next(PVP.idToName)~=nil and PVP.SV.playersDB[rawName] then
							for k, v in pairs (PVP.idToName) do
								if PVP.SV.playersDB[v] and PVP.SV.playersDB[v].unitAccName==PVP.SV.playersDB[rawName].unitAccName then
									unitId=k
									break
								end
							end
						end
						AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_TO_KOS), function()
								local cool = PVP:FindInCOOL(rawName)
								if cool then
									chat:printf("Removed from COOL: %s%s!", PVP:GetFormattedName(PVP.SV.playersDB[rawName].unitName), PVP.SV.playersDB[rawName].unitAccName)
									PVP.SV.coolList[cool] = nil
									PVP:PopulateReticleOverNamesBuffer()
								end
								chat:Printf("Added to KOS: %s%s!", PVP:GetFormattedName(rawName), PVP.SV.playersDB[rawName].unitAccName) table.insert(PVP.SV.KOSList, {unitName=rawName, unitAccName=PVP.SV.playersDB[rawName].unitAccName, unitId=unitId})

								PVP:PopulateKOSBuffer()
							end)
						local cool = PVP:FindInCOOL(rawName)

						if not cool then
							AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_ADD_TO_COOL), function()
								chat:Printf("Added to COOL: %s%s!", PVP:GetFormattedName(PVP.SV.playersDB[rawName].unitName), PVP.SV.playersDB[rawName].unitAccName)
								PVP.SV.coolList[rawName] = PVP.SV.playersDB[rawName].unitAccName
								PVP:PopulateKOSBuffer()
								PVP:PopulateReticleOverNamesBuffer()
							end)
						else
							AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_REMOVE_FROM_COOL), function()
								chat:Printf("Removed from COOL: %s%s!", PVP:GetFormattedName(PVP.SV.playersDB[rawName].unitName), PVP.SV.playersDB[rawName].unitAccName)
								local cool = PVP:FindInCOOL(rawName)
								if cool then
									PVP.SV.coolList[cool] = nil
									PVP:PopulateKOSBuffer()
									PVP:PopulateReticleOverNamesBuffer()
								end
							end)
						end
					end
				end
				AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_WHO), function() PVP:Who(rawName) end)
			end
		end
		ShowMenu()
    end
end)

function PVP:InitializeSV()
	self.SV = ZO_SavedVars:NewAccountWide("PVPalerts_Settings", self.version, "Settings", self.defaults)
	if self.SV.guild3d == nil then
	    self.SV.guild3d = true
	end
	if not self.SV.coolList then self.SV.coolList = {} end
	if not self.SV.CP then self.SV.CP = {} end
	if self.SV.enabled then self:InitializeChat() end
end

function PVP.OnLoad(eventCode, addonName)
	if addonName~=PVP.name then return end
	EVENT_MANAGER:UnregisterForEvent(PVP.name, EVENT_ADD_ON_LOADED, PVP.OnLoad)

	PVP:InitializeSV()
	PVP:InitializeAddonMenu()
	PVP:AvAHax()
	PVP_KOS_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_KOS, nil, 0)
	PVP_COUNTER_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_Counter, nil, 0)
	PVP_KILLFEED_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_KillFeed, nil, 0)
	PVP_NAMES_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_Names, nil, 0)
	PVP_CAMP_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_ForwardCamp, nil, 0)
	PVP_CAPTURE_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_Capture, nil, 0)
	PVP_TARGETNAME_SCENE_FRAGMENT = ZO_FadeSceneFragment:New(PVP_TargetName, nil, 0)
	PVP_DEATH_FRAGMENT = ZO_HUDFadeSceneFragment:New(PVP_Death_Buttons)
	PVP_TOOLTIP3D_FRAGMENT = ZO_FadeSceneFragment:New(PVP_WorldTooltip, nil, 0)
	PVP_MEDALS_FRAGMENT = ZO_FadeSceneFragment:New(PVP_Medals, nil, 0)
	PVP_ONSCREEN_FRAGMENT = ZO_FadeSceneFragment:New(PVP_OnScreen, nil, 0)
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_SHOW_AD', 'Toggle AD tooltip')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_SHOW_DC', 'Toggle DC tooltip')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_SHOW_EP', 'Toggle EP tooltip')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_SET_WAYPOINT', 'Set waypoint to mouseover 3d icon')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_ADD_KOS_MOUSEOVER', 'Mouseover Add to KOS')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_ADD_COOL_MOUSEOVER', 'Mouseover Add to COOL')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_WHO_IS', 'Mouseover Whois')
	ZO_CreateStringId('SI_BINDING_NAME_PVP_ALERTS_TOGGLE_BG_SCOREBOARD', 'Toggle Scoreboard')
	ZO_CreateStringId("SI_CHAT_PLAYER_CONTEXT_REMOVE_FROM_KOS", "Remove from KOS")
	ZO_CreateStringId("SI_CHAT_PLAYER_CONTEXT_WHO", "Who is this?")
	ZO_CreateStringId("SI_CHAT_PLAYER_CONTEXT_ADD_TO_KOS", "Add to KOS")
	ZO_CreateStringId("SI_CHAT_PLAYER_CONTEXT_REMOVE_FROM_COOL", "Remove from COOL")
	ZO_CreateStringId("SI_CHAT_PLAYER_CONTEXT_ADD_TO_COOL", "Add to COOL")

	CALLBACK_MANAGER:FireCallbacks(PVP.name.."_OnAddOnLoaded")
	EVENT_MANAGER:RegisterForEvent(PVP.name, EVENT_PLAYER_ACTIVATED, PVP.Activated)
end

EVENT_MANAGER:RegisterForEvent(PVP.name, EVENT_ADD_ON_LOADED, PVP.OnLoad)
