require("animation")
require("unit")
require("unit_class")
require("unit_layer")
require("weapon_class")
require("queue")
require("combat")
require("special_ability")
require("special_class")

world = {
    
}

function world.create(observer, game, mods, teams, animation, map)
    local self = {observer = observer, game = game, mods = mods, teams = teams, animation = animation, map = map}
    setmetatable(self, {__index = world})

    self.command_queue = {}

    self.unit_size = 32
    self.unit_layer = unit_layer.create(self.map, self.observer)

    self:populate_units()

    self.listeners = {
        self.observer:add_listener("new_turn", function() self:new_turn() end),
        self.observer:add_listener("new_turn_cycle", function() self:activate_spawners() end),
        self.observer:add_listener("animation_ended", function() self:clean_dead_units() end),
        self.observer:add_listener("world_changed", function() self:check_game_end() end),
    }

    return self
end

function world:populate_units()
    local unit_layer = self.unit_layer
    local teams = self.teams
    local mods = self.mods

    for i, unit_base in ipairs(self.map.layers.units.objects) do
        local x, y = unit_base.x / 16, unit_base.y / 16

        local upvalues = { teams = teams, mods = mods, unit_class = unit_class, weapon_class = weapon_class, special_class = special_class }

        local unit_class = string_to_value(unit_base.properties.unit_class, upvalues)
        local unit_data = string_to_value(unit_base.properties.unit_data, upvalues)

        unit_layer:create_unit(unit_class, x, y, unit_data)
    end

    -- -- Create player units.
    -- unit_layer:create_unit(unit_class.sword_fighter, 1, 2, { active_weapon = 1, weapons = {weapon_class.iron_sword}, team = teams[1] })
    -- unit_layer:create_unit(unit_class.axe_fighter, 3, 5, { active_weapon = 1, weapons = {weapon_class.iron_axe}, team = teams[1] })
    -- unit_layer:create_unit(unit_class.lance_fighter, 2, 10, { active_weapon = 1, weapons = {weapon_class.iron_lance}, team = teams[1] })
    -- unit_layer:create_unit(unit_class.bow_fighter, 2, 8, { active_weapon = 1, weapons = {weapon_class.iron_bow, weapon_class.iron_sword}, team = teams[1] })

    -- -- Unit with unit_class from mod.
    -- unit_layer:create_unit(mods.konosuba.unit_class.crimson_demon, 4, 8, { active_weapon = 1, weapons = {weapon_class.mini_explosion}, specials = {mods.konosuba.special_class.explosion}, team = teams[1] })


    -- -- Create enemy units.
    -- unit_layer:create_unit(unit_class.sword_fighter, 3, 18, { active_weapon = 1, weapons = {weapon_class.iron_sword}, team = teams[2] })
    -- unit_layer:create_unit(unit_class.sword_fighter, 1, 19, { active_weapon = 1, weapons = {weapon_class.iron_sword}, team = teams[2] })
    -- unit_layer:create_unit(unit_class.axe_fighter, 1, 20, { active_weapon = 1, weapons = {weapon_class.iron_axe}, team = teams[2] })
    -- unit_layer:create_unit(unit_class.lance_fighter, 3, 20, { active_weapon = 1, weapons = {weapon_class.iron_lance}, team = teams[2] })
    -- unit_layer:create_unit(unit_class.bow_fighter, 2, 21, { active_weapon = 1, weapons = {weapon_class.iron_bow}, team = teams[2] })
end

function world:destroy()
    observer.remove_listeners_from_object(self)
end

function world:receive_command(command)
    table.insert(self.command_queue, command)
end

function world:process_command_queue()
    for k, command in pairs(self.command_queue) do
        local data = command.data
        if command.action == "move_unit" then
            self:move_unit(data.unit, data.tile_x, data.tile_y, data.path)
        elseif command.action == "attack" then
            self:combat(data.unit, data.tile_x, data.tile_y)
        elseif command.action == "special" then
            self:activate_special_ability(data.unit, data.special, data.tile_x, data.tile_y)
        end
    end

    self.command_queue = {}
end

