cursor = {
    sprite = {
        move = love.graphics.newImage("assets/cursor_move.png"),
        attack = love.graphics.newImage("assets/cursor_attack.png"),
    }
}
cursor.sprite.move:setFilter("nearest")
cursor.sprite.attack:setFilter("nearest")

function cursor.create(ui, tile_x, tile_y)
    local self = { ui = ui, tile_x = tile_x, tile_y = tile_y }
    setmetatable(self, { __index = cursor })

    self.state = "move"

    return self
end

function cursor:draw()
    local sprite = self.sprite[self.state]
    love.graphics.draw(sprite, self.tile_x * tile_size, self.tile_y * tile_size)
end

function cursor:update()

end

function cursor:control(input_queue)
    local input_type = { up = "move", down = "move", left = "move", right = "move", select = "select", cancel = "cancel" }

    for input in pairs(input_queue) do
        local input_type = input_type[input]
        if input_type == "move" then
            self:move(input)
        end
        if input_type == "select" then
            self:select()
        end
        if input_type == "cancel" then
            self:cancel()
        end
    end
end

function cursor:move(direction)
    local tile_axis = { up = "tile_y", down = "tile_y", left = "tile_x", right = "tile_x" }
    local origin_direction = { up = -1, down = 1, left = -1, right = 1 }

    -- Make cursor unmoveable to outside border.
    if self[tile_axis[direction]] + origin_direction[direction] >= 0 then
        self[tile_axis[direction]] = self[tile_axis[direction]] + origin_direction[direction]
    end
end

function cursor:select()
    local feedback = { action = "select" }
    feedback.data = { tile_x = self.tile_x, tile_y = self.tile_y }

    self.ui:receive_feedback(feedback)
end

function cursor:cancel()
    local feedback = { action = "cancel" }
    feedback.data = { tile_x = self.tile_x, tile_y = self.tile_y }

    self.ui:receive_feedback(feedback)
end

function cursor:get_position()
    return self.tile_x * tile_size, self.tile_y * tile_size
end

function cursor:get_unit()
    return self.ui.world:get_unit(self.tile_x, self.tile_y)
end