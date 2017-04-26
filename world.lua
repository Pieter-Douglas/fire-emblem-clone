require("animation")
require("unit")
require("unit_class")
require("unit_layer")
require("weapon_class")
require("queue")
require("debug")

local sti = require "libs/Simple-Tiled-Implementation/sti"

world = {
    
}

function world.create(observer, teams, animation)
    local self = {observer = observer, teams = teams, animation = animation}
    setmetatable(self, {__index = world})

    self.map = sti("maps/test_map.lua")

    self.command_queue = {}

    local unit_layer = unit_layer.create(self.map, self.observer)

    -- Create player units.
    unit_layer:create_unit(unit_class.sword_fighter, 0, 0, { weapon = weapon_class.iron_sword, team = self.teams[1] })
    unit_layer:create_unit(unit_class.axe_fighter, 3, 5, { weapon = weapon_class.iron_axe, team = self.teams[1] })
    unit_layer:create_unit(unit_class.lance_fighter, 2, 10, { weapon = weapon_class.iron_lance, team = self.teams[1] })
    unit_layer:create_unit(unit_class.bow_fighter, 4, 8, { weapon = weapon_class.iron_bow, team = self.teams[1] })

    -- Create enemy units.
    unit_layer:create_unit(unit_class.sword_fighter, 3, 14, { weapon = weapon_class.iron_sword, team = self.teams[2] })
    unit_layer:create_unit(unit_class.sword_fighter, 29, 29, { weapon = weapon_class.iron_sword, team = self.teams[2] })
    unit_layer:create_unit(unit_class.axe_fighter, 26, 24, { weapon = weapon_class.iron_axe, team = self.teams[2] })
    unit_layer:create_unit(unit_class.lance_fighter, 27, 20, { weapon = weapon_class.iron_lance, team = self.teams[2] })
    unit_layer:create_unit(unit_class.bow_fighter, 22, 26, { weapon = weapon_class.iron_bow, team = self.teams[2] })

    self.observer:add_listener("new_turn", function() self:new_turn() end)

    return self
end

function world:receive_command(command)
    table.insert(self.command_queue, command)
end

function world:process_command_queue()
    for k, command in pairs(self.command_queue) do
        local data = command.data
        if command.action == "move_unit" then
            self:move_unit(data.unit, data.tile_x, data.tile_y)
        end
        if command.action == "attack" then
            self:combat(data.unit, data.tile_x, data.tile_y)
        end

        self.observer:notify("world_changed")
    end

    self.command_queue = {}
end

function world:combat(attacker, tile_x, tile_y)
    local attack_power = attacker.strength + attacker.data.weapon.power

    local target_unit = self:get_unit(tile_x, tile_y)

    if target_unit then
        target_unit.data.health = target_unit.data.health - attack_power

        -- Regenerate health_bar display since health is changed.
        target_unit:generate_health_bar()

        if target_unit.data.health <= 0 then
            local unit_layer = self.map.layers.unit_layer
            unit_layer:delete_unit(target_unit)
        end
    end

    -- Construct animation from combat.
    local animation = { type = "attack" }
    animation.data = { attacker = attacker, tile_x = tile_x, tile_y = tile_y }

    self.animation:receive_animation(animation)
end

function world:new_turn()
    -- Uncheck 'moved' flag on every unit.
    for k, unit in pairs(self:get_all_units()) do
        unit.data.moved = false
    end
end

function world:update()
    self:process_command_queue()

    self.map:update()
end

function world:draw(component)
    if component == "tiles" then
        for i, layer in ipairs(self.map.layers) do
            if layer.type == "tilelayer" and layer.visible and layer.opacity > 0 then
                self.map:drawTileLayer(layer)
            end
        end
    elseif component == "units" then
        self.map.layers.unit_layer:draw()
    end
end

function world:get_unit(tile_x, tile_y)
    return self.map.layers.unit_layer:get_unit(tile_x, tile_y)
end

function world:get_all_units()
    return self.map.layers.unit_layer:get_all_units()
end

function world:move_unit(unit, tile_x, tile_y)
    self.map.layers.unit_layer:move_unit(unit, tile_x, tile_y)

    -- Mark unit as moved.
    unit.data.moved = true
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

function world:get_tiles_in_distance(arg)
    local function key(x, y) return string.format("(%i, %i)", x, y) end

    -- Movement filter defaults to treat everything as 1 value for weapon.
    local movement_filter = arg.movement_filter or function() return 1 end
    -- Unlandable filter defaults to treat everything as landable.
    local unlandable_filter = arg.unlandable_filter or function() return nil end

    local output = {}
    output[key(arg.tile_x, arg.tile_y)] = { x = arg.tile_x, y = arg.tile_y, distance = 0 }

    -- Initiate the frontier, with a queue for each unit of distance.
    -- The frontier index is one less than the distance since Lua indexs start from 1.
    local frontiers = {}
    for i = 1, arg.distance + 1 do
        frontiers[i] = queue.create()
    end

    -- Start the frontier from the first tile.
    frontiers[1]:push(output[key(arg.tile_x, arg.tile_y)])

    -- Each iteration increases the distance.
    for i = 1, arg.distance do
        -- Expand each frontier in current distance.
        while not frontiers[i]:empty() do
            local current = frontiers[i]:pop()
            for k, tile in pairs(self:get_adjacent_tiles(current.x, current.y)) do
                -- Get the terrain and unit on tile.
                local terrain
                local unit_on_tile

                -- Check if tile is still in bound, if it's out of bound then terrain and unit_on_tile will be nil.
                if tile.x >= 0 and tile.y >= 0 and tile.x < self.map.width and tile.y < self.map.height then
                    terrain = self.map:getTileProperties("terrain", tile.x + 1, tile.y + 1).terrain
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
                    output[key(tile.x, tile.y)] == nil and cost ~= "impassable" and i - 1 + cost <= arg.distance then
                    output[key(tile.x, tile.y)] = { x = tile.x, y = tile.y, distance = i - 1 + cost, unlandable = unlandable }
                    frontiers[i + cost]:push(output[key(tile.x, tile.y)])
                end
            end
        end
    end

    -- Filter out tiles where it is less than minimum distance or unlandable (for example because there's an allied unit on the tile).

    for k, tile in pairs(output) do
        if arg.min_distance then
            if tile.distance < arg.min_distance then
                output[k] = nil
            end
        end
        if tile.unlandable then
            output[k] = nil
        end
    end

    return output
end