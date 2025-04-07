-- Roguelike Deckbuilder Game
-- Module structure with state management

-- =====================================
-- Configuration
-- =====================================
local Config = {
    WINDOW_WIDTH = 800,
    WINDOW_HEIGHT = 600,
    CARD_WIDTH = 100,
    CARD_HEIGHT = 150,
    STARTING_STRIKES = 5,
    STARTING_DEFENDS = 5,
    HAND_SIZE = 5,
    REWARD_OPTIONS = 3
}

-- =====================================
-- Utility Functions
-- =====================================
local Utils = {}

function Utils.deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = Utils.deepCopy(orig_value)
        end
        setmetatable(copy, Utils.deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function Utils.shuffle(t)
    for i = #t, 2, -1 do
        local j = love.math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- =====================================
-- Game Data
-- =====================================
local GameData = {}

-- Card templates
GameData.CardTemplates = {
    {name = "Strike", type = "attack", cost = 1, damage = 6, description = "Deal 6 damage", color = {0.8, 0.2, 0.2}},
    {name = "Defend", type = "skill", cost = 1, block = 5, description = "Gain 5 block", color = {0.2, 0.6, 0.8}},
    {name = "Bash", type = "attack", cost = 2, damage = 8, vulnerable = 2, description = "Deal 8 damage\nApply 2 Vulnerable", color = {0.8, 0.2, 0.2}},
    {name = "Cleave", type = "attack", cost = 1, damage = 4, aoe = true, description = "Deal 4 damage to ALL enemies", color = {0.8, 0.2, 0.2}},
    {name = "Shrug It Off", type = "skill", cost = 1, block = 8, draw = 1, description = "Gain 8 block\nDraw 1 card", color = {0.2, 0.6, 0.8}},
    {name = "Pommel Strike", type = "attack", cost = 1, damage = 9, draw = 1, description = "Deal 9 damage\nDraw 1 card", color = {0.8, 0.2, 0.2}},
    {name = "Anger", type = "attack", cost = 0, damage = 6, copy = true, description = "Deal 6 damage\nAdd a copy to discard pile", color = {0.8, 0.2, 0.2}},
    {name = "Iron Wave", type = "attack", cost = 1, damage = 5, block = 5, description = "Deal 5 damage\nGain 5 block", color = {0.8, 0.4, 0.2}}
}

-- Enemy templates
GameData.EnemyTemplates = {
    {name = "Slime", health = 30, maxHealth = 30, damage = 8, intents = {"attack"}, color = {0.5, 0.7, 0.3}},
    {name = "Goblin", health = 25, maxHealth = 25, damage = 10, intents = {"attack", "defend"}, color = {0.7, 0.5, 0.2}},
    {name = "Cultist", health = 20, maxHealth = 20, damage = 6, buff = 3, intents = {"attack", "buff"}, color = {0.5, 0.2, 0.7}}
}

-- =====================================
-- Class System
-- =====================================
local Class = {}
function Class.new(base)
    local c = {}
    c.__index = c
    
    function c:new(...)
        local instance = setmetatable({}, self)
        if instance.init then instance:init(...) end
        return instance
    end
    
    if base then
        setmetatable(c, {__index = base})
    end
    
    return c
end

-- =====================================
-- Entity Classes
-- =====================================

-- Card Class
local Card = Class.new()

function Card:init(template)
    for k, v in pairs(template) do
        self[k] = v
    end
end

function Card:render(x, y, selected)
    -- Draw card background
    local borderWidth = selected and 3 or 1
    
    -- Card base
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", x, y, Config.CARD_WIDTH, Config.CARD_HEIGHT)
    
    -- Card border
    love.graphics.setColor(selected and {1, 1, 0} or {0, 0, 0})
    love.graphics.rectangle("line", x, y, Config.CARD_WIDTH, Config.CARD_HEIGHT, 5, 5)
    
    -- Energy cost
    love.graphics.setColor(0.9, 0.9, 0.2)
    love.graphics.circle("fill", x + 15, y + 15, 12)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(self.cost, x + 11, y + 8)
    
    -- Card name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.name, x + 10, y + 30)
    
    -- Card description
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(self.description, x + 10, y + 80, 80, "left", 0, 0.8, 0.8)
    
    -- Card type icon
    if self.type == "attack" then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.circle("fill", x + 85, y + 15, 8)
    elseif self.type == "skill" then
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.rectangle("fill", x + 80, y + 10, 10, 10)
    end
end

function Card:canPlay(player)
    return player.energy >= self.cost
end

