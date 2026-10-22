-- ==============================================================================
-- Achievement Unlocker Core Logic
-- Manages achievement retrieval and one-click unlocking
-- ==============================================================================

local M = {}

-- Static catalog of official Transport Fever achievements as safe fallback
local FALLBACK_ACHIEVEMENTS = {
    { id = "ACH_FIRST_CARGO_DELIVERED", icon = "::/gui/achievements/ach_first_cargo_delivered@2x.tga", name = "First Delivery", desc = "Deliver your first cargo" },
    { id = "ACH_FIRST_PASSENGER_ONBOARD", icon = "::/gui/achievements/ach_first_passenger_onboard@2x.tga", name = "First Passenger", desc = "Transport your first passenger" },
    { id = "ACH_FIRST_SUBSIDY_SUCCESS", icon = "::/gui/achievements/ach_first_subsidy_success@2x.tga", name = "Subsidized", desc = "Successfully complete a subsidy contract" },
    { id = "ACH_SUBSIDIES_STREAK_10", icon = "::/gui/achievements/ach_subsidies_streak_10@2x.tga", name = "Contractor", desc = "Complete 10 subsidies in a row" },
    { id = "ACH_FIRST_SETTLEMENT_DELIVERIES", icon = "::/gui/achievements/ach_first_settlement_deliveries@2x.tga", name = "Town Supply", desc = "Fulfill all cargo demands for a town" },
    { id = "ACH_FIRST_SETTLEMENT_RANKUP", icon = "::/gui/achievements/ach_first_settlement_rankup@2x.tga", name = "Boomtown", desc = "Help a town reach the next size tier" },
    { id = "ACH_FIRST_SETTLEMENT_DEMAND_INC", icon = "::/gui/achievements/ach_first_settlement_demand_inc@2x.tga", name = "Expanding Market", desc = "Increase the demand of a town" },
    { id = "ACH_SETTLEMENT_REPUTATION_LOW", icon = "::/gui/achievements/ach_settlement_reputation_low@2x.tga", name = "Bad Reputation", desc = "Get a low rating in a town" },
    { id = "ACH_FIRST_COMPANY_RANKUP", icon = "::/gui/achievements/ach_first_company_rankup@2x.tga", name = "Growing Business", desc = "Advance your company rank" },
    { id = "ACH_COMPANY_MAXRANK", icon = "::/gui/achievements/ach_company_maxrank@2x.tga", name = "Tycoon", desc = "Reach the maximum company rank" },
    { id = "ACH_FIRST_PLANT_TREE", icon = "::/gui/achievements/ach_first_plant_tree@2x.tga", name = "Green Thumb", desc = "Plant your first tree" },
    { id = "ACH_FIRST_CHANGE_DAYTIME", icon = "::/gui/achievements/ach_first_change_daytime@2x.tga", name = "Night Owl", desc = "Change the time of day" },
    { id = "ACH_FIRST_CHANGE_WEATHER", icon = "::/gui/achievements/ach_first_change_weather@2x.tga", name = "Meteorologist", desc = "Change the weather in the game" },
    { id = "ACH_FIRST_HELI_LANDING_OILPLAT", icon = "::/gui/achievements/ach_first_heli_landing_oilplat@2x.tga", name = "Offshore Connection", desc = "Land a helicopter on an offshore oil platform" },
    { id = "ACH_SUMMIT_STOPOVER", icon = "::/gui/achievements/ach_summit_stopover@2x.tga", name = "High Altitude", desc = "Establish a station stop high in the mountains" },
    { id = "ACH_CENTRALIZED", icon = "::/gui/achievements/ach_centralized@2x.tga", name = "Central Hub", desc = "Connect many lines into a single central station" },
    { id = "ACH_PERFECTIONIST", icon = "::/gui/achievements/ach_perfectionist@2x.tga", name = "Perfectionist", desc = "Achieve maximum delivery rating across multiple towns" },
    { id = "ACH_HERITAGE_FLEET", icon = "::/gui/achievements/ach_heritage_fleet@2x.tga", name = "Heritage Fleet", desc = "Maintain active antique vehicles alongside modern ones" },
    { id = "ACH_UFO", icon = "::/gui/achievements/ach_ufo@2x.tga", name = "I Want to Believe", desc = "Find and spot an alien UFO in the game" },
    { id = "ACH_ALL_VEHICLES", icon = "::/gui/achievements/ach_all_vehicles@2x.tga", name = "Connoisseur", desc = "Use all available vehicles in Free Game mode" },
    { id = "ACH_CARGO_1M", icon = "::/gui/achievements/ach_cargo_1m@2x.tga", name = "Freight Magnate", desc = "Transport 1,000,000 units of cargo" },
    { id = "ACH_PASSENGERS_1M", icon = "::/gui/achievements/ach_passengers_1m@2x.tga", name = "Mass Transit", desc = "Transport 1,000,000 passengers" },
    { id = "ACH_POP_100K", icon = "::/gui/achievements/ach_pop_100k@2x.tga", name = "Metropolis", desc = "Grow a town to 100,000 population" },
    { id = "ACH_POP_SETTLEMENT_3K", icon = "::/gui/achievements/ach_pop_settlement_3k@2x.tga", name = "Big City", desc = "Grow a settlement to 3,000 population" },
    { id = "ACH_POP_TOTAL_50K", icon = "::/gui/achievements/ach_pop_total_50k@2x.tga", name = "Urban Nation", desc = "Reach 50,000 total map population" },
    { id = "ACH_EARNINGS_100B", icon = "::/gui/achievements/ach_earnings_100b@2x.tga", name = "Billionaire", desc = "Reach 100 Billion in company balance" },
    { id = "ACH_WAREHOUSE_10K", icon = "::/gui/achievements/ach_warehouse_10k@2x.tga", name = "Master of Logistics", desc = "Stock 10,000 units in warehouses" },
    { id = "ACH_INDUSTRY_BOOSTER_10", icon = "::/gui/achievements/ach_industry_booster_10@2x.tga", name = "Industrial Giant", desc = "Boost 10 industries to maximum level" },
    { id = "ACH_INDUSTRY_PROD_CARS", icon = "::/gui/achievements/ach_industry_prod_cars@2x.tga", name = "Motor City", desc = "Supply all components and produce cars" },
    { id = "ACH_OLDSCHOOL", icon = "::/gui/achievements/ach_oldschool@2x.tga", name = "Old School", desc = "Operate vintage transport lines without modern upgrades" },
    { id = "ACH_ALL_ANIMALS", icon = "::/gui/achievements/ach_all_animals@2x.tga", name = "Fauna Collector", desc = "Discover all wild animal species on the map" },
    { id = "ACH_ALL_CARGO_TYPES_DELIVERED", icon = "::/gui/achievements/ach_all_cargo_types_delivered@2x.tga", name = "Omnivorous", desc = "Successfully transport every cargo type in the game" },
    { id = "ACH_ALL_CLIMATES", icon = "::/gui/achievements/ach_all_climates@2x.tga", name = "Globetrotter", desc = "Play games across all climate types" },
    { id = "ACH_ALL_CLIMATES_TYCOON", icon = "::/gui/achievements/ach_all_climates_tycoon@2x.tga", name = "Climate Tycoon", desc = "Reach highest company rank in all climates" },
    { id = "ACH_AROUND_WORLD", icon = "::/gui/achievements/ach_around_world@2x.tga", name = "Around the World", desc = "Travel cumulative distance around the world" },
    { id = "ACH_BANK_INTEREST_10M", icon = "::/gui/achievements/ach_bank_interest_10m@2x.tga", name = "Debt Free", desc = "Repay loan interest of 10M" },
    { id = "ACH_BICENTENNIAL", icon = "::/gui/achievements/ach_bicentennial@2x.tga", name = "Bicentennial", desc = "Play across a span of 200 game years" },
    { id = "ACH_CAMPAIGN_FIRST", icon = "::/gui/achievements/ach_campaign_first@2x.tga", name = "Campaign Starter", desc = "Complete the first campaign mission" },
    { id = "ACH_CAMPAIGN_ALL", icon = "::/gui/achievements/ach_campaign_all@2x.tga", name = "Grand Master", desc = "Complete all campaign missions" },
    { id = "ACH_ALL_MEDALS", icon = "::/gui/achievements/ach_all_medals@2x.tga", name = "Medalist", desc = "Earn all campaign challenge medals" },
    { id = "ACH_ALL_STARS", icon = "::/gui/achievements/ach_all_stars@2x.tga", name = "Star Struck", desc = "Earn all stars in the game" },
}

