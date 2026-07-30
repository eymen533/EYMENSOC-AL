(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const a of document.querySelectorAll('link[rel="modulepreload"]'))r(a);new MutationObserver(a=>{for(const s of a)if(s.type==="childList")for(const o of s.addedNodes)o.tagName==="LINK"&&o.rel==="modulepreload"&&r(o)}).observe(document,{childList:!0,subtree:!0});function i(a){const s={};return a.integrity&&(s.integrity=a.integrity),a.referrerPolicy&&(s.referrerPolicy=a.referrerPolicy),a.crossOrigin==="use-credentials"?s.credentials="include":a.crossOrigin==="anonymous"?s.credentials="omit":s.credentials="same-origin",s}function r(a){if(a.ep)return;a.ep=!0;const s=i(a);fetch(a.href,s)}})();const I=[{key:"Fajr",name:"İmsak"},{key:"Sunrise",name:"Güneş",meta:!0},{key:"Dhuhr",name:"Öğle"},{key:"Asr",name:"İkindi"},{key:"Maghrib",name:"Akşam"},{key:"Isha",name:"Yatsı"}],L=[{city:"Istanbul",label:"İstanbul"},{city:"Ankara",label:"Ankara"},{city:"Izmir",label:"İzmir"},{city:"Bursa",label:"Bursa"},{city:"Antalya",label:"Antalya"},{city:"Konya",label:"Konya"},{city:"Gaziantep",label:"Gaziantep"},{city:"Adana",label:"Adana"},{city:"Trabzon",label:"Trabzon"},{city:"Erzurum",label:"Erzurum"}],j=[{id:"sari-siyah",label:"Sarı · Siyah",swatch:["#0a0a0a","#f5c518"]},{id:"yesil",label:"Yeşil",swatch:["#0d1f14","#3d8b5f"]},{id:"beyaz-yesil",label:"Beyaz · Yeşil",swatch:["#f4f7f2","#1f7a4c"]},{id:"lacivert",label:"Lacivert",swatch:["#f2f5fb","#1a2a6c"]},{id:"gece-mavi",label:"Gece · Mavi",swatch:["#071018","#4db0ff"]},{id:"zeytin",label:"Zeytin",swatch:["#1a1c12","#c6a84b"]}],g=document.querySelector("#app");let n={city:localStorage.getItem("vakit-city")||"Istanbul",label:localStorage.getItem("vakit-label")||"İstanbul",theme:localStorage.getItem("vakit-theme")||"sari-siyah",timings:null,dateLabel:"",hijri:"",loading:!0,error:"",now:new Date,nextKey:""},d=!1;function N(e,t=n.now){const[i,r]=e.split(":").map(Number),a=new Date(t);return a.setHours(i,r,0,0),a}function l(e){return String(e).padStart(2,"0")}function v(e){const t=Math.max(0,Math.floor(e/1e3));return{h:l(Math.floor(t/3600)),m:l(Math.floor(t%3600/60)),s:l(t%60)}}function $(e){return{h:l(e.getHours()),m:l(e.getMinutes()),s:l(e.getSeconds())}}function w(){return n.timings?I.map(e=>({...e,time:n.timings[e.key],date:N(n.timings[e.key])})):[]}function T(e){const t=n.now.getTime(),i=e.filter(s=>!s.meta&&s.date.getTime()>t);if(i.length)return i[0];const r=e.find(s=>s.key==="Fajr");if(!r)return null;const a=new Date(r.date);return a.setDate(a.getDate()+1),{...r,date:a,tomorrow:!0}}function A(e){const t=n.now.getTime(),i=e.filter(a=>!a.meta);let r=i[i.length-1];for(let a=0;a<i.length;a++)i[a].date.getTime()<=t&&(r=i[a]);return r}function h(e){n.theme=e,localStorage.setItem("vakit-theme",e),document.body.dataset.theme=e}async function C(e){const t=`https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(e)}&country=Turkey&method=13&school=1`,i=await fetch(t);if(!i.ok)throw new Error("Vakitler alınamadı");const a=(await i.json()).data,s=["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran","Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"],o=a.date.gregorian;return{timings:a.timings,dateLabel:`${Number(o.day)} ${s[Number(o.month.number)-1]} ${o.year}`,hijri:`${a.date.hijri.day} ${a.date.hijri.month.en} ${a.date.hijri.year}`}}async function y(){n.loading=!0,n.error="",d=!1,u();try{const e=await C(n.city);n.timings=e.timings,n.dateLabel=e.dateLabel,n.hijri=e.hijri,n.loading=!1}catch{n.loading=!1,n.error="Vakitler yüklenemedi. Bağlantını kontrol et."}u()}function M(e,t){n.city=e,n.label=t,localStorage.setItem("vakit-city",e),localStorage.setItem("vakit-label",t),y()}function p(e,t){return`
    <div class="digits" aria-hidden="false">
      <span class="num" id="${e}-h">${t.h}</span>
      <span class="sep">:</span>
      <span class="num" id="${e}-m">${t.m}</span>
      <span class="sep">:</span>
      <span class="num" id="${e}-s">${t.s}</span>
    </div>
  `}function f(){return`
    <div class="themes" role="listbox" aria-label="Renk teması">
      ${j.map(e=>`
        <button type="button" class="theme-chip ${n.theme===e.id?"active":""}" data-theme="${e.id}" title="${e.label}" aria-label="${e.label}">
          <span class="swatch" style="--a:${e.swatch[0]};--b:${e.swatch[1]}"></span>
          <span class="theme-name">${e.label}</span>
        </button>`).join("")}
    </div>
  `}function u(){h(n.theme);const e=w(),t=T(e),i=A(e);if(n.nextKey=(t==null?void 0:t.key)||"",n.loading||n.error){d=!1,g.innerHTML=`
      <div class="bg" aria-hidden="true"><div class="bg-orb"></div><div class="bg-grid"></div></div>
      <main class="shell">
        <header class="top"><div class="brand"><h1>VAKİT</h1></div></header>
        ${f()}
        <div class="status ${n.error?"error":""}">
          <p>${n.error||"Vakitler hazırlanıyor…"}</p>
          ${n.error?'<button type="button" id="retry">Tekrar dene</button>':""}
        </div>
      </main>`,b();return}const r=t?v(t.date.getTime()-n.now.getTime()):{h:"00",m:"00",s:"00"},a=$(n.now);g.innerHTML=`
    <div class="bg" aria-hidden="true">
      <div class="bg-orb"></div>
      <div class="bg-grid"></div>
    </div>

    <main class="shell">
      <header class="top">
        <div class="brand">
          <span class="brand-mark" aria-hidden="true"></span>
          <h1>VAKİT</h1>
        </div>
        <label class="city">
          <span class="sr">Şehir</span>
          <select id="city-select" aria-label="Şehir seç">
            ${L.map(s=>`<option value="${s.city}" ${s.city===n.city?"selected":""}>${s.label}</option>`).join("")}
          </select>
        </label>
      </header>

      ${f()}

      <section class="hero">
        <div class="hero-card">
          <p class="eyebrow">ŞU ANKİ SAAT</p>
          ${p("clock",a)}
        </div>

        <div class="hero-card hero-card-accent">
          <p class="eyebrow" id="next-kicker">${t!=null&&t.tomorrow?"YARIN":"SIRADAKİ VAKİT"} · <strong id="next-name">${((t==null?void 0:t.name)||"—").toUpperCase()}</strong></p>
          ${p("cd",r)}
          <div class="cd-labels" aria-hidden="true">
            <span>SAAT</span><span></span><span>DAKİKA</span><span></span><span>SANİYE</span>
          </div>
          <p class="hero-meta" id="hero-meta">${n.label.toUpperCase()} · ${(t==null?void 0:t.time)||""} · ${n.dateLabel.toUpperCase()}</p>
        </div>
      </section>

      <section class="times">
        <div class="times-head">
          <h2>GÜNÜN VAKİTLERİ</h2>
          <p id="hijri-line">${n.hijri}</p>
        </div>
        <ul class="time-list" id="time-list">
          ${e.map(s=>{const o=t&&s.key===t.key&&!t.tomorrow,c=i&&s.key===i.key&&!s.meta,m=s.date.getTime()<=n.now.getTime()&&!o;return`
                <li class="time-row ${s.meta?"is-meta":""} ${o?"is-next":""} ${c?"is-now":""} ${m?"is-passed":""}" data-key="${s.key}">
                  <span class="time-name">${s.name.toUpperCase()}</span>
                  <span class="time-clock">${s.time}</span>
                </li>`}).join("")}
        </ul>
      </section>
    </main>
  `,b(),d=!0}function b(){var e,t;(e=document.getElementById("city-select"))==null||e.addEventListener("change",i=>{const r=i.target.selectedOptions[0];M(r.value,r.textContent)}),(t=document.getElementById("retry"))==null||t.addEventListener("click",y),document.querySelectorAll(".theme-chip").forEach(i=>{i.addEventListener("click",()=>{h(i.dataset.theme),document.querySelectorAll(".theme-chip").forEach(r=>r.classList.toggle("active",r===i))})})}function k(e,t){const i=document.getElementById(`${e}-h`),r=document.getElementById(`${e}-m`),a=document.getElementById(`${e}-s`);return!i||!r||!a?!1:(i.textContent=t.h,r.textContent=t.m,a.textContent=t.s,!0)}function K(){if(n.now=new Date,!d||n.loading||n.error||!n.timings)return;const e=w(),t=T(e),i=A(e);if(((t==null?void 0:t.key)||"")!==n.nextKey){u();return}k("clock",$(n.now)),t&&k("cd",v(t.date.getTime()-n.now.getTime()));const r=document.getElementById("next-kicker"),a=document.getElementById("next-name");r&&a&&(a.textContent=((t==null?void 0:t.name)||"—").toUpperCase()),document.querySelectorAll(".time-row").forEach(s=>{const o=e.find(E=>E.key===s.dataset.key);if(!o)return;const c=t&&o.key===t.key&&!t.tomorrow,m=i&&o.key===i.key&&!o.meta,S=o.date.getTime()<=n.now.getTime()&&!c;s.classList.toggle("is-next",!!c),s.classList.toggle("is-now",!!m),s.classList.toggle("is-passed",!!S)})}h(n.theme);y();setInterval(K,1e3);
