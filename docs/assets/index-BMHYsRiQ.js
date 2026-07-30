(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const t of document.querySelectorAll('link[rel="modulepreload"]'))o(t);new MutationObserver(t=>{for(const s of t)if(s.type==="childList")for(const r of s.addedNodes)r.tagName==="LINK"&&r.rel==="modulepreload"&&o(r)}).observe(document,{childList:!0,subtree:!0});function i(t){const s={};return t.integrity&&(s.integrity=t.integrity),t.referrerPolicy&&(s.referrerPolicy=t.referrerPolicy),t.crossOrigin==="use-credentials"?s.credentials="include":t.crossOrigin==="anonymous"?s.credentials="omit":s.credentials="same-origin",s}function o(t){if(t.ep)return;t.ep=!0;const s=i(t);fetch(t.href,s)}})();const L=[{key:"Fajr",name:"İmsak",short:"Sabah"},{key:"Sunrise",name:"Güneş",short:"Doğuş",meta:!0},{key:"Dhuhr",name:"Öğle",short:"Öğle"},{key:"Asr",name:"İkindi",short:"İkindi"},{key:"Maghrib",name:"Akşam",short:"Akşam"},{key:"Isha",name:"Yatsı",short:"Yatsı"}],B=[{city:"Istanbul",label:"İstanbul"},{city:"Ankara",label:"Ankara"},{city:"Izmir",label:"İzmir"},{city:"Bursa",label:"Bursa"},{city:"Antalya",label:"Antalya"},{city:"Konya",label:"Konya"},{city:"Gaziantep",label:"Gaziantep"},{city:"Adana",label:"Adana"},{city:"Trabzon",label:"Trabzon"},{city:"Erzurum",label:"Erzurum"}],v=document.querySelector("#app");let a={city:localStorage.getItem("vakit-city")||"Istanbul",label:localStorage.getItem("vakit-label")||"İstanbul",timings:null,dateLabel:"",hijri:"",loading:!0,error:"",now:new Date,theme:"night",nextKey:""},h=null,y=!1;function C(n,e=a.now){const[i,o]=n.split(":").map(Number),t=new Date(e);return t.setHours(i,o,0,0),t}function b(n){const e=Math.max(0,Math.floor(n/1e3));return{h:String(Math.floor(e/3600)).padStart(2,"0"),m:String(Math.floor(e%3600/60)).padStart(2,"0"),s:String(e%60).padStart(2,"0")}}function w(){return a.timings?L.map(n=>({...n,time:a.timings[n.key],date:C(a.timings[n.key])})):[]}function $(n){const e=a.now.getTime(),i=n.filter(s=>!s.meta&&s.date.getTime()>e);if(i.length)return i[0];const o=n.find(s=>s.key==="Fajr");if(!o)return null;const t=new Date(o.date);return t.setDate(t.getDate()+1),{...o,date:t,tomorrow:!0}}function T(n){const e=a.now.getTime(),i=n.filter(t=>!t.meta);let o=i[i.length-1];for(let t=0;t<i.length;t++)i[t].date.getTime()<=e&&(o=i[t]);return o}function I(n){return{Fajr:"dawn",Dhuhr:"noon",Asr:"afternoon",Maghrib:"dusk",Isha:"night"}[n]||"night"}async function z(n){const e=`https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(n)}&country=Turkey&method=13&school=1`,i=await fetch(e);if(!i.ok)throw new Error("Vakitler alınamadı");const t=(await i.json()).data,s=["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran","Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"],r=t.date.gregorian,l=Number(r.month.number)-1;return{timings:t.timings,dateLabel:`${Number(r.day)} ${s[l]} ${r.year}`,hijri:`${t.date.hijri.day} ${t.date.hijri.month.en} ${t.date.hijri.year}`}}async function k(){a.loading=!0,a.error="",y=!1,g();try{const n=await z(a.city);a.timings=n.timings,a.dateLabel=n.dateLabel,a.hijri=n.hijri,a.loading=!1}catch{a.loading=!1,a.error="Vakitler yüklenemedi. Bağlantını kontrol et."}g()}function M(n,e){a.city=n,a.label=e,localStorage.setItem("vakit-city",n),localStorage.setItem("vakit-label",e),k()}function g(){var t,s;const n=w(),e=$(n),i=T(n);if(a.theme=I((e==null?void 0:e.key)||(i==null?void 0:i.key)),a.nextKey=(e==null?void 0:e.key)||"",document.body.dataset.sky=a.theme,a.loading||a.error){y=!1,v.innerHTML=`
      <div class="sky" aria-hidden="true">
        <div class="sky-glow"></div>
        <div class="sky-arch"></div>
        <div class="sky-veil"></div>
      </div>
      <main class="shell">
        <header class="top">
          <div class="brand"><span class="crescent" aria-hidden="true"></span><h1>VAKİT</h1></div>
        </header>
        <div class="status ${a.error?"error":""}">
          <p>${a.error||"Vakitler hazırlanıyor…"}</p>
          ${a.error?'<button type="button" id="retry">Tekrar dene</button>':""}
        </div>
      </main>`,(t=document.getElementById("retry"))==null||t.addEventListener("click",k);return}const o=e?b(e.date.getTime()-a.now.getTime()):{h:"00",m:"00",s:"00"};v.innerHTML=`
    <div class="sky" aria-hidden="true">
      <div class="sky-glow"></div>
      <div class="sky-arch"></div>
      <div class="sky-veil"></div>
    </div>

    <main class="shell">
      <header class="top">
        <div class="brand">
          <span class="crescent" aria-hidden="true"></span>
          <h1>VAKİT</h1>
        </div>
        <label class="city">
          <span class="sr">Şehir</span>
          <select id="city-select" aria-label="Şehir seç">
            ${B.map(r=>`<option value="${r.city}" ${r.city===a.city?"selected":""}>${r.label}</option>`).join("")}
          </select>
        </label>
      </header>

      <section class="hero">
        <p class="hero-kicker" id="hero-kicker">${e!=null&&e.tomorrow?"Yarın":"Sıradaki vakit"}</p>
        <h2 class="hero-name" id="hero-name">${(e==null?void 0:e.name)||"—"}</h2>
        <div class="countdown" aria-live="polite">
          <div class="unit"><span id="cd-h">${o.h}</span><small>saat</small></div>
          <span class="sep" aria-hidden="true">:</span>
          <div class="unit"><span id="cd-m">${o.m}</span><small>dk</small></div>
          <span class="sep" aria-hidden="true">:</span>
          <div class="unit"><span id="cd-s">${o.s}</span><small>sn</small></div>
        </div>
        <p class="hero-sub" id="hero-sub">${a.label} · ${(e==null?void 0:e.time)||""}</p>
      </section>

      <section class="times" aria-label="Günün namaz vakitleri">
        <div class="times-head">
          <div>
            <h3>Bugünün vakitleri</h3>
            <p id="date-line">${a.dateLabel}</p>
          </div>
          <p class="hijri" id="hijri-line">${a.hijri}</p>
        </div>
        <ul class="time-list" id="time-list">
          ${n.map(r=>{const l=e&&r.key===e.key&&!e.tomorrow,d=i&&r.key===i.key&&!r.meta,m=r.date.getTime()<=a.now.getTime()&&!l;return`
                <li class="time-row ${r.meta?"is-meta":""} ${l?"is-next":""} ${d?"is-now":""} ${m?"is-passed":""}" data-key="${r.key}">
                  <span class="time-name">${r.name}</span>
                  <span class="time-clock">${r.time}</span>
                </li>`}).join("")}
        </ul>
      </section>
    </main>
  `,(s=document.getElementById("city-select"))==null||s.addEventListener("change",r=>{const l=r.target.selectedOptions[0];M(l.value,l.textContent)}),y=!0}function N(){if(a.now=new Date,!y||a.loading||a.error||!a.timings)return;const n=w(),e=$(n),i=T(n),o=I((e==null?void 0:e.key)||(i==null?void 0:i.key));if(((e==null?void 0:e.key)||"")!==a.nextKey||o!==a.theme){a.theme=o,a.nextKey=(e==null?void 0:e.key)||"",g();return}const t=e?b(e.date.getTime()-a.now.getTime()):null,s=document.getElementById("cd-h"),r=document.getElementById("cd-m"),l=document.getElementById("cd-s");s&&t&&(s.textContent=t.h,r.textContent=t.m,l.textContent=t.s);const d=document.getElementById("hero-kicker"),m=document.getElementById("hero-name"),p=document.getElementById("hero-sub");d&&(d.textContent=e!=null&&e.tomorrow?"Yarın":"Sıradaki vakit"),m&&(m.textContent=(e==null?void 0:e.name)||"—"),p&&(p.textContent=`${a.label} · ${(e==null?void 0:e.time)||""}`),document.querySelectorAll(".time-row").forEach(u=>{const S=u.dataset.key,c=n.find(A=>A.key===S);if(!c)return;const f=e&&c.key===e.key&&!e.tomorrow,j=i&&c.key===i.key&&!c.meta,E=c.date.getTime()<=a.now.getTime()&&!f;u.classList.toggle("is-next",!!f),u.classList.toggle("is-now",!!j),u.classList.toggle("is-passed",!!E)})}function K(){h&&clearInterval(h),h=setInterval(N,1e3)}k();K();