-- Fetch live list of achievements with real-time unlock status
function M.getAchievements()
    local result = {}
    local unlockedSet = {}

    -- 1. Try to fetch unlocked status from official user profile
    if app and app.getUserProfile then
        local ok, profile = pcall(app.getUserProfile)
        if ok and profile and profile.getUnlockedAchievementIds then
            local okIds, ids = pcall(profile.getUnlockedAchievementIds, profile)
            if okIds and type(ids) == "table" then
                unlockedSet = ids
            end
        end
    end

    -- 2. Try to fetch dynamic achievement catalog from official AchievementRep
    local dynamicListLoaded = false
    if app and app.getUserProfile then
        pcall(function()
            local profile = app.getUserProfile()
            if profile and profile.getAchievementRep then
                local rep = profile:getAchievementRep()
                if rep and rep.getNumAchievements then
                    local count = rep:getNumAchievements()
                    if count and count > 0 then
                        for i = 1, count do
                            local ach = rep:get(i - 1)
                            if ach and ach.id then
                                local isUnlocked = (unlockedSet[ach.id] == true)
                                table.insert(result, {
                                    id = ach.id,
                                    name = ach.name or ach.id,
                                    desc = ach.description or "",
                                    icon = isUnlocked and (ach.icon or "") or (ach.lockedIcon or ach.icon or ""),
                                    unlocked = isUnlocked,
                                    hidden = ach.hidden or false,
                                })
                            end
                        end
                        dynamicListLoaded = true
                    end
                end
            end
        end)
    end

    -- 3. If dynamic catalog was not available, use built-in catalog
    if not dynamicListLoaded or #result == 0 then
        for _, fb in ipairs(FALLBACK_ACHIEVEMENTS) do
            local isUnlocked = (unlockedSet[fb.id] == true)
            -- Check if engine considers it already locked/unlocked
            if not isUnlocked and api and api.gui and api.gui.achievements and api.gui.achievements.isAchievementUnlockable then
                local ok, canUnlock = pcall(api.gui.achievements.isAchievementUnlockable, fb.id)
                if ok and canUnlock == false then
                    -- If cannot unlock, might already be unlocked
                    isUnlocked = true
                end
            end

            table.insert(result, {
                id = fb.id,
                name = fb.name,
                desc = fb.desc,
                icon = fb.icon,
                unlocked = isUnlocked,
                hidden = false,
            })
        end
    end

    return result
end

-- Directly unlock an achievement by ID
function M.unlock(id)
    if not id or #id == 0 then return false end
    if api and api.gui and api.gui.achievements and api.gui.achievements.unlockAchievement then
        api.gui.achievements.unlockAchievement(id)
        return true
    end
    return false
end

-- Unlock all achievements currently locked
function M.unlockAll(achievementsList)
    local list = achievementsList or M.getAchievements()
    local count = 0
    for _, ach in ipairs(list) do
        if not ach.unlocked then
            if M.unlock(ach.id) then
                count = count + 1
            end
        end
    end
    return count
end

return M
