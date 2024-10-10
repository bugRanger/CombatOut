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

local debuffStorage = debuffStorage or {}
debuffStorage.items = {}
debuffStorage.items_by_index = {}
debuffStorage.counter = 0

function debuffStorage:push(name)
	self.counter = self.counter + 1
	local texture, _, _ = UnitDebuff('player', self.counter)

	local item = self.items[name] or {}
	item.id = nil
	item.expiration = nil
	item.texture = texture
	item.counter = (item.counter  or 0) + 1

	self.items[name] = item
	self.items_by_index[self.counter] = item
end

function debuffStorage:drop(name)
	if self.counter > 0 then
		self.counter = self.counter - 1
	end

	local item = self.items[name]
	if item then
		if item.counter > 0 then
			item.counter = item.counter - 1
		end

		if item.counter == 0 then
			self.items[name] = nil
		end
	end
end

-- Возможно ID не меняется после перестроения, надо проверить.
function debuffStorage:has_expirate(index, id)
	local item = self.items_by_index[index]
	if not item then
		return false
	end

	local has_expirate = false
	if not item.id then
		item.id = id
		item.expiration = GetTime() + GetPlayerBuffTimeLeft(id)
	elseif item.id == id then
		local expiration = GetTime() + GetPlayerBuffTimeLeft(id)
		if item.expiration < expiration then
			item.expiration = expiration
			has_expirate = true
		end
	else
		-- Remove its debuff
		return false
	end

	-- local texture, _, kind = UnitDebuff("player", index)
	-- local prev_expiration = -1 -- find and expiration from storage
	-- local curr_expiration = GetTime() + GetPlayerBuffTimeLeft(id)
	-- if prev_expiration == -1 then
		-- prev_expiration = curr_expiration
	-- else
	-- end
	return has_expirate
end

function debuffStorage:try_update()
	local has_update = false

	for index=0,31 do
		local id, _ = GetPlayerBuff(index,"HARMFUL")
		if id > -1 then
			has_update = has_update or self:has_expirate(index + 1, id)
		end
	end

	return has_update
end

local combatRefresher = combatRefresher or {}
combatRefresher.in_combat = false
combatRefresher.timestamp = 0
combatRefresher.step_tick = 0.4
combatRefresher.next_tick = 0

function combatRefresher:handle_event(arg1, arg2)
	if arg1 == AURA_START_HARMFUL_EVENT then
		self:refresh_combat()
		debuffStorage:push(arg2)
	elseif arg1 == AURA_END_HARMFUL_EVENT then
		debuffStorage:drop(arg2)
	end
end

function combatRefresher:handle_tick(tick)
	if self.next_tick > tick then
		return
	end

	self.next_tick = tick + self.step_tick

	if debuffStorage:try_update() then
		self:refresh_combat()
	end
end

function combatRefresher:refresh_combat()
	self.in_combat = true
	self.timestamp = GetTime()
end

-- ============================================
-- Fixture for tests
-- ============================================
local AURA_INDEX_STEP = 1

local fixture = fixture or {}
fixture.aura = {}
fixture.aura_uids = {}
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
		self.aura[uid].duration = self.aura[uid].duration or duration
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
	self.time = self.time + (interval or self.time_step)
	self.raise_tick(self.time)
end

function fixture:set_callbacks(test_data)
	self.time_step = test_data.step_tick
	self.raise_event = function(...) test_data.handle_event(test_data, ...) end
	self.raise_tick = function(...) test_data.handle_tick(test_data, ...) end
end

function fixture:set_hooks()
	local to_id = function(index)
		return (index + 1) * 2
	end
	local to_index = function(id)
		return id / 2 - 1
	end

	_G['UnitDebuff'] = function(unit, index)
		local aura = fixture.aura[index] 
		if aura then
			return aura.texture, nil, aura.kind
		end

		-- Texture, Stack, Type
		return nil, nil, nil
	end

	_G['GetPlayerBuff'] = function(index, filter)
		local aura = fixture.aura[index + 1] 
		if aura then
			return to_id(aura.index), nil
		end

		-- id, cancelling
		return -1, nil
	end

	_G['GetPlayerBuffTimeLeft'] = function(id)
		local aura = fixture.aura[to_index(id)]
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
fixture:set_hooks()
fixture:set_callbacks(combatRefresher)

-- start aura
function start_aura_when_out_combat_then_in_combat()
	-- Arrange
	fixture:reset()

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function start_aura_when_out_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()

	local expected = fixture.time

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function start_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

	combatRefresher.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function start_aura_when_in_combat_then_changed_timestamp()
	-- Arrange
	fixture:reset()

	local expected = fixture.time
	combatRefresher.in_combat = true

	-- Act
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

-- refresh aura
function refresh_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

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
	fixture:reset()

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
	fixture:reset()

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
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:refresh_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, fixture.time)
end

-- finish aura
function finish_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

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
	fixture:reset()

	local expected = fixture.time
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
	fixture:reset()

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
	fixture:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:advance_time()

	combatRefresher.in_combat = false

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

-- remove aura
function remove_first_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function remove_first_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(1)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function remove_mid_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function remove_mid_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(2)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

function remove_last_aura_when_in_combat_then_in_combat()
	-- Arrange
	fixture:reset()

	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert(combatRefresher.in_combat)
end

function remove_last_aura_when_in_combat_then_unchanged_timestamp()
	-- Arrange
	fixture:reset()

	local expected = fixture.time
	fixture:start_aura(1, "Death", "magic", "TEXTURE\\DEAD", 20)
	fixture:start_aura(2, "Toxic", "poison", "TEXTURE\\Toxic", 25)
	fixture:start_aura(3, "Poison", "poison", "TEXTURE\\Poison", 30)
	fixture:advance_time()

	-- Act
	fixture:finish_aura(3)
	fixture:advance_time()

	-- Assert
	fixture.assert_eq(combatRefresher.timestamp, expected)
end

start_aura_when_out_combat_then_in_combat()
start_aura_when_out_combat_then_changed_timestamp()
start_aura_when_in_combat_then_in_combat()
start_aura_when_in_combat_then_changed_timestamp()

refresh_aura_when_out_combat_then_in_combat()
refresh_aura_when_out_combat_then_changed_timestamp()
refresh_aura_when_in_combat_then_in_combat()
refresh_aura_when_in_combat_then_changed_timestamp()

finish_aura_when_out_combat_then_out_combat()
finish_aura_when_out_combat_then_unchanged_timestamp()
finish_aura_when_in_combat_then_in_combat()
finish_aura_when_in_combat_then_unchanged_timestamp()

remove_first_aura_when_in_combat_then_in_combat()
remove_first_aura_when_in_combat_then_unchanged_timestamp()
remove_mid_aura_when_in_combat_then_in_combat()
remove_mid_aura_when_in_combat_then_unchanged_timestamp()
remove_last_aura_when_in_combat_then_in_combat()
remove_last_aura_when_in_combat_then_unchanged_timestamp()