function world:check_game_end()
    local function check_annihilated(team)
        local no_more_unit = true

        for k, unit in pairs(self:get_all_units()) do
            if unit.data.team == team then
                no_more_unit = false
            end
        end

        return no_more_unit
    end

    local game_mode = self.game.game_mode

    if game_mode == "death_match" then
        if check_annihilated(self.teams[1]) then
            self.observer:notify("game_end", { winner = "enemy" })
        end

        if check_annihilated(self.teams[2]) then
            self.observer:notify("game_end", { winner = "player" })
        end
    elseif game_mode == "defense" then
        if check_annihilated(self.teams[1]) then
            self.observer:notify("game_end", { winner = "enemy" })
        end

        if self.game.turn_count == self.map.properties.turns_to_defend_for then
            self.observer:notify("game_end", { winner = "player" })
        end

        if self.defense_point_captured then
            self.observer:notify("game_end", { winner = "enemy" })
        end
    end
end

function world:combat(attacker, tile_x, tile_y)
    combat.initiate(self, attacker, tile_x, tile_y)

    self.observer:notify("world_changed")
end

function world:activate_special_ability(caster, special, tile_x, tile_y)
    special_ability.activate(self, caster, special, tile_x, tile_y)

    self.observer:notify("world_changed")
end

function world:new_turn()
    -- Uncheck 'moved' flag on every unit.
    for k, unit in pairs(self:get_all_units()) do
        unit.data.moved = false
    end

    self.observer:notify("world_changed")
end

function world:clean_dead_units()
    for k, unit in pairs(self:get_all_units()) do
        if unit.death_flag then
            unit:die(self)
        end
    end

    self.observer:notify("world_changed")
end

function world:update()
    self:process_command_queue()

    self.map:update()
end

function world:update_animation()
    units = self:get_all_units()

    for k, unit in pairs(units) do
        unit:update_animation()
    end
end

function world:draw(component)
    if component == "tiles" then
        for i, layer in ipairs(self.map.layers) do
            if layer.type == "tilelayer" and layer.visible and layer.opacity > 0 then
                self.map:drawTileLayer(layer)
            end
        end
    elseif component == "units" then
        love.graphics.push()
            love.graphics.scale(tile_size / unit_size)
            self.map.layers.unit_layer:draw()
        love.graphics.pop()
    elseif component == "health_bars" then
        love.graphics.push()
            love.graphics.scale(tile_size / unit_size)
            self.map.layers.unit_layer:draw_health_bars()
        love.graphics.pop()
    end
end

function world:get_unit(tile_x, tile_y)
    return self.map.layers.unit_layer:get_unit(tile_x, tile_y)
end

function world:get_all_units()
    return self.map.layers.unit_layer:get_all_units()
end

function world:move_unit(unit, tile_x, tile_y, path)
    self.map.layers.unit_layer:move_unit(unit, tile_x, tile_y)

    -- Check if path is provided for animation.
    if path then
        local animation = { type = "move" }
        animation.data = { unit = unit, path = path }

        self.animation:receive_animation(animation)
    end

    -- Mark unit as moved.
    unit.data.moved = true

    self.observer:notify("world_changed")
end

function world:activate_spawners()
    local spawners = self.map.layers.spawners.objects
    local unit_layer = self.unit_layer
    local teams = self.teams
    local mods = self.mods

    for i, spawner in ipairs(spawners) do
        local x, y = spawner.x / 16, spawner.y / 16

        local upvalues = { teams = teams, mods = mods, unit_class = unit_class, weapon_class = weapon_class, special_class = special_class }

        local unit_class = string_to_value(spawner.properties.unit_class, upvalues)
        local unit_data = string_to_value(spawner.properties.unit_data, upvalues)

        local active_turns = string_to_value(spawner.properties.active_turns)

        if table_contains(active_turns, self.game.turn_count) and unit_layer:get_unit(x, y) == nil then
            unit_layer:create_unit(unit_class, x, y, unit_data)
        end 
    end

    self.observer:notify("world_changed")
end

function world:capture_defense_point()
    self.defense_point_captured = true

    self.observer:notify("world_changed")
end

function world:get_terrain_map()
    local terrain_map = {}

    for x = 0, self.map.width - 1 do
        for y = 0, self.map.height - 1 do
            local terrain = self.map:getTileProperties("terrain", x + 1, y + 1).terrain

            table.insert(terrain_map, {x = x, y = y, terrain = terrain })
        end
    end

    return terrain_map
end

function world:get_adjacent_tiles(tile_x, tile_y)
    return  {
                { x = tile_x, y = tile_y + 1 },
                { x = tile_x, y = tile_y - 1 },
                { x = tile_x + 1, y = tile_y },
                { x = tile_x - 1, y = tile_y }
            }
end

