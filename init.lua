pvp_choice = {}
pvp_choice.extinguish = {}

-- Function to toggle PvP for a player
local function toggle_pvp(player)
    local pvp_setting = player:get_meta():get_string("pvp_enabled")

    if pvp_setting == "" or pvp_setting == "false" then
        player:get_meta():set_string("pvp_enabled", "true")
        minetest.chat_send_player(player:get_player_name(), "PvP is now enabled for you.")
    else
        player:get_meta():set_string("pvp_enabled", "false")
        minetest.chat_send_player(player:get_player_name(), "PvP is now disabled for you.")
    end
end

-- Function to check if PvP is enabled for a player
local function is_pvp_enabled(player)
    local pvp_setting = player:get_meta():get_string("pvp_enabled")
    return pvp_setting ~= "false"
end

-- Registering the /toggle_pvp command
minetest.register_chatcommand("toggle_pvp", {
    description = "Toggle PvP on or off",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            toggle_pvp(player)
        end
    end,
})

-- Register the on punch player event
minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    -- Check if both player and hitter are valid and are players
    if not player or not hitter or not player:is_player() or not hitter:is_player() then
        return
    end

    local player_pvp_setting = player:get_meta():get_string("pvp_enabled")
    local hitter_pvp_setting = hitter:get_meta():get_string("pvp_enabled")

    -- Check if PvP is disabled for either player
    if player_pvp_setting == "false" or hitter_pvp_setting == "false" then
        if minetest.get_modpath("mcl_burning") then
            mcl_burning.extinguish(player)  -- Extinguish the player if they are on fire
        end
        return true  -- Cancel the punch event
    end
end)


-- Initialize PvP setting for each player as they join
minetest.register_on_joinplayer(function(player)
    -- Default to PvP off if not already set
    if player:get_meta():get_string("pvp_enabled") == "" then
        player:get_meta():set_string("pvp_enabled", "false")
    end
end)

if minetest.get_modpath("mcl_inventory") then
        -- Override the damage handling function
        local original_damage_function = mcl_damage.run_modifiers
        mcl_damage.run_modifiers = function(obj, damage, reason)
            -- Check if obj and reason.source are valid and if the damage is caused by a projectile
            if obj and obj:is_player() and reason.source and reason.source:is_player() and 
            (reason.type == "arrow" or reason.type == "fireball") then
                -- Check PvP settings for both players
                if not is_pvp_enabled(obj) or not is_pvp_enabled(reason.source) then
                    mcl_potions._extinguish_nearby_fire(obj:get_pos(),4)
                    table.insert(pvp_choice.extinguish, obj:get_player_name())
                    return 0 -- No damage if PvP is disabled for either player
                end
            end

            -- Call the original damage function for all other cases
            return original_damage_function(obj, damage, reason)
        end

    minetest.log("action", "[PvP Mod] mcl_inventory modpath found. Registering PvP tab.")
    
    mcl_inventory.register_survival_inventory_tab({
        id = "pvp_toggle",
        description = "PvP Toggle",
        item_icon = "mcl_tools:sword_diamond",  -- Replace with an appropriate icon
        show_inventory = true,
        build = function(player)
            minetest.log("action", "[PvP Mod] Building PvP formspec for player " .. player:get_player_name())
            local pvp_setting = player:get_meta():get_string("pvp_enabled")
            local button_label = pvp_setting == "true" and "Disable PvP" or "Enable PvP"
            return "label[1,1;PvP Settings]" ..
                   "button[2,2;3,1;toggle_pvp;" .. button_label .. "]"
        end,
        handle = function(player, fields)
            minetest.log("action", "[PvP Mod] PvP tab pressed by" .. player:get_player_name())
            if fields.toggle_pvp then
                minetest.log("action", "[PvP Mod] PvP toggle button pressed by " .. player:get_player_name())
                toggle_pvp(player)
                mcl_inventory.update_inventory(player)  -- Update inventory to refresh the tab
            end
        end,
    })

    minetest.log("action", "[PvP Mod] PvP tab registered.")
else
    minetest.log("error", "[PvP Mod] mcl_inventory modpath not found. PvP tab not registered.")
end

minetest.register_globalstep(function(dtime)
    if minetest.get_modpath("mcl_burning") then
        -- Temporary table to track players who are no longer burning
        local not_burning = {}

        -- Loop over each player name in pvp_choice.extinguish
        for _, player_name in ipairs(pvp_choice.extinguish) do
            local player = minetest.get_player_by_name(player_name)
            if player then
                -- Extinguish the player
                mcl_burning.extinguish(player)

                -- Check if the player is still burning
                if not mcl_burning.is_burning(player) then
                    table.insert(not_burning, player_name)
                end
            end
        end

        -- Remove players who are no longer burning from pvp_choice.extinguish
        for _, player_name in ipairs(not_burning) do
            for i, name in ipairs(pvp_choice.extinguish) do
                if name == player_name then
                    table.remove(pvp_choice.extinguish, i)
                    break
                end
            end
        end
    end
end)