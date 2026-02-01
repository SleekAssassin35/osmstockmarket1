AddEventHandler('onClientResourceStart', function(resName)
    if (GetCurrentResourceName() ~= resName) then return end
    SetNuiFocus(false,false)
    SendNUIMessage({action='setVisibleStockMarket', data=false})
end)


local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local LoggedIn = false

local function setUI(visible)
  uiOpen = visible
  SetNuiFocus(visible, visible)
  SendNUIMessage({ action = 'setVisibleStockMarket', data = visible })
end

RegisterNetEvent("osm-stockmarket:notify", function(msg, type)
    SendNUIMessage({
        action = "notify",
        msg = msg,
        type = type
    })
end)

RegisterNetEvent("chat:receive", function(data)
    SendNUIMessage({
        action = "chat:receive",
        name = data.name,
        msg = data.msg
    })
end)

RegisterNetEvent("osm-stockmarket:frozen", function()
    SendNUIMessage({ action="frozen" })
end)


RegisterNetEvent('osm-stockmarket:open', function()
  if uiOpen then return end
  setUI(true)
  QBCore.Functions.TriggerCallback('osm-stockmarket:getStocks', function(stocks, config)
    SendNUIMessage({ action='init', data={ stocks=stocks or {}, config=config or {} } })
  end)
end)

RegisterNetEvent('osm-stockmarket:updateStocks', function(stocks)
  if uiOpen then SendNUIMessage({ action='updateStocks', data=stocks or {} }) end
end)

local function IsPlayerReady()
  local ok = pcall(function() return LocalPlayer.state and LocalPlayer.state.isLoggedIn end)
  if ok and LocalPlayer.state and LocalPlayer.state.isLoggedIn then return true end
  return NetworkIsSessionActive() and QBCore.Functions.GetPlayerData() ~= nil
end

RegisterNUICallback('checkSession', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:checkSession', function(res)
    LoggedIn = res and res.loggedIn or false
    cb({ loggedIn = LoggedIn })
  end)
end)

RegisterNUICallback('getBalance', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:getBalance', function(res) cb(res or {balance=0}) end)
end)

-- Admin Panel için
RegisterNUICallback("admin:getUsers", function(data,cb)
    QBCore.Functions.TriggerCallback("admin:getUsers", function(res)
        cb(res)
    end)
end)

RegisterNUICallback("admin:getUserDetail", function(data,cb)
    QBCore.Functions.TriggerCallback("admin:getUserDetail", function(res)
        cb(res)
    end, data)
end)

RegisterNUICallback("admin:getFinance", function(data,cb)
    QBCore.Functions.TriggerCallback("admin:getFinance", function(res)
        cb(res)
    end, data)
end)

-- Support
RegisterNUICallback("support:new", function(data,cb)
    TriggerServerEvent("support:new", data)
    cb("ok")
end)

RegisterNUICallback("support:getMy", function(data,cb)
    QBCore.Functions.TriggerCallback("support:getMy", function(res)
        cb(res)
    end, data)
end)

-- Market
RegisterNUICallback("market:topGainers", function(data,cb)
    QBCore.Functions.TriggerCallback("market:topGainers", function(res)
        cb(res)
    end)
end)

-- Chat
RegisterNUICallback("chat:send", function(data,cb)
    TriggerServerEvent("chat:send", data)
    cb("ok")
end)

RegisterNUICallback('registerAccount', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:register', function(res) if res and res.ok then LoggedIn = true end; cb(res or {ok=false}) end, data)
end)
RegisterNUICallback('loginAccount', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:login', function(res) if res and res.ok then LoggedIn = true end; cb(res or {ok=false}) end, data)
end)
RegisterNUICallback('logoutAccount', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:logout', function(res) if res and res.ok then LoggedIn = false end; cb(res or {ok=false}) end)
end)
RegisterNUICallback('forgotPassword', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:forgotPassword', function(res) cb(res or {ok=false}) end, data)
end)
RegisterNUICallback('changePassword', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:changePassword', function(res) cb(res or {ok=false}) end, data)
end)

