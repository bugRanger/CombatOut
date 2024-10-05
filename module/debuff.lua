local textures = {}
local debuffs = {}
local debuff_index = 0;


local UPDATE_INTERVAL = 0.04
local frame = CreateFrame("Frame", "CoDebuffWatcher")
frame.tick = GetTime() + UPDATE_INTERVAL

frame:RegisterEvent("COMBAT_TEXT_UPDATE")
frame:SetScript("OnEvent", function()
	if event ~= 'COMBAT_TEXT_UPDATE' then
		return
	end

	if arg1 == 'AURA_END_HARMFUL' then
		debuff_index = debuff_index - 1
		local texture = textures[arg2]
		if texture ~= nil and debuffs[texture] == nil then
			debuffs[texture].timeleft = -1
		end
	end

	if arg1 == 'AURA_START_HARMFUL' then
		debuff_index = debuff_index + 1

		local texture, _, _ = UnitDebuff("player", debuff_index)
		if texture ~= nil and debuffs[texture] == nil then
			textures[arg2] = texture
			debuffs[texture] = debuffs[texture] or {}
			debuffs[texture].timeleft = -1
			debuffs[texture].timestamp = GetTime()
		end

		return
	end

end)
frame:SetScript("OnUpdate", function()
	if (this.tick >= GetTime()) then
		return
	end

	this.tick = GetTime() + UPDATE_INTERVAL

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