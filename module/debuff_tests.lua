-- ============================================
-- This is API WOW 1.12
-- ============================================
local AURA_START_HARMFUL_EVENT = 'AURA_START_HARMFUL'
local AURA_END_HARMFUL_EVENT = 'AURA_END_HARMFUL'

-- ============================================
-- Fixture for tests
-- ============================================
local AURA_INDEX_STEP = 1

local test_data = test_data or require("debuff")

local silenceMode = true
local logger = logger or {}
function logger:debug(msg)
	if silenceMode then return end
	print(msg)
end

local fixture = fixture or {}
fixture.aura = {}
fixture.aura_index = {}
fixture.aura_count = 0
fixture.time = 0
fixture.time_step = 0
fixture.event_handler = nil
fixture.tick_handler = nil

function fixture:reset()
	self.aura = {}
	self.aura_index = {}
	self.aura_uids = {}
	self.aura_count = 0
	self.time = 0

	test_data:reset()
end

function fixture:start_aura(uid, name, kind, texture, duration)
	self.aura_count = self.aura_count + AURA_INDEX_STEP
	local aura = {}
	aura.index = self.aura_count
	aura.name = name
	aura.kind = kind
	aura.texture = texture

	self.aura[uid] = aura
	self.aura_index[aura.index] = aura

	local result = self.event_handler(AURA_START_HARMFUL_EVENT, name)

	aura.start = self.time
	aura.duration = duration

	return result
end

function fixture:refresh_aura(uid, duration)
	if self.aura[uid] then
		self.aura[uid].start = self.time
		self.aura[uid].duration = self.aura[uid].duration or duration
	end
end

function fixture:finish_aura(uid)
	local aura = self.aura[uid]
	if aura then
		self.event_handler(AURA_END_HARMFUL_EVENT, aura.name)
	end

	local prev_aura = nil
	for i=self.aura_count + 1, aura.index, -1 do
		local curr_aura = self.aura_index[i]
		if curr_aura then
			curr_aura.index = curr_aura.index - 1
		end

		self.aura_index[i] = prev_aura
		prev_aura = curr_aura
	end

	if self.aura_count > 0 then
		self.aura_count = self.aura_count - AURA_INDEX_STEP
	end

	self.aura[uid] = nil
end

function fixture:raise_tick(interval)
	self.time = self.time + (interval or self.time_step)
	return self.tick_handler(self.time)
end

function fixture:set_behavior()
	test_data.logger = logger
	self.time_step = test_data.step_tick
	self.event_handler = function(arg1, arg2) return test_data.handle_event(test_data, arg1, arg2) end
	self.tick_handler = function(arg1) return test_data.handle_tick(test_data, arg1) end
end

function fixture:set_hooks()
	local to_idx = function(index)
		return (index + 1) * 2
	end
	local to_index = function(id)
		return id / 2 - 1
	end

	_G['UnitDebuff'] = function(unit, index)
		local aura = fixture.aura_index[index]
		if aura then
			return aura.texture, nil, aura.kind
		end

		-- Texture, Stack, Type
		return nil, nil, nil
	end

	_G['GetPlayerBuff'] = function(index, filter)
		local aura = fixture.aura_index[index + 1]
		if aura then
			return to_idx(aura.index), nil
		end

		-- id, cancelling
		return -1, nil
	end

	_G['GetPlayerBuffTimeLeft'] = function(id)
		local aura = fixture.aura_index[to_index(id)]
		if aura then
			local remain  = aura.start + aura.duration
			if remain > fixture.time then
				return remain - fixture.time
			end
		end

		-- timeleft
		return nil
	end

	_G['GetTime'] = function()
		return fixture.time
	end
end

function __FUNC__() return debug.getinfo(3, 'n').name end

function assert(value)
	if value then
		print('OK - '..__FUNC__())
	else
		print('FAIL - '..__FUNC__())
		error('assertion failed!')
	end
end

function assert_eq(left, right)
	if left == right then
		print('OK - '..__FUNC__())
	else
		print('FAIL - '..__FUNC__())
		error('assertion `left == right` failed! \n  left: '..(left or 'nil')..'\n right: '..(right or 'nil'))
	end
end

-- ============================================
-- Test cases
-- ============================================

fixture:set_behavior()
fixture:set_hooks()

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
	fixture:start_aura(3, "Death", "magic", "TEXTURE\\DEAD", 20)
	local updated = fixture:raise_tick()

	-- Assert
	assert(updated)
end

function start_aura_when_aura_from_blacklist_then_not_updated()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:raise_tick()

	-- Act
	fixture:start_aura(2, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:start_aura(3, "Earthbind Totem", "magic", "TEXTURE\\EARTHBIND_TOTEM", 20)
	fixture:start_aura(4, "Detect Magic", "magic", "TEXTURE\\DETECT_MAGIC", 20)
	fixture:start_aura(5, "Speed", "none", "TEXTURE\\SPEED", 20)
	fixture:start_aura(6, "Restoration", "none", "TEXTURE\\RESTORATION", 20)
	fixture:start_aura(7, "Berserking", "none", "TEXTURE\\BERSERKING", 20)
	fixture:start_aura(8, "Hunter's Mark", "none", "TEXTURE\\HUNTER_MARK", 20)
	fixture:start_aura(9, "Fleeing", "none", "TEXTURE\\FLEEING", 20)

	fixture:start_aura(10, "Blood Fury", "none", "TEXTURE\\BLOOD_FURY", 20)	
	fixture:start_aura(11, "Party Time!", "magic", "TEXTURE\\PARTY_TIME", 20)
	fixture:start_aura(12, "Sleepy", "magic", "TEXTURE\\SLEEPY", 20)
	fixture:start_aura(13, "Shrink", "curse", "TEXTURE\\SHRINK", 20)
	fixture:start_aura(14, "Recently Bandaged", "none", "TEXTURE\\RECENTLY_BANDAGED", 20)
	fixture:start_aura(15, "Forbearance", "none", "TEXTURE\\FORBEARANCE", 20)
	local updated = fixture:raise_tick()

	-- Assert
	assert(not updated)
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
