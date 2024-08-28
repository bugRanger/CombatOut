local Name = "CombatOut"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {}
Parameters.debugMode = true
Parameters.latency = 0
Parameters.duration = 0
Parameters.finish_at = 0

local defaults = {
	x = 0,
	y = -161,
	w = 200,
	h = 13,
	b = 0,
	a = 1,
	s = 1,
	sound = "off"
}

local settings = {
	x = "Bar X position",
	y = "Bar Y position",
	w = "Bar width",
	h = "Bar height",
	b = "Border height",
	a = "Alpha between 0 and 1",
	s = "Bar scale",
}

local debug = function (msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
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
	if (Parameters.duration <= 0) then
		CombatOut_FrameTime:Hide()
		CombatOut_Frame:Hide()
	else
		local width = (Parameters.duration / 6 ) * CombatOut_Settings["w"]
		if width > 0 then
			CombatOut_FrameTime:SetWidth(width)
			CombatOut_FrameTime:Show()
		else
			CombatOut_FrameTime:Hide()
		end
		CombatOut_FrameShadowTime:SetWidth(width)
		CombatOut_FrameShadowTime:Show()

		CombatOut_FrameText:SetText(string.sub(Parameters.duration, 1, 3))
		CombatOut_Frame:SetAlpha(CombatOut_Settings["a"])
	end
end

local function OnChatCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))
end

function CombatOut_OnLoad()
	debug("begin: Register events")
	CombatOut_Frame:RegisterEvent('ADDON_LOADED')
	CombatOut_Frame:RegisterEvent('PLAYER_REGEN_ENABLED')
	CombatOut_Frame:RegisterEvent('PLAYER_REGEN_DISABLED')

	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_MISSES')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_SELF_HITS')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_SPELL_SELF_DAMAGE')
	CombatOut_Frame:RegisterEvent('CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES')

	CombatOut_Frame:RegisterEvent('COMBAT_TEXT_UPDATE')
	debug("end: register events")
end

function CombatOut_OnEvent()
	debug(string.format("handle event - '%s'", event))
	if event == 'ADDON_LOADED' then
		if (string.upper(arg1) == string.upper(Name)) then
			UpdateSettings()
			UpdateAppearance()
			UpdateDisplay()
		end

		return
	end

	if event == 'PLAYER_REGEN_ENABLED' then
		OnCombatOut()
	else
		OnCombatIn()
		CombatOut_Frame:Show()
	end
end

function CombatOut_OnUpdate(delta)
	if (Parameters.duration > 0) then
		Parameters.duration = Parameters.duration - delta
		if (Parameters.duration < 0) then
			Parameters.duration = 0
		end
	end

	UpdateDisplay()
end

function OnCombatIn() 
	Parameters.duration = 6
	Parameters.finish_at = GetTime() + Parameters.duration
	debug("handle event - in combat")
end

function OnCombatOut()
	local latency = math.floor((GetTime() - Parameters.finish_at) * 1000)
	Parameters.finish_at = 0
	Parameters.duration = 0
	Parameters.latency = latency
	debug(string.format("handle event - out combat (latency:%s ms)", latency))
end

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[Name] = OnChatCommand;