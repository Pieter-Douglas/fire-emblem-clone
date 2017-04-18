require("utility")

action_menu = {}

function action_menu.create(ui, tile_x, tile_y)
    local self = { ui = ui, tile_x = tile_x, tile_y = tile_y }
    setmetatable(self, { __index = action_menu })

    self:generate_content()

    return self
end

function action_menu:generate_content()
    self.items = {}
    self.actions = {}
    self.pointer = 1

    self.items  = { "Wait", "Attack", "Items" }
    self.actions = { "wait", "attack", "items" }

    self.item_count = #self.items
end

function action_menu:control(input_queue)
    for input in pairs(input_queue) do
        -- Move the selected item with keys.
        if input == "up" then
            -- self.scroll_sound:play()
            if self.pointer == 1 then
                self.pointer = self.item_count    -- If self.pointer is at first item, set it to the last item.
            else
                self.pointer = self.pointer - 1
            end
        end
        if input == "down" then
            -- self.scroll_sound:play()
            if self.pointer == self.item_count then
                self.pointer = 1             -- If self.pointer is at last item, set it to the first item.
            else
                self.pointer = self.pointer + 1
            end
        end
        if input == "select" then
            -- self.select_sound:play()
            -- Push feedback to ui.
            self:push_action(self.actions[self.pointer])
        end
        if input == "cancel" then
            self:push_action("cancel")
        end
    end
end

function action_menu:push_action(action)
    local feedback = {}
    feedback.action = action

    self.ui:receive_feedback(feedback)
end

function action_menu:draw()
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