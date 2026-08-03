-- EYMEN HTML Cluster protocol for BeamNG.drive
-- Serves an iPhone-friendly HTML cockpit over HTTP (no PC app install).
-- iPhone Safari → http://PC_IP:8765
-- Enable by placing this mod, enter vehicle, Ctrl+R

local M = {}

local PORT = 8765
local socket = require('libs/luasocket/socket.socket')

local server
local clients = {}
local latestJson = '{"ok":false}'
local trail = {}
local lastTrailT = 0

local function clamp01(v)
  v = tonumber(v) or 0
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function gearLabel(g)
  g = tonumber(g)
  if g == nil then return 'N' end
  if g < 0 then return 'R' end
  if g == 0 then return 'N' end
  return tostring(math.floor(g))
end

local function pushTrail(x, y)
  local now = socket.gettime()
  local last = trail[#trail]
  if not last or ((x - last.x) * (x - last.x) + (y - last.y) * (y - last.y) > 2.25) then
    trail[#trail + 1] = { x = x, y = y, t = math.floor(now * 1000) }
    if #trail > 200 then
      table.remove(trail, 1)
    end
  end
end

local function jsonEscape(s)
  s = tostring(s or '')
  s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
  return s
end

local function buildTelemetry()
  local ev = electrics.values
  local speedMs = ev.wheelspeed or ev.airspeed or 0
  local rpm = ev.rpm or 0
  local fuel = clamp01(ev.fuel or ev.fuelVolume or 0)
  -- some cars use 0-1 fuel already
  if (ev.fuel or 0) > 1 then fuel = clamp01((ev.fuel or 0) / 100) end

  local pos = obj:getPosition()
  local dir = obj:getDirectionVector()
  local yaw = math.atan2(dir.x, dir.y)
  pushTrail(pos.x, pos.y)

  local trailParts = {}
  for i = 1, #trail do
    local p = trail[i]
    trailParts[#trailParts + 1] = string.format('{"x":%.2f,"y":%.2f,"t":%d}', p.x, p.y, p.t)
  end

  local lights = string.format(
    '{"shift":%s,"fullbeam":%s,"handbrake":%s,"tc":%s,"signalL":%s,"signalR":%s,"oilWarn":%s,"battery":%s,"abs":%s}',
    tostring((ev.should_shift or 0) > 0.5),
    tostring((ev.highbeam or 0) > 0.5),
    tostring((ev.parkingbrake or 0) > 0.5),
    tostring((ev.esc or ev.tcs or 0) > 0.5),
    tostring((ev.signal_L or 0) > 0.5),
    tostring((ev.signal_R or 0) > 0.5),
    tostring((ev.oil or 0) > 0.5),
    tostring((ev.lowpressure or ev.lowfuel or 0) > 0.5),
    tostring((ev.abs or 0) > 0.5)
  )

  return string.format(
    '{"gearLabel":"%s","speedKmh":%.2f,"speedMph":%.2f,"preferKm":true,"rpm":%.1f,"turbo":%.2f,"engTemp":%.1f,"fuel":%.3f,"throttle":%.3f,"brake":%.3f,"showTurbo":%s,"source":"live","lights":%s,"map":{"x":%.2f,"y":%.2f,"z":%.2f,"yaw":%.4f,"velX":0,"velY":0,"speedMs":%.3f},"trail":[%s]}',
    jsonEscape(gearLabel(ev.gear)),
    speedMs * 3.6,
    speedMs * 2.236936,
    rpm,
    ev.turboBoost or ev.boost or 0,
    ev.watertemp or ev.oiltemp or 90,
    fuel,
    clamp01(ev.throttle or 0),
    clamp01(ev.brake or 0),
    tostring((ev.turboBoost or ev.boost or 0) ~= 0),
    lights,
    pos.x, pos.y, pos.z, yaw, speedMs,
    table.concat(trailParts, ',')
  )
end

-- Minimal digital cockpit HTML (iPhone Safari / PWA)
local INDEX_HTML = [[<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover"/>
<meta name="apple-mobile-web-app-capable" content="yes"/>
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
<meta name="mobile-web-app-capable" content="yes"/>
<meta name="theme-color" content="#02060c"/>
<title>EYMEN Cluster</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;height:100%;overflow:hidden;background:#02060c;color:#e9f7ff;
font-family:-apple-system,system-ui,Orbitron,monospace;user-select:none;-webkit-user-select:none;
-webkit-touch-callout:none;touch-action:manipulation}
body{background:radial-gradient(ellipse 90% 60% at 50% -20%,#123055,transparent 55%),#02060c}
.wrap{height:100%;display:grid;grid-template-rows:auto 1fr auto;padding:max(8px,env(safe-area-inset-top)) 12px max(8px,env(safe-area-inset-bottom))}
.top{display:flex;justify-content:space-between;align-items:center}
.brand{font-weight:800;letter-spacing:.28em;color:#5ee7ff;font-size:14px}
.chip{font-size:11px;letter-spacing:.18em;border:1px solid rgba(94,231,255,.25);padding:6px 10px;color:#6f8aa3}
.chip.live{color:#3dffb0;border-color:rgba(61,255,176,.45)}
.chip.lost{color:#ff4d3a;border-color:rgba(255,77,58,.45)}
.main{display:grid;grid-template-columns:1fr 1.1fr 1fr;gap:8px;min-height:0;align-items:center}
.gauge{text-align:center}
.big{font-size:clamp(28px,9vh,56px);font-weight:800;letter-spacing:.04em}
.sub{font-size:11px;letter-spacing:.25em;color:#6f8aa3;margin-top:4px}
.center{display:flex;flex-direction:column;align-items:center;gap:8px;min-width:0}
.gear{font-size:clamp(36px,10vh,64px);font-weight:800}
.icons{display:flex;flex-wrap:wrap;gap:4px;justify-content:center}
.ico{font-size:9px;letter-spacing:.08em;border:1px solid rgba(111,138,163,.3);color:rgba(111,138,163,.35);padding:4px 6px}
.ico.on{color:#3dffb0;border-color:rgba(61,255,176,.5)}
.ico.warn.on{color:#ffc14d;border-color:rgba(255,193,77,.55)}
.ico.hot.on{color:#ff4d3a;border-color:rgba(255,77,58,.6)}
.map{width:100%;border:1px solid rgba(94,231,255,.22);background:rgba(4,12,22,.75)}
.map canvas{width:100%;display:block;height:28vh;max-height:220px}
.ped{width:100%;height:6px;background:rgba(255,255,255,.06);margin-top:4px}
.ped>i{display:block;height:100%;width:0;background:linear-gradient(90deg,#2f7dff,#5ee7ff)}
.ped.b>i{background:linear-gradient(90deg,#ff4d3a,#ffb09a)}
.bot{display:flex;gap:12px;align-items:center;font-size:12px;border-top:1px solid rgba(94,231,255,.12);padding-top:8px}
.bar{flex:1;height:6px;background:rgba(255,255,255,.06)}
.bar>i{display:block;height:100%;width:0;background:linear-gradient(90deg,#2f7dff,#9fe9ff)}
.meta{margin-left:auto;color:#6f8aa3;font-size:11px;white-space:nowrap}
@media(orientation:portrait){.main{grid-template-columns:1fr}.map canvas{height:22vh}}
</style>
</head>
<body>
<div class="wrap">
  <div class="top"><div class="brand">EYMEN</div><div class="chip" id="st">BAĞLANIYOR</div></div>
  <div class="main">
    <div class="gauge"><div class="big" id="spd">0</div><div class="sub" id="spdu">km/h · SPEED</div></div>
    <div class="center">
      <div class="icons">
        <span class="ico" id="iL">◀</span><span class="ico" id="iB">BEAM</span><span class="ico" id="iR">▶</span>
        <span class="ico warn" id="iP">P</span><span class="ico warn" id="iA">ABS</span>
        <span class="ico warn" id="iT">TC</span><span class="ico hot" id="iS">SHIFT</span>
      </div>
      <div class="gear" id="gear">N</div>
      <div class="sub">GEAR</div>
      <div class="map"><canvas id="cv"></canvas></div>
      <div class="ped"><i id="thr"></i></div>
      <div class="ped b"><i id="brk"></i></div>
    </div>
    <div class="gauge"><div class="big" id="rpm">0.0</div><div class="sub">×1000 rpm</div></div>
  </div>
  <div class="bot">
    <span>FUEL</span><div class="bar"><i id="fuel"></i></div><b id="fuelv">—</b>
    <span>TEMP</span><div class="bar"><i id="temp"></i></div><b id="tempv">—</b>
    <span class="meta" id="meta">iPhone · HTML</span>
  </div>
</div>
<script>
const $=id=>document.getElementById(id);
const cv=$('cv'),ctx=cv.getContext('2d');
function fit(){const r=cv.getBoundingClientRect();const d=Math.min(2,devicePixelRatio||1);
cv.width=Math.max(260,r.width*d);cv.height=Math.max(120,r.height*d);}
fit();addEventListener('resize',fit);
function on(el,v){el.classList.toggle('on',!!v)}
function draw(d){
  const m=d.map,trail=d.trail||[];const w=cv.width,h=cv.height;ctx.clearRect(0,0,w,h);
  ctx.strokeStyle='rgba(94,231,255,.08)';for(let x=0;x<w;x+=24){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,h);ctx.stroke()}
  if(!m){ctx.fillStyle='#6f8aa3';ctx.font='14px monospace';ctx.textAlign='center';ctx.fillText('harita bekleniyor',w/2,h/2);return}
  let minX=m.x,maxX=m.x,minY=m.y,maxY=m.y;
  for(const p of trail){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
  const ahead=50+(m.speedMs||0)*3,route=[];
  for(let i=1;i<=8;i++){const dist=ahead*i/8;route.push({x:m.x+Math.sin(m.yaw)*dist,y:m.y+Math.cos(m.yaw)*dist})}
  for(const p of route){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
  const span=Math.max(40,maxX-minX,maxY-minY)*1.3,cx=(minX+maxX)/2,cy=(minY+maxY)/2,sc=Math.min((w-40)/span,(h-40)/span);
  const X=x=>w/2+(x-cx)*sc,Y=y=>h/2-(y-cy)*sc;
  if(trail.length>1){ctx.beginPath();ctx.strokeStyle='rgba(94,231,255,.45)';ctx.lineWidth=2;ctx.moveTo(X(trail[0].x),Y(trail[0].y));for(let i=1;i<trail.length;i++)ctx.lineTo(X(trail[i].x),Y(trail[i].y));ctx.stroke()}
  ctx.beginPath();ctx.setLineDash([8,6]);ctx.strokeStyle='rgba(61,255,176,.8)';ctx.moveTo(X(m.x),Y(m.y));for(const p of route)ctx.lineTo(X(p.x),Y(p.y));ctx.stroke();ctx.setLineDash([]);
  const x=X(m.x),y=Y(m.y);ctx.save();ctx.translate(x,y);ctx.rotate(-m.yaw);ctx.fillStyle='#5ee7ff';ctx.beginPath();ctx.moveTo(0,-9);ctx.lineTo(6,8);ctx.lineTo(0,4);ctx.lineTo(-6,8);ctx.closePath();ctx.fill();ctx.restore();
}
function apply(d){
  $('spd').textContent=Math.round(d.speedKmh||0);
  $('rpm').textContent=((d.rpm||0)/1000).toFixed(1);
  $('gear').textContent=d.gearLabel||'N';
  $('thr').style.width=((d.throttle||0)*100)+'%';
  $('brk').style.width=((d.brake||0)*100)+'%';
  $('fuel').style.width=((d.fuel||0)*100)+'%';$('fuelv').textContent=Math.round((d.fuel||0)*100)+'%';
  const tp=Math.min(1,Math.max(0,((d.engTemp||0)-40)/80));
  $('temp').style.width=(tp*100)+'%';$('tempv').textContent=Math.round(d.engTemp||0)+'°';
  const L=d.lights||{};on($('iL'),L.signalL);on($('iR'),L.signalR);on($('iB'),L.fullbeam);on($('iP'),L.handbrake);on($('iA'),L.abs);on($('iT'),L.tc);on($('iS'),L.shift);
  draw(d);$('meta').textContent='LIVE · '+Math.round(d.speedKmh||0)+' km/h';
  const st=$('st');st.textContent='CANLI';st.className='chip live';
}
let fail=0;
async function tick(){
  try{
    const r=await fetch('/t?ts='+Date.now(),{cache:'no-store'});
    const d=await r.json();apply(d);fail=0;
  }catch(e){
    fail++;if(fail>8){const st=$('st');st.textContent='SİNYAL YOK';st.className='chip lost';$('meta').textContent='BeamNG + mod + Ctrl+R'}
  }
}
setInterval(tick,50);tick();
</script>
</body></html>
]]

local function httpResponse(status, contentType, body)
  return table.concat({
    'HTTP/1.1 ' .. status .. '\r\n',
    'Content-Type: ' .. contentType .. '\r\n',
    'Content-Length: ' .. tostring(#body) .. '\r\n',
    'Connection: close\r\n',
    'Access-Control-Allow-Origin: *\r\n',
    'Cache-Control: no-store\r\n',
    '\r\n',
    body
  })
end

local function handleClient(client)
  client:settimeout(0)
  local req, err = client:receive('*l')
  if not req then
    if err ~= 'timeout' then
      client:close()
      clients[client] = nil
    end
    return
  end
  -- drain headers quickly
  while true do
    local line = client:receive('*l')
    if not line or line == '' then break end
  end

  local path = req:match('^%w+%s+(.-)%s+HTTP') or '/'
  path = path:match('^([^%?]+)') or path
  local body
  if path == '/t' or path == '/api/telemetry' then
    body = httpResponse('200 OK', 'application/json; charset=utf-8', latestJson)
  elseif path == '/' or path == '/index.html' then
    body = httpResponse('200 OK', 'text/html; charset=utf-8', INDEX_HTML)
  else
    body = httpResponse('404 Not Found', 'text/plain', 'not found')
  end
  client:send(body)
  client:close()
  clients[client] = nil
end

local function ensureServer()
  if server then return end
  local ok, sock = pcall(function()
    local s = assert(socket.bind('0.0.0.0', PORT))
    s:settimeout(0)
    return s
  end)
  if ok then
    server = sock
    log('I', 'eymen_html_cluster', 'HTTP cluster http://0.0.0.0:' .. PORT .. ' (iPhone Safari)')
  else
    log('E', 'eymen_html_cluster', 'HTTP bind failed: ' .. tostring(sock))
  end
end

local function onUpdate(dt)
  ensureServer()
  latestJson = buildTelemetry()

  if server then
    local client = server:accept()
    if client then
      client:settimeout(0)
      clients[client] = true
    end
  end

  for c, _ in pairs(clients) do
    handleClient(c)
  end
end

function M.onInit()
  ensureServer()
  log('I', 'eymen_html_cluster', 'EYMEN HTML Cluster protocol loaded — open http://PC_IP:8765 on iPhone')
end

function M.onUpdate(dt)
  onUpdate(dt)
end

-- vehicle protocol API
local function updateGFX(dt)
  onUpdate(dt)
end

M.updateGFX = updateGFX

return M
