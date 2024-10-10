-- ============================================
-- This is API WOW 1.12
-- ============================================
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
-- impl Addon
-- ============================================
local AURA_START_HARMFUL_EVENT = 'AURA_START_HARMFUL'
local AURA_END_HARMFUL_EVENT = 'AURA_END_HARMFUL'

local combatRefresher = combatRefresher or {}
combatRefresher.in_combat = false
combatRefresher.timestamp = 0
combatRefresher.step_tick = 0.4
combatRefresher.next_tick = 0

function combatRefresher:HandleEvent(arg1, arg2)
	if arg1 == AURA_START_HARMFUL_EVENT then
		self.in_combat = true
		self.timestamp = GetTime()
	elseif arg1 == AURA_END_HARMFUL_EVENT then
		return
	end
end

function combatRefresher:HandleTick(tick)
	if self.next_tick > tick then
		return
	end

	self.next_tick = tick + self.step_tick
end

-- ============================================
-- Fixture for tests
-- ============================================
local AURA_INDEX_STEP = 1

local fixture = fixture or {}
fixture.time = 0
fixture.next_tick = 0
fixture.aura = {}
fixture.aura_uids = {}
fixture.aura_count = 0
fixture.raise_event = nil
fixture.raise_tick = nil

function fixture:set(test_data)
	self.raise_event = function(...) test_data.HandleEvent(test_data, ...) end
	self.raise_tick = function(...) test_data.HandleTick(test_data, ...) end
	self.next_tick = test_data.next_tick
end

function fixture:start_aura(uid, name, kind, texture, duration)
	self.raise_event(AURA_START_HARMFUL_EVENT, name)

	self.aura_count = self.aura_count + AURA_INDEX_STEP
	local aura = self.aura[uid]  or {}
	aura.index = self.aura_count
	aura.name = name
	aura.kind = kind
	aura.texture = texture
	aura.duration = duration
	aura.start = self.time
	self.aura[uid] = aura

	self.aura_uids[aura.index] = uid

end

function fixture:refresh_aura(uid, duration)
	if self.aura[uid] then
		self.aura[uid].start = self.time
		self.aura[uid].duration = duration
	end
end

function fixture:finish_aura(uid)
	local aura = self.aura[uid]
	if aura then
		self.raise_event(AURA_END_HARMFUL_EVENT, aura.name)
	end

	if self.aura_count > 0 then
		self.aura_count = self.aura_count - AURA_INDEX_STEP
	end

	self.aura[uid] = nil

	local prev_aura_uid = nil
	for i=self.aura_count, aura.index, -1 do
		local aura_uid = self.aura_uids[i]
		self.aura_uids[i] = prev_aura_uid
		prev_aura_uid = aura_uid
	end
end

function fixture:advance_time(interval)
	interval = interval or self.next_tick
	self.time = self.time + interval
	self.raise_tick(self.time)
end

function fixture:set_hooks()
	_G['UnitDebuff'] = function(unit, index)
		if fixture.aura[index] then
			return fixture.aura[index].texture, nil, self.aura[index].kind
		end

		-- Texture, Stack, Type
		return nil, nil, nil
	end

	_G['GetPlayerBuff'] = function(index, filter)
		if fixture.aura[index] then
			return fixture.aura[index].index * 2, nil
		end

		-- id, cancelling
		return nil, nil
	end

	_G['GetPlayerBuffTimeLeft'] = function(id)
		if fixture.aura[index /2] then
			local remain  = fixture.aura[index].start + fixture.aura[index].duration
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
fixture.set_hooks()

function start_aura_when_out_combat_then_in_combat()
	-- Arrange
	fixture:set(combatRefresher)

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function start_aura_when_out_combat_then_changed_timestamp()
	-- Arrange
	local expected = fixture.time
	fixture:set(combatRefresher)

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function start_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:set(combatRefresher)
	combatRefresher.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function start_aura_when_in_combat_then_changed_timestamp()
	-- Arrange
	local expected = fixture.time

	fixture:set(combatRefresher)
	combatRefresher.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function refresh_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function refresh_aura_when_in_combat_then_changed_timestamp()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, fixture.time)
end

function refresh_aura_when_out_combat_then_in_combat()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function refresh_aura_when_out_combat_then_changed_timestamp()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, fixture.time)
end

function finish_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function finish_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	local expected = fixture.time

	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function finish_aura_when_out_combat_then_out_combat()
	-- Arrange
	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(not combatRefresher.in_combat)
end

function finish_aura_when_out_combat_then_unchanged_timestamp()
	-- Arrange
	local expected = fixture.time

	fixture:set(combatRefresher)
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

start_aura_when_out_combat_then_in_combat()
start_aura_when_out_combat_then_changed_timestamp()
start_aura_when_in_combat_then_in_combat()
start_aura_when_in_combat_then_changed_timestamp()

refresh_aura_when_in_combat_then_in_combat()
refresh_aura_when_in_combat_then_changed_timestamp()
refresh_aura_when_out_combat_then_in_combat()
refresh_aura_when_out_combat_then_changed_timestamp()

finish_aura_when_in_combat_then_in_combat()
finish_aura_when_in_combat_then_unchanged_timestamp()
finish_aura_when_out_combat_then_out_combat()
finish_aura_when_out_combat_then_unchanged_timestamp()