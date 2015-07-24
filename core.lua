--- Quests core.
-- @module core

-- Boilerplate to support localized strings if intllib mod is installed.
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	-- If you don't use insertions (@1, @2, etc) you can use this:
	S = function(s) return s end
end
local empty_callback = function(...) end


--- Registers a quest for later use.
-- There are two types of quests: simple and tasked.
--
-- * Simple quests are made of a single objective
-- * Taked quests are made of tasks, allowing simultaneous progress
--   within the quest as well as branching quest objectives
-- 
-- Both quest types are defined by a table, and they share common information:
--     {
--       title,         -- Self-explanatory. Should describe the objective for simple quests.
--       description,   -- Description/lore of the quest
--       icon,          -- Texture name of the quest's icon. If missing, a default icon is used.
--       startcallback, -- Called upon quest start.  function(playername, questname, metadata)
--       autoaccept,    -- If true, quest automatically becomes completed if its progress reaches the max.
--       endcallback,   -- If autoaccept is true, gets called at the end of the quest.
--                      --   function(playername, questname, metadata)
--       abortcallback, -- Called when a player cancels the quest.  function(playername, questname, metadata)
--       periodicity    -- Delay in seconds before the quest becomes available again. If nil or 0, doesn't restart.
--     }
-- 
-- In addition, simple quests have a number-type `max` element indicating the max progress of the quest.
-- As for tasked quests, they have a table-type `tasks` element which value is like this:
--     tasks = {
--       start = {
--         title,
--         description,
--         icon,
--         max          -- Max task progress
--       },
--       another_task = {
--         [...],
--     
--         requires = {"start"},
--         -- Table of task names which one must be completed for this task to unlock.
--         --   To to task completion groups (i.e. where ALL must be compileted), pass said names in a (sub)table.
--     
--         availablecallback,
--         -- Called when the task becomes available.
--         --   function(playername, questname, metadata, taskname, enablingtaskname)
--         --   enablingtaskname is a string or a table of strings, depending on the condition that unlocked the task
--       }
--       something = {
--         [...],
--         requires = {"start"},
--     
--         disables_on = {"another_task"},
--         -- Same as `requires`, but *disables* the task (it then does not count towards quest completion)
--     
--         disablecallback,
--         -- Called when the task becomes disabled.
--         --   function(playername, questname, metadata, taskname, disablingtaskname)
--         --   disablingtaskname is a string or a table of strings, depending on the condition that locked the task
--       }
--     }
-- In this previous example the 2 last tasks enables once the `start` one is completed, and the
-- last one disables upon `another_task` completion, effectively making it optional if one
-- completes `another_task` before it.
-- @param questname Name of the quest. Should follow the naming conventions: `modname:questname`
-- @param quest Quest definition `table`
-- @return `true` when the quest was successfully registered
-- @return `false` when there was already such a quest, or if mandatory info was omitted/corrupt
function quests.register_quest(questname, quest)
	if (quests.registered_quests[questname] ~= nil) then
		return false -- The quest was not registered since there already a quest with that name
	end
	quests.registered_quests[questname] = {
		title         = quest.title or S("missing title"),
		description   = quest.description or S("missing description"),
		icon          = quest.icon or "quests_default_quest_icon.png",
		startcallback = quest.startcallback or empty_callback,
		autoaccept    = quest.autoaccept or false,
		callback      = quest.callback or empty_callback,
		endcallback   = quest.endcallback or empty_callback,
		abortcallback = quest.abortcallback or empty_callback,
		periodicity   = quest.periodicity or 0 
	}
	local new_quest = quests.registered_quests[questname]
	if quest.max ~= nil then -- Simple quest
		new_quest.max = quest.max or 1
		new_quest.simple = true
	else
		if quest.tasks == nil or type(quests.task) ~= "table" then
			quests.registered_quests[questname] = nil
			return false
		end
		new_quest.tasks = {}
		local tcount = 0
		for tname, task in pairs(quest.tasks) do
			new_quest.tasks[tname] = {
				title             = quest.title or S("missing title"),
				description       = quest.description or S("missing description"),
				icon              = quest.icon or "quests_default_quest_icon.png",
				max               = quest.max or 1,
				requires          = quest.requires,
				availablecallback = quest.availablecallback or empty_callback,
				disables_on       = quest.disables_on,
				disablecallback   = quest.disablecallback or empty_callback
			}
			tcount = tcount + 1
		end
		if tcount == 0 then -- No tasks!
			quests.registered_quests[questname] = nil
			return false
		end
	end
	return true
