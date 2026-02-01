function showNotification(message, level){
  try{
    const wrap = document.createElement('div');
    wrap.className = 'osm-toast ' + (level||'');
    wrap.innerText = message;
    document.body.appendChild(wrap);
    setTimeout(()=>wrap.classList.add('hide'), 3500);
    setTimeout(()=>wrap.remove(), 4200);
  }catch(e){ console.log('notify error', e); }
}
(function(){
  const style = document.createElement('style');
  style.innerHTML = `.osm-toast{position:fixed;right:20px;bottom:20px;background:rgba(0,0,0,0.85);color:#fff;padding:10px 16px;border-radius:10px;font-size:14px;z-index:99999;transition:opacity .6s;opacity:1}
  .osm-toast.hide{opacity:0}.osm-toast.success{background:rgba(34,197,94,.9)}.osm-toast.error{background:rgba(239,68,68,.9)}`;
  document.head.appendChild(style);
})();    
let nuiReady = false;
let updateTimer = null;
let isInputActive = false;
let stocks = {};
let Config = {};
let session = { loggedIn: false };

function startUpdateTimer(){
  if (updateTimer) { clearInterval(updateTimer); updateTimer = null; }
  if (!nuiReady) return;
  updateTimer = setInterval(()=>{
    if (!isInputActive) { loadData(); }
    updateMarketSummary();
    if (!isInputActive) { loadPortfolioData(); }
    refreshAggPnl();
  }, 3000);
}
function formatCurrency(v){
  if (v===undefined || v===null) return '$ 0';
  try { return (Config?.currency?.Symbol || '$ ') + Number(v).toLocaleString('tr-TR', {minimumFractionDigits:2, maximumFractionDigits:2}); } catch(e){ return '$ '+v; }
}
function notify(msg, type='success', ms=3000){
  const box = document.getElementById('toasts'); if (!box) return;
  const el = document.createElement('div'); el.className = `toast ${type}`; el.textContent = msg;
  box.appendChild(el); setTimeout(()=>{ el.remove(); }, ms);
}
function closeUI(){ fetch(`https://${GetParentResourceName()}/hideComponent`, {method:'POST', body:'{}'}); }
window.addEventListener('keydown', (e)=>{ if (e.key === 'Escape'){ closeUI(); } });
document.addEventListener('click', (e)=>{ const btn = e.target.closest('#btn-close'); if(btn){ closeUI(); } });

// Track input focus to avoid clearing typed values on refresh
document.addEventListener('focusin', (e)=>{
  if (e.target && (e.target.matches('input,textarea'))) { isInputActive = true; }
});
document.addEventListener('focusout', (e)=>{
  if (e.target && (e.target.matches('input,textarea'))) {
    setTimeout(()=>{
      const a = document.activeElement;
      isInputActive = !!(a && a.matches && a.matches('input,textarea'));
    }, 0);
  }
});

async function post(name, data){ const r = await fetch(`https://${GetParentResourceName()}/${name}`, {method:'POST', body: JSON.stringify(data||{})}); return r.json(); }
function val(id){ return document.getElementById(id).value; }

async function refreshBalance(){
  try{
    const r = await fetch(`https://${GetParentResourceName()}/getBalance`, {method:'POST'});
    const { balance } = await r.json();
    const el = document.getElementById('walletBalance');
    if (el) el.textContent = formatCurrency(balance||0);
  }catch(e){}
}

async function refreshAggPnl(){
  try{
    const res = await fetch(`https://${GetParentResourceName()}/getMyTransactions`, {method:'POST'});
    const data = await res.json();
    const pnl = Number(data.net_pnl||0);
    const el = document.getElementById('aggPnl');
    if (el){
      el.textContent = formatCurrency(pnl);
      el.classList.remove('pos','neg');
      el.classList.add(pnl >= 0 ? 'pos' : 'neg');
    }
  }catch(e){}
}

