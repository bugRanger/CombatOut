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

-- Try for get effect name by spell name.
-- Returns effect name or nil.
function GetSpellEffectAoE(spellName)
	return nil
end

function GetSpellText(spellName)
	-- Scan for check spell with AOE effect.
	-- # NOTE need use cache.
	-- # EXAMPLE from https://wowwiki-archive.fandom.com/wiki/UIOBJECT_GameTooltip
	-- Use GameTooltip for find `AOE and effect`.
	-- /run for i=1,GameTooltip:NumLines()do local mytext=_G["GameTooltipTextLeft"..i] local text=mytext:GetText()print(text)end
	return nil
end
