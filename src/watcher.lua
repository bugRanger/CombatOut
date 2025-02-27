combatWatcher = combatWatcher or {
    logger = nil,
    state = {
        latency = 0,
        duration = 0,
        finish_at = 0,
    },
}

local CombatTextUpdateEventTypes = {
	["AURA_START_HARMFUL"] = true, 
	["SPELL_DAMAGE"] = true, --someone got damaged by caster 
	["SPELL_RESISTED"] = true, 
	["SPELL_MISSED"] = true, --someone missed, resisted, absorbed, etc. damage by caster
	["SPELL_HEAL"] = true, --someone got healed by caster
	["SPELL_CAST_SUCCESS"] = true, --some got affected by instant spell like Counterspell
	["SPELL_AURA_APPLIED"] = true, --someone got buffed/debuffed by caster
	["SPELL_AURA_DISPELLED"] = true, --someones buff/debuff got dispelled by caster
	["SPELL_AURA_STOLEN"] = true, --someones buff got stolen by caster
	["SPELL_DISPEL_FAILED"] = true, --caster failed to dispel buff/debuff
	["SPELL_PERIODIC_DISPEL_FAILED"] = true, --caster failed to dispel dot/hot
}

function combatWatcher:debug(msg)
	if not self.logger then return end
	self.logger:debug(msg)
end

function combatWatcher:OnCombatIn()
	self.state.duration = 6
	self.state.finish_at = GetTime() + self.state.duration
	combatWatcher:debug(string.format("combat in - finish_at:%s ms", self.state.finish_at))
end

function combatWatcher:OnCombatRefresh(latency)
	local latency = latency or 0
	self.state.duration = 6 + latency
	self.state.finish_at = GetTime() + self.state.duration
	combatWatcher:debug(string.format("combat refresh - finish_at:%s ms", self.state.finish_at))
end

function combatWatcher:OnCombatTick(delta)
	if (self.state.duration > 0) then
		self.state.duration = self.state.duration - delta
		if (self.state.duration < 0) then
			self.state.duration = 0
		end
	end
end

function combatWatcher:OnCombatOut()
	local latency = math.floor((GetTime() - self.state.finish_at) * 1000)
	self.state.finish_at = 0
	self.state.duration = 0
	self.state.latency = latency
	combatWatcher:debug(string.format("combat out - latency:%s ms", latency))
end

function combatWatcher:reset()
	self.state.latency = 0
	self.state.duration = 0
	self.state.finish_at = 0
	debuffWatcher:reset()
end

function combatWatcher:subscribe(frame)
	frame:RegisterEvent('PLAYER_REGEN_ENABLED')
	frame:RegisterEvent('PLAYER_REGEN_DISABLED')

	frame:RegisterEvent('CHAT_MSG_SPELL_SELF_DAMAGE')
	frame:RegisterEvent('CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF')

	frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_HITS')
	frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_MISSES') -- MISS and BLOCK, PARRY, DODGE
	frame:RegisterEvent('CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS')
	frame:RegisterEvent('CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES') -- MISS and BLOCK, PARRY, DODGE
	frame:RegisterEvent('CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS')
	frame:RegisterEvent('CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES') -- MISS and BLOCK, PARRY, DODGE

	frame:RegisterEvent('COMBAT_TEXT_UPDATE')

	debuffWatcher:subscribe(frame)
end 

function combatWatcher:set_logger(logger)
	self.logger = logger
	debuffWatcher.logger = logger
end

function combatWatcher:handle_event(event, arg1, arg2) 
	combatWatcher:debug(string.format("handle event: %s (%s %s)", tostring(event), tostring(arg1), tostring(arg2)))
	debuffWatcher:handle_event(event, arg1, arg2)

	if event == 'PLAYER_REGEN_DISABLED' then
		combatWatcher:OnCombatIn()
		return true
	end

	if event == 'PLAYER_REGEN_ENABLED' then
		combatWatcher:OnCombatOut()
		return false
	end

	if event == 'CHAT_MSG_SPELL_SELF_DAMAGE' then
		if string.find(arg1, "^Your Taunt") ~= nil or
		   string.find(arg1, "^Your Growl") ~= nil then
			return nil
		end
	end

	if event == 'CHAT_MSG_COMBAT_SELF_HITS' then
		if string.find(arg1, "^You fall and lose %d+ health.$") ~= nil then
			return nil
		end
	end

	if event == 'COMBAT_TEXT_UPDATE' then
		if not CombatTextUpdateEventTypes[arg1] then
			return nil
		end
	end

	combatWatcher:OnCombatRefresh()
	return nil
end

function combatWatcher:handle_tick(tick, delta)
	combatWatcher:debug(string.format("handle tick: %s (%s)", tostring(tick), tostring(delta)))
	if debuffWatcher:handle_tick(tick) then
		combatWatcher:OnCombatRefresh()
		return true
	end
	
	combatWatcher:OnCombatTick(delta)	
	return false
end

return combatWatcher