function Card:play(gameState)
    -- Apply card effects
    if self.type == "attack" then
        local damage = self.damage
        
        -- Apply damage to enemy
        if gameState.currentEnemy then
            -- Check if enemy is vulnerable
            if gameState.currentEnemy.vulnerable and gameState.currentEnemy.vulnerable > 0 then
                damage = math.floor(damage * 1.5)
            end
            
            gameState.currentEnemy:takeDamage(damage)
            
            -- Apply vulnerable if the card has it
            if self.vulnerable and self.vulnerable > 0 then
                gameState.currentEnemy.vulnerable = (gameState.currentEnemy.vulnerable or 0) + self.vulnerable
            end
            
            -- Check if enemy is defeated
            if gameState.currentEnemy.health <= 0 then
                gameState:endCombat()
                return
            end
        end
    end
    
    -- Apply skill effects
    if self.block and self.block > 0 then
        gameState.player.block = gameState.player.block + self.block
    end
    
    -- Draw cards if the card has draw effect
    if self.draw and self.draw > 0 then
        gameState:drawCards(self.draw)
    end
    
    -- Add copy to discard pile if the card has copy effect
    if self.copy then
        table.insert(gameState.discardPile, Utils.deepCopy(self))
    end
    
    -- Use energy
    gameState.player.energy = gameState.player.energy - self.cost
end

-- Enemy Class
local Enemy = Class.new()

