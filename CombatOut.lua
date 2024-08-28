local Name = "COMBATOUT"
local ShortName = "CO"
local SlashCommandFull = "/combatout"
local SlashCommandShort = "/co"

local Parameters = {}
Parameters.debugMode = true


local debug = function (msg)
	if not Parameters.debugMode then return end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("%s debug '%s'", ShortName, msg))
end

function OnChatCommand(msg)
	msg = msg or ""
	debug(string.format("handle command - '%s'", msg))
end

SLASH_COMBATOUT1 = SlashCommandFull
SLASH_COMBATOUT2 = SlashCommandShort

SlashCmdList[Name] = OnChatCommand;