RegisterNUICallback('getStocks', function(_, cb)
  if not IsPlayerReady() then cb({}) return end
  QBCore.Functions.TriggerCallback('osm-stockmarket:getStocks', function(stocks) cb(stocks or {}) end)
end)
RegisterNUICallback('getMarketStats', function(_, cb)
  if not IsPlayerReady() then cb({ totalVolume=0, activeStocks=0 }) return end
  QBCore.Functions.TriggerCallback('osm-stockmarket:getMarketStats', function(stats) cb(stats or { totalVolume=0, activeStocks=0 }) end)
end)
RegisterNUICallback('getPortfolio', function(_, cb)
  if not IsPlayerReady() then cb({}) return end
  QBCore.Functions.TriggerCallback('osm-stockmarket:getPortfolio', function(holdings) cb(holdings or {}) end)
end)
RegisterNUICallback('getMyTransactions', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:getMyTransactions', function(res) cb(res or {rows={}, net_pnl=0}) end)
end)
RegisterNUICallback('getSubscription', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:getSubscription', function(res) cb(res or {}) end)
end)
RegisterNUICallback('buySubscription', function(_, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:buySubscription', function(res) cb(res or {ok=false}) end)
end)

RegisterNUICallback('deposit', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:deposit', function(res) cb(res or {ok=false}) end, data)
end)
RegisterNUICallback('withdraw', function(data, cb)
  QBCore.Functions.TriggerCallback('osm-stockmarket:withdraw', function(res) cb(res or {ok=false}) end, data)
end)

RegisterNUICallback('buyStocks', function(data, cb)
  if not LoggedIn then cb({ success=false, message='Önce kayıt/giriş yapın' }); return end
  QBCore.Functions.TriggerCallback('osm-stockmarket:buyStocks', function(res) cb(res or {success=false}) end, data and data.symbol or nil, tonumber(data and data.amount or 0) or 0)
end)
RegisterNUICallback('sellStocks', function(data, cb)
  if not LoggedIn then cb({ success=false, message='Önce kayıt/giriş yapın' }); return end
  QBCore.Functions.TriggerCallback('osm-stockmarket:sellStocks', function(res) cb(res or {success=false}) end, data and data.symbol or nil, tonumber(data and data.amount or 0) or 0)
end)

RegisterNUICallback('hideComponent', function(_, cb) setUI(false); cb(true) end)

RegisterCommand('stocks', function() TriggerEvent('osm-stockmarket:open') end, false)


-- Hide UI on start to avoid blank screen
CreateThread(function()
  SetNuiFocus(false,false)
  SendNUIMessage({action='setVisibleStockMarket', data=false})
end)

-- Admin panel command
RegisterCommand("ba", function()
    SetNuiFocus(true, true)
    SendNUIMessage({action="openAdmin"})
end)


-- ========= NUI Bridges =========
RegisterNUICallback('checkSession', function(data, cb) cb({loggedIn=false}) end)

RegisterNUICallback('admin:getUsers', function(data, cb)
    QBCore.Functions.TriggerCallback('admin:getUsers', function(res) cb(res or {}) end)
end)

RegisterNUICallback('admin:getUserDetail', function(data, cb)
    QBCore.Functions.TriggerCallback('admin:getUserDetail', function(res) cb(res or {}) end, data)
end)

RegisterNUICallback('admin:getFinance', function(data, cb)
    QBCore.Functions.TriggerCallback('admin:getFinance', function(res) cb(res or {balance=0}) end)
end)

RegisterNUICallback('support:list', function(data, cb)
    QBCore.Functions.TriggerCallback('support:list', function(res) cb(res or {}) end)
end)

RegisterNUICallback('support:new', function(data, cb)
    QBCore.Functions.TriggerCallback('support:new', function(res) cb(res or {ok=false}) end, data)
end)

RegisterNUICallback('matrix:get', function(data, cb)
    QBCore.Functions.TriggerCallback('osm-stockmarket:getMatrixData', function(res) cb(res or {}) end)
end)

RegisterNUICallback('withdraw:request', function(data, cb)
    QBCore.Functions.TriggerCallback('withdraw:request', function(res) cb(res or {ok=false}) end, data)
end)

RegisterNUICallback('chat:send', function(data, cb)
    TriggerServerEvent('chat:send', {msg = data and data.msg or ''})
    cb({ok=true})
end)

RegisterNUICallback('checkSession', function(data, cb) cb({loggedIn=false}) end)
RegisterNUICallback('checkSession', function(data, cb) cb({loggedIn=false}) end)