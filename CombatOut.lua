local Name = "CombatOut"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {}
Parameters.debugMode = true
Parameters.latency = 0
Parameters.start_at = 0
Parameters.finish_at = 0

local debug = function (msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
end


function OnChatCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))
end

debug("create frame")
local frame = CreateFrame("Frame")

function OnCombatIn() 
	frame:SetScript("OnEvent", OnCombatOut)
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")

	Parameters.start_at = GetTime()
	Parameters.finish_at = 0
	debug(string.format("handle event - combat in %s", Parameters.start_at))
end

function OnCombatOut()
	frame:SetScript("OnEvent", OnCombatIn)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")

	Parameters.finish_at = GetTime()
	Parameters.latency = Parameters.finish_at - Parameters.start_at
	Parameters.start_at = 0
	debug(string.format("handle event - combat out %s (%s)", Parameters.finish_at, Parameters.latency))
end

OnCombatOut()

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[Name] = OnChatCommand;