local fixture = fixture or require("test_data")
fixture.silence_mode = true

-- ============================================
-- Test cases
-- ============================================

fixture:set_hooks()


-- handle events
function raise_event_when_combat_events_then_updated()
	local events = {
		PLAYER_REGEN_DISABLED = COMBAT_ACTION_START,
		PLAYER_REGEN_ENABLED = COMBAT_ACTION_FINISH,
		CHAT_MSG_SPELL_SELF_DAMAGE = COMBAT_ACTION_UPDATE,
		CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_SELF_HITS = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_SELF_MISSES = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = COMBAT_ACTION_UPDATE,
		CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = COMBAT_ACTION_UPDATE,
	}

	for raised_event, expected_action in pairs(events) do
		-- Arrange
		fixture:reset()

		-- Act
		local action = fixture:raise_event(raised_event, '', '')

		-- Assert
		assert_eq(action, expected_action, raised_event)
	end
end

function raise_event_when_non_combat_events_then_not_updated()
	local events = {
		[0] = { event = CHAT_MSG_COMBAT_SELF_HITS, args = { arg1 = "You fall and lose 100 health." }},
		[1] = { event = CHAT_MSG_SPELL_SELF_DAMAGE, args = { arg1 = "Your Taunt applyed on Target1." }},
		[2] = { event = CHAT_MSG_SPELL_SELF_DAMAGE, args = { arg1 = "Your Growl applyed on Target1." }},
	}

	for _, params in pairs(events) do
		-- Arrange
		fixture:reset()

		-- Act
		local action = fixture:raise_event(params.event, params.args.arg1, params.args.arg2)

		-- Assert
		assert_eq(action, COMBAT_ACTION_IGNORE, params.event, params.args)
	end
end

-- start aura
function start_aura_when_without_auras_then_not_updated()
	-- Arrange
	fixture:reset()

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function start_aura_when_duplicate_aura_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

function start_aura_when_duplicate_aura_with_blacklist_aura_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	fixture:start_aura(2, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:raise_tick()

	-- Act
	local updated = fixture:start_aura(3, "Death", "magic", "TEXTURE\\DEAD", 20)

	-- Assert
	assert(updated)
end

function start_aura_when_aura_from_blacklist_then_not_updated()
	local blacklist_debuffs = {
		[1] = { name = "Earthbind" },
		[2] = { name = "Earthbind Totem" },
		[3] = { name = "Detect Magic" },
		[4] = { name = "Speed" },
		[5] = { name = "Restoration" },
		[6] = { name = "Berserking" },
		[7] = { name = "Hunter's Mark" },
		[8] = { name = "Fleeing" },
		[9] = { name = "Blood Fury" },
		[10] = { name = "Party Time!" },
		[11] = { name = "Sleepy" },
		[12] = { name = "Shrink" },
		[13] = { name = "Recently Bandaged" },
		[14] = { name = "Forbearance" },
	}

	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	for index, blacklist_debuff in pairs(blacklist_debuffs) do
		local debuff_texture = string.upper(blacklist_debuff.name):gsub(" ", "_")
		-- Act
		fixture:start_aura(1 + index, blacklist_debuff.name, "none", "TEXTURE\\"..debuff_texture, 20)
		local updated = fixture:raise_tick()

		-- Assert
		assert(not updated, blacklist_debuff.name)
	end
end

-- refresh aura
function refresh_aura_when_without_auras_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:refresh_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

function refresh_aura_when_duplicate_aura_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:refresh_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

function refresh_aura_when_with_blacklist_aura_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	fixture:start_aura(2, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:raise_tick()

	-- Act
	fixture:refresh_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

function refresh_aura_when_aura_from_blacklist_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	fixture:start_aura(2, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:raise_tick()

	-- Act
	fixture:refresh_aura(2)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function refresh_aura_when_jitter_time_then_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:refresh_aura(1, 19.9)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

-- finish aura
function finish_aura_when_without_auras_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_duplicate_aura_first_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_duplicate_aura_second_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(2)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_duplicate_aura_with_long_time_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 10)
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(2)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_duplicate_aura_with_short_time_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 10)
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_first_aura_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(1)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_second_aura_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(2)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

function finish_aura_when_last_aura_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:raise_tick()

	-- Act
	fixture:finish_aura(3)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
end

start_aura_when_without_auras_then_not_updated()
start_aura_when_duplicate_aura_then_updated()
start_aura_when_duplicate_aura_with_blacklist_aura_then_updated()
start_aura_when_aura_from_blacklist_then_not_updated()

refresh_aura_when_without_auras_then_updated()
refresh_aura_when_duplicate_aura_then_updated()
refresh_aura_when_with_blacklist_aura_then_updated()
refresh_aura_when_aura_from_blacklist_then_not_updated()
refresh_aura_when_jitter_time_then_updated()

finish_aura_when_without_auras_then_not_updated()
finish_aura_when_duplicate_aura_first_then_not_updated()
finish_aura_when_duplicate_aura_second_then_not_updated()
finish_aura_when_duplicate_aura_with_long_time_then_not_updated()
finish_aura_when_duplicate_aura_with_short_time_then_not_updated()
finish_aura_when_first_aura_then_not_updated()
finish_aura_when_second_aura_then_not_updated()
finish_aura_when_last_aura_then_not_updated()

raise_event_when_combat_events_then_updated()
raise_event_when_non_combat_events_then_not_updated()