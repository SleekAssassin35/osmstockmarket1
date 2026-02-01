# OsmFX Stock Market - The Most Realistic Trading Script ever built for FiveM

A comprehensive stock trading system for FiveM QBCore framework, featuring real-time price updates, dynamic market behavior, and admin controls.

## 🌟 Features

- Real-time stock price updates
- Dynamic market behavior with configurable volatility
- Interactive chart with zoom capabilities
- Portfolio management
- Transaction history
- Admin controls for market manipulation
- Database-driven stock configuration
- Exports for external script integration
- Detailed transaction logging

## 📊 Stock Market Mechanics

### Price Calculation
- Base price: Starting reference price for each stock
- Volatility: Random price movement (percentage)
- Liquidity Factor: Trading impact sensitivity
- Trading Impact: How trades affect prices
- Volume Decay: How trading impact fades over time

### Price Limits
- Minimum: 10% of base price
- Maximum: 1000% of base price
- Update Interval: 3 seconds (configurable) (Increase for Better Performance)

## 💻 Exports

### Server Exports
```lua
-- Modify single stock price
exports['osm-stockmarket']:ModifyStockPrice(symbol, impact, reason)
-- symbol: Stock symbol (e.g., 'LIFE')
-- impact: -100 to 100 (percentage impact)
-- reason: Reason for modification
-- Modify multiple stocks
exports['osm-stockmarket']:ModifyMultipleStocks(modifications)
-- modifications: Table of stock modifications
-- Example: {
-- LIFE = { impact = 50, reason = "Record profits" },
-- MAZE = { impact = -30, reason = "Security breach" }
-- }
```

## 🛠️ Admin Commands

### Price Modification
- `/modifystock [symbol] [impact] [reason]`
  - Modify stock price with percentage impact
  - Example: `/modifystock LIFE 50 "Company announced record profits"`

### History & Rollback
- `/stockhistory [symbol] [limit]`
  - View stock modification history
  - Example: `/stockhistory LIFE 10`

- `/stockrollback [hours] [citizenid]`
  - Rollback transactions within specified timeframe
  - Example: `/stockrollback 24 ABC123`

- `/stockstats [citizenid]`
  - View trading statistics
  - Example: `/stockstats ABC123`

## 📝 Database Tables

### stocks_config
- Stock configuration and basic information
- Stores base prices, volatility, logos

### stocks_history
- Price modification history
- Tracks all price changes with reasons

### player_stocks
- Player holdings
- Tracks owned shares and average purchase price

### stock_transactions
- Transaction history
- Tracks all buys/sells with profit/loss

## ⚙️ Configuration
```lua
Config.Market = {
PriceImpactFactor = 0.001, -- Trading impact (0.1% per share)
VolumeDecay = 0.98, -- Volume decay (2% reduction per update)
MinimumPrice = 0.1, -- Minimum price (10% of base)
MaximumPrice = 10.0 -- Maximum price (1000% of base)
}
Config.Trading = {
MinQuantity = 1, -- Minimum shares per trade
MaxQuantity = 1000, -- Maximum shares per trade
UpdateInterval = 30, -- UI refresh rate (seconds)
PriceDisplayDecimals = 2 -- Price decimal places
}
```


## 🔧 Installation

1. Import `stocks.sql` to your database
2. Add to your resources folder
3. Add to server.cfg: `ensure osm-stockmarket`
4. Configure `config.lua` as needed

## 📋 Dependencies

- qb-core
- oxmysql
- ox_lib

## 🎮 Usage

- Access via command: `/stocks`
- Or use target interaction at configured locations
- View market prices, trade stocks, manage portfolio
- Monitor profit/loss in real-time

## 🔄 Integration Example
```lua
-- Affect stock price based on game events
exports['osm-stockmarket']:ModifyStockPrice('LIFE', 30, "Successful marketing campaign")
-- Multiple stock modifications
exports['osm-stockmarket']:ModifyMultipleStocks({
LIFE = { impact = -20, reason = "Security breach" },
MAZE = { impact = 15, reason = "New partnership" }
})
```


## 📱 UI Features

- Real-time price updates
- Interactive price chart with zoom
- Portfolio tracking
- Transaction history
- Market statistics
- Company logos
- Buy/Sell controls

## 🔒 Security

- Admin-only commands
- Transaction logging
- Modification history
- Rollback capability
- Input validation
- Price manipulation limits

## 🎨 Customization

- Configurable currency display
- Custom company logos
- Adjustable UI refresh rate
- Customizable price limits
- Flexible trading rules

## 📈 Market Behavior

The stock market simulates realistic behavior through:
- Random volatility
- Trading impact
- Volume-based price changes
- Price limits
- Market trends
- Trading volume decay

