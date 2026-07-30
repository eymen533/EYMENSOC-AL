(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const e of document.querySelectorAll('link[rel="modulepreload"]'))r(e);new MutationObserver(e=>{for(const n of e)if(n.type==="childList")for(const o of n.addedNodes)o.tagName==="LINK"&&o.rel==="modulepreload"&&r(o)}).observe(document,{childList:!0,subtree:!0});function s(e){const n={};return e.integrity&&(n.integrity=e.integrity),e.referrerPolicy&&(n.referrerPolicy=e.referrerPolicy),e.crossOrigin==="use-credentials"?n.credentials="include":e.crossOrigin==="anonymous"?n.credentials="omit":n.credentials="same-origin",n}function r(e){if(e.ep)return;e.ep=!0;const n=s(e);fetch(e.href,n)}})();const S=[{key:"Fajr",name:"İmsak"},{key:"Sunrise",name:"Güneş",meta:!0},{key:"Dhuhr",name:"Öğle"},{key:"Asr",name:"İkindi"},{key:"Maghrib",name:"Akşam"},{key:"Isha",name:"Yatsı"}],E=[{city:"Istanbul",label:"İstanbul"},{city:"Ankara",label:"Ankara"},{city:"Izmir",label:"İzmir"},{city:"Bursa",label:"Bursa"},{city:"Antalya",label:"Antalya"},{city:"Konya",label:"Konya"},{city:"Gaziantep",label:"Gaziantep"},{city:"Adana",label:"Adana"},{city:"Trabzon",label:"Trabzon"},{city:"Erzurum",label:"Erzurum"}],A=[{id:"sari-siyah",label:"Sarı · Siyah",swatch:["#0a0a0a","#f5c518"]},{id:"yesil",label:"Yeşil tonlar",swatch:["#0d1f14","#3d8b5f"]},{id:"beyaz-yesil",label:"Beyaz · Yeşil",swatch:["#f4f7f2","#1f7a4c"]},{id:"lacivert",label:"Beyaz · Lacivert",swatch:["#f2f5fb","#1a2a6c"]},{id:"gece-mavi",label:"Gece · Mavi",swatch:["#071018","#4db0ff"]},{id:"zeytin",label:"Zeytin · Altın",swatch:["#1a1c12","#c6a84b"]}],y=document.querySelector("#app");let i={city:localStorage.getItem("vakit-city")||"Istanbul",label:localStorage.getItem("vakit-label")||"İstanbul",theme:localStorage.getItem("vakit-theme")||"sari-siyah",timings:null,dateLabel:"",hijri:"",loading:!0,error:"",now:new Date,nextKey:""},c=!1;function I(a,t=i.now){const[s,r]=a.split(":").map(Number),e=new Date(t);return e.setHours(s,r,0,0),e}function f(a){const t=Math.max(0,Math.floor(a/1e3));return{h:String(Math.floor(t/3600)).padStart(2,"0"),m:String(Math.floor(t%3600/60)).padStart(2,"0"),s:String(t%60).padStart(2,"0")}}function d(a){return a.toLocaleTimeString("tr-TR",{hour:"2-digit",minute:"2-digit",second:"2-digit",hour12:!1})}function b(){return i.timings?S.map(a=>({...a,time:i.timings[a.key],date:I(i.timings[a.key])})):[]}function v(a){const t=i.now.getTime(),s=a.filter(n=>!n.meta&&n.date.getTime()>t);if(s.length)return s[0];const r=a.find(n=>n.key==="Fajr");if(!r)return null;const e=new Date(r.date);return e.setDate(e.getDate()+1),{...r,date:e,tomorrow:!0}}function k(a){const t=i.now.getTime(),s=a.filter(e=>!e.meta);let r=s[s.length-1];for(let e=0;e<s.length;e++)s[e].date.getTime()<=t&&(r=s[e]);return r}function u(a){i.theme=a,localStorage.setItem("vakit-theme",a),document.body.dataset.theme=a}async function L(a){const t=`https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(a)}&country=Turkey&method=13&school=1`,s=await fetch(t);if(!s.ok)throw new Error("Vakitler alınamadı");const e=(await s.json()).data,n=["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran","Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"],o=e.date.gregorian;return{timings:e.timings,dateLabel:`${Number(o.day)} ${n[Number(o.month.number)-1]} ${o.year}`,hijri:`${e.date.hijri.day} ${e.date.hijri.month.en} ${e.date.hijri.year}`}}async function h(){i.loading=!0,i.error="",c=!1,m();try{const a=await L(i.city);i.timings=a.timings,i.dateLabel=a.dateLabel,i.hijri=a.hijri,i.loading=!1}catch{i.loading=!1,i.error="Vakitler yüklenemedi. Bağlantını kontrol et."}m()}function j(a,t){i.city=a,i.label=t,localStorage.setItem("vakit-city",a),localStorage.setItem("vakit-label",t),h()}function g(){return`
    <div class="themes" role="listbox" aria-label="Renk teması">
      ${A.map(a=>`
        <button type="button" class="theme-chip ${i.theme===a.id?"active":""}" data-theme="${a.id}" title="${a.label}" aria-label="${a.label}">
          <span class="swatch" style="--a:${a.swatch[0]};--b:${a.swatch[1]}"></span>
          <span class="theme-name">${a.label}</span>
        </button>`).join("")}
    </div>
  `}function m(){u(i.theme);const a=b(),t=v(a),s=k(a);if(i.nextKey=(t==null?void 0:t.key)||"",i.loading||i.error){c=!1,y.innerHTML=`
      <div class="bg" aria-hidden="true"><div class="bg-orb"></div><div class="bg-grid"></div></div>
      <main class="shell">
        <header class="top">
          <div class="brand"><h1>VAKİT</h1></div>
        </header>
        ${g()}
        <div class="status ${i.error?"error":""}">
          <p>${i.error||"Vakitler hazırlanıyor…"}</p>
          ${i.error?'<button type="button" id="retry">Tekrar dene</button>':""}
        </div>
      </main>`,p();return}const r=t?f(t.date.getTime()-i.now.getTime()):{h:"00",m:"00",s:"00"};y.innerHTML=`
    <div class="bg" aria-hidden="true">
      <div class="bg-orb"></div>
      <div class="bg-grid"></div>
      <div class="bg-noise"></div>
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
            ${E.map(e=>`<option value="${e.city}" ${e.city===i.city?"selected":""}>${e.label}</option>`).join("")}
          </select>
        </label>
      </header>

      ${g()}

      <section class="hero" aria-live="polite">
        <div class="hero-now">
          <p class="eyebrow">Şu an</p>
          <p class="clock" id="clock-now">${d(i.now)}</p>
        </div>

        <div class="hero-next">
          <p class="eyebrow" id="next-kicker">${t!=null&&t.tomorrow?"Yarın":"Sıradaki"} · <span id="next-name">${(t==null?void 0:t.name)||"—"}</span></p>
          <div class="countdown">
            <div class="cd"><span id="cd-h">${r.h}</span><small>SAAT</small></div>
            <span class="colon">:</span>
            <div class="cd"><span id="cd-m">${r.m}</span><small>DAKİKA</small></div>
            <span class="colon">:</span>
            <div class="cd"><span id="cd-s">${r.s}</span><small>SANİYE</small></div>
          </div>
          <p class="hero-meta" id="hero-meta">${i.label.toUpperCase()} · ${(t==null?void 0:t.time)||""} · ${i.dateLabel.toUpperCase()}</p>
        </div>
      </section>

      <section class="times">
        <div class="times-head">
          <h2>Günün vakitleri</h2>
          <p id="hijri-line">${i.hijri}</p>
        </div>
        <ul class="time-list" id="time-list">
          ${a.map(e=>{const n=t&&e.key===t.key&&!t.tomorrow,o=s&&e.key===s.key&&!e.meta,l=e.date.getTime()<=i.now.getTime()&&!n;return`
                <li class="time-row ${e.meta?"is-meta":""} ${n?"is-next":""} ${o?"is-now":""} ${l?"is-passed":""}" data-key="${e.key}">
                  <span class="time-name">${e.name.toUpperCase()}</span>
                  <span class="time-clock">${e.time}</span>
                </li>`}).join("")}
        </ul>
      </section>
    </main>
  `,p(),c=!0}function p(){var a,t;(a=document.getElementById("city-select"))==null||a.addEventListener("change",s=>{const r=s.target.selectedOptions[0];j(r.value,r.textContent)}),(t=document.getElementById("retry"))==null||t.addEventListener("click",h),document.querySelectorAll(".theme-chip").forEach(s=>{s.addEventListener("click",()=>{u(s.dataset.theme),document.querySelectorAll(".theme-chip").forEach(r=>r.classList.toggle("active",r===s))})})}function C(){if(i.now=new Date,!c||i.loading||i.error||!i.timings){const n=document.getElementById("clock-now");n&&(n.textContent=d(i.now));return}const a=b(),t=v(a),s=k(a);if(((t==null?void 0:t.key)||"")!==i.nextKey){m();return}const r=t?f(t.date.getTime()-i.now.getTime()):null,e=document.getElementById("clock-now");e&&(e.textContent=d(i.now)),r&&(document.getElementById("cd-h").textContent=r.h,document.getElementById("cd-m").textContent=r.m,document.getElementById("cd-s").textContent=r.s),document.querySelectorAll(".time-row").forEach(n=>{const o=a.find(T=>T.key===n.dataset.key);if(!o)return;const l=t&&o.key===t.key&&!t.tomorrow,w=s&&o.key===s.key&&!o.meta,$=o.date.getTime()<=i.now.getTime()&&!l;n.classList.toggle("is-next",!!l),n.classList.toggle("is-now",!!w),n.classList.toggle("is-passed",!!$)})}u(i.theme);h();setInterval(C,1e3);
