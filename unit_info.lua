unit_info = {}

function unit_info.create(observer, ui, x, y)
    local self = { observer = observer, ui = ui, x = x, y = y }
    setmetatable(self, {__index = unit_info})

    self.listeners = {
        self.observer:add_listener("cursor_moved", function() self:set_displayed_unit_from_cursor() end),
        self.observer:add_listener("unit_deleted", function(unit) self:handle_unit_deletion(unit) end),
    }

    return self
end

function unit_info:destroy()
    observer.remove_listeners_from_object(self)
end

function unit_info:set_displayed_unit(unit)
    self.displayed_unit = unit
end

function unit_info:set_displayed_unit_from_cursor()
    local ui = self.ui

    local unit_on_cursor = ui.world:get_unit(ui.cursor.tile_x, ui.cursor.tile_y)
    local selected_unit = ui.selected_unit

    if unit_on_cursor then
        self:set_displayed_unit(unit_on_cursor)
    elseif selected_unit then
        self:set_displayed_unit(selected_unit)
    end
end

-- If the deleted unit is the displayed_unit, remove it.
function unit_info:handle_unit_deletion(unit)
    if unit == self.displayed_unit then
        self.displayed_unit = nil
    end
end

function unit_info:draw()
    local unit = self.displayed_unit
    if unit then
        local info = string.format("%s\nHealth: %i\nStrength: %i\nDefense: %i\nMagic: %i\nResistance: %i\nSkill: %i\nSpeed: %i\n",
            unit.name, unit.data.health, unit.strength, unit.defense, unit.magic, unit.resistance, unit.skill, unit.speed)
        if not is_empty(unit.data.weapons) then
            info = info .. "Weapons:\n"
            for i, weapon in ipairs(unit.data.weapons) do
                info = info .. "- " .. weapon.name

                if i == unit.data.active_weapon then 
                    info = info .. " [e]"
                end

                info = info .. "\n"
            end
        end
        if not is_empty(unit.data.specials) then
            info = info .. "Specials:\n"
            for i, special in ipairs(unit.data.specials) do
                info = info .. "- " .. special.name .. "\n"
            end
        end
        love.graphics.print(info, self.x, self.y)
    end
end