end

--- Starts a quest for a specified player.
-- @param playername Name of the player
-- @param questname Name of the quest, which was registered with @{quests.register_quest}
-- @param metadata Optional additional data
-- @return `false` on failure
-- @return `true` if the quest was started
function quests.start_quest(playername, questname, metadata)
	local quest = quests.registered_quests[questname]
	if quest == nil then
		return false
	end
	if quests.active_quests[playername] == nil then
		quests.active_quests[playername] = {}
	end
	if quests.active_quests[playername][questname] ~= nil then
		return false -- the player already has this quest
	end
	if quest.simple then
		quests.active_quests[playername][questname] = {value = 0, metadata = metadata}
	else
		quests.active_quests[playername][questname] = {metadata = metadata}
	end

	quests.update_hud(playername)
	quests.show_message("new", playername, S("New quest:") .. " " .. quest.title)
	return true
end

local function check_active_quest(playername, questname)
	return not(
		playername == nil or
		questname == nil or
		quests.registered_quests[questname] == nil or -- Quest doesn't exist
		quests.active_quests[playername] == nil or -- Player has no data
		quests.active_quests[playername][questname] == nil -- Quest isn't active
	)
end

--- Updates a *simple* quest's status.
-- Calls the quest's `endcallback` if autoaccept is `true` and the quest reaches its max value.
-- Has no effect on tasked quests.
-- @param playername Name of the player
-- @param questname Quest which gets updated
-- @param value Value to add to the quest's progress (can be negative)
-- @return `true` if the quest is finished
-- @return `false` if there is no such quest, is a tasked one, or the quest continues
-- @see quests.update_quest_task
function quests.update_quest(playername, questname, value)
	if not check_active_quest(playername, questname) then
		return false -- There is no such quest or it isn't active
	end
	if value == nil then
		return false -- No value given
	end
	local plr_quest = quests.active_quests[playername][questname]
	if plr_quest.finished then
		return false -- The quest is already finished
	end
	local quest = quests.registered_quests[questname]
	plr_quest.value = plr_quest.value + value
	if plr_quest.value >= quest.max then
		plr_quest.value = quest.max
		if quest.autoaccept then
			quest.endcallback(playername, questname, plr_quest.metadata)
			quests.accept_quest(playername,questname)
			quests.update_hud(playername)
		end
		return true -- the quest is finished
	end
	quests.update_hud(playername)
	return false -- the quest continues
end

--- Updates a *tasked* quest task's status.
-- Calls the quest's `endcallback` if autoaccept is `true` and all the quest's enabled
--   tasks reaches their max value.
-- Has no effect on simple quests.
-- @param playername Name of the player
-- @param questname Quest which gets updated
-- @param taskname Task to update
-- @param value Value to add to the task's progress (can be negative)
-- @return `true` if the quest is finished
-- @return `false` if there is no such quest, is a simple one, or the quest continues
-- @see quests.update_quest
function quests.update_quest_task(playername, questname, taskname, value)
--[[
	if not check_active_quest(playername, questname) then
		return false -- There is no such quest or it isn't active
	end
	local quest = quests.registered_quests[questname]
	if taskname == nil or quest.tasks[taskname] == nil or value == nil then
		return false
	end
	local plr_quest = quests.active_quests[playername][questname]
	if plr_quest.finished then
		return false -- The quest is already finished
	end
	plr_quest.value = plr_quest.value + value
	if plr_quest.value >= quest.max then
		plr_quest.value = quest.max
		if quest.autoaccept then
			quest.endcallback(playername, questname, plr_quest.metadata)
			quests.accept_quest(playername,questname)
			quests.update_hud(playername)
		end
		return true -- the quest is finished
	end
	quests.update_hud(playername)
	return false -- the quest continues
]]
end

