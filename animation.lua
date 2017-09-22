require("queue")
require("attack_animation")
require("wait_animation")
require("move_animation")
require("special_animation")

animation = {
    colorize_shader = love.graphics.newShader("shaders/colorize_shader.fs"),
}

function animation.create(observer)
    local self = { observer = observer }
    setmetatable(self, {__index = animation})

    self.active = false

    self.animation_queue = queue.create()
    self.current_animation = nil

    return self
end

-- Side effect: hides actors in the animation
function animation:receive_animation(animation)
    self.animation_queue:push(animation)
    self.active = true

    self:hide_actors(animation)
end

-- Currently not hiding attack and wait animation since it is queued long after move animation
-- when moving, hiding the target while the attacker moves.
function animation:hide_actors(animation)
    -- if animation.type == "attack" then
    --     animation.data.attacker.hidden = true
    --     animation.data.target.hidden = true
    -- elseif animation.type == "wait" then
    --     animation.data.attacker.hidden = true
    --     animation.data.target.hidden = true
    if animation.type == "move" then
        animation.data.unit.hidden = true
    end
end

function animation:process_animation_queue()
    if not self.animation_queue:empty() then
        local animation = self.animation_queue:pop()
        if animation.type == "attack" then
            self.current_animation = attack_animation.create(animation.data)
        elseif animation.type == "special" then
            self.current_animation = special_animation.create(animation.data)
        elseif animation.type == "wait" then
            self.current_animation = wait_animation.create(animation.data)
        elseif animation.type == "move" then
            self.current_animation = move_animation.create(animation.data)
        end
    else
        self.active = false

        self.observer:notify("animation_ended")
    end
end

function animation:update_current_animation()
    self.current_animation:update()
end

function animation:update()
    if self.current_animation and not self.current_animation.complete then
        self:update_current_animation()
    else
        self:process_animation_queue()
    end
end

function animation:draw()
    if self.current_animation then
        self.current_animation:draw()
    end
end