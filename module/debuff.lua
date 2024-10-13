-- ============================================
-- The module solves the problem of updating the battle after receiving a debuff that 
-- has already affected you up to that point. 
-- Since the WOW 1.12 API does not do this on its own, you will have to track 
-- the state of your debuffs through other API commands and analyze them for changes.
-- 
-- 2024 (c) Rugly
-- ============================================
local AURA_START_HARMFUL_EVENT = 'AURA_START_HARMFUL'
local AURA_END_HARMFUL_EVENT = 'AURA_END_HARMFUL'

local debuffStorage = debuffStorage or {}
debuffStorage.items = {}
debuffStorage.items_by_index = {}
debuffStorage.counter = 0
debuffStorage.blacklist = {
	-- Mage
	['Detect Magic'] = true, 
	-- Shaman
	['Earthbind'] = true, 
	['Earthbind Totem'] = true,
	-- Battleground
	['Speed'] = true,
	['Restoration'] = true,
	['Berserking'] = true,
}

function debuffStorage:reset()
	self.items = {}
	self.items_by_index = {}
	self.counter = 0
end

function debuffStorage:try_push(name)
	if self.blacklist[name] then
		return false
	end

	self.counter = self.counter + 1
	local texture, _, _ = UnitDebuff('player', self.counter)
	local item = self.items[name] or {}
	item.name = item.name or name
	item.expiration = item.expiration or -1
	item.texture = item.texture or texture
	item.counter = (item.counter  or 0) + 1

	self.items[name] = item
	self.items_by_index[self.counter] = item
	return true
end

function debuffStorage:drop(name)
	local item = self.items[name]
	if item then
		if item.counter > 0 then
			item.counter = item.counter - 1
		end

		if item.counter == 0 then
			if self.counter > 0 then
				self.counter = self.counter - 1
			end

			self.items[name] = nil
		end
	end
end

function debuffStorage:has_expirate(index, id)
	local texture, _, _ = UnitDebuff('player', index)

	local has_expirate = false
	while self.counter > 0 do
		local item = self.items_by_index[index]
		if not item then
			break
		end

		local expiration = GetTime() + GetPlayerBuffTimeLeft(id)

		if item.expiration == -1 then
			item.expiration = expiration
			break
		elseif item.texture ~= texture then
			local counter = self.counter
			self:drop(item.name)

			local prev_item = nil
			for i=counter + 1,index,-1 do
				local curr_item = self.items_by_index[i]
				self.items_by_index[i] = prev_item
				prev_item = curr_item
			end
		else
			if item.expiration < expiration then
				item.expiration = expiration
				has_expirate = true
			end

			break
		end
	end

	return has_expirate
end

function debuffStorage:try_update()
	local has_update = false
	local counter = 0
	for index=0,31 do
		local id, _ = GetPlayerBuff(index,"HARMFUL")
		if id > -1 then
			counter = counter + 1
			has_update = self:has_expirate(index + 1, id) or has_update
		end
	end

	for i=counter,self.counter do
		if self.items_by_index[i + 1] ~= nil then
			self:drop(self.items_by_index[i + 1].name)
			self.items_by_index[i + 1] = nil
		end
	end

	return has_update
end

debuffCombatRefresher = debuffCombatRefresher or {}
debuffCombatRefresher.in_combat = false
debuffCombatRefresher.timestamp = 0
debuffCombatRefresher.step_tick = 0.04
debuffCombatRefresher.next_tick = 0

function debuffCombatRefresher:reset()
	self.in_combat = false
	self.timestamp = 0
	self.step_tick = 0.04
	self.next_tick = 0

	debuffStorage:reset()
end

function debuffCombatRefresher:handle_event(arg1, arg2)
	if arg1 == AURA_START_HARMFUL_EVENT then
		if debuffStorage:try_push(arg2)then
			self:refresh_combat()
		end
	elseif arg1 == AURA_END_HARMFUL_EVENT then
		return
	end
end

function debuffCombatRefresher:handle_tick(tick)
	if self.next_tick > tick then
		return
	end

	self.next_tick = tick + self.step_tick
	if debuffStorage:try_update() then
		self:refresh_combat()
		return true
	end

	return false
end

function debuffCombatRefresher:refresh_combat()
	self.in_combat = true
	self.timestamp = GetTime()
end

return debuffCombatRefresher
