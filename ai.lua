require("generate_path")

ai = {}

function ai.create(observer, game, world)
    local self = { observer = observer, game = game, world = world }
    setmetatable(self, {__index = ai})

    return self
end

function ai:set_team(team)
    self.team = team
end

function ai:do_step()
    local units = self.world:get_all_units()
    local move_unit_flag = false

    for k, unit in pairs(units) do
        if unit.data.team == self.team and not unit.data.moved then
            -- Get where the unit would move and feed it to attack position.
            local x_move, y_move = self:move_unit(unit)
            
            self:attempt_capture_defense_point(unit, x_move, y_move)
            self:attack_enemy_in_range(unit, x_move, y_move)

            move_unit_flag = true
            break
        end
    end

    if not move_unit_flag then
        self.game:new_turn()
    end
end

function ai:move_unit(unit)
    local move_command = { action = "move_unit" }
    local game_mode = self.game.game_mode

    local x, y, path

    if game_mode == "death_match" then 
        x, y, path = self:move_to_nearest_enemy(unit)
    elseif game_mode == "defense" then
        x, y, path = self:move_to_closest_objective(unit)
    end

    move_command.data = { unit = unit, tile_x = x, tile_y = y, path = path }

    self.world:receive_command(move_command)

    return x, y
end

function ai:move_to_closest_objective(unit)
    local function key(x, y) return string.format("(%i, %i)", x, y) end

    -- Early exit defense tile is found.
    local function early_exit(tile)
        return not tile.unlandable and tile.tile_content.special_property == "defense"
    end

    local traversed_tiles = self.world:get_tiles_in_distance({distance = 100, tile_x = unit.tile_x, tile_y = unit.tile_y, early_exit = early_exit, movement_filter = unit.movement_filter, unlandable_filter = unit.unlandable_filter})

    -- Find the nearest spot where the unit can attack an enemy.
    local nearest_objective

    for key, tile in pairs(traversed_tiles) do
        if tile.trigger_early_exit then
            nearest_objective = tile
        end
    end

    -- If there's a spot that the unit can attack from, move to get closer to it
    -- If there's none, seek nearest enemy.
    if nearest_objective then
        local furthest_traversable_spot = nearest_objective

        while furthest_traversable_spot.distance > unit.movement or furthest_traversable_spot.unlandable do
            furthest_traversable_spot = traversed_tiles[key(furthest_traversable_spot.come_from.x, furthest_traversable_spot.come_from.y)]
        end

        local path = generate_path(furthest_traversable_spot, traversed_tiles)

        return furthest_traversable_spot.x, furthest_traversable_spot.y, path
    else
        local x, y, path = self:move_to_nearest_enemy(unit)

        return x, y, path
    end
end

function ai:move_to_nearest_enemy(unit)
    local function key(x, y) return string.format("(%i, %i)", x, y) end

    -- Early exit if the unit can attack from the position.
    local function early_exit(tile)
        if not tile.unlandable then
            local attack_area = unit:get_attack_area(self.world, tile.x, tile.y, unit.data.weapons)

            for key, tile in pairs(attack_area) do
                if tile.tile_content.unit then
                    if tile.tile_content.unit.data.team ~= unit.data.team then
                        return true
                    end
                end
            end
        end
    end

    local traversed_tiles = self.world:get_tiles_in_distance({distance = 100, tile_x = unit.tile_x, tile_y = unit.tile_y, early_exit = early_exit, movement_filter = unit.movement_filter, unlandable_filter = unit.unlandable_filter})

    -- Find the nearest spot where the unit can attack an enemy.
    local nearest_attacking_spot

    for key, tile in pairs(traversed_tiles) do
        if tile.trigger_early_exit then
            nearest_attacking_spot = tile
        end
    end

    -- If there's a spot that the unit can attack from, move to get closer to it
    -- If there's none, stay
    if nearest_attacking_spot then
        local furthest_traversable_spot = nearest_attacking_spot

        while furthest_traversable_spot.distance > unit.movement or furthest_traversable_spot.unlandable do
            furthest_traversable_spot = traversed_tiles[key(furthest_traversable_spot.come_from.x, furthest_traversable_spot.come_from.y)]
        end

        local path = generate_path(furthest_traversable_spot, traversed_tiles)

        return furthest_traversable_spot.x, furthest_traversable_spot.y, path
    else
        local path = generate_path(traversed_tiles[key(unit.tile_x, unit.tile_y)], traversed_tiles)

        return unit.tile_x, unit.tile_y, path
    end
end

-- Attack a random enemy within range.
function ai:attack_enemy_in_range(unit, x, y)
    local attack_area = unit:get_attack_area(self.world, x, y, unit.data.weapons)

    local enemies_in_range = {}

    for key, tile in pairs(attack_area) do
        if tile.tile_content.unit then
            local unit_on_tile = tile.tile_content.unit

            if unit_on_tile.data.team ~= unit.data.team then
                table.insert(enemies_in_range, unit_on_tile)
            end
        end
    end

    if #enemies_in_range ~= 0 then
        local random_enemy = enemies_in_range[ math.random(#enemies_in_range) ]

        local attack_command = { action = "attack" }
        attack_command.data = { unit = unit, tile_x = random_enemy.tile_x, tile_y = random_enemy.tile_y }

        self.world:receive_command(attack_command)
    end
end

-- Capture defense point if standing on one.
function ai:attempt_capture_defense_point(unit, x, y)
    local end_tile

    for key, tile in pairs(self.world:get_tiles_in_distance({tile_x = x, tile_y = y, distance = 0})) do
        end_tile = tile
    end

    if end_tile.tile_content.special_property == "defense" then
        self.world:capture_defense_point()
    end
end