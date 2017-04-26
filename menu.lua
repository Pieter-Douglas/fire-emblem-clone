require("utility")

menu = {}

function menu.create(ui, menu_type, tile_x, tile_y)
    local self = { ui = ui, menu_type = menu_type, tile_x = tile_x, tile_y = tile_y }
    setmetatable(self, { __index = menu })

    self:generate_content()

    return self
end

function menu:generate_content()
    self.items = {}
    self.actions = {}
    self.pointer = 1

    if self.menu_type == "action" then
        self.items  = { "Wait", "Attack", "Items" }
        self.actions = { "wait", "attack", "items" }
    elseif self.menu_type == "turn" then
        self.items = { "End turn" }
        self.actions = { "end_turn" }
    end

    self.item_count = #self.items
end

function menu:control(input_queue)
    for input, data in pairs(input_queue) do
        -- Move the selected item with keys.
        if input == "up" then
            -- self.scroll_sound:play()
            if self.pointer == 1 then
                self.pointer = self.item_count    -- If self.pointer is at first item, set it to the last item.
            else
                self.pointer = self.pointer - 1
            end
        elseif input == "down" then
            -- self.scroll_sound:play()
            if self.pointer == self.item_count then
                self.pointer = 1             -- If self.pointer is at last item, set it to the first item.
            else
                self.pointer = self.pointer + 1
            end
        elseif input == "select" then
            -- self.select_sound:play()
            -- Push feedback to ui.
            self:push_action(self.actions[self.pointer])
        elseif input == "cancel" then
            self:push_action("cancel")
        elseif input == "mouse_pressed" then
            self:mouse_pressed(data)
        end
    end
end

function menu:mouse_pressed(data)
    if data.button == 1 then
        local index = self:get_index_from_coordinate(data.x, data.y)

        if index >= 1 and index <= self.item_count then
            if self.pointer == index then
                self:push_action(self.actions[self.pointer])
            else
                self.pointer = index
            end
        end
    end
    if data.button == 2 then
        self:push_action("cancel")
    end
end

function menu:get_index_from_coordinate(x, y)
    -- Only works if font height is the same as tile_size.
    local tile_x, tile_y = self.ui.game:get_tile_from_coordinate(x, y)
    local index = tile_y - self.tile_y + 1
    return index
end

function menu:push_action(action)
    local feedback = {}
    feedback.action = action

    self.ui:receive_feedback(feedback)
end

function menu:draw()
    local output = ""

    for i = 1, self.item_count do
        -- If the item is selected print the character '-' in front of it, else it's blank or a space.
        if i == self.pointer then
            output = output .. "-"
        else
            output = output .. " "
        end
        output = output .. self.items[i] .. "\n"
    end

    love.graphics.print(output, self.tile_x * tile_size, self.tile_y * tile_size)
end