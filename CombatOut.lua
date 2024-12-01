local Name = "CombatOut"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {}
Parameters.debugMode = false
Parameters.event_types = {
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

local CombatState = {}
CombatState.latency = 0
CombatState.duration = 0
CombatState.finish_at = 0

local defaults = {
	x = 0,
	y = -161,
	w = 200,
	h = 13,
	b = 0,
	a = 1,
	s = 1,
	colorR = 1,
	colorG = 0,
	colorB = 0,
}

local settings = {
	x = "Bar X position",
	y = "Bar Y position",
	w = "Bar width",
	h = "Bar height",
	b = "Border height",
	a = "Alpha between 0 and 1",
	s = "Bar scale",
	colorR = "Bar color R",
	colorG = "Bar color G",
	colorB = "Bar color B",
}

local debug = function (msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
end

local print = function (msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local split = function (s,t)
	local l = {n=0}
	local f = function (s)
		l.n = l.n + 1
		l[l.n] = s
	end
	local p = "%s*(.-)%s*"..t.."%s*"
	s = string.gsub(s,"^%s+","")
	s = string.gsub(s,"%s+$","")
	s = string.gsub(s,p,f)
	l.n = l.n + 1
	l[l.n] = string.gsub(s,"(%s%s*)$","")
	return l
end

CombatOut = CombatOut or {}

function CombatOut:Debug(msg)
	debug(msg)
end

function CombatOut:OnCombatIn()
	CombatState.duration = 6
	CombatState.finish_at = GetTime() + CombatState.duration
	debug("handle event - in combat")
end

function CombatOut:OnCombatRefresh(latency)
	latency = latency or 0
	CombatState.duration = 6 + latency
	CombatState.finish_at = GetTime() + CombatState.duration
	debug("handle event - refresh combat")
end

function CombatOut:OnCombatOut()
	local latency = math.floor((GetTime() - CombatState.finish_at) * 1000)
	CombatState.finish_at = 0
	CombatState.duration = 0
	CombatState.latency = latency
	debug(string.format("handle event - out combat (latency:%s ms)", latency))
end

local function UpdateSettings()
	if not CombatOut_Settings then CombatOut_Settings = {} end
	for option, value in defaults do
		if CombatOut_Settings[option] == nil then
			CombatOut_Settings[option] = value
		end
	end
end

local function UpdateAppearance()
	CombatOut_Frame:ClearAllPoints()
	CombatOut_Frame:SetPoint("CENTER", "UIParent", "CENTER", CombatOut_Settings["x"], CombatOut_Settings["y"])

	local regions = {"CombatOut_Frame", "CombatOut_FrameShadowTime",
		"CombatOut_FrameTime", "CombatOut_FrameText"}

	for _,region in ipairs(regions) do
		getglobal(region):SetWidth(CombatOut_Settings["w"])
	end

	CombatOut_Frame:SetHeight(CombatOut_Settings["h"])
	CombatOut_FrameText:SetHeight(CombatOut_Settings["h"])

	CombatOut_FrameTime:SetHeight(CombatOut_Settings["h"] - CombatOut_Settings["b"])
	CombatOut_FrameShadowTime:SetHeight(CombatOut_Settings["h"] - CombatOut_Settings["b"])

	CombatOut_FrameText:SetFont("Fonts\\FRIZQT__.TTF", CombatOut_Settings["h"])
	CombatOut_Frame:SetAlpha(CombatOut_Settings["a"])
	CombatOut_Frame:SetScale(CombatOut_Settings["s"])
end

local function UpdateDisplay()
	if (CombatState.duration <= 0) then
		CombatOut_FrameTime:Hide()
		CombatOut_Frame:Hide()
	else
		local width = (CombatState.duration / 6 ) * CombatOut_Settings["w"]
		if width > 0 then
			CombatOut_FrameTime:SetVertexColor(CombatOut_Settings["colorR"], CombatOut_Settings["colorG"], CombatOut_Settings["colorB"])
			CombatOut_FrameTime:SetWidth(width)
			CombatOut_FrameTime:Show()
		else
			CombatOut_FrameTime:Hide()
		end
		CombatOut_FrameShadowTime:SetWidth(width)
		CombatOut_FrameShadowTime:Show()

		CombatOut_FrameText:SetText(string.sub(CombatState.duration, 1, 3))
		CombatOut_Frame:SetAlpha(CombatOut_Settings["a"])
	end
end

local function OnChatCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))

	local vars = split(msg, " ")
	for k,v in vars do
		if v == "" then
			v = nil
		end
	end

	local cmd, arg = vars[1], vars[2]

	if cmd == "test" then
		CombatOut:OnCombatIn()
		CombatOut_Frame:Show()
	elseif cmd == "debug" then
		Parameters.debugMode = not Parameters.debugMode
		print(string.format("toggle debug mode: %s", tostring(Parameters.debugMode)))
	elseif cmd == "reset" then
		CombatOut_Settings = nil
		UpdateSettings()
		UpdateAppearance()
		print("Reset to defaults.")
	elseif settings[cmd] ~= nil then
		if arg ~= nil then
			if arg == "on" then arg = 1 end
			if arg == "off" then arg = 0 end
			local number = tonumber(arg)
			if number then
				CombatOut_Settings[cmd] = number
				UpdateAppearance()
			else
				print("Error: Invalid argument")
			end
		end
		print(format("%s %s %s (%s)",
			SlashCommandShort, cmd, CombatOut_Settings[cmd], settings[cmd]))
	else
		for k, v in settings do
			print(format("%s %s %s (%s)",
				SlashCommandShort, k, CombatOut_Settings[k], v))
		end
	end
end

function CombatOut_OnLoad()
	debug("begin: Register events")
	CombatOut_Frame:RegisterEvent('ADDON_LOADED')
	CombatOut_Frame:RegisterEvent('PLAYER_REGEN_ENABLED')
	CombatOut_Frame:RegisterEvent('PLAYER_REGEN_DISABLED')

	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_HITS')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_MISSES') -- MISS and BLOCK, PARRY, DODGE
	CombatOut_Frame:RegisterEvent('CHAT_MSG_SPELL_SELF_DAMAGE')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF')

	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES') -- MISS and BLOCK, PARRY, DODGE
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES') -- MISS and BLOCK, PARRY, DODGE

	-- Handle spell cast Sunder etc
	-- CombatOut_Frame:RegisterEvent('SPELLCAST_STOP')

	CombatOut_Frame:RegisterEvent('COMBAT_TEXT_UPDATE')
	debug("end: register events")
