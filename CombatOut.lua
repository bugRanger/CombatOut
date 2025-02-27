local Name = "CombatOut"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {
	debugMode = false,
}

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

local logger = logger or {}
function logger:debug(msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
end
function logger:info(msg)
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

local function UpdateDisplay(duration)
	if (duration <= 0) then
		CombatOut_FrameTime:Hide()
		CombatOut_Frame:Hide()
	else
		local width = (duration / 6 ) * CombatOut_Settings["w"]
		if width > 0 then
			CombatOut_FrameTime:SetVertexColor(CombatOut_Settings["colorR"], CombatOut_Settings["colorG"], CombatOut_Settings["colorB"])
			CombatOut_FrameTime:SetWidth(width)
			CombatOut_FrameTime:Show()
		else
			CombatOut_FrameTime:Hide()
		end
		CombatOut_FrameShadowTime:SetWidth(width)
		CombatOut_FrameShadowTime:Show()

		CombatOut_FrameText:SetText(string.sub(duration, 1, 3))
		CombatOut_Frame:SetAlpha(CombatOut_Settings["a"])
	end
end

local function OnChatCommand(msg)
	msg = msg or ""
	logger:debug(string.format("handle command - '%s'", msg))

	local vars = split(msg, " ")
	for k,v in vars do
		if v == "" then
			v = nil
		end
	end

	local cmd, arg = vars[1], vars[2]

	if cmd == "test" then
		combatWatcher:OnCombatIn()
		CombatOut_Frame:Show()
	elseif cmd == "debug" then
		Parameters.debugMode = not Parameters.debugMode
		logger:info(string.format("toggle debug mode: %s", tostring(Parameters.debugMode)))
	elseif cmd == "reset" then
		CombatOut_Settings = nil
		UpdateSettings()
		UpdateAppearance()
		logger:info("Reset to defaults.")
	elseif settings[cmd] ~= nil then
		if arg ~= nil then
			if arg == "on" then arg = 1 end
			if arg == "off" then arg = 0 end
			local number = tonumber(arg)
			if number then
				CombatOut_Settings[cmd] = number
				UpdateAppearance()
			else
				logger:info("Error: Invalid argument")
			end
		end
		logger:info(format("%s %s %s (%s)",
			SlashCommandShort, cmd, CombatOut_Settings[cmd], settings[cmd]))
	else
		for k, v in settings do
			logger:info(format("%s %s %s (%s)",
				SlashCommandShort, k, CombatOut_Settings[k], v))
		end
	end
end

function CombatOut_OnLoad()
	logger:debug("begin: Register events")
	CombatOut_Frame:RegisterEvent('ADDON_LOADED')
	combatWatcher:set_logger(logger)
	combatWatcher:subscribe(CombatOut_Frame)
	logger:debug("end: Register events")
end

function CombatOut_OnEvent()
	logger:debug(string.format("handle event - %s (%s %s)", tostring(event), tostring(arg1), tostring(arg2)))

	if event == 'ADDON_LOADED' then
		if (string.upper(arg1) == string.upper(Name)) then
			UpdateSettings()
			UpdateAppearance()
		end

		return
	end

	if combatWatcher:handle_event(event, arg1, arg2) == true then
		CombatOut_Frame:Show()
		return
	end
end

function CombatOut_OnUpdate(delta)
	combatWatcher:handle_tick(GetTime(), delta)
	UpdateDisplay(combatWatcher.state.duration)
end

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[string.upper(Name)] = OnChatCommand;