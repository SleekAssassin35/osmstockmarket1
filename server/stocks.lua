local QBCore = exports['qb-core']:GetCoreObject()

-- Resolve account by citizenid
local function getAccount(src)
  local P = QBCore.Functions.GetPlayer(src)
  if not P then return nil end
  local cid = P.PlayerData.citizenid
  local r = MySQL.query.await("SELECT * FROM exchange_accounts WHERE citizenid=?", {cid})
  if r and r[1] then return r[1] end
  return nil
end

local Config = Config or {}
local RESOURCE = GetCurrentResourceName()

-- === Params ===
local UpdateIntervalMinutes = Config.UpdateInterval or 0.05   -- ~3s
local MaxHistory = (Config.History and Config.History.MaxPoints) or 100

-- Fees and job accounts
local Fees = { Buyer = 0.001, Seller = 0.002 }
local Jobs = { Exchange = 'oblivion', Tax = 'devlet' }
local Subscription = { MonthlyPrice = 5000, DaysPerMonth = 30 }

-- Runtime
local Market = { stocks = {} }
local JsonHistory = {}
local Sessions = {}  -- [source]=citizenid

-- DB helpers
local function dbQ(q,p,cb) exports.oxmysql:execute(q,p or {}, function(r) if cb then cb(r or {}) end end) end
local function dbScalar(q,p,cb) exports.oxmysql:scalar(q,p or {}, function(v) if cb then cb(v) end end) end

-- Money helpers
local function SafeAddJobMoney(job, amt)
  amt = math.floor((amt or 0)*100)/100
  if amt <= 0 then return end
  if GetResourceState('qb-management') == 'started' then
    pcall(function() exports['qb-management']:AddMoney(job, amt) end)
  end
end

-- JSON IO
local function readHistoryJson()
  local content = LoadResourceFile(RESOURCE, 'stockhistory.json')
  if not content or content == '' then return {} end
  local ok, data = pcall(json.decode, content); return (ok and type(data)=='table') and data or {}
end
local function writeHistoryJson() local ok, enc = pcall(json.encode, JsonHistory); if ok then SaveResourceFile(RESOURCE,'stockhistory.json',enc,-1) end end

-- Helpers
local function clampPrice(base, price)
  local minP = (Config.Market and Config.Market.MinimumPrice or 0.1) * base
  local maxP = (Config.Market and Config.Market.MaximumPrice or 10.0) * base
  if price < minP then price = minP end
  if price > maxP then price = maxP end
  return price
end
local function randomVolatility(vol) return (math.random()*2 - 1) * (vol or 0.003) end

