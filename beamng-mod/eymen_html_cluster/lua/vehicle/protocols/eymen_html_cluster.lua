-- EYMEN HTML Cluster — BeamNG vehicle protocol
-- iPhone Safari: http://PC_IP:8765   (PC’ye ayrı program yok, sadece bu mod)
-- Arabaya bin → Ctrl+R

local M = {}

local PORT = 8765
local socket = require('libs/luasocket/socket.socket')

local server
local clients = {} -- client -> { buf = string }
local latestJson = '{"ok":false,"source":"boot"}'
local trail = {}

local function clamp01(v)
  v = tonumber(v) or 0
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function gearLabel()
  local ev = electrics.values
  local g = ev.gearIndex
  if g == nil then g = ev.gear end
  g = tonumber(g)
  if g == nil then
    local s = tostring(ev.gear or 'N')
    if s == 'R' or s == 'N' or s == 'P' or s == 'D' then return s end
    return 'N'
  end
  if g < 0 then return 'R' end
  if g == 0 then return 'N' end
  return tostring(math.floor(g))
end

local function pushTrail(x, y)
  local last = trail[#trail]
  if not last or ((x - last.x) ^ 2 + (y - last.y) ^ 2 > 2.25) then
    trail[#trail + 1] = { x = x, y = y, t = math.floor(socket.gettime() * 1000) }
    while #trail > 200 do table.remove(trail, 1) end
  end
end

local function buildTelemetry()
  if not electrics or not electrics.values or not obj then
    return latestJson
  end
  local ev = electrics.values
  local speedMs = tonumber(ev.wheelspeed or ev.airspeed or 0) or 0
  local rpm = tonumber(ev.rpm or 0) or 0
  local fuel = tonumber(ev.fuel or 0) or 0
  if fuel > 1.01 then fuel = fuel / 100 end
  fuel = clamp01(fuel)

  local pos = obj:getPosition()
  local dir = obj:getDirectionVector()
  local yaw = math.atan2(dir.x, dir.y)
  pushTrail(pos.x, pos.y)

  local trailParts = {}
  for i = 1, #trail do
    local p = trail[i]
    trailParts[#trailParts + 1] = string.format('{"x":%.2f,"y":%.2f,"t":%d}', p.x, p.y, p.t)
  end

  local function on(v) return tostring((tonumber(v) or 0) > 0.5) end

  local lights = string.format(
    '{"shift":%s,"fullbeam":%s,"handbrake":%s,"tc":%s,"signalL":%s,"signalR":%s,"oilWarn":%s,"battery":%s,"abs":%s}',
    on(ev.should_shift), on(ev.highbeam), on(ev.parkingbrake), on(ev.esc or ev.tcs),
    on(ev.signal_L), on(ev.signal_R), on(ev.oil), on(ev.lowpressure), on(ev.abs)
  )

  local boost = tonumber(ev.turboBoost or ev.boost or 0) or 0

  return string.format(
    '{"gearLabel":"%s","speedKmh":%.2f,"speedMph":%.2f,"preferKm":true,"rpm":%.1f,"turbo":%.2f,"engTemp":%.1f,"fuel":%.3f,"throttle":%.3f,"brake":%.3f,"showTurbo":%s,"source":"live","lights":%s,"map":{"x":%.2f,"y":%.2f,"z":%.2f,"yaw":%.4f,"velX":0,"velY":0,"speedMs":%.3f},"trail":[%s]}',
    gearLabel(),
    speedMs * 3.6,
    speedMs * 2.236936,
    rpm,
    boost,
    tonumber(ev.watertemp or ev.oiltemp or 90) or 90,
    fuel,
    clamp01(ev.throttle),
    clamp01(ev.brake),
    tostring(boost ~= 0),
    lights,
    pos.x, pos.y, pos.z, yaw, speedMs,
    table.concat(trailParts, ',')
  )
end

local INDEX_HTML = nil -- filled below

local function httpResponse(status, contentType, body)
  return table.concat({
    'HTTP/1.1 ', status, '\r\n',
    'Content-Type: ', contentType, '\r\n',
    'Content-Length: ', tostring(#body), '\r\n',
    'Connection: close\r\n',
    'Access-Control-Allow-Origin: *\r\n',
    'Cache-Control: no-store\r\n',
    '\r\n',
    body
  })
end

local function reply(client, body)
  pcall(function() client:send(body) end)
  pcall(function() client:close() end)
  clients[client] = nil
end

local function processRequest(client, reqHead)
  local path = reqHead:match('^%w+%s+(.-)%s+HTTP') or '/'
  path = path:match('^([^%?]+)') or path
  if path == '/t' or path == '/api/telemetry' then
    reply(client, httpResponse('200 OK', 'application/json; charset=utf-8', latestJson))
  elseif path == '/' or path == '/index.html' then
    reply(client, httpResponse('200 OK', 'text/html; charset=utf-8', INDEX_HTML))
  else
    reply(client, httpResponse('404 Not Found', 'text/plain', 'not found'))
  end
end

local function pumpClients()
  for client, state in pairs(clients) do
    local chunk, err, partial = client:receive(2048)
    if chunk then
      state.buf = state.buf .. chunk
    elseif partial and partial ~= '' then
      state.buf = state.buf .. partial
    end

    if err == 'closed' then
      clients[client] = nil
      pcall(function() client:close() end)
    else
      local headerEnd = state.buf:find('\r\n\r\n', 1, true)
      if headerEnd then
        local head = state.buf:sub(1, headerEnd - 1)
        processRequest(client, head)
      end
    end
  end
end

local function ensureServer()
  if server then return true end
  local ok, sockOrErr = pcall(function()
    local s = assert(socket.bind('0.0.0.0', PORT))
    s:settimeout(0)
    local ip, port = s:getsockname()
    log('I', 'eymen_html_cluster', string.format('iPhone HTML cluster ready → http://%s:%s', tostring(ip), tostring(port)))
    return s
  end)
  if ok then
    server = sockOrErr
    return true
  end
  log('E', 'eymen_html_cluster', 'HTTP bind failed: ' .. tostring(sockOrErr))
  return false
end

local function updateGFX(dt)
  latestJson = buildTelemetry()
  if not ensureServer() then return end

  local client = server:accept()
  if client then
    client:settimeout(0)
    clients[client] = { buf = '' }
  end
  pumpClients()
end

local function onInit()
  ensureServer()
  log('I', 'eymen_html_cluster', 'EYMEN HTML Cluster loaded. iPhone Safari: http://PC_IP:8765  (Ctrl+R after spawn)')
end

INDEX_HTML = [[<!DOCTYPE html>
<html lang="tr"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover"/>
<meta name="apple-mobile-web-app-capable" content="yes"/>
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
<meta name="theme-color" content="#02060c"/>
<title>EYMEN</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;height:100%;overflow:hidden;color:#e9f7ff;
font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display",monospace;user-select:none;-webkit-user-select:none;touch-action:manipulation}
body{background:radial-gradient(ellipse 90% 60% at 50% -20%,#123055,transparent 55%),#02060c}
.wrap{height:100%;display:grid;grid-template-rows:auto 1fr auto;padding:max(10px,env(safe-area-inset-top)) 14px max(10px,env(safe-area-inset-bottom))}
.top{display:flex;justify-content:space-between;align-items:center}
.brand{font-weight:800;letter-spacing:.3em;color:#5ee7ff}
.chip{font-size:11px;letter-spacing:.16em;border:1px solid rgba(94,231,255,.25);padding:6px 10px;color:#6f8aa3}
.chip.live{color:#3dffb0;border-color:rgba(61,255,176,.45)}.chip.lost{color:#ff4d3a;border-color:rgba(255,77,58,.45)}
.main{display:grid;grid-template-columns:1fr 1.15fr 1fr;gap:10px;min-height:0;align-items:center}
.big{font-size:clamp(30px,10vh,58px);font-weight:800;text-align:center}
.sub{font-size:10px;letter-spacing:.22em;color:#6f8aa3;text-align:center;margin-top:4px}
.center{display:flex;flex-direction:column;align-items:center;gap:8px;min-width:0}
.gear{font-size:clamp(40px,11vh,68px);font-weight:800}
.icons{display:flex;flex-wrap:wrap;gap:5px;justify-content:center}
.ico{font-size:9px;letter-spacing:.06em;border:1px solid rgba(111,138,163,.28);color:rgba(111,138,163,.35);padding:4px 7px}
.ico.on{color:#3dffb0;border-color:rgba(61,255,176,.55)}.ico.warn.on{color:#ffc14d}.ico.hot.on{color:#ff4d3a}
.map{width:100%;border:1px solid rgba(94,231,255,.2);background:rgba(4,12,22,.8)}
canvas{width:100%;height:28vh;max-height:230px;display:block}
.ped{width:100%;height:6px;background:rgba(255,255,255,.06)}.ped>i{display:block;height:100%;width:0;background:linear-gradient(90deg,#2f7dff,#5ee7ff)}
.ped.b>i{background:linear-gradient(90deg,#ff4d3a,#ffb09a)}
.bot{display:flex;gap:10px;align-items:center;font-size:11px;border-top:1px solid rgba(94,231,255,.1);padding-top:8px}
.bar{flex:1;height:6px;background:rgba(255,255,255,.06)}.bar>i{display:block;height:100%;width:0;background:linear-gradient(90deg,#2f7dff,#9fe9ff)}
.meta{margin-left:auto;color:#6f8aa3;white-space:nowrap}
@media(orientation:portrait){.main{grid-template-columns:1fr}}
</style></head><body>
<div class="wrap">
<div class="top"><div class="brand">EYMEN</div><div class="chip" id="st">BAĞLANIYOR</div></div>
<div class="main">
  <div><div class="big" id="spd">0</div><div class="sub">km/h</div></div>
  <div class="center">
    <div class="icons">
      <span class="ico" id="iL">◀</span><span class="ico" id="iB">BEAM</span><span class="ico" id="iR">▶</span>
      <span class="ico warn" id="iP">P</span><span class="ico warn" id="iA">ABS</span>
      <span class="ico warn" id="iT">TC</span><span class="ico hot" id="iS">SHIFT</span>
    </div>
    <div class="gear" id="gear">N</div><div class="sub">GEAR</div>
    <div class="map"><canvas id="cv"></canvas></div>
    <div class="ped"><i id="thr"></i></div><div class="ped b"><i id="brk"></i></div>
  </div>
  <div><div class="big" id="rpm">0.0</div><div class="sub">×1000 rpm</div></div>
</div>
<div class="bot"><span>FUEL</span><div class="bar"><i id="fuel"></i></div><b id="fuelv">—</b>
<span>TEMP</span><div class="bar"><i id="temp"></i></div><b id="tempv">—</b>
<span class="meta" id="meta">iPhone HTML</span></div>
</div>
<script>
const $=i=>document.getElementById(i);const cv=$('cv'),ctx=cv.getContext('2d');
function fit(){const r=cv.getBoundingClientRect(),d=Math.min(2,devicePixelRatio||1);cv.width=Math.max(240,r.width*d);cv.height=Math.max(110,r.height*d)}
fit();addEventListener('resize',fit);addEventListener('orientationchange',()=>setTimeout(fit,200));
const on=(e,v)=>e.classList.toggle('on',!!v);
function draw(d){const m=d.map,trail=d.trail||[],w=cv.width,h=cv.height;ctx.clearRect(0,0,w,h);
ctx.strokeStyle='rgba(94,231,255,.08)';for(let x=0;x<w;x+=22){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke()}
if(!m){ctx.fillStyle='#6f8aa3';ctx.font='13px sans-serif';ctx.textAlign='center';ctx.fillText('harita',w/2,h/2);return}
let minX=m.x,maxX=m.x,minY=m.y,maxY=m.y;for(const p of trail){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
const ahead=48+(m.speedMs||0)*3,route=[];for(let i=1;i<=8;i++){const dist=ahead*i/8;route.push({x:m.x+Math.sin(m.yaw)*dist,y:m.y+Math.cos(m.yaw)*dist})}
for(const p of route){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
const span=Math.max(40,maxX-minX,maxY-minY)*1.3,cx=(minX+maxX)/2,cy=(minY+maxY)/2,sc=Math.min((w-36)/span,(h-36)/span);
const X=x=>w/2+(x-cx)*sc,Y=y=>h/2-(y-cy)*sc;
if(trail.length>1){ctx.beginPath();ctx.strokeStyle='rgba(94,231,255,.45)';ctx.lineWidth=2;ctx.moveTo(X(trail[0].x),Y(trail[0].y));for(let i=1;i<trail.length;i++)ctx.lineTo(X(trail[i].x),Y(trail[i].y));ctx.stroke()}
ctx.beginPath();ctx.setLineDash([7,6]);ctx.strokeStyle='rgba(61,255,176,.85)';ctx.moveTo(X(m.x),Y(m.y));for(const p of route)ctx.lineTo(X(p.x),Y(p.y));ctx.stroke();ctx.setLineDash([]);
ctx.save();ctx.translate(X(m.x),Y(m.y));ctx.rotate(-m.yaw);ctx.fillStyle='#5ee7ff';ctx.beginPath();ctx.moveTo(0,-8);ctx.lineTo(6,7);ctx.lineTo(0,3);ctx.lineTo(-6,7);ctx.closePath();ctx.fill();ctx.restore()}
function apply(d){$('spd').textContent=Math.round(d.speedKmh||0);$('rpm').textContent=((d.rpm||0)/1000).toFixed(1);$('gear').textContent=d.gearLabel||'N';
$('thr').style.width=((d.throttle||0)*100)+'%';$('brk').style.width=((d.brake||0)*100)+'%';
$('fuel').style.width=((d.fuel||0)*100)+'%';$('fuelv').textContent=Math.round((d.fuel||0)*100)+'%';
$('temp').style.width=(Math.min(1,Math.max(0,((d.engTemp||0)-40)/80))*100)+'%';$('tempv').textContent=Math.round(d.engTemp||0)+'°';
const L=d.lights||{};on($('iL'),L.signalL);on($('iR'),L.signalR);on($('iB'),L.fullbeam);on($('iP'),L.handbrake);on($('iA'),L.abs);on($('iT'),L.tc);on($('iS'),L.shift);
draw(d);$('meta').textContent='LIVE · '+Math.round(d.speedKmh||0)+' km/h';const st=$('st');st.textContent='CANLI';st.className='chip live'}
let fail=0;async function tick(){try{const r=await fetch('/t?t='+Date.now(),{cache:'no-store'});apply(await r.json());fail=0}catch(e){fail++;if(fail>10){$('st').textContent='SİNYAL YOK';$('st').className='chip lost';$('meta').textContent='Ctrl+R · aynı Wi‑Fi'}}}
setInterval(tick,50);tick();
</script></body></html>]]

M.onInit = onInit
M.updateGFX = updateGFX

return M
