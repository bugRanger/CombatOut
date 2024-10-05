local debuffs = {}

local UPDATE_INTERVAL = 0.04
local frame = CreateFrame("Frame", "CoDebuffWatcher")
frame.time = GetTime() + UPDATE_INTERVAL

frame:RegisterEvent("COMBAT_TEXT_UPDATE")
frame:SetScript("OnEvent", function()
	if event ~= 'COMBAT_TEXT_UPDATE' then
		return
	end

	if arg1 ~= 'AURA_START_HARMFUL' then
		return
	end

	for i=0,16 do
		local texture, _, _ = UnitDebuff("player", i)
		if texture ~= nil and debuffs[texture] == nil then
			debuffs[texture] = debuffs[texture] or {}
			debuffs[texture].timeleft = -1
			debuffs[texture].timestamp = GetTime()
		end
	end
end)
frame:SetScript("OnUpdate", function()
	if (this.time >= GetTime()) then
		return
	end

	this.time = GetTime() + UPDATE_INTERVAL

	for i=0,31 do
		local id, _ = GetPlayerBuff(i,"HARMFUL")
		if id ~= 0 then
			local texture  = GetPlayerBuffTexture(i)
			local timeleft = GetPlayerBuffTimeLeft(i)
			local timestamp = GetTime()

			if debuffs[texture] ~= nil then
				if debuffs[texture].timeleft < timeleft then
					CombatOut:OnCombatRefresh()
					CombatOut:Debug(string.format("Debuff index: %s", i))
				end

				debuffs[texture].timeleft = timeleft
				debuffs[texture].timestamp = timestamp
			end
		end
	end
end)