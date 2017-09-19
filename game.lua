require("cursor")
require("ai")
require("ui")
require("world")
require("animation")
require("team")
require("color")
require("camera")
require("pause_menu")
require("result_screen")

game = {}

function game.create(application, observer)
    local self = { application = application, observer = observer }
    setmetatable(self, {__index = game})

    self.teams = {
        team.create("Player 1 Army", color.create_from_rgb(25, 83, 255), "player"),
        team.create("Player 2 Army", color.create_from_rgb(255, 25, 25), "ai"),
    }

    self.current_turn = self.teams[1]
    self.current_turn_number = 1

    self.is_paused = false

    self.pause_menu = pause_menu.create(self.application)
    self.animation = animation.create(self.observer)
    self.world = world.create(self.observer, self.teams, self.animation)
    self.ui = ui.create(self.observer, self, self.world)
    self.ai = ai.create(self.observer, self, self.world)
    self.camera = camera.create(self.observer, self.ui)

    self.listeners = {
        self.observer:add_listener("game_end", function(args) self:game_end(args) end)
    }

    return self
end

function game:destroy()
    self.world:destroy()
    self.ui:destroy()
    self.camera:destroy()

    -- Remove listeners from observer.
    observer.remove_listeners_from_object(self)
end

function game:game_end(args)
    self.application:change_state(result_screen, args)
end

function game:new_turn()
    self.observer:notify("new_turn")

    -- Change current turn, cycle if previous turn is the last team.
    self.current_turn_number = self.current_turn_number + 1
    if self.current_turn_number > #self.teams then
        self.current_turn_number = 1
    end

    self.current_turn = self.teams[self.current_turn_number]
end

function game:update()
    -- Camera is moveable both during and outside animation.
    self.camera:update()
    self.world:update_animation()

    if self.is_paused then
        self.pause_menu:update()
    elseif self.animation.active then
        self.animation:update()
    else
        self.ui:update()
        if self.current_turn.controller == "ai" then
            self.ai:set_team(self.current_turn)
            self.ai:do_step()
        end
        self.world:update()
    end
end

function game:draw()
    -- Draw the world and animation with cursor at the center of the screen.
    love.graphics.push()
        self.camera:set_translate()
        self.camera:set_zoom()

        self.world:draw("tiles")
        self.ui:draw("areas")
        self.ui:draw("cursor")
        self.world:draw("units")
        self.ui:draw("selected_unit")
        self.world:draw("health_bars")

        -- Draw animation if active.
        if self.animation.active then
            self.animation:draw()
        end
    love.graphics.pop()

    love.graphics.push()
        self.ui:draw("hud")
        self.ui:draw("menu")
    love.graphics.pop()

    if self.is_paused then
        self.pause_menu:draw()
    end
end

function game:process_event(event)
    if event.type == "key_pressed" and event.data.key == "p" then
        self.is_paused = not self.is_paused
    end

    self.camera:process_event(event)

    if self.is_paused then
        self.pause_menu:process_event(event)
    else
        if self.current_turn.controller == "player" then
            self.ui:process_event(event)
        end
    end
end