async function loadData(){
  if (!nuiReady) return;
  try {
    const r = await fetch(`https://${GetParentResourceName()}/getStocks`, {method:'POST'});
    stocks = await r.json() || {};
    if (!isInputActive) renderStocks();
  } catch(e) {}
}
async function updateMarketSummary(){
  if (!nuiReady) return;
  try{
    const r = await fetch(`https://${GetParentResourceName()}/getMarketStats`, {method:'POST'});
    const s = await r.json();
    if (s) document.getElementById('totalVolume').textContent = Math.round(s.totalVolume||0);
  }catch(e){}
}
async function loadPortfolioData(){
  if (!nuiReady || !session.loggedIn) return;
  try{
    const r = await fetch(`https://${GetParentResourceName()}/getPortfolio`, {method:'POST'});
    const rows = await r.json() || [];
    if (!isInputActive) renderPortfolio(rows);
  }catch(e){}
}

function withBuyFee(price){ return price * (1 + (Config?.commissions?.buyer || 0)); }
function withSellFeeNet(price){ return price * (1 - (Config?.commissions?.seller || 0)); }

function renderStocks(){
  const list = document.getElementById('stocks-list'); if (!list) return;
  list.innerHTML='';
  const syms = Object.keys(stocks); syms.sort();
  syms.forEach(sym=>{
    const s = stocks[sym]; if (!s) return;
    const el = document.createElement('div'); el.className='stock-card';
    el.innerHTML = `
      <div class="stock-head">
        <div class="name">${s.name || s.symbol}</div>
        <div class="price">${formatCurrency(s.currentPrice)}</div>
      </div>
      <div class="stock-stats">
        <span>24s Yüksek: <strong>${formatCurrency(s.high24||s.currentPrice)}</strong></span>
        <span>24s Düşük: <strong>${formatCurrency(s.low24||s.currentPrice)}</strong></span>
      </div>
      <div class="trade-controls">
        <input class="qty" type="number" placeholder="Adet" data-symbol="${s.symbol}" />
        <button class="btn buy">Al</button>
        <button class="btn sell">Sat</button>
      </div>`;
    const qty = el.querySelector('.qty');
    const buy = el.querySelector('.buy');
    const sell = el.querySelector('.sell');
    const disableTrade = !session.loggedIn;
    buy.disabled = disableTrade; sell.disabled = disableTrade; qty.disabled = disableTrade;
    buy.onclick = async ()=>{
      const a = parseInt(qty.value||'0');
      const res = await fetch(`https://${GetParentResourceName()}/buyStocks`, {method:'POST', body: JSON.stringify({symbol:s.symbol, amount:a})});
      const out = await res.json();
      if (out.success){ notify(out.message||'Alım başarılı'); refreshBalance(); refreshAggPnl(); loadPortfolioData(); }
      else { notify(out.message||'Alım başarısız','error'); }
    };
    sell.onclick = async ()=>{
      const a = parseInt(qty.value||'0');
      const res = await fetch(`https://${GetParentResourceName()}/sellStocks`, {method:'POST', body: JSON.stringify({symbol:s.symbol, amount:a})});
      const out = await res.json();
      if (out.success){ notify(out.message||'Satış başarılı'); refreshBalance(); refreshAggPnl(); loadPortfolioData(); }
      else { notify(out.message||'Satış başarısız','error'); }
    };
    list.appendChild(el);
  });
}

