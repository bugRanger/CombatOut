function UnitDebuffName(unit, index)
	if not UnitDebuff(unit, index) then
		return nil
	end

    local text = getglobal(DebuffTooltip:GetName().."TextLeft1")
	DebuffTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	DebuffTooltip:SetUnitDebuff(unit, index)
	name = text:GetText()
	DebuffTooltip:Hide()
	return name
end

