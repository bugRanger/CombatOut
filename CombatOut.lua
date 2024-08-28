local Name = "CombatOut"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {}
Parameters.debugMode = true
Parameters.latency = 0
Parameters.finish_at = 0

local debug = function (msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
end


function OnChatCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))
end

function OnEvent()
	debug(string.format("handle event - '%s'", tostring(event)))

	if (event == 'PLAYER_REGEN_DISABLED') then
		OnCombatIn()
	end

	if (event == 'PLAYER_REGEN_ENABLED') then
		OnCombatOut()
	end
end

function OnCombatIn() 
	Parameters.finish_at = GetTime() + 5
	debug("handle event - in combat")
end

function OnCombatOut()
	local latency = GetTime() - Parameters.finish_at
	Parameters.finish_at = 0
	Parameters.latency = latency
	debug(string.format("handle event - out combat (latency:%s s)", latency))
end

debug("create frame")
local frame = CreateFrame("Frame")

debug("register frame events")
frame:SetScript('OnEvent', OnEvent)
frame:RegisterEvent('PLAYER_REGEN_ENABLED')
frame:RegisterEvent('PLAYER_REGEN_DISABLED')

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[Name] = OnChatCommand;