function renderPortfolio(rows){
  const pane = document.getElementById('portfolio'); if (!pane) return;
  pane.innerHTML = '';
  if (!rows || !rows.length){ pane.innerHTML = '<div class="card">Portföy boş.</div>'; return; }
  rows.forEach(r=>{
    const s = stocks[r.symbol];
    const current = s ? Number(s.currentPrice||0) : 0;
    const avgCost = Number(r.average_price||0);
    const avgIncl = withBuyFee(avgCost);
    const currentNet = withSellFeeNet(current);
    const qty = Number(r.amount||0);
    const pnlPerShare = currentNet - avgIncl;
    const pnlTotal = pnlPerShare * qty;
    const el = document.createElement('div'); el.className='card';
    el.innerHTML = `
      <h4>${r.symbol}</h4>
      <div class="metric"><div>Sahip Olunan Hisseler</div><div>${qty}</div></div>
      <div class="metric"><div>Ortalama Maliyet (komisyon dahil)</div><div>${formatCurrency(avgIncl)}</div></div>
      <div class="metric"><div>Güncel Fiyat (satış komisyonu sonrası net)</div><div>${formatCurrency(currentNet)}</div></div>
      <div class="metric"><div>Kar/Zarar (adet başına)</div><div class="${pnlPerShare>=0?'val pos':'val neg'}">${formatCurrency(pnlPerShare)}</div></div>
      <div class="metric"><div>Toplam Kar/Zarar</div><div class="${pnlTotal>=0?'val pos':'val neg'}">${formatCurrency(pnlTotal)}</div></div>
      <div class="trade-controls" style="margin-top:8px">
        <input class="sell-qty" type="number" min="1" max="${qty}" placeholder="Adet" />
        <button class="btn sell-part">Parça Sat</button>
        <button class="btn sell">Hepsini Sat</button>
      </div>`;
    const sellQty = el.querySelector('.sell-qty');
    el.querySelector('.sell-part').onclick = async ()=>{
      const a = parseInt(sellQty.value||'0');
      if (!a || a<1){ notify('Geçersiz adet','error'); return; }
      const res = await fetch(`https://${GetParentResourceName()}/sellStocks`, {method:'POST', body: JSON.stringify({symbol:r.symbol, amount:a})});
      const out = await res.json();
      if (out.success){ notify(out.message||'Satış başarılı'); refreshBalance(); refreshAggPnl(); loadPortfolioData(); }
      else notify(out.message||'Satış başarısız','error');
    };
    el.querySelector('.sell').onclick = async ()=>{
      const res = await fetch(`https://${GetParentResourceName()}/sellStocks`, {method:'POST', body: JSON.stringify({symbol:r.symbol, amount:qty})});
      const out = await res.json();
      if (out.success){ notify(out.message||'Satış başarılı'); refreshBalance(); refreshAggPnl(); loadPortfolioData(); }
      else notify(out.message||'Satış başarısız','error');
    };
    pane.appendChild(el);
  });
}

async function renderHistory(){
  const pane = document.getElementById('history'); if (!pane) return;
  pane.innerHTML = '';
  const res = await fetch(`https://${GetParentResourceName()}/getMyTransactions`, {method:'POST'});
  const data = await res.json();
  const rows = data.rows || []; const net = data.net_pnl || 0;
  const top = document.createElement('div'); top.className='card';
  const cls = net>=0 ? 'pos' : 'neg';
  top.innerHTML = `<h3>Hesap Açılışından Beri Net PnL: <span class="val ${cls}">${formatCurrency(net)}</span></h3>`;
  pane.appendChild(top);
  if (!rows.length){ pane.appendChild(Object.assign(document.createElement('div'),{className:'card',innerHTML:'Kayıt yok.'})); return; }
  rows.forEach(r=>{
    const isBuy = (r.type||'').toUpperCase()==='BUY';
    const netCls = (Number(r.net||0)>=0?'pos':'neg');
    const plCls  = (Number(r.profit_loss||0)>=0?'pos':'neg');
    const el = document.createElement('div'); el.className='history-row';
    el.innerHTML = `
      <div class="top">
        <div><span class="pill ${isBuy?'buy':'sell'}">${r.type}</span> <strong>${r.symbol} x${r.amount}</strong></div>
        <div>${new Date(r.timestamp||Date.now()).toLocaleString()}</div>
      </div>
      <div class="sep"></div>
      <div class="kv"><div>Fiyat</div><div>${formatCurrency(r.price_per_share)}</div></div>
      <div class="kv"><div>Brüt Tutar</div><div>${formatCurrency(r.total_value)}</div></div>
      <div class="kv"><div>Komisyon</div><div class="val warn">${formatCurrency(r.fee)}</div></div>
      <div class="kv"><div>Net</div><div class="val ${netCls}">${formatCurrency(r.net)}</div></div>
      <div class="kv"><div>P/L</div><div class="val ${plCls}">${formatCurrency(r.profit_loss)}</div></div>`;
    pane.appendChild(el);
  });
}