function world:get_tiles_in_distance(args)
    -- Args:
    -- tile_x: origin tile x
    -- tile_y: origin tile y
    -- distance: the max distance / max cost to traverse
    -- min_distance: to exclude tiles that can't be attacked such as by bow users.
    -- movement_filter: function that converts tile data (unit on it and terrain) to value on how much it cost to traverse.
    -- unlandable_filter: function that determines if a tile is landable or not based on the unit and tile on it.
    -- early_exit: function that returns true if early exit condition is met.

    local function key(x, y) return string.format("(%i, %i)", x, y) end

    -- Movement filter defaults to treat everything as 1 value for weapon.
    local movement_filter = args.movement_filter or function() return 1 end
    -- Unlandable filter defaults to treat everything as landable.
    local unlandable_filter = args.unlandable_filter or function() return nil end

    -- Default early_exit function which never exits.
    local early_exit = args.early_exit or function() return nil end

    local output = {}
    -- Include the origin tile.
    local origin_tile = { x = args.tile_x, y = args.tile_y, distance = 0,
                                            tile_content = {
                                                terrain = self.map:getTileProperties("terrain", args.tile_x + 1, args.tile_y + 1).terrain,
                                                special_property = self.map:getTileProperties("special_area", args.tile_x + 1, args.tile_y + 1).type,
                                                unit = self:get_unit(args.tile_x, args.tile_y)
                                            },
                                            come_from = "origin"
    }
    origin_tile.trigger_early_exit = early_exit(origin_tile)
    output[key(args.tile_x, args.tile_y)] = origin_tile

    -- Initiate the frontier, with a queue for each unit of distance.
    -- The frontier index is one less than the distance since Lua indexs start from 1.
    local frontiers = {}
    
    for i = 1, args.distance + 1 do
        frontiers[i] = queue.create()
    end

    -- If the origin tile itself qualifies for early_exit, then skip the rest.
    if origin_tile.trigger_early_exit then
        goto early_exit_loop
    end


    -- Start the frontier from the first tile.
    frontiers[1]:push(output[key(args.tile_x, args.tile_y)])

    -- Each iteration increases the distance.
    for i = 1, args.distance do
        -- Expand each frontier in current distance.
        while not frontiers[i]:empty() do
            local current = frontiers[i]:pop()
            for k, tile in pairs(self:get_adjacent_tiles(current.x, current.y)) do
                -- Get the terrain and unit on tile.
                local terrain
                local special_property
                local unit_on_tile

                -- Check if tile is still in bound, if it's out of bound then terrain and unit_on_tile will be nil.
                if tile.x >= 0 and tile.y >= 0 and tile.x < self.map.width and tile.y < self.map.height then
                    terrain = self.map:getTileProperties("terrain", tile.x + 1, tile.y + 1).terrain
                    special_property = self.map:getTileProperties("special_area", tile.x + 1, tile.y + 1).type
                    unit_on_tile = self:get_unit(tile.x, tile.y)
                end

                -- Get the cost to traverse the terrain using the unit's filter, e.g. ground units need 2 movement
                -- unit to traverse a forest terrain.
                -- Or to make it impassable if there's an enemy unit occupying it.
                local cost = movement_filter(terrain, unit_on_tile)

                -- Check if tile is landable, e.g. if there's an allied unit the tile is unlandable.
                local unlandable = unlandable_filter(terrain, unit_on_tile)

                -- If tile is in bound, not already in output, and is not impassable, and the distance to the tile is not larger than the max distance
                -- add it to output and frontier.
                if  (tile.x >= 0 and tile.y >= 0 and tile.x < self.map.width and tile.y < self.map.height) and
                    output[key(tile.x, tile.y)] == nil and cost ~= "impassable" and i - 1 + cost <= args.distance then

                    local output_tile = { x = tile.x, y = tile.y, distance = i - 1 + cost, unlandable = unlandable, come_from = { x = current.x, y = current.y },
                    tile_content = { terrain = terrain, unit = unit_on_tile, special_property = special_property }}
                    output_tile.trigger_early_exit = early_exit(output_tile)

                    output[key(tile.x, tile.y)] = output_tile
                    frontiers[i + cost]:push(output[key(tile.x, tile.y)])

                    if early_exit(output_tile) then
                        goto early_exit_loop
                    end
                end
            end
        end
    end
    ::early_exit_loop::

    -- Mark tiles where it is less than minimum distance.
    for k, tile in pairs(output) do
        if args.min_distance then
            if tile.distance < args.min_distance then
                output[k].unlandable = true
            end
        end
    end

    return output
end