--[[
    GD50
    Breakout Remake

    -- Brick Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents a brick in the world space that the ball can collide with;
    differently colored bricks have different point values. On collision,
    the ball will bounce away depending on the angle of collision. When all
    bricks are cleared in the current map, the player should be taken to a new
    layout of bricks.
]]

local EventBus = require 'src/model/EventBus'
local Events = require 'src/model/Events'
local Object = require 'src/Object'

local BrickUnbreakable = Object()

function BrickUnbreakable:initialize(x, y)
    self.x = x
    self.y = y
    self.width = 32
    self.height = 16
end

function BrickUnbreakable:hit()
    EventBus:notify(Events.BRICK_UNBREAKABLE_HIT, self)
end

function BrickUnbreakable:level()
    return 0
end

function BrickUnbreakable:in_play()
    return true
end

return BrickUnbreakable