async function renderMatrix(){
  const pane = document.getElementById('matrix'); if (!pane) return;
  pane.innerHTML = '';
  const sub = await (await fetch(`https://${GetParentResourceName()}/getSubscription`, {method:'POST'})).json();
  const until = sub && sub.active_until;
  if (!until){
    pane.innerHTML = `<div class="card"><h3>Matriks Data</h3><p>Bu alan özel aboneliktir. Aylık 5000$.</p><button id="btn-buy-sub" class="btn btn-primary">Abone Ol</button></div>`;
    document.getElementById('btn-buy-sub').onclick = async ()=>{
      const r = await (await fetch(`https://${GetParentResourceName()}/buySubscription`, {method:'POST'})).json();
      if (r.ok){ notify('Abonelik aktif'); renderMatrix(); } else notify(r.msg||'Başarısız','error');
    };
    return;
  }
  pane.innerHTML = `<div class="card"><h3>Matriks Data</h3><p>Abonelik bitiş: ${until}</p><div id="mx-whales"></div><div id="mx-news"></div></div>`;
  const data = await (await fetch(`https://${GetParentResourceName()}/getMatrixData`, {method:'POST'})).json();
  const whales = (data||[]).filter(x=>x.kind==='WHALE');
  const news   = (data||[]).filter(x=>x.kind==='NEWS');
  const w = document.getElementById('mx-whales');
  const n = document.getElementById('mx-news');
  w.innerHTML = '<h4>10.000$+ İşlemler</h4>' + (whales.map(x=>`<div class="kv"><div>${x.title}</div><div>${formatCurrency(x.amount)}</div></div>`).join('') || '<div class="kv">Kayıt yok</div>');
  n.innerHTML = '<h4>Haberler</h4>' + (news.map(x=>`<div class="kv"><div>${x.title}</div><div>${new Date(x.created_at).toLocaleString()}</div></div>`).join('') || '<div class="kv">Kayıt yok</div>');
}

// Modals & auth buttons
function openModal(id){ document.getElementById(id).style.display='block'; }
function closeModals(){ document.querySelectorAll('.modal').forEach(m=>m.style.display='none'); }

window.addEventListener('load', ()=>{
  document.querySelectorAll('.modal .modal-close').forEach(b=>b.addEventListener('click', closeModals));
  document.getElementById('btn-open-register').onclick = ()=>openModal('modal-register');
  document.getElementById('btn-open-login').onclick = ()=>openModal('modal-login');
  document.getElementById('link-forgot').onclick = (e)=>{ e.preventDefault(); closeModals(); openModal('modal-forgot'); };

  document.getElementById('reg-submit').onclick = async ()=>{
    const data = { name: val('reg-name'), phone: val('reg-phone'), email: val('reg-email'), password: val('reg-pass') };
    const out = await post('registerAccount', data);
    if(out.ok){ afterLogin(); notify('Kayıt başarılı'); } else notify(out.msg||'Kayıt başarısız','error');
  };
  document.getElementById('log-submit').onclick = async ()=>{
    const out = await post('loginAccount', { username: val('log-user'), password: val('log-pass') });
    if(out.ok){ afterLogin(); notify('Giriş başarılı'); } else notify(out.msg||'Giriş başarısız','error');
  };
  document.getElementById('btn-logout').onclick = async ()=>{
    const out = await post('logoutAccount',{});
    if(out.ok){ afterLogout(); notify('Çıkış yapıldı'); }
  };
  document.getElementById('fp-submit').onclick = async ()=>{
    const out = await post('forgotPassword', { email: val('fp-email') });
    if(out.ok){ notify('E-posta gönderildi'); closeModals(); } else notify(out.msg||'Gönderilemedi','error');
  };
  document.getElementById('btn-deposit').onclick = async ()=>{
    const amt = Number(val('dep-amount')||0); const out = await post('deposit', {amount:amt});
    if(out.ok){ notify('Yatırıldı'); refreshBalance(); refreshAggPnl(); } else notify(out.msg||'Başarısız','error');
  };
  document.getElementById('btn-withdraw').onclick = async ()=>{
    const amt = Number(val('wd-amount')||0); const out = await post('withdraw', {amount:amt});
    if(out.ok){ notify('Çekildi'); refreshBalance(); refreshAggPnl(); } else notify(out.msg||'Başarısız','error');
  };
  document.getElementById('btn-changepw').onclick = async ()=>{
    const out = await post('changePassword', { old: val('pwd-old'), new: val('pwd-new') });
    if(out.ok){ notify('Şifre değişti'); } else notify(out.msg||'Hata','error');
  };
  document.getElementById('btn-refresh').onclick = ()=>{ loadData(); updateMarketSummary(); loadPortfolioData(); refreshBalance(); refreshAggPnl(); };

  document.querySelectorAll('.tabs button[data-tab]').forEach(b=>{
    b.onclick = ()=>{
      document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
      document.getElementById('tab-'+b.dataset.tab).classList.add('active');
      if(b.dataset.tab==='history') renderHistory();
      if(b.dataset.tab==='matrix') renderMatrix();
      if(b.dataset.tab==='portfolio') loadPortfolioData();
    };
  });
});

