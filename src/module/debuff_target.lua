debuffTargetWatcher = debuffTargetWatcher or {}
debuffTargetWatcher.expiration_time = 0.5
debuffTargetWatcher.pending_effects = {}
debuffTargetWatcher.step_tick = 0.04
debuffTargetWatcher.next_tick = 0
debuffTargetWatcher.logger = nil

function debuffTargetWatcher:reset()
	self.expiration_time = 0.5
	self.pending_effects = {}
	self.step_tick = 0.04
	self.next_tick = 0
end

function debuffTargetWatcher:try_update()
	local has_update = false
	for index = 1, 32 do
		local effect = UnitDebuffName("target", index)
		if self.pending_effects[effect] then
			has_update = true
		end
	end

	return has_update
end

function debuffTargetWatcher:queue(effectName, currentTime)
	self.pending_effects[effectName] = currentTime + self.expiration_time
end

function debuffTargetWatcher:clear(tick)
	for effectName in pairs (self.pending_effects) do
		local expiration = self.pending_effects[effectName]
		if expiration < tick then
			self.pending_effects[effectName] = nil
		end
	end
end

function debuffTargetWatcher:subscribe(frame)
	-- frameRegisterEvent("SPELLCAST_START")
	frameRegisterEvent("SPELLCAST_STOP")
	-- frameRegisterEvent("SPELLCAST_FAILED")
	-- frameRegisterEvent("SPELLCAST_INTERRUPTED")
	-- frameRegisterEvent("SPELLCAST_DELAYED")
	-- frameRegisterEvent("SPELLCAST_CHANNEL_START")
	-- frameRegisterEvent("SPELLCAST_CHANNEL_STOP")
	-- frameRegisterEvent("SPELLCAST_CHANNEL_UPDATE")
end

function debuffTargetWatcher:handle_event(event, arg1, arg2)
	-- impl logic for handle event.
end

function debuffTargetWatcher:handle_tick(tick)
	if self.next_tick > tick then
		return false
	end

	self:clear(tick)
	self.next_tick = tick + self.step_tick
	return self:try_update()
end

function debuffTargetWatcher:debug(msg)
	if not self.logger then return end
	self.logger:debug(msg)
end

hooksecurefunc("CastSpellByName", function(spellName)
	local effectName = GetSpellEffectAoE(spellName)
	if effectName then
		-- #TODO get current debuff time.
		debuffTargetWatcher.queue(effectName, GetTime())
	end
end)

return debuffTargetWatcher