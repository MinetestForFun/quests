assert(sfinv.enabled, "Please enable sfinv in order to use it.")
local old_func = sfinv.pages["sfinv:crafting"].get
sfinv.override_page("sfinv:crafting", {
	get = function(self, player, context)
		local fs = old_func(self, player, context)
		return fs .. "image_button[0,0;1,1;inventory_plus_quests.png;quests;]"
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if fields.quests then
		quests.show_formspec(player:get_player_name())
		return true
	elseif fields.quests_exit then
		sfinv.set_page(player, "sfinv:crafting")
		return true
	end
	return false
end)