// NUI message handler
window.addEventListener('message', (event)=>{
  if (event.data.action === 'init') {
    nuiReady = true;
    stocks = event.data.data.stocks;
    Config = { ...Config, ...event.data.data.config };
    if (Config && Config.commissions){
      const f = Config.commissions; const buyerPct=(f.buyer*100).toFixed(2); const sellerPct=(f.seller*100).toFixed(2);
      const el = document.getElementById('feesInfo'); if (el) el.textContent = `Alıcı %${buyerPct} | Satıcı %${sellerPct}`;
    }
    fetch(`https://${GetParentResourceName()}/checkSession`, {method:'POST'}).then(r=>r.json()).then(s=>{ session.loggedIn = !!(s && s.loggedIn); applyAuthUI(); });
    renderStocks(); updateMarketSummary(); startUpdateTimer(); refreshBalance(); refreshAggPnl();
  } else if (event.data.action === 'updateStocks') {
    if (!isInputActive){ stocks = event.data.data; renderStocks(); updateMarketSummary(); }
  } else if (event.data.action === 'setVisibleStockMarket') {
  } else if (event.data.action === 'openAdmin') {
    const root = document.getElementById('root');
    if(root){ root.style.display='block'; root.setAttribute('tabindex','-1'); root.focus(); }
    const panel = document.getElementById('admin-panel');
    if(panel){ panel.style.display='flex'; }
    fetchNui('admin:getUsers',{}, res=>{ if(typeof renderUsers==='function') renderUsers(res); });
    fetchNui('admin:getFinance',{}, res=>{ const el=document.getElementById('admin-oblivion-balance'); if(el && res) el.innerText='$ '+(res.balance||0); });
  } else if (event.data.action === 'notify') {
    if(typeof showNotification==='function') showNotification(event.data.text || 'Bilgi', event.data.level || 'success');
  } else if (event.data.action === 'chat:receive') {
    if (typeof appendChat==='function') appendChat(event.data.data);
  }

    const root = document.getElementById('root'); root.style.display = event.data.data ? 'block':'none';
    if (event.data.data) { root.setAttribute('tabindex','-1'); root.focus(); startUpdateTimer(); }
    else { if (updateTimer){ clearInterval(updateTimer); updateTimer=null; } }
  }
);

function applyAuthUI(){
  const guest = document.getElementById('auth-guest');
  const user  = document.getElementById('auth-user');
  const tabs  = document.getElementById('tabs');
  guest.style.display = session.loggedIn ? 'none':'block';
  user.style.display  = session.loggedIn ? 'block':'none';
  tabs.style.display  = session.loggedIn ? 'block':'none';
}
function afterLogin(){ closeModals(); session.loggedIn=true; applyAuthUI(); loadPortfolioData(); refreshBalance(); refreshAggPnl(); }
function afterLogout(){ session.loggedIn=false; applyAuthUI(); }

// =============== GLOBALS ===================
let myPerm = 0; // 0=normal,1=mod,2=admin,3=kurucu
let topGainers = [];

// =============== HELPER FUNCS ==============
function toast(msg, type="success"){
  const box = document.createElement("div");
  box.className = "toast " + type;
  box.innerText = msg;
  document.getElementById("toasts").appendChild(box);
  setTimeout(()=>box.remove(),3000);
}

