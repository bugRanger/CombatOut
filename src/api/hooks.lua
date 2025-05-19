function hooksecurefunc(functionName, hookFunction)
	if not _G[functionName] then return end

	local originFunction = _G[functionName]
	_G[functionName] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		hookFunction(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		originFunction(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
	end
end