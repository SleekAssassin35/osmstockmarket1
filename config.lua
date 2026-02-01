Config = {}

-- Check stock_config table for stock configurations
--[[ STOCK CONFIGURATIONS
    Each stock entry contains:
    - name: Company's full name
    - symbol: Stock market symbol/ticker
    - basePrice: Starting price of the stock
    - volatility: How much the price fluctuates randomly (0.02 = 2% potential change each update)
    - liquidityFactor: How easily the price moves with trades (1.0 = normal, <1 = more volatile to trades)
]]

Config.CommandPermissions = {
    modifystock = 'admin',
    stockhistory = 'admin',
    stockrollback = 'admin',
    stockstats = 'admin',
}

Config.Locations = {
    {
        model = `mp_m_securoguard_01`,
        coords = vector4(-73.31, -797.17, 44.23, 331.79)
    },
    {
        model = `mp_m_securoguard_01`,
        coords = vector4(-62.98, -800.19, 44.23, 17.35)
    },
}

Config.Stocks = {} -- Update stocks directly in the database stocks_config table

--[[ GENERAL MARKET SETTINGS ]]
-- How often the stock prices update (in minutes)
Config.UpdateInterval = 0.05 -- 3 seconds

-- Maximum number of shares a player can own of each company
Config.MaxStocksPerPlayer = 100000

--[[ TRADING PARAMETERS
    Controls the rules and limitations of trading:
    - MinQuantity: Minimum shares per trade
    - MaxQuantity: Maximum shares per trade
    - UpdateInterval: How often the UI refreshes (seconds)
    - PriceDisplayDecimals: Number of decimal places shown for prices
]]
Config.Trading = {
    MinQuantity = 1,          -- Minimum shares per trade
    MaxQuantity = 1000,       -- Maximum shares per trade
    UpdateInterval = 30,      -- UI refresh rate in seconds
    PriceDisplayDecimals = 2  -- Show prices like $123.45
}

--[[ UI NOTIFICATION SETTINGS
    Controls the behavior of popup notifications:
    - Position: Where notifications appear on screen
    - Duration: How long notifications stay visible
    - AnimationDuration: How long entrance/exit animations last
]]
Config.Notifications = {
    Position = 'top-right',     -- Notification position on screen
    Duration = 3000,            -- Display time in milliseconds
    AnimationDuration = 300     -- Animation time in milliseconds
}

--[[ MARKET MECHANICS
    Fine-tune the stock market behavior:
    - PriceImpactFactor: How much trading affects prices (0.001 = 0.1% per share)
    - VolumeDecay: How quickly trading impact fades (0.95 = 5% decay per update)
    - MinimumPrice: Lowest possible price as factor of basePrice
    - MaximumPrice: Highest possible price as factor of basePrice
]]
Config.Market = {
    PriceImpactFactor = 0.001,  -- Trading impact strength
    VolumeDecay = 0.98,         -- Trading impact decay rate
    MinimumPrice = 0.1,         -- Can't go below 10% of base price
    MaximumPrice = 10.0         -- Can't go above 1000% of base price
}

-- History settings
Config.History = {
    MaxPoints = 100  -- Store last 100 price points
}

-- Add to Config
Config.Currency = {
    Symbol = "$ ",
    Position = "before", -- 'before' ($100) or 'after' (100$)
    Code = "USD "
}

-- Add logo configuration
Config.logos = {
    Enabled = true,
    Size = 64,  -- Size in pixels
    Fallback = "https://pluspng.com/img-png/fivem-logo-png-fivem-m-logo-png-transparent-png-kindpng-860x872.png"  -- Default logo if company logo is missing
}