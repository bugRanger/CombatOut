-- ============================================
-- This is API WOW 1.12
-- ============================================
local AURA_START_HARMFUL_EVENT = 'AURA_START_HARMFUL'
local AURA_END_HARMFUL_EVENT = 'AURA_END_HARMFUL'

function UnitDebuff(unit, index)
  -- Texture, Stack, Type
  return nil, nil, nil
end

function GetPlayerBuff(index, filter)
  -- id, cancelling
  return nil, nil
end

function GetPlayerBuffTimeLeft(id)
  -- timeleft
  return nil
end

function GetTime()
  -- time in inner ticks
  return nil
end

-- ============================================
-- Fixture for tests
-- ============================================
local AURA_INDEX_STEP = 1

local fixture = fixture or {}
fixture.aura = {}
fixture.aura_index = {}
fixture.aura_count = 0
fixture.time = 0
fixture.time_step = 0
fixture.raise_event = nil
fixture.raise_tick = nil

function fixture:reset()
	self.aura = {}
	self.aura_uids = {}
	self.aura_count = 0
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

	self.raise_event(AURA_START_HARMFUL_EVENT, name)

	aura.duration = duration
	aura.start = self.time

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
		self.raise_event(AURA_END_HARMFUL_EVENT, aura.name)
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

function fixture:advance_time(interval)
	self.time = self.time + (interval or self.time_step)
	self.raise_tick(self.time)
end

function fixture:set_data(test_data)
	self.time_step = test_data.step_tick
	self.raise_event = function(arg1, arg2) test_data.handle_event(test_data, arg1, arg2) end
	self.raise_tick = function(arg1) test_data.handle_tick(test_data, arg1) end
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

function fixture.assert(value)
	if value then
		print('OK - '..__FUNC__())
	else
		print('FAIL - '..__FUNC__())
		error('assertion failed!')
	end
end

function fixture.assert_eq(left, right)
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
local test_data = require("debuff")

fixture:set_hooks()
fixture:set_data(test_data)

-- start aura
function start_aura_when_out_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function start_aura_when_out_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function start_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	test_data.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function start_aura_when_in_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	test_data.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function start_aura_when_duplicate_aura_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function start_aura_when_duplicate_aura_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, fixture.time)
end

function start_aura_when_non_combat_aura_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	-- Act
	fixture:start_aura(1, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:start_aura(2, "Earthbind Totem", "magic", "TEXTURE\\EARTHBIND_TOTEM", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function start_aura_when_non_combat_aura_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	-- Act
	fixture:start_aura(1, "Earthbind", "magic", "TEXTURE\\EARTHBIND", 20)
	fixture:start_aura(2, "Earthbind Totem", "magic", "TEXTURE\\EARTHBIND_TOTEM", 20)
	fixture:start_aura(3, "Detect Magic", "magic", "TEXTURE\\DETECT_MAGIC", 20)
	fixture:start_aura(4, "Speed", "none", "TEXTURE\\SPEED", 20)
	fixture:start_aura(5, "Restoration", "none", "TEXTURE\\RESTORATION", 20)
	fixture:start_aura(6, "Berserking", "none", "TEXTURE\\BERSERKING", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, 0)
end

-- refresh aura
function refresh_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function refresh_aura_when_in_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, fixture.time)
end

function refresh_aura_when_out_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function refresh_aura_when_out_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, fixture.time)
end

function refresh_aura_when_duplicate_aura_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function refresh_aura_when_duplicate_aura_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, fixture.time)
end

function refresh_aura_when_jitter_time_then_changed_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(1, 19.9)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, fixture.time)
end

-- finish aura
function finish_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function finish_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function finish_aura_when_out_combat_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function finish_aura_when_out_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function finish_aura_when_duplicate_aura_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function finish_aura_when_duplicate_aura_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()
	fixture:start_aura(2, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	local expected = fixture.time
	test_data.in_combat = false

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

-- remove first/mid/last aura
function remove_first_aura_when_out_combat_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function remove_first_aura_when_out_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function remove_first_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function remove_first_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end


function remove_mid_aura_when_out_combat_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function remove_mid_aura_when_out_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function remove_mid_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function remove_mid_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end


function remove_last_aura_when_out_combat_then_out_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert(not test_data.in_combat)
end

function remove_last_aura_when_out_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	test_data.in_combat = false

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

function remove_last_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()
	test_data:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert(test_data.in_combat)
end

function remove_last_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()
	test_data:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(test_data.timestamp, expected)
end

start_aura_when_out_combat_then_in_combat()
start_aura_when_out_combat_then_changed_timestamp()
start_aura_when_in_combat_then_in_combat()
start_aura_when_in_combat_then_changed_timestamp()
start_aura_when_non_combat_aura_then_out_combat()
start_aura_when_non_combat_aura_then_unchanged_timestamp()

refresh_aura_when_out_combat_then_in_combat()
refresh_aura_when_out_combat_then_changed_timestamp()
refresh_aura_when_in_combat_then_in_combat()
refresh_aura_when_in_combat_then_changed_timestamp()
refresh_aura_when_jitter_time_then_changed_timestamp()

finish_aura_when_out_combat_then_out_combat()
finish_aura_when_out_combat_then_unchanged_timestamp()
finish_aura_when_in_combat_then_in_combat()
finish_aura_when_in_combat_then_unchanged_timestamp()

remove_first_aura_when_out_combat_then_out_combat()
remove_first_aura_when_out_combat_then_unchanged_timestamp()
remove_mid_aura_when_out_combat_then_out_combat()
remove_mid_aura_when_out_combat_then_unchanged_timestamp()
remove_last_aura_when_out_combat_then_out_combat()
remove_last_aura_when_out_combat_then_unchanged_timestamp()

remove_first_aura_when_in_combat_then_in_combat()
remove_first_aura_when_in_combat_then_unchanged_timestamp()
remove_mid_aura_when_in_combat_then_in_combat()
remove_mid_aura_when_in_combat_then_unchanged_timestamp()
remove_last_aura_when_in_combat_then_in_combat()
remove_last_aura_when_in_combat_then_unchanged_timestamp()

start_aura_when_duplicate_aura_then_in_combat()
start_aura_when_duplicate_aura_then_changed_timestamp()

refresh_aura_when_duplicate_aura_then_in_combat()
refresh_aura_when_duplicate_aura_then_changed_timestamp()

finish_aura_when_duplicate_aura_then_out_combat()
finish_aura_when_duplicate_aura_then_unchanged_timestamp()
