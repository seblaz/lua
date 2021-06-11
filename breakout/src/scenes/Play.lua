--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

local table = require 'table'
local EventBus = require 'src/model/EventBus'
local Base = require 'src/scenes/Base'

local Fonts = require 'src/assets/Fonts'
local PlaySounds = require 'src/sounds/Play'

local BrickView = require 'src/views/Brick'
local BrickClouds = require 'src/views/BrickClouds'
local PaddleView = require 'src/views/Paddle'
local ScoreView = require 'src/views/Score'
local HealthView = require 'src/views/Health'
local Constants = require 'src/constants'

local Play = Base()

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function Play:enter(params)
    self.paddle = params.paddle
    self.paddleView = params.paddleView
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.ballView = params.ballView
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball.dx = math.random(-200, 200)
    self.ball.dy = math.random(-50, -60)

    -- Views
    local clouds = BrickClouds()
    self.views = table.map(self.bricks, BrickView)
    table.insert(self.views, clouds)
    table.insert(self.views, self.paddleView)
    table.insert(self.views, self.ballView) -- Recibo el ballView de otra escena para que mantenga la misma vista y no inicialice otra
    table.insert(self.views, ScoreView(self.score))
    table.insert(self.views, HealthView(self.health))

    -- Models
    self.models = {self.paddle, self.ball, clouds}

    -- Sounds
    self.sounds = PlaySounds()
end

function Play:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            Constants.gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        Constants.gSounds['pause']:play()
        return
    end

    -- update model based on velocity
    table.apply(self.models, function(model) model:update(dt) end)

    if self.ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        self.ball.y = self.paddle.y - 8
        self.ball.dy = -self.ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

        -- if we hit the paddle on its left side while moving left...
        if self.ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
            self.ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.ball.x))

        -- else if we hit the paddle on its right side while moving right...
        elseif self.ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
            self.ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.ball.x))
        end

        Constants.gSounds['paddle-hit']:play()
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick:in_play() and self.ball:collides(brick) then

            -- add to score
            self.score:add(brick:level() * 25)

            -- trigger the brick's hit function, which removes it from play
            brick:hit()

            -- if we have enough points, recover a point of health
            -- this had a bug because it always added one more health above xxx points
            --if self.score:points() > self.recoverPoints then
            --    -- can't go above 3 health
            --    self.health = math.min(3, self.health + 1)
            --
            --    -- multiply recover points by 2
            --    self.recoverPoints = math.min(100000, self.recoverPoints * 2)
            --
            --    -- play recover sound effect
            --    Constants.gSounds['recover']:play()
            --end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                Constants.gSounds['victory']:play()

                EventBus:reset()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    paddleView = self.paddleView,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.ball,
                    ballView = self.ballView, -- Le paso el ballView al victory para que mantenga la misma vista y no inicialice otra
                    recoverPoints = self.recoverPoints
                })
            end

            --
            -- collision code for bricks
            --
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 
            --

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if self.ball.x + 2 < brick.x and self.ball.dx > 0 then

                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x - 8

            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif self.ball.x + 6 > brick.x + brick.width and self.ball.dx < 0 then

                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x + 32

            -- top edge if no X collisions, always check
            elseif self.ball.y < brick.y then

                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y - 8

            -- bottom edge if no X collisions or top collision, last possibility
            else

                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(self.ball.dy) < 150 then
                self.ball.dy = self.ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if self.ball.y >= Constants.VIRTUAL_HEIGHT then
        self.health:decrease()
        Constants.gSounds['hurt']:play()

        if not self.health:is_alive() then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            gStateMachine:change('serve', {
                paddle = self.paddle,
                paddleView = self.paddleView,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints
            })
        end
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function Play:render()
    table.apply(self.views, function(view) view:render() end)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(Fonts:get('large'))
        love.graphics.printf("PAUSED", 0, Constants.VIRTUAL_HEIGHT / 2 - 16, Constants.VIRTUAL_WIDTH, 'center')
    end
end

function Play:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick:in_play() then
            return false
        end
    end

    return true
end

return Play