end

function CombatOut_OnEvent()
	debug(string.format("handle event - %s (%s %s)", tostring(event), tostring(arg1), tostring(arg2)))

	if event == 'ADDON_LOADED' then
		if (string.upper(arg1) == string.upper(Name)) then
			UpdateSettings()
			UpdateAppearance()
			UpdateDisplay()
		end

		return
	end

	if event == 'PLAYER_REGEN_ENABLED' then
		CombatOut:OnCombatOut()
		return
	end

	if event == 'PLAYER_REGEN_DISABLED' then
		CombatOut:OnCombatIn()
		CombatOut_Frame:Show()
		return
	end

	if event == 'CHAT_MSG_SPELL_SELF_DAMAGE' then
		if string.find(arg1, "^Your Taunt") ~= nil or
		   string.find(arg1, "^Your Growl") ~= nil then
			return
		end
	end

	if event == 'CHAT_MSG_COMBAT_SELF_HITS' then
		if string.find(arg1, "^You fall and lose %d+ health.$") ~= nil then
			return
		end
	end

	if event == 'COMBAT_TEXT_UPDATE' then
		if not Parameters.event_types[arg1] then
			return
		end
	end

	CombatOut:OnCombatRefresh()
end

function CombatOut_OnUpdate(delta)
	if (CombatState.duration > 0) then
		CombatState.duration = CombatState.duration - delta
		if (CombatState.duration < 0) then
			CombatState.duration = 0
		end
	end

	UpdateDisplay()
end

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[string.upper(Name)] = OnChatCommand;