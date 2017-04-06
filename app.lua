application = {
    tile_size = 16
}

function application.create()
    local self = {}
    setmetatable(self, { __index = application })

    self.cursor = cursor.create(8, 8)
    self.world = world.create()
    return self
end

function application:update()
    self.world:update()
end

function application:draw()
    love.graphics.push()
    local zoom = 2
    love.graphics.scale(zoom)

    local cursor_x, cursor_y = self.cursor:get_position()
    love.graphics.translate(love.graphics.getWidth() / zoom / 2 - cursor_x - (tile_size / 2), love.graphics.getHeight() / zoom / 2 - cursor_y - (tile_size / 2))

    self.world:draw()
    self.cursor:draw()
    love.graphics.pop()
end

function application:keypressed(key)
    if key == "escape" then
        love.window.close()
    end
    
    if key == "w" then
        app.cursor.tile_y = app.cursor.tile_y - 1
    end
    if key == "r" then
        app.cursor.tile_y = app.cursor.tile_y + 1
    end
    if key == "a" then
        app.cursor.tile_x = app.cursor.tile_x - 1
    end
    if key == "s" then
        app.cursor.tile_x = app.cursor.tile_x + 1
    end
end