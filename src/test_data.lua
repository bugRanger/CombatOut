 -- ============================================
-- This is API WOW 1.12 for tests.
-- ============================================
local COMBAT_TEXT_UPDATE = 'COMBAT_TEXT_UPDATE'
local AURA_START_HARMFUL = 'AURA_START_HARMFUL'
local AURA_END_HARMFUL = 'AURA_END_HARMFUL'

PLAYER_REGEN_ENABLED = 'PLAYER_REGEN_ENABLED'
PLAYER_REGEN_DISABLED = 'PLAYER_REGEN_DISABLED'
CHAT_MSG_SPELL_SELF_DAMAGE = 'CHAT_MSG_SPELL_SELF_DAMAGE'
CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = 'CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF'
CHAT_MSG_COMBAT_SELF_HITS = 'CHAT_MSG_COMBAT_SELF_HITS'
CHAT_MSG_COMBAT_SELF_MISSES = 'CHAT_MSG_COMBAT_SELF_MISSES'
CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = 'CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS'
CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES = 'CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES'
CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = 'CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS'
CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES = 'CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES'

-- ============================================
-- Fixture for tests
-- ============================================
local AURA_INDEX_STEP = 1

debuffWatcher = debuffWatcher or require("module.debuff")

local test_data = test_data or require("watcher")

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
fixture.time_step = 0.04

function fixture:reset()
	self.aura = {}
	self.aura_index = {}
	self.aura_uids = {}
	self.aura_count = 0
	self.time = 0

	test_data:set_logger(logger)
	test_data:reset()
end

function fixture:raise_event(name, args)
	return test_data:handle_event(name, args)
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

	test_data:handle_event(COMBAT_TEXT_UPDATE, AURA_START_HARMFUL, name)

	aura.start = self.time
	aura.duration = duration
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
		test_data:handle_event(COMBAT_TEXT_UPDATE, AURA_END_HARMFUL, aura.name)
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
	local delta = (interval or self.time_step)
	self.time = self.time + delta
	return test_data:handle_tick(self.time, delta)
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

local function __FUNC__() return debug.getinfo(3, 'n').name end
local function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = `' .. dump(v) .. '`,'
		end
		return s .. '} '
	else
		return tostring(o) or 'nil'
	end
end

local function assert_by(func, left, right, case, args)
	local case = tostring(case or '')
	if case ~= '' then
		case = ': case - '..case
		if args ~= nil then
			case = case..' ('..dump(args)..')'
		end
	end

	if left == right then
		print('OK - '..func..case)
	else
		print('FAIL - '..func..case)
		error('assertion `left == right` failed! \n  left: '..(tostring(left) or 'nil')..'\n right: '..(tostring(right) or 'nil'))
	end
end

function assert(value, case, args)
	assert_by(__FUNC__(), value, true, case, args)
end

function assert_eq(left, right, case, args)
	assert_by(__FUNC__(), left, right, case, args)
end

return fixture