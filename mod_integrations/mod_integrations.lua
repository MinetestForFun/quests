-- support for several inventory mods
if minetest.get_modpath("unified_inventory") then
	dofile(minetest.get_modpath("quests") .. "/mod_integrations/unified_inventory.lua")
end

if minetest.get_modpath("inventory_plus") then
	dofile(minetest.get_modpath("quests") .. "/mod_integrations/inventory_plus.lua")
end


--mod that displays notifications in the screen's center
if minetest.get_modpath("central_message") then
	dofile(minetest.get_modpath("quests") .. "/mod_integrations/central_message.lua")

else -- define blank function so we can still use this in the code later
	function quests.show_message(...) end
end