function setTab(tab){
  document.querySelectorAll(".tab").forEach(t=>t.classList.remove("active"));
  document.getElementById("tab-"+tab).classList.add("active");
}
function setAdminTab(tab){
  document.querySelectorAll("#admin-panel .tab").forEach(t=>t.classList.remove("active"));
  document.getElementById("admin-"+tab).classList.add("active");
}

// =============== ADMIN PANEL ===============
document.getElementById("btn-admin-close").onclick = ()=>{
  document.getElementById("admin-panel").style.display="none";
};
document.querySelectorAll("#admin-panel .tabs button").forEach(b=>{
  b.onclick=()=>setAdminTab(b.dataset.admintab);
});

// admin panel açma butonu
document.getElementById("btn-admin").onclick=()=>{
  document.getElementById("admin-panel").style.display="flex";
  // backendden veri çek
  fetchNui("admin:getUsers",{},res=>{
    renderUsers(res);
  });
  fetchNui("admin:getFinance",{},res=>{
    document.getElementById("admin-oblivion-balance").innerText="$ "+res.balance;
  });
};

// kullanıcı liste render
function renderUsers(users){
  const wrap=document.getElementById("users-list");
  wrap.innerHTML="";
  users.forEach(u=>{
    let row=document.createElement("div");
    row.className="user-row";
    row.innerHTML=`<span>${u.name}</span><span>$${u.balance}</span>`;
    row.onclick=()=>showUserDetail(u.id);
    wrap.appendChild(row);
  });
}
function showUserDetail(uid){
  fetchNui("admin:getUserDetail",{id:uid},res=>{
    const detail=document.createElement("div");
    detail.className="card";
    detail.innerHTML=`
      <h3>${res.name} (${res.email})</h3>
      <p>Bakiye: $${res.balance}</p>
      <p>Portföy: ${JSON.stringify(res.portfolio)}</p>
      <p>Kazanç: $${res.pnl}</p>
      <button onclick="freezeAccount(${uid})" class="btn btn-secondary">Hesap Dondur</button>
    `;
    document.getElementById("admin-users").appendChild(detail);
  });
}
function freezeAccount(uid){
  fetchNui("admin:freezeAccount",{id:uid},res=>{
    toast("Hesap donduruldu","success");
  });
}

// =============== SUPPORT (TICKETS) ===============
document.getElementById("btn-new-ticket").onclick=()=>{
  let title=prompt("Talep başlığı:");
  let body=prompt("Açıklama:");
  fetchNui("support:new",{title,body},res=>{
    toast("Talep oluşturuldu");
  });
};
function renderSupportTickets(list){
  const wrap=document.getElementById("support-myreqs");
  wrap.innerHTML="";
  list.forEach(t=>{
    let d=document.createElement("div");
    d.className="req-row";
    d.innerHTML=`#${t.id} - ${t.title} (${t.status})`;
    wrap.appendChild(d);
  });
}

// =============== TOP GAINERS PYRAMID ============
document.getElementById("btn-topgainers").onclick=()=>{
  fetchNui("market:topGainers",{},res=>{
    topGainers=res;
    showPyramid();
  });
};
function showPyramid(){
  const modal=document.createElement("div");
  modal.className="modal";
  const box=document.createElement("div");
  box.className="modal-box";
  box.innerHTML="<h3>En Çok Kazananlar</h3><div class='pyramid' id='pyr'></div><div class='modal-actions'><button class='btn modal-close'>Kapat</button></div>";
  modal.appendChild(box);
  document.body.appendChild(modal);
  let pyr=document.getElementById("pyr");
  let idx=0;
  let rows=[1,2,4,6,8,9]; // toplam 30
  rows.forEach(r=>{
    let row=document.createElement("div");
    row.className="pyramid-row";
    for(let i=0;i<r;i++){
      if(idx<topGainers.length){
        let b=document.createElement("div");
        b.className="box";
        b.innerText=topGainers[idx].name+"\n$"+topGainers[idx].profit;
        row.appendChild(b);
        idx++;
      }
    }
    pyr.appendChild(row);
  });
  box.querySelector(".modal-close").onclick=()=>modal.remove();
}

