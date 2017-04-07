cursor = {
    sprite = love.graphics.newImage("assets/cursor.png")
}
cursor.sprite:setFilter("nearest")

function cursor.create(tile_x, tile_y)
    local self = { tile_x = tile_x, tile_y = tile_y }
    setmetatable(self, { __index = cursor })

    self.input_map = { w = "up", r = "down", a = "left", s = "right" }
    self.move_queue = { up = false, down = false, left = false, right = false }
    -- Timer is countdown in tick (1/60 second).
    -- Timer for rapid input when button is held.
    self.rapid_time = 10
    -- Timer for subsequent movements when rapid input is activated.
    self.rapid_rate = 3
    self.move_timer = { up = self.rapid_time, down = self.rapid_time, left = self.rapid_time, right = self.rapid_time }

    return self
end

function cursor:draw()
    love.graphics.draw(self.sprite, self.tile_x * app.tile_size, self.tile_y * app.tile_size)
end

function cursor:update()
    local tile_axis = { up = "tile_y", down = "tile_y", left = "tile_x", right = "tile_x" }
    local origin_direction = { up = -1, down = 1, left = -1, right = 1 }
    local opposite = {up = "down", down = "up", left = "right", right = "left" }

    for key, d in pairs(self.input_map) do  -- d = direction
        if self.move_queue[d] or self.move_timer[d] == 0 then
            self[tile_axis[d]] = self[tile_axis[d]] + origin_direction[d]
            self.move_queue[d] = false
            if self.move_timer[d] == 0 then
                self.move_timer[d] = self.rapid_rate
            end
        end

        if love.keyboard.isDown(key) and self.move_timer[d] ~= 0 then
            self.move_timer[d] = self.move_timer[d] - 1
            self.move_timer[opposite[d]] = self.rapid_time
        end
    end
end

function cursor:process_input(key, pressed)
    -- If pressed is false the event is key_released.
    local input = self.input_map[key]
    if input ~= nil then
        if pressed then
            self.move_queue[input] = true
        else
            self.move_timer[input] = self.rapid_time
        end
    end
end

function cursor:get_position()
    return self.tile_x * app.tile_size, self.tile_y * app.tile_size
end