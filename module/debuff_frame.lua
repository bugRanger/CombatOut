local frame = CreateFrame("Frame", "CoDebuffWatcher")
frame:RegisterEvent("COMBAT_TEXT_UPDATE")
frame:SetScript("OnEvent", function()
	if event ~= 'COMBAT_TEXT_UPDATE' then
		return
	end

	debuffWatcher:handle_event(arg1, arg2)
end)
frame:SetScript("OnUpdate", function()
	if debuffWatcher:handle_tick(GetTime()) then
		CombatOut:OnCombatRefresh()
	end
end)