// =============== CHAT ===========================
document.getElementById("btn-chat").onclick=()=>{
  const modal=document.createElement("div");
  modal.className="modal";
  modal.innerHTML=`<div class="modal-box"><h3>Sohbet</h3><div id="chat-box" style="height:200px;overflow:auto;border:1px solid #333;padding:6px;margin-bottom:8px"></div><input id="chat-msg" placeholder="Mesaj yaz" /><button id="chat-send" class="btn btn-primary">Gönder</button><div class="modal-actions"><button class="btn modal-close">Kapat</button></div></div>`;
  document.body.appendChild(modal);
  modal.querySelector(".modal-close").onclick=()=>modal.remove();
  modal.querySelector("#chat-send").onclick=()=>{
    let m=modal.querySelector("#chat-msg").value;
    fetchNui("chat:send",{msg:m},()=>{});
  };
};

// =============== NUI BIND =======================
function fetchNui(event,data,cb){
  fetch(`https://osm-stockmarket/${event}`,{
    method:"POST",
    headers:{"Content-Type":"application/json; charset=UTF-8"},
    body:JSON.stringify(data||{})
  }).then(r=>r.json()).then(cb);
}

(function(){
  const css = `.support-modal{position:fixed;inset:0;display:none;align-items:center;justify-content:center;z-index:99999;background:rgba(0,0,0,.4)}
  .support-card{background:#0b1220;border:1px solid #374151;border-radius:12px;padding:16px;min-width:340px;color:#fff}
  .support-card input,.support-card textarea{width:100%;margin:6px 0;padding:8px;border-radius:8px;border:1px solid #4b5563;background:#0b1220;color:#fff}
  .support-actions{display:flex;gap:8px;justify-content:flex-end;margin-top:10px}
  .btn{padding:8px 12px;border-radius:8px;border:1px solid #374151;background:#1f2937;color:#fff;cursor:pointer}
  .btn.primary{background:#2563eb;border-color:#1d4ed8}`;
  const st=document.createElement('style'); st.innerHTML=css; document.head.appendChild(st);
  const wrap=document.createElement('div'); wrap.className='support-modal'; wrap.innerHTML=`
    <div class="support-card">
      <h3>Yeni Destek Talebi</h3>
      <input id="sup-subject" placeholder="Talep başlığı"/>
      <textarea id="sup-message" rows="4" placeholder="Açıklama"></textarea>
      <div class="support-actions">
        <button class="btn" id="sup-cancel">İptal</button>
        <button class="btn primary" id="sup-send">Gönder</button>
      </div>
    </div>`;
  document.body.appendChild(wrap);
  function openSupport(){ wrap.style.display='flex'; }
  function closeSupport(){ wrap.style.display='none'; }
  window.openSupport=openSupport; window.closeSupport=closeSupport;
  const btn = document.getElementById('btn-new-ticket');
  if(btn){ btn.onclick=(e)=>{ e.preventDefault(); openSupport(); }; }
  wrap.addEventListener('click', e=>{ if(e.target===wrap) closeSupport(); });
  document.addEventListener('click', e=>{
    if(e.target && e.target.id==='sup-cancel') closeSupport();
    if(e.target && e.target.id==='sup-send'){
      const subject=document.getElementById('sup-subject').value.trim();
      const message=document.getElementById('sup-message').value.trim();
      if(!subject || !message){ showNotification('Başlık ve açıklama zorunlu','error'); return; }
      fetchNui('support:new',{subject,message}, res=>{
        if(res && res.ok){ showNotification('Talep oluşturuldu','success'); closeSupport(); fetchNui('support:list',{}, (list)=>{ if(typeof renderTickets==='function') renderTickets(list); }); }
        else{ showNotification('Talep oluşturulamadı','error'); }
      });
    }
  });
})();
function appendChat(payload){
  if(!payload) return;
  const box = document.getElementById('chat-box');
  if(!box) return;
  const line = document.createElement('div');
  line.className = 'chat-line';
  line.textContent = (payload.name ? payload.name : 'Anon') + ': ' + (payload.msg || '');
  box.appendChild(line);
  box.scrollTop = box.scrollHeight;
}


function fmtMs(ms){
  if(!ms) return '-';
  const d = new Date(parseInt(ms,10));
  if(isNaN(d.getTime())) return String(ms);
  return d.toLocaleString();
}
