unit_layer = {}

function unit_layer.create(map, observer)
    local self = map:addCustomLayer("unit_layer")
    self.observer = observer
    self.width, self.height = map.width, map.height

    -- Operation that involves self.tiles should be translated 1 since Lua index starts from 1.
    self.tiles = {}
    for y = 1, map.height do
        self.tiles[y] = {}
        for x = 1, map.width do
            self.tiles[y][x] = nil
        end
    end

    function self:draw()
        for y, column in pairs(self.tiles) do
            for x, unit in pairs(column) do
                -- Unit will be hidden during animation and when it's selected.
                if unit ~= nil and not unit.hidden then
                    local x, y = (x - 1) * unit_size, (y - 1) * unit_size

                    unit:draw("idle", x, y)
                end
            end
        end
    end

    function self:draw_health_bars()
        for y, column in pairs(self.tiles) do
            for x, unit in pairs(column) do
                -- Unit will be hidden during animation and when it's selected.
                if unit ~= nil and not unit.hidden then
                    local x, y = (x - 1) * unit_size, (y - 1) * unit_size

                    unit:draw_health_bar(x, y)
                end
            end
        end
    end

    function self:update(dt)

    end

    function self:create_unit(class, tile_x, tile_y, data)
        if tile_x >= self.width or tile_y >= self.height then error("Unit placement out of bounds") end

        local unit = unit.create(class, tile_x, tile_y, data)

        self:set_unit(unit, tile_x, tile_y)
    end

    function self:set_unit(unit, tile_x, tile_y)
        if tile_x >= self.width or tile_y >= self.height then error("Unit placement out of bounds") end

        -- Translation since lua index starts from 1.
        self.tiles[tile_y + 1][tile_x + 1] = unit
    end

    function self:get_unit(tile_x, tile_y)
        local unit

        -- Prevent nil error when tile_y is 1 or lower.
        if tile_x >= 0 and tile_y >= 0 then
            -- Translation since lua index starts from 1.
            unit = self.tiles[tile_y + 1][tile_x + 1]
        end

        return unit
    end

    function self:get_all_units()
        local units = {}

        for y = 1, self.height do
            for x = 1, self.width do
                local unit = self:get_unit(x - 1, y - 1)
                if unit then
                    table.insert(units, unit)
                end
            end
        end

        return units
    end

    function self:delete_unit(unit)
        self.observer:notify("unit_deleted", unit)

        self:set_unit(nil, unit.tile_x, unit.tile_y)
    end

    function self:move_unit(unit, end_x, end_y)
        if end_x >= self.width or end_y >= self.height then error("Unit placement out of bounds") end

        local start_x, start_y = unit.tile_x, unit.tile_y
        -- Move the actual unit in the unit's state.
        local unit = self:get_unit(start_x, start_y)
        unit:move(end_x, end_y)

        -- Change the map tiles.
        -- Translate 1 since it involves self.tiles
        self.tiles[start_y + 1][start_x + 1] = nil
        self.tiles[end_y + 1][end_x + 1] = unit
    end

    return self
end