local function pushHistory(symbol, ts, price)
  local s = Market.stocks[symbol]; if not s then return end
  s.history.timestamps[#s.history.timestamps+1] = ts
  s.history.prices[#s.history.prices+1] = price
  if #s.history.timestamps > MaxHistory then table.remove(s.history.timestamps,1); table.remove(s.history.prices,1) end
  local j = JsonHistory[symbol]; if not j then j={timestamps={},prices={}}; JsonHistory[symbol]=j end
  j.timestamps[#j.timestamps+1]=ts; j.prices[#j.prices+1]=price
  if #j.timestamps > 1000 then table.remove(j.timestamps,1); table.remove(j.prices,1) end
end

local function compute24hHL(s)
  local ts, ps = s.history.timestamps or {}, s.history.prices or {}
  if #ts == 0 then return s.currentPrice or 0, s.currentPrice or 0 end
  local cut = os.time() - 86400
  local hi, lo = -math.huge, math.huge
  for i=#ts,1,-1 do
    if ts[i] < cut then break end
    local p = tonumber(ps[i]) or 0
    if p > hi then hi = p end
    if p < lo then lo = p end
  end
  if hi == -math.huge or lo == math.huge then
    for i=1,#ps do local p=tonumber(ps[i]) or 0; if p>hi then hi=p end; if p<lo then lo=p end end
  end
  if hi == -math.huge then hi = s.currentPrice or 0 end
  if lo ==  math.huge then lo = s.currentPrice or 0 end
  return hi, lo
end

-- Load
local function loadStocks(cb)
  JsonHistory = readHistoryJson()
  dbQ([[SELECT symbol,name,base_price,volatility,liquidity_factor,COALESCE(logo_url,'') logo_url,enabled FROM stocks_config]], {}, function(rows)
    local temp, loadedFromJson, enabledCount = {}, 0, 0
    for _, r in ipairs(rows) do
      local sym = string.upper(r.symbol)
      local base = tonumber(r.base_price) or 100.0
      local vol  = tonumber(r.volatility) or 0.003
      local liq  = tonumber(r.liquidity_factor) or 1.0
      local enabled = (r.enabled == 1 or r.enabled == true or r.enabled == '1' or r.enabled == 'true')
      local series = JsonHistory[sym]
      local last = (series and series.prices and series.prices[#series.prices]) and tonumber(series.prices[#series.prices]) or nil
      local start = last or base
      if last then loadedFromJson = loadedFromJson + 1 end
      temp[sym] = {
        symbol=sym, name=r.name or sym, basePrice=base, volatility=vol, liquidityFactor=liq,
        logo=(r.logo_url~='' and r.logo_url or nil), enabled=enabled,
        currentPrice=start, previousPrice=start, volume=0,
        history={timestamps=(series and series.timestamps or {}), prices=(series and series.prices or {})},
        high24=start, low24=start
      }
      if enabled then enabledCount = enabledCount + 1 end
      if not JsonHistory[sym] then JsonHistory[sym] = {timestamps={},prices={}} end
    end
    Market.stocks = temp
    for _, s in pairs(Market.stocks) do s.high24, s.low24 = compute24hHL(s) end
    print(('[osm-stockmarket] Aktif hisse: %d | JSON’dan son fiyat: %d | enabled=true: %d'):format(#rows, loadedFromJson, enabledCount))
    if cb then cb() end
  end)
end

-- Ticker
local function broadcast() TriggerClientEvent('osm-stockmarket:updateStocks', -1, Market.stocks) end

local function updatePricesTick()
  local changed = false
  for sym, s in pairs(Market.stocks) do
    if s.enabled ~= false then
      local prev = s.currentPrice or s.basePrice
      local nextP = prev * (1.0 + randomVolatility(s.volatility) + ((Config.Market and Config.Market.PriceImpactFactor or 0.001) * (s.volume or 0) / math.max(s.liquidityFactor or 1, 0.01)) / 100.0)
      nextP = clampPrice(s.basePrice, nextP)
      nextP = math.floor(nextP*100)/100
      s.volume = (s.volume or 0) * (Config.Market and Config.Market.VolumeDecay or 0.98)
      if nextP ~= prev then
        s.previousPrice = prev
        s.currentPrice = nextP
        pushHistory(sym, os.time(), nextP)
        s.high24, s.low24 = compute24hHL(s)
        dbQ('INSERT INTO stocks_history (symbol,price,reason) VALUES (?,?,?)', {sym,nextP,'auto-tick'})
        changed = true
      end
    end
  end
  if changed then writeHistoryJson(); broadcast() end
end

local function startTicker()
  local ms = math.floor((UpdateIntervalMinutes or 0.05) * 60 * 1000)
  CreateThread(function() while true do Wait(ms); updatePricesTick() end end)
end

-- Auth helpers
local function hashPassword(pw) return GetHashKey(''..pw) end
local function ensureWallet(cid, cb) dbQ('INSERT IGNORE INTO exchange_wallet (citizenid,balance) VALUES (?,0)', {cid}, function() if cb then cb() end end) end
local function getWallet(cid, cb) dbScalar('SELECT balance FROM exchange_wallet WHERE citizenid=?', {cid}, function(b) cb(tonumber(b or 0)) end) end
local function setWallet(cid, bal, cb) dbQ('UPDATE exchange_wallet SET balance=? WHERE citizenid=?', {bal,cid}, function() if cb then cb() end end) end

-- Session/balance
QBCore.Functions.CreateCallback('osm-stockmarket:checkSession', function(source, cb) cb({ loggedIn = Sessions[source] ~= nil }) end)
QBCore.Functions.CreateCallback('osm-stockmarket:getBalance', function(source, cb)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({balance=0}); return end
  local cid = P.PlayerData.citizenid
  if Sessions[source] ~= cid then cb({balance=0}); return end
  getWallet(cid, function(bal) cb({balance=bal}) end)
end)

-- Register
QBCore.Functions.CreateCallback('osm-stockmarket:register', function(source, cb, data)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false,msg='Oyuncu yok'}); return end
  local cid = P.PlayerData.citizenid
  local name, phone, email, pw = data.name or '', data.phone or '', data.email or '', data.password or ''
  if name=='' or phone=='' or email=='' or pw=='' then cb({ok=false,msg='Eksik bilgi'}); return end
  dbQ('SELECT 1 FROM exchange_accounts WHERE citizenid=?', {cid}, function(r)
    if r[1] then cb({ok=false,msg='Hesap zaten var'}); return end
    dbQ('INSERT INTO exchange_accounts (citizenid,display_name,phone,email,password_hash) VALUES (?,?,?,?,?)', {cid,name,phone,email,tostring(hashPassword(pw))}, function()
      dbQ('INSERT IGNORE INTO exchange_settings (citizenid) VALUES (?)', {cid})
      ensureWallet(cid, function() Sessions[source]=cid; cb({ok=true}) end)
    end)
  end)
end)

-- Login (with username)
QBCore.Functions.CreateCallback('osm-stockmarket:login', function(source, cb, data)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false}); return end
  local cid = P.PlayerData.citizenid
  local pw = data.password or ''
  local uname = (data.username or ''):gsub('^%s+',''):gsub('%s+$','')
  if uname == '' then cb({ok=false,msg='Kullanıcı adı gerekli'}); return end
  dbQ('SELECT display_name,password_hash FROM exchange_accounts WHERE citizenid=?', {cid}, function(r)
    if r[1] and string.lower(tostring(r[1].display_name or '')) == string.lower(uname) and tostring(r[1].password_hash)==tostring(hashPassword(pw)) then
      Sessions[source]=cid; cb({ok=true})
    else
      cb({ok=false,msg='Kullanıcı adı / şifre hatalı veya hesap yok'})
    end
  end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:logout', function(source, cb) Sessions[source]=nil; cb({ok=true}) end)

QBCore.Functions.CreateCallback('osm-stockmarket:forgotPassword', function(source, cb, data)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false}); return end
  local cid = P.PlayerData.citizenid
  local email = data.email or ''
  if email=='' then cb({ok=false,msg='Email gerekli'}); return end
  local token = tostring(math.random(100000,999999))..tostring(math.random(100000,999999))
  local expires = os.date('%Y-%m-%d %H:%M:%S', os.time()+3600)
  dbQ([[INSERT INTO exchange_password_resets (token,citizenid,email,expires_at)
        VALUES (?,?,?,?)
        ON DUPLICATE KEY UPDATE citizenid=VALUES(citizenid), email=VALUES(email), expires_at=VALUES(expires_at)]], {token,cid,email,expires}, function()
    pcall(function() exports['lb-phone']:SendMail(email, 'Borsa Şifre Sıfırlama', ('Sıfırlama kodunuz: %s'):format(token), 'Borsa') end)
    cb({ok=true})
  end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:changePassword', function(source, cb, data)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false}); return end
  local cid = P.PlayerData.citizenid
  local oldp = data.old or ''; local newp = data.new or ''
  dbQ('SELECT password_hash FROM exchange_accounts WHERE citizenid=?',{cid}, function(r)
    if r[1] and tostring(r[1].password_hash)==tostring(hashPassword(oldp)) then
      dbQ('UPDATE exchange_accounts SET password_hash=? WHERE citizenid=?', {tostring(hashPassword(newp)), cid}, function() cb({ok=true}) end)
    else cb({ok=false,msg='Mevcut şifre yanlış'}) end
  end)
end)

-- Wallet: deposit/withdraw (now moving money between bank <-> borsa cüzdanı)
QBCore.Functions.CreateCallback('osm-stockmarket:deposit', function(source, cb, data)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false}); return end
  local cid = P.PlayerData.citizenid
  if Sessions[source] ~= cid then cb({ok=false,msg='Önce giriş yapın'}); return end
  local amt = tonumber(data.amount or 0) or 0
  if amt <= 0 then cb({ok=false,msg='Geçersiz tutar'}); return end
  local bank = P.Functions.GetMoney('bank') or 0
  if bank < amt then cb({ok=false,msg='Banka bakiyesi yetersiz'}); return end
  if not P.Functions.RemoveMoney('bank', amt, 'exchange-deposit') then cb({ok=false,msg='Banka çekimi başarısız'}) return end
  ensureWallet(cid, function()
    getWallet(cid, function(bal)
      local newBal = math.floor((bal+amt)*100)/100
      setWallet(cid, newBal, function()
        SafeAddJobMoney(Jobs.Exchange, math.floor(amt*1.2*100)/100) -- +20% to oblivion (bilgilendirme satırında belirtildiği gibi)
        dbQ('INSERT INTO exchange_cashlog (citizenid,type,amount,fee,net) VALUES (?,?,?,?,?)', {cid,'DEPOSIT',amt,0,amt})
        cb({ok=true,balance=newBal})
      end)
    end)
  end)
end)

RegisterNetEvent("osm-stockmarket:withdraw", function(amount)
    local src = source
    local acc = getAccount(src)
    if not acc then return end
    if acc.balance < amount then 
        TriggerClientEvent("osm-stockmarket:notify", src, "Yetersiz bakiye", "error")
        return
    end
    MySQL.update("UPDATE exchange_accounts SET balance = balance - ? WHERE id=?", {amount, acc.id})
    MySQL.insert("INSERT INTO exchange_withdraw_requests (user_id, amount) VALUES (?,?)",{acc.id,amount})
    TriggerClientEvent("osm-stockmarket:notify", src, "Çekim talebiniz oluşturuldu", "success")
end)

-- Admin: Users
QBCore.Functions.CreateCallback("admin:getUsers", function(src,cb)
    local result = MySQL.query.await("SELECT id,name,balance FROM exchange_accounts", {})
    cb(result)
end)

QBCore.Functions.CreateCallback("admin:getUserDetail", function(src,cb,data)
    local id = data.id
    local result = MySQL.query.await("SELECT * FROM exchange_accounts WHERE id=?", {id})
    if not result[1] then cb(nil) return end
    local portfolio = MySQL.query.await("SELECT * FROM exchange_portfolio WHERE user_id=?", {id})
    cb({
        id=result[1].id,
        name=result[1].name,
        email=result[1].email,
        balance=result[1].balance,
        pnl=result[1].pnl or 0,
        portfolio=portfolio
    })
end)

RegisterNetEvent("admin:freezeAccount", function(data)
    local src=source
    local acc=getAccount(src)
    if not acc or acc.perm<2 then return end
    MySQL.update("UPDATE exchange_accounts SET frozen=1 WHERE id=?", {data.id})
end)

QBCore.Functions.CreateCallback("admin:getFinance", function(src,cb)
    local sumDep = MySQL.query.await("SELECT SUM(amount) as s FROM exchange_deposits", {})[1].s or 0
    local sumWdr = MySQL.query.await("SELECT SUM(amount) as s FROM exchange_withdraws", {})[1].s or 0
    local balance = sumDep - sumWdr
    cb({balance=balance})
end)

RegisterNetEvent("admin:approveWithdraw", function(data)
    local src=source
    local acc=getAccount(src)
    if not acc or acc.perm<1 then return end
    local wid=data.id
    local req=MySQL.query.await("SELECT * FROM exchange_withdraw_requests WHERE id=?", {wid})
    if not req[1] then return end
    MySQL.update("UPDATE exchange_withdraw_requests SET status='approved' WHERE id=?", {wid})
    TriggerClientEvent("osm-stockmarket:notify",src,"Çekim onaylandı","success")
end)

RegisterNetEvent("admin:rejectWithdraw", function(data)
    local src=source
    local acc=getAccount(src)
    if not acc or acc.perm<1 then return end
    local wid=data.id
    local req=MySQL.query.await("SELECT * FROM exchange_withdraw_requests WHERE id=?", {wid})
    if not req[1] then return end
    MySQL.update("UPDATE exchange_withdraw_requests SET status='rejected' WHERE id=?", {wid})
    MySQL.update("UPDATE exchange_accounts SET balance=balance+? WHERE id=?", {req[1].amount, req[1].user_id})
    TriggerClientEvent("osm-stockmarket:notify",src,"Çekim reddedildi","error")
end)

-- Support
RegisterNetEvent("support:new", function(data)
    local src=source
    local acc=getAccount(src)
    if not acc then return end
    MySQL.insert('INSERT INTO exchange_tickets (user_id, subject, message) VALUES (?,?,?)',{acc.id,data.title,data.body})
end)

QBCore.Functions.CreateCallback("support:getMy", function(src,cb)
    local acc=getAccount(src)
    if not acc then cb({}) return end
    local result=MySQL.query.await("SELECT * FROM exchange_tickets WHERE user_id=?", {acc.id})
    cb(result)
end)

-- Chat
RegisterNetEvent("chat:send", function(data)
    local src=source
    local acc=getAccount(src)
    if not acc then return end
    MySQL.insert("INSERT INTO exchange_chat (user_id,message) VALUES (?,?)",{acc.id,data.msg})
    TriggerClientEvent("chat:receive",-1,{name=acc.name,msg=data.msg})
end)

-- Top gainers
QBCore.Functions.CreateCallback("market:topGainers", function(src,cb)
    local result=MySQL.query.await("SELECT name, pnl as profit FROM exchange_accounts ORDER BY pnl DESC LIMIT 30")
    cb(result)
end)



-- Subscription
QBCore.Functions.CreateCallback('osm-stockmarket:buySubscription', function(source, cb)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({ok=false}); return end
  local cid = P.PlayerData.citizenid
  local price = Subscription.MonthlyPrice
  if not P.Functions.RemoveMoney('bank', price, 'matrix-subscription') then cb({ok=false,msg='Bakiye yetersiz'}); return end
  local untilDate = os.date('%Y-%m-%d %H:%M:%S', os.time()+Subscription.DaysPerMonth*24*3600)
  dbQ([[INSERT INTO exchange_subscriptions (citizenid,active_until) VALUES (?,?)
        ON DUPLICATE KEY UPDATE active_until=VALUES(active_until)]], {cid, untilDate}, function()
    SafeAddJobMoney(Jobs.Exchange, price) -- subscription to oblivion
    cb({ok=true, active_until=untilDate})
  end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:getSubscription', function(source, cb)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({active_until=nil}); return end
  local cid = P.PlayerData.citizenid
  dbQ('SELECT active_until FROM exchange_subscriptions WHERE citizenid=?', {cid}, function(r) cb(r and r[1] or {active_until=nil}) end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:getMatrixData', function(source, cb)
  dbQ("SELECT kind,title,details,amount,created_at FROM exchange_events ORDER BY id DESC LIMIT 50", {}, function(r) cb(r) end)
end)

-- UI data
local function decorateStocksForUI()
  local out = {}
  for sym, s in pairs(Market.stocks) do
    out[sym] = {}
    for k,v in pairs(s) do out[sym][k]=v end
    out[sym].name = s.name -- komisyonu isim yanına eklemeyelim; üstte 'Komisyonlar' alanında gösteriliyor
  end
  return out
end

QBCore.Functions.CreateCallback('osm-stockmarket:getStocks', function(source, cb)
  for _, s in pairs(Market.stocks) do s.high24, s.low24 = compute24hHL(s) end
  cb(decorateStocksForUI(), {
    maxStocksPerPlayer = Config.MaxStocksPerPlayer or 100000,
    trading = Config.Trading or { MinQuantity = 1, MaxQuantity = 1000, UpdateInterval = 30, PriceDisplayDecimals = 2 },
    notifications = Config.Notifications or { Position = 'top-right', Duration = 3000, AnimationDuration = 300 },
    currency = Config.Currency or { Symbol = '$ ', Position = 'before', Code = 'USD ' },
    logos = Config.logos or { Enabled = true, Size = 64, Fallback = '' },
    commissions = { buyer = Fees.Buyer, seller = Fees.Seller }
  })
end)

QBCore.Functions.CreateCallback('osm-stockmarket:getMarketStats', function(source, cb)
  local totalVolume, active = 0, 0
  for _, s in pairs(Market.stocks) do if s.enabled then active=active+1; totalVolume = totalVolume + (s.volume or 0) end end
  cb({ totalVolume = math.floor(totalVolume), activeStocks = active })
end)

QBCore.Functions.CreateCallback('osm-stockmarket:getPortfolio', function(source, cb)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({}); return end
  local cid = P.PlayerData.citizenid
  dbQ('SELECT symbol,amount,average_price FROM player_stocks WHERE citizenid=?', {cid}, function(r) cb(r or {}) end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:getMyTransactions', function(source, cb)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({rows={}, net_pnl=0}); return end
  local cid = P.PlayerData.citizenid
  dbQ([[SELECT type,symbol,amount,price_per_share,total_value,profit_loss,timestamp
        FROM stock_transactions WHERE citizenid=? ORDER BY id DESC LIMIT 200]], {cid}, function(rows)
    local net_pnl = 0; local out = {}
    for _, r in ipairs(rows or {}) do
      local typ = r.type; local gross = tonumber(r.total_value or 0) or 0; local fee = 0
      if typ == 'BUY' then fee = math.floor(gross*Fees.Buyer*100)/100 end
      if typ == 'SELL' then fee = math.floor(gross*Fees.Seller*100)/100 end
      local net = (typ=='BUY') and (-(gross+fee)) or (gross-fee)
      net_pnl = net_pnl + net + (tonumber(r.profit_loss or 0) or 0)
      r.fee = fee; r.net = net; out[#out+1] = r
    end
    cb({rows=out, net_pnl=math.floor(net_pnl*100)/100})
  end)
end)

-- Buy/Sell now use borsa cüzdanı (exchange_wallet), bankayı değil
QBCore.Functions.CreateCallback('osm-stockmarket:buyStocks', function(source, cb, symbol, amount)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({success=false,msg='Oyuncu yok'}); return end
  local cid = P.PlayerData.citizenid
  if Sessions[source] ~= cid then cb({success=false,message='Önce kayıt/giriş yapın'}); return end
  local s = Market.stocks[(type(symbol)=='string' and symbol:upper() or '')]; amount = tonumber(amount or 0) or 0
  if not s or not s.enabled or amount<=0 then cb({success=false,message='Geçersiz'}); return end
  local price = s.currentPrice; local goods = math.floor(price*amount*100)/100
  local fee = math.floor(goods*Fees.Buyer*100)/100; local total = goods + fee
  ensureWallet(cid, function()
    getWallet(cid, function(bal)
      if (bal or 0) < total then cb({success=false,message='Borsa bakiyesi yetersiz (komisyon dahil)'}); return end
      setWallet(cid, math.floor((bal-total)*100)/100, function()
        SafeAddJobMoney(Jobs.Exchange, fee)
        dbQ('SELECT amount,average_price FROM player_stocks WHERE citizenid=? AND symbol=?',{cid,s.symbol}, function(r)
          local curr = (r[1] and tonumber(r[1].amount) or 0); local avg = (r[1] and tonumber(r[1].average_price) or 0)
          local newAmount = curr + amount; local newAvg = (curr<=0) and price or (((avg*curr)+(price*amount))/newAmount); newAvg=math.floor(newAvg*100)/100
          dbQ([[INSERT INTO player_stocks (citizenid,symbol,amount,average_price)
                VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE amount=VALUES(amount), average_price=VALUES(average_price)]], {cid,s.symbol,newAmount,newAvg})
          dbQ([[INSERT INTO stock_transactions (citizenid,type,symbol,amount,price_per_share,total_value,profit_loss)
                VALUES (?,?,?,?,?,?,0)]], {cid,'BUY',s.symbol,amount,price,goods})
          s.volume = (s.volume or 0) + amount
          if goods >= 10000 then dbQ('INSERT INTO exchange_events (kind,title,details,amount) VALUES (?,?,?,?)', {'WHALE', s.symbol..' ALIM', cid, goods}) end
          if goods >= 100000 then TriggerClientEvent('QBCore:Notify', source, 'BÜYÜK ALIM: '..s.symbol..' '..goods, 'primary', 7500) end
          cb({success=true,message=('Alım başarılı: %s x%d (Komisyon: %0.2f)'):format(s.symbol, amount, fee)})
        end)
      end)
    end)
  end)
end)

QBCore.Functions.CreateCallback('osm-stockmarket:sellStocks', function(source, cb, symbol, amount)
  local P = QBCore.Functions.GetPlayer(source); if not P then cb({success=false,msg='Oyuncu yok'}); return end
  local cid = P.PlayerData.citizenid
  if Sessions[source] ~= cid then cb({success=false,message='Önce kayıt/giriş yapın'}); return end
  local s = Market.stocks[(type(symbol)=='string' and symbol:upper() or '')]; amount = tonumber(amount or 0) or 0
  if not s or not s.enabled or amount<=0 then cb({success=false,message='Geçersiz'}); return end
  dbQ('SELECT amount,average_price FROM player_stocks WHERE citizenid=? AND symbol=?',{cid,s.symbol}, function(r)
    local curr = (r[1] and tonumber(r[1].amount) or 0); local avg = (r[1] and tonumber(r[1].average_price) or 0)
    if curr < amount then cb({success=false,message='Yetersiz hisse'}) return end
    local price = s.currentPrice; local gross = math.floor(price*amount*100)/100; local fee = math.floor(gross*Fees.Seller*100)/100; local net = gross - fee; if net < 0 then net = 0 end
    -- add net to wallet (borsa cüzdanı)
    ensureWallet(cid, function()
      getWallet(cid, function(bal)
        setWallet(cid, math.floor((bal+net)*100)/100, function()
          SafeAddJobMoney(Jobs.Exchange, fee)
          local newAmount = curr - amount
          if newAmount <= 0 then dbQ('DELETE FROM player_stocks WHERE citizenid=? AND symbol=?',{cid,s.symbol})
          else dbQ('UPDATE player_stocks SET amount=? WHERE citizenid=? AND symbol=?',{newAmount,cid,s.symbol}) end
          local pnl = math.floor((price-avg)*amount*100)/100
          dbQ([[INSERT INTO stock_transactions (citizenid,type,symbol,amount,price_per_share,total_value,profit_loss)
                VALUES (?,?,?,?,?,?,?)]], {cid,'SELL',s.symbol,amount,price,gross,pnl})
          s.volume = (s.volume or 0) + amount
          if gross >= 10000 then dbQ('INSERT INTO exchange_events (kind,title,details,amount) VALUES (?,?,?,?)', {'WHALE', s.symbol..' SATIM', cid, gross}) end
          if gross >= 100000 then TriggerClientEvent('QBCore:Notify', source, 'BÜYÜK SATIM: '..s.symbol..' '..gross, 'primary', 7500) end
          cb({success=true,message=('Satış başarılı: %s x%d | Komisyon: %0.2f | P/L: %0.2f'):format(s.symbol, amount, fee, pnl)})
        end)
      end)
    end)
  end)
end)

-- News command
local function hasAdminPerm(src)
  local req = (Config.CommandPermissions and Config.CommandPermissions['modifystock']) or 'admin'
  return QBCore.Functions.HasPermission(src, req)
end

QBCore.Commands.Add('modifystock','Fiyatı yüzde etkile',{ {name='symbol'}, {name='impact'}, {name='reason'} }, false, function(src,args)
  if not hasAdminPerm(src) then TriggerClientEvent('QBCore:Notify', src, 'Yetki yok','error'); return end
  local sym = tostring(args[1] or ''):upper(); local imp = tonumber(args[2] or 0) or 0; local reason = table.concat(args,' ',3)
  local s = Market.stocks[sym]; if not s then TriggerClientEvent('QBCore:Notify', src, 'Hisse yok','error'); return end
  local prev = s.currentPrice
  local nextP = clampPrice(s.basePrice, prev * (1+(imp/100)))
  nextP = math.floor(nextP*100)/100
  s.previousPrice = prev; s.currentPrice = nextP
  pushHistory(sym, os.time(), nextP); s.high24, s.low24 = compute24hHL(s)
  writeHistoryJson(); dbQ('INSERT INTO stocks_history (symbol,price,reason) VALUES (?,?,?)',{sym,nextP,reason~='' and reason or ('manual '..imp..'%')})
  dbQ('INSERT INTO exchange_events (kind,title,details) VALUES (?,?,?)', {'NEWS', (sym..' '..(reason or '')), (sym..' -> '..string.format('%0.2f',nextP))})
  broadcast()
  TriggerClientEvent('QBCore:Notify', src, (sym..' -> '..string.format('%0.2f',nextP)), 'success')
end)

QBCore.Commands.Add('stocks', 'Borsa arayüzünü aç', {}, false, function(src) TriggerClientEvent('osm-stockmarket:open', src) end)

AddEventHandler('playerDropped', function() Sessions[source]=nil end)
AddEventHandler('onResourceStart', function(res) if res ~= RESOURCE then return end loadStocks(function() startTicker(); print('[osm-stockmarket] Market yüklendi & ticker başladı') end) end)

-- Withdraw: create request
QBCore.Functions.CreateCallback('withdraw:request', function(src, cb, data)
    local acc = getAccount(src); if not acc then cb({ok=false, err='noacc'}) return end
    local amount = tonumber(data and data.amount) or 0
    if amount <= 0 then cb({ok=false, err='amount'}) return end
    if (acc.balance or 0) < amount then cb({ok=false, err='insufficient'}) return end
    MySQL.insert("INSERT INTO exchange_withdraw_requests (user_id, amount) VALUES (?,?)", {acc.id, amount}, function(id)
        if id then
            MySQL.update("UPDATE exchange_accounts SET balance = balance - ? WHERE id=?", {amount, acc.id})
            MySQL.insert("INSERT INTO exchange_withdraw_requests (user_id, amount) VALUES (?,?)", {acc.id, amount})
            MySQL.insert("INSERT INTO exchange_withdraws (user_id, amount) VALUES (?,?)", {acc.id, amount})
            cb({ok=true, id=id})
        else cb({ok=false}) end
    end)
end)


-- Chat: receive from client and broadcast + store
RegisterNetEvent('chat:send', function(payload)
  local src = source
  local acc = getAccount(src); if not acc then return end
  local msg = ''
  if type(payload) == 'table' and payload.msg then msg = tostring(payload.msg) end
  msg = string.sub(msg or '', 1, 500)
  if msg == '' then return end
  MySQL.insert('INSERT INTO exchange_chat (user_id, message) VALUES (?,?)', {acc.id, msg})
  local name = acc.name or 'User'
  TriggerClientEvent('chat:receive', -1, {name=name, msg=msg, user_id=acc.id})
end)

QBCore.Functions.CreateCallback('chat:list', function(src, cb)
  local rows = MySQL.query.await('SELECT ec.message, ec.created_at, ea.name FROM exchange_chat ec LEFT JOIN exchange_accounts ea ON ea.id=ec.user_id ORDER BY ec.id DESC LIMIT 100', {}) or {}
  cb(rows)
end)

