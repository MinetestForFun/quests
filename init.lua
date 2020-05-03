-- reading previous quests
local file = io.open(minetest.get_worldpath().."/quests", "r")
if file then
	minetest.log("action", "Reading quests...")
	quests = minetest.deserialize(file:read("*all"))
	file:close()
end
quests = quests or {}
quests.registered_quests = {}
quests.active_quests = quests.active_quests or {}
quests.successfull_quests = quests.successfull_quests or {}
quests.failed_quests = quests.failed_quests or {}
quests.info_quests = quests.info_quests or {}
quests.hud = quests.hud or {}
for idx,_ in pairs(quests.hud) do
	quests.hud[idx].first = true
end


quests.formspec_lists = {}
function quests.round(num, n) 
	local mult = 10^(n or 0)
	return math.floor(num * mult + .5) / mult
end

quests.colors = {
	new     = "0xAAAA00",
	success = "0x00AD00",
	failed  = "0xAD0000",
}


local MP = minetest.get_modpath("quests")

function quests.sorted_pairs(t)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
			else return a[i], t[a[i]]
		end
	end
	return iter
end

dofile(MP .. "/core.lua")
dofile(MP .. "/hud.lua")
dofile(MP .. "/formspecs.lua")
dofile(MP .. "/mod_integrations/mod_integrations.lua")



-- write the quests to file
minetest.register_on_shutdown(function()
	for playername, quest in pairs(quests.active_quests) do
		for questname, questspecs in pairs(quest) do
			if questspecs.finished then
				quests.active_quests[playername][questname] = nil -- make sure no finished quests are saved as unfinished
			end
		end
	end
	local file, err = io.open(minetest.get_worldpath().."/quests", "w")
	if file then
		file:write(minetest.serialize({
			active_quests      = quests.active_quests,
			successfull_quests = quests.successfull_quests,
			failed_quests      = quests.failed_quests,
			info_quests        = quests.info_quests
		}))
		file:close()
		minetest.log("action", "Wrote quests to file")
	else
		minetest.log("action", "Failed writing quests to file: open failed: " .. err)
	end
end)