--- Confirms quest completion and ends it.
-- When the mod handles the end of quests himself, e.g. you have to talk to somebody to finish the quest,
-- you have to call this method to end a quest
-- @param playername Player's name
-- @param questname Quest name
-- @return `true` when the quest is completed
-- @return `false` when the quest is still ongoing
function quests.accept_quest(playername, questname)
	if check_active_quest(playername, questname) and not quests.active_quests[playername][questname].finished then
		if quests.successfull_quests[playername] == nil then
			quests.successfull_quests[playername] = {}
		end
		if quests.successfull_quests[playername][questname] ~= nil then
			quests.successfull_quests[playername][questname].count = quests.successfull_quests[playername][questname].count + 1
		else
			quests.successfull_quests[playername][questname] = {count = 1}
		end
		quests.active_quests[playername][questname].finished = true
		for _,quest in ipairs(quests.hud[playername].list) do
			if (quest.name == questname) then
				local player = minetest.get_player_by_name(playername)
				player:hud_change(quest.id, "number", quests.colors.success)
			end
		end
		quests.show_message("success", playername, S("Quest completed:") .. " " .. quests.registered_quests[questname].title)
		minetest.after(3, function(playername, questname)
			quests.active_quests[playername][questname] = nil
			quests.update_hud(playername)
		end, playername, questname)
		return true -- the quest is finished, the mod can give a reward
	end
	return false -- the quest hasn't finished
end

--- Aborts a quest.
-- Call this method when you want to end a quest even when it was not finished.
-- Example: the player failed.
-- @param playername Player's name
-- @param questname Quest name
-- @return `false` if the quest was not aborted
-- @return `true` when the quest was aborted
function quests.abort_quest(playername, questname)
	if not check_active_quest(playername, questname) then
		return false
	end
	if quests.failed_quests[playername] == nil then
		quests.failed_quests[playername] = {}
	end
	if quests.failed_quests[playername][questname] ~= nil then
		quests.failed_quests[playername][questname].count = quests.failed_quests[playername][questname].count + 1
	else
		quests.failed_quests[playername][questname] = { count = 1 }
	end

	quests.active_quests[playername][questname].finished = true
	for _,quest in ipairs(quests.hud[playername].list) do
		if quest.name == questname then
			local player = minetest.get_player_by_name(playername)
			player:hud_change(quest.id, "number", quests.colors.failed)
		end
	end

	local quest = quests.registered_quests[questname]
	quest.abortcallback(playername, questname, quests.active_quests[playername][questname].metadata)
	quests.show_message("failed", playername, S("Quest failed:") .. " " .. quest.title)
	minetest.after(3, function(playername, questname)
		quests.active_quests[playername][questname] = nil
		quests.update_hud(playername)
	end, playername, questname)
end

--- Get quest metadata.
-- @return Metadata of the quest, `nil` if there is none
-- @return `nil, false` if the quest doesn't exist or isn't active
-- @see quests.set_metadata
function quests.get_metadata(playername, questname)
	if not check_active_quest(playername, questname) then
		return nil, false
	end
	return quests.active_quests[playername][questname].metadata
end

--- Set quest metadata.
-- @return `false` if the quest doesn't exist or isn't active
-- @return `nil` otherwise
-- @see quests.get_metadata
function quests.set_metadata(playername, questname, metadata)
	if not check_active_quest(playername, questname) then
		return false
	end
	quests.active_quests[playername][questname].metadata = metadata
end

