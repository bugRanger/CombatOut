-- ============================================
-- The module solves the problem of updating the battle after receiving a debuff that 
-- has already affected you up to that point. 
-- Since the WOW 1.12 API does not do this on its own, you will have to track 
-- the state of your debuffs through other API commands and analyze them for changes.
-- 
-- 2024 (c) Rugly
-- ============================================
local debuffStorage = debuffStorage or {}
debuffStorage.items = {}
debuffStorage.items_by_index = {}
debuffStorage.counter = 0
debuffStorage.blacklist = {
	-- First aid effects
	["Recently Bandaged"] = true,
	-- Deviate Fish effects
	["Party Time!"] = true,
	["Sleepy"] = true,
	["Shrink"] = true,
	-- Racial
	["Fleeing"] = true, -- Debuff from Exit Strategy (Racial Goblin).
	["Blood Fury"] = true, -- Debuff from Blood Fury (Racial Orc).	
	-- Priest
	["Weakened Soul"] = true,
	-- Hunter
	["Hunter's Mark"] = true,
	-- Mage
	['Detect Magic'] = true, 
	-- Shaman
	['Earthbind'] = true, 
	['Earthbind Totem'] = true,
	-- Paladin
	['Forbearance'] = true, 
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

function debuffStorage:push(name)
	self.counter = self.counter + 1
	local item = self.items[name] or {}
	item.name = item.name or name
	item.expiration = item.expiration or -1
	item.counter = (item.counter or 0) + 1
	
	if self.blacklist[name] then
		item.has_tracked = false
	else
		item.has_tracked = true
	end

	self.items[name] = item
	self.items_by_index[self.counter] = item

	debuffWatcher:debug('add aura: '..name)
end

function debuffStorage:drop(name)
	debuffWatcher:debug('drop aura: '..name)
	local item = self.items[name]
	if item then
		if self.counter > 0 then
			self.counter = self.counter - 1
		end

		if item.counter > 0 then
			item.counter = item.counter - 1
			if item.counter == 0 then
				self.items[name] = nil
			end
		end
	end
end

function debuffStorage:zip(remain, total)
	local curr_index = 1
	local next_index = 2
	local swap_counter = remain

	while next_index < total + 2 do
		if self.items_by_index[curr_index] then
			curr_index = curr_index + 1
			next_index = next_index + 1
		else
			while next_index < total + 1 do
				if self.items_by_index[next_index] then
					break
				else
					next_index = next_index + 1
				end
			end
	
			if swap_counter > 0 then
				self.items_by_index[curr_index] = self.items_by_index[next_index]
				self.items_by_index[next_index] = nil
				swap_counter = swap_counter - 1
			else
				self.items_by_index[next_index] = nil
			end

			curr_index = curr_index + 1
			next_index = next_index + 1
		end
	end
	
	for index = remain, total + 1 do
		if self.items_by_index[index + 1] then
			self:drop(self.items_by_index[index + 1].name)
			self.items_by_index[index + 1] = nil
		end
	end

	self.counter = remain
end

function debuffStorage:regenerate(index)
	local debuff = nil
	local name = UnitDebuffName("player", index)
	local item = self.items_by_index[index]
	if item then 
		if item.name == name then
			debuff = item
		end
	end
	
	for idx = index + 1, 32 do
		local item = self.items_by_index[idx]
		if item then
			if item.name == name then
				self.items_by_index[idx] = nil
				debuff = item
				break
			end
		end
	end
	
	if debuff then
		local item = self.items_by_index[index + 1]
		if item then
			self:drop(item.name)
			debuffWatcher:debug('regenerate aura: '..index..' - '..debuff.name)
		end
		self.items_by_index[index + 1] = debuff
	end

	return debuff
end

function debuffStorage:try_update()
	local has_update = false
	local remain_count = 0
	local total_count = self.counter

	for index = 0, 31 do
		local id, _ = GetPlayerBuff(index, "HARMFUL")
		if id == -1 then
			break
		end

		local expiration = GetTime() + GetPlayerBuffTimeLeft(id)
		debuffWatcher:debug('expiration aura: '..index..' - '..expiration)

		local debuff = self:regenerate(index + 1)

		if debuff then
			debuffWatcher:debug('find debuff: '..index..' - '..debuff.name)
			if debuff.expiration == -1 then
				debuff.expiration = expiration
			else
				if debuff.expiration < expiration then
					debuff.expiration = expiration
					if debuff.has_tracked then
						has_update = true
						debuffWatcher:debug('update aura: '..index..' - '..debuff.name)
					end
				end
			end
		end

		remain_count = remain_count + 1
	end

	if remain_count < total_count then
		self:zip(remain_count, total_count)
		debuffWatcher:debug('zip: '..remain_count..' <- '..total_count)
	end

	return has_update
end

debuffWatcher = debuffWatcher or {}
debuffWatcher.step_tick = 0.04
debuffWatcher.next_tick = 0
debuffWatcher.logger = nil

function debuffWatcher:reset()
	self.step_tick = 0.04
	self.next_tick = 0

	debuffStorage:reset()
end

function debuffWatcher:subscribe(frame)
	frame:RegisterEvent('COMBAT_TEXT_UPDATE')
end 

function debuffWatcher:handle_event(event, arg1, arg2)
	if event ~= 'COMBAT_TEXT_UPDATE' then
		return
	end

	if arg1 == 'AURA_START_HARMFUL' then
		debuffStorage:push(arg2)
	end
end

function debuffWatcher:handle_tick(tick)
	if self.next_tick > tick then
		return false
	end

	self.next_tick = tick + self.step_tick
	return debuffStorage:try_update()
end

function debuffWatcher:debug(msg)
	if not self.logger then return end
	self.logger:debug(msg)
end

return debuffWatcher
