---------------------------------------------------------------------------------------------------------
-- ECONOMY SCRIPT
---------------------------------------------------------------------------------------------------------
-- Purpose:  To adjust the economy
-- Authors:  Rahkiin, reallogger
--

ssEconomy = {}
g_seasons.economy = ssEconomy

ssEconomy.EQUITY_LOAN_RATIO = 0.3

function ssEconomy:load(savegame, key)
    self.aiPricePerHourWork = ssStorage.getXMLFloat(savegame, key .. ".settings.aiPricePerHourWork", 1650)
    self.aiPricePerHourOverwork = ssStorage.getXMLFloat(savegame, key .. ".settings.aiPricePerHourOverwork", 2475)
    self.aiDayStart = ssStorage.getXMLFloat(savegame, key .. ".settings.aiDayStart", 6)
    self.aiDayEnd = ssStorage.getXMLFloat(savegame, key .. ".settings.aiDayEnd", 18)
    self.loanMax = ssStorage.getXMLFloat(savegame, key .. ".settings.loanMax", 1000000)
    self.baseLoanInterest = ssStorage.getXMLFloat(savegame, key .. ".settings.baseLoanInterest", 10)
end

function ssEconomy:save(savegame, key)
    ssStorage.setXMLFloat(savegame, key .. ".settings.aiPricePerHourWork", self.aiPricePerHourWork)
    ssStorage.setXMLFloat(savegame, key .. ".settings.aiPricePerHourOverwork", self.aiPricePerHourOverwork)
    ssStorage.setXMLFloat(savegame, key .. ".settings.aiDayStart", self.aiDayStart)
    ssStorage.setXMLFloat(savegame, key .. ".settings.aiDayEnd", self.aiDayEnd)
    ssStorage.setXMLFloat(savegame, key .. ".settings.loanMax", self.loanMax)
    ssStorage.setXMLFloat(savegame, key .. ".settings.baseLoanInterest", self.baseLoanInterest)
end

function ssEconomy:loadMap(name)
    -- Update leasing costs
    EconomyManager.DEFAULT_LEASING_DEPOSIT_FACTOR = 0.04 -- factor of price (vanilla: 0.05)
    EconomyManager.DEFAULT_RUNNING_LEASING_FACTOR = 0.04 -- factor of price (vanilla: 0.05)
    EconomyManager.PER_DAY_LEASING_FACTOR = 0.008 -- factor of price (vanilla: 0.01)

    AIVehicle.updateTick = Utils.overwrittenFunction(AIVehicle.updateTick, ssEconomy.aiUpdateTick)
    FieldDefinition.setFieldOwnedByPlayer = Utils.overwrittenFunction(FieldDefinition.setFieldOwnedByPlayer, ssEconomy.setFieldOwnedByPlayer)

    Placeable.finalizePlacement = Utils.appendedFunction(Placeable.finalizePlacement, ssEconomy.placeableFinalizePlacement)
    Placeable.onSell = Utils.appendedFunction(Placeable.onSell, ssEconomy.placeablenOnSell)

    if g_currentMission:getIsServer() then
        self:setup()
    end
end

function ssEconomy:setup()
    -- Some calculations to make the code faster on the hotpath
    ssEconomy.aiPricePerMSWork = ssEconomy.aiPricePerHourWork / (60 * 60 * 1000)
    ssEconomy.aiPricePerMSOverwork = ssEconomy.aiPricePerHourOverwork / (60 * 60 * 1000)

    g_currentMission.missionStats.loanMax = self:getLoanCap()
    g_currentMission.missionStats.ssLoan = 0
end

function ssEconomy:readStream(streamId, connection)
    self.aiPricePerHourWork = streamReadFloat32(streamId)
    self.aiPricePerHourOverwork = streamReadFloat32(streamId)
    self.aiDayStart = streamReadFloat32(streamId)
    self.aiDayEnd = streamReadFloat32(streamId)
    self.loanMax = streamReadFloat32(streamId)
    self.baseLoanInterest = streamReadFloat32(streamId)

    self:setup()
end

function ssEconomy:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.aiPricePerHourWork)
    streamWriteFloat32(streamId, self.aiPricePerHourOverwork)
    streamWriteFloat32(streamId, self.aiDayStart)
    streamWriteFloat32(streamId, self.aiDayEnd)
    streamWriteFloat32(streamId, self.loanMax)
    streamWriteFloat32(streamId, self.baseLoanInterest)
end

function ssEconomy:updateTick(dt)
    if g_currentMission:getIsServer() then
        local stats = g_currentMission.missionStats

        if stats.ssLoan ~= stats.loan then
            self:calculateLoanInterestRate()
            stats.ssLoan = stats.loan
        end
    end
end

function ssEconomy:calculateLoanInterestRate()
    -- local stats = g_currentMission.missionStats
    local yearInterest = self.baseLoanInterest / 2 * g_currentMission.missionInfo.difficulty

    -- Convert the interest to be made in a Seasons year to a vanilla year so that the daily interests are correct
    local seasonsYearInterest = yearInterest * (356 / (g_seasons.environment.daysInSeason * g_seasons.environment.SEASONS_IN_YEAR))

    g_currentMission.missionStats.loanAnnualInterestRate = seasonsYearInterest
end

function ssEconomy.aiUpdateTick(self, superFunc, dt)
    if self:getIsActive() then
        local hour = g_currentMission.environment.currentHour
        local dow = ssUtil.dayOfWeek(g_seasons.environment:currentDay())

        if hour >= ssEconomy.aiDayStart and hour <= ssEconomy.aiDayEnd and dow <= 5 then
            self.pricePerMS = ssEconomy.aiPricePerMSWork
        else
            self.pricePerMS = ssEconomy.aiPricePerMSOverwork
        end
    end

    return superFunc(self, dt)
end

-- Calculate equity by summing all owned land. I know this is not
-- economically correct but it is the best we got for a value that moves
-- up as the game progresses
function ssEconomy:getEquity()
    local equity = 0

    if g_currentMission.fieldDefinitionBase ~= nil then -- can be nil on WIP maps
        for _, field in pairs(g_currentMission.fieldDefinitionBase.fieldDefs) do
            if field.ownedByPlayer then
                equity = equity + field.fieldPriceInitial
            end
        end
    end

    for _, type in pairs(g_currentMission.ownedItems) do
        if type.storeItem.species == "placeable" then
            for _, placeable in pairs(type.items) do
                equity = equity + placeable:getSellPrice()
            end
        end
    end

    return equity
end

function ssEconomy:getLoanCap()
    local roundedTo5000 = math.floor(ssEconomy.EQUITY_LOAN_RATIO * self:getEquity() / 5000) * 5000
    return Utils.clamp(roundedTo5000, 300000, ssEconomy.loanMax)
end

function ssEconomy:updateLoan()
    g_currentMission.missionStats.loanMax = self:getLoanCap()
end

function ssEconomy:setFieldOwnedByPlayer(superFunc, fieldDef, isOwned)
    local ret = superFunc(self, fieldDef, isOwned)

    g_seasons.economy:updateLoan()

    return ret
end

function ssEconomy:placeableFinalizePlacement()
    g_seasons.economy:updateLoan()
end

function ssEconomy:placeablenOnSell()
    g_seasons.economy:updateLoan()
end