function Enemy:init(template)
    for k, v in pairs(template) do
        self[k] = v
    end
    self.intent = self.intents[love.math.random(#self.intents)]
    self.vulnerable = 0
    self.weak = 0
    self.block = 0
end

function Enemy:takeDamage(amount)
    -- Apply block first
    if self.block > 0 then
        if amount > self.block then
            amount = amount - self.block
            self.block = 0
        else
            self.block = self.block - amount
            amount = 0
        end
    end
    
    self.health = math.max(0, self.health - amount)
    
    -- Play hit animation or sound here
end

function Enemy:render(x, y)
    -- Draw enemy body
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", x - 40, y - 60, 80, 100, 5, 5)
    
    -- Draw enemy name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.name, x - 30, y - 50)
    
    -- Draw health bar
    love.graphics.setColor(0.8, 0, 0)
    love.graphics.rectangle("fill", x - 30, y + 50, 60 * (self.health / self.maxHealth), 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x - 30, y + 50, 60, 10)
    love.graphics.print(self.health .. "/" .. self.maxHealth, x - 20, y + 65)
    
    -- Draw block if any
    if self.block > 0 then
        love.graphics.setColor(0.3, 0.8, 0.9)
        love.graphics.print("Block: " .. self.block, x - 30, y + 85)
    end
    
    -- Draw status effects
    local statusY = y + 85
    if self.vulnerable and self.vulnerable > 0 then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print("Vulnerable: " .. self.vulnerable, x - 30, statusY)
        statusY = statusY + 15
    end
    if self.weak and self.weak > 0 then
        love.graphics.setColor(0.7, 0.3, 0.7)
        love.graphics.print("Weak: " .. self.weak, x - 30, statusY)
    end
    
    -- Draw enemy intent
    love.graphics.setColor(1, 1, 0)
    if self.intent == "attack" then
        local damage = self.damage
        if self.weak and self.weak > 0 then
            damage = math.floor(damage * 0.75)
        end
        love.graphics.print("Attack: " .. damage, x - 30, y + 20)
    elseif self.intent == "defend" then
        love.graphics.print("Defend", x - 30, y + 20)
    elseif self.intent == "buff" then
        love.graphics.print("Buff", x - 30, y + 20)
    end
end

function Enemy:updateIntent()
    self.intent = self.intents[love.math.random(#self.intents)]
end

function Enemy:takeTurn(gameState)
    -- Apply enemy intent
    if self.intent == "attack" then
        local damage = self.damage
        
        -- Apply weak status effect
        if self.weak and self.weak > 0 then
            damage = math.floor(damage * 0.75)
        end
        
        gameState.player:takeDamage(damage)
        
        -- Check if player is defeated
        if gameState.player.health <= 0 then
            gameState:gameOver()
            return
        end
    elseif self.intent == "defend" then
        self.block = self.block + 5
    elseif self.intent == "buff" then
        self.damage = self.damage + self.buff
    end
    
    -- Reduce status effect durations
    if self.vulnerable > 0 then
        self.vulnerable = self.vulnerable - 1
    end
    if self.weak > 0 then
        self.weak = self.weak - 1
    end
    
    -- Update intent for next turn
    self:updateIntent()
end

-- Player Class
local Player = Class.new()

function Player:init()
    self.health = 100
    self.maxHealth = 100
    self.energy = 3
    self.maxEnergy = 3
    self.block = 0
    self.weak = 0
    self.vulnerable = 0
end

function Player:takeDamage(amount)
    -- Apply block first
    if self.block > 0 then
        if amount > self.block then
            amount = amount - self.block
            self.block = 0
        else
            self.block = self.block - amount
            amount = 0
        end
    end
    
    self.health = math.max(0, self.health - amount)
    
    -- Play hit animation or sound here
end

function Player:render(x, y)
    -- Draw player info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Health: " .. self.health .. "/" .. self.maxHealth, x, y)
    love.graphics.print("Energy: " .. self.energy .. "/" .. self.maxEnergy, x, y + 20)
    love.graphics.print("Block: " .. self.block, x, y + 40)
    
    -- Draw status effects
    local statusY = y + 60
    if self.vulnerable and self.vulnerable > 0 then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print("Vulnerable: " .. self.vulnerable, x, statusY)
        statusY = statusY + 15
    end
    if self.weak and self.weak > 0 then
        love.graphics.setColor(0.7, 0.3, 0.7)
        love.graphics.print("Weak: " .. self.weak, x, statusY)
    end
end

function Player:startTurn()
    self.energy = self.maxEnergy
    
    -- Reduce status effect durations
    if self.vulnerable > 0 then
        self.vulnerable = self.vulnerable - 1
    end
    if self.weak > 0 then
        self.weak = self.weak - 1
    end
end

function Player:endTurn()
    self.block = 0 -- Block resets at end of turn
end

-- =====================================
-- Game State Management
-- =====================================
local GameState = Class.new()

function GameState:init()
    self.state = "menu" -- menu, game, combat, rewards, gameover
    self.player = Player:new()
    self.deck = {}
    self.hand = {}
    self.discardPile = {}
    self.currentEnemy = nil
    self.selectedCardIndex = nil
    self.rewardCards = {}
    self.turnEnding = false
    self.turnEndDelay = 0
    self.animation = nil
    self.animationTimer = 0
    
    -- Create starting deck
    for i = 1, Config.STARTING_STRIKES do
        table.insert(self.deck, Card:new(GameData.CardTemplates[1])) -- Strikes
    end
    for i = 1, Config.STARTING_DEFENDS do
        table.insert(self.deck, Card:new(GameData.CardTemplates[2])) -- Defends
    end
    
    -- Add one special card
    table.insert(self.deck, Card:new(GameData.CardTemplates[3])) -- Bash
    
    self:shuffleDeck()
end

function GameState:update(dt)
    -- Update animations if any
    if self.animation then
        self.animationTimer = self.animationTimer + dt
        if self.animationTimer > self.animation.duration then
            self.animation = nil
        end
    end
    
    -- Process turn ending
    if self.state == "combat" and self.turnEnding then
        self.turnEndDelay = self.turnEndDelay + dt
        if self.turnEndDelay > 0.5 then
            self:endTurn()
            self.turnEnding = false
            self.turnEndDelay = 0
        end
    end
end

function GameState:startGame()
    self.state = "combat"
    self:startCombat()
end

function GameState:startCombat()
    -- Reset player for combat
    self.player.energy = self.player.maxEnergy
    self.player.block = 0
    
    -- Create enemy
    local enemyTemplate = GameData.EnemyTemplates[love.math.random(#GameData.EnemyTemplates)]
    self.currentEnemy = Enemy:new(enemyTemplate)
    
    -- Draw starting hand
    self:drawCards(Config.HAND_SIZE)
    
    self.state = "combat"
end

function GameState:shuffleDeck()
    -- Add discard pile back to deck
    for _, card in ipairs(self.discardPile) do
        table.insert(self.deck, card)
    end
    self.discardPile = {}
    
    -- Shuffle the deck
    Utils.shuffle(self.deck)
end

function GameState:drawCards(count)
    for i = 1, count do
        if #self.deck == 0 and #self.discardPile == 0 then
            return -- No more cards to draw
        end
        
        if #self.deck == 0 then
            self:shuffleDeck()
        end
        
        table.insert(self.hand, table.remove(self.deck, 1))
    end
end

function GameState:playCard(index)
    if index > #self.hand then return end
    
    local card = self.hand[index]
    
    if not card:canPlay(self.player) then
        return false
    end
    
    -- Play the card
    card:play(self)
    
    -- Move to discard pile
    table.insert(self.discardPile, table.remove(self.hand, index))
    
    return true
end

function GameState:endTurn()
    -- Player end turn
    self.player:endTurn()
    
    -- Move hand to discard pile
    for _, card in ipairs(self.hand) do
        table.insert(self.discardPile, card)
    end
    self.hand = {}
    
    -- Enemy turn
    if self.currentEnemy then
        self.currentEnemy:takeTurn(self)
    end
    
    -- Start new turn
    self.player:startTurn()
    self:drawCards(Config.HAND_SIZE)
end

function GameState:endCombat()
    -- Show rewards
    self.state = "rewards"
    
    -- Generate reward cards
    self.rewardCards = {}
    for i = 1, Config.REWARD_OPTIONS do
        local cardTemplate = GameData.CardTemplates[love.math.random(#GameData.CardTemplates)]
        table.insert(self.rewardCards, Card:new(cardTemplate))
    end
end

function GameState:addCardToDeck(index)
    if index > #self.rewardCards then return end
    
    table.insert(self.deck, Utils.deepCopy(self.rewardCards[index]))
    self:shuffleDeck()
end

function GameState:gameOver()
    self.state = "gameover"
end

function GameState:render()
    if self.state == "menu" then
        self:renderMenu()
    elseif self.state == "combat" then
        self:renderCombat()
    elseif self.state == "rewards" then
        self:renderRewards()
    elseif self.state == "gameover" then
        self:renderGameOver()
    end
end

function GameState:renderMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ROGUELIKE DECKBUILDER", 300, 200, 0, 2, 2)
    
    -- Draw start button with improved appearance
    love.graphics.setColor(0.3, 0.6, 0.3)
    love.graphics.rectangle("fill", 300, 300, 200, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 300, 300, 200, 50, 10, 10)
    love.graphics.print("Start Game", 340, 315, 0, 1.5, 1.5)
end

function GameState:renderCombat()
    -- Draw player info
    self.player:render(20, 20)
    
    -- Draw deck and discard counts
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Deck: " .. #self.deck, 700, 20)
    love.graphics.print("Discard: " .. #self.discardPile, 700, 40)
    
    -- Draw enemy
    if self.currentEnemy then
        self.currentEnemy:render(400, 200)
    end
    
    -- Draw hand
    for i, card in ipairs(self.hand) do
        local isSelected = (self.selectedCardIndex == i)
        card:render(120 + (i-1) * 120, 400, isSelected)
    end
    
    -- Draw end turn button
    love.graphics.setColor(0.4, 0.4, 0.7)
    love.graphics.rectangle("fill", 650, 500, 100, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 650, 500, 100, 50, 10, 10)
    love.graphics.print("End Turn", 665, 515)
end

function GameState:renderRewards()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Choose a card to add to your deck:", 250, 150, 0, 1.5, 1.5)
    
    -- Draw reward cards
    for i, card in ipairs(self.rewardCards) do
        card:render(200 + (i-1) * 150, 250, false)
    end
    
    -- Draw skip button
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("fill", 350, 450, 100, 50, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 350, 450, 100, 50, 10, 10)
    love.graphics.print("Skip", 380, 465)
end

function GameState:renderGameOver()
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.print("GAME OVER", 300, 250, 0, 3, 3)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Press SPACE to return to menu", 320, 350)
end

function GameState:handleMousePressed(x, y, button)
    if button ~= 1 then return end
    
    if self.state == "menu" then
        -- Check if start button was clicked
        if x > 300 and x < 500 and y > 300 and y < 350 then
            self:startGame()
        end
    elseif self.state == "combat" then
        -- Check if a card in hand was clicked
        for i, card in ipairs(self.hand) do
            local cardX = 120 + (i-1) * 120
            local cardY = 400
            if x > cardX and x < cardX + Config.CARD_WIDTH and 
               y > cardY and y < cardY + Config.CARD_HEIGHT then
                if card:canPlay(self.player) then
                    self.selectedCardIndex = i
                    self:playCard(i)
                end
                break
            end
        end
        
        -- Check if end turn button was clicked
        if x > 650 and x < 750 and y > 500 and y < 550 then
            self.turnEnding = true
        end
    elseif self.state == "rewards" then
        -- Check if a reward card was clicked
        for i, card in ipairs(self.rewardCards) do
            local cardX = 200 + (i-1) * 150
            local cardY = 250
            if x > cardX and x < cardX + Config.CARD_WIDTH and 
               y > cardY and y < cardY + Config.CARD_HEIGHT then
                self:addCardToDeck(i)
                self:startCombat()
                break
            end
        end
        
        -- Check if skip button was clicked
        if x > 350 and x < 450 and y > 450 and y < 500 then
            self:startCombat()
        end
    end
end

function GameState:handleKeyPressed(key)
    if key == "escape" then
        love.event.quit()
    end
    
    if self.state == "combat" and key == "space" then
        self.turnEnding = true
    end
    
    if self.state == "gameover" and key == "space" then
        self.state = "menu"
    end
end

-- =====================================
-- LÖVE Callbacks
-- =====================================
local gameState

function love.load()
    -- Set up window
    love.window.setTitle("Roguelike Deckbuilder")
    love.window.setMode(Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.2)
    
    -- Initialize random seed
    love.math.setRandomSeed(os.time())
    
    -- Initialize game state
    gameState = GameState:new()
end

function love.update(dt)
    gameState:update(dt)
end

function love.draw()
    gameState:render()
    
    -- Display FPS for debugging
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 580)
end

function love.mousepressed(x, y, button)
    gameState:handleMousePressed(x, y, button)
end

function love.keypressed(key)
    gameState:handleKeyPressed(key)
end