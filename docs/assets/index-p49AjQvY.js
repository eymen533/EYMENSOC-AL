(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const e of document.querySelectorAll('link[rel="modulepreload"]'))r(e);new MutationObserver(e=>{for(const i of e)if(i.type==="childList")for(const l of i.addedNodes)l.tagName==="LINK"&&l.rel==="modulepreload"&&r(l)}).observe(document,{childList:!0,subtree:!0});function s(e){const i={};return e.integrity&&(i.integrity=e.integrity),e.referrerPolicy&&(i.referrerPolicy=e.referrerPolicy),e.crossOrigin==="use-credentials"?i.credentials="include":e.crossOrigin==="anonymous"?i.credentials="omit":i.credentials="same-origin",i}function r(e){if(e.ep)return;e.ep=!0;const i=s(e);fetch(e.href,i)}})();const g=[{key:"Fajr",name:"İmsak",short:"Sabah"},{key:"Sunrise",name:"Güneş",short:"Doğuş",meta:!0},{key:"Dhuhr",name:"Öğle",short:"Öğle"},{key:"Asr",name:"İkindi",short:"İkindi"},{key:"Maghrib",name:"Akşam",short:"Akşam"},{key:"Isha",name:"Yatsı",short:"Yatsı"}],f=[{city:"Istanbul",label:"İstanbul"},{city:"Ankara",label:"Ankara"},{city:"Izmir",label:"İzmir"},{city:"Bursa",label:"Bursa"},{city:"Antalya",label:"Antalya"},{city:"Konya",label:"Konya"},{city:"Gaziantep",label:"Gaziantep"},{city:"Adana",label:"Adana"},{city:"Trabzon",label:"Trabzon"},{city:"Erzurum",label:"Erzurum"}],p=document.querySelector("#app");let n={city:localStorage.getItem("vakit-city")||"Istanbul",label:localStorage.getItem("vakit-label")||"İstanbul",timings:null,dateLabel:"",hijri:"",loading:!0,error:"",now:new Date},c=null;function k(a,t=n.now){const[s,r]=a.split(":").map(Number),e=new Date(t);return e.setHours(s,r,0,0),e}function b(a){const t=Math.max(0,Math.floor(a/1e3)),s=Math.floor(t/3600),r=Math.floor(t%3600/60),e=t%60;return{h:String(s).padStart(2,"0"),m:String(r).padStart(2,"0"),s:String(e).padStart(2,"0")}}function v(){return n.timings?g.map(a=>({...a,time:n.timings[a.key],date:k(n.timings[a.key])})):[]}function w(a){const t=n.now.getTime(),s=a.filter(i=>!i.meta&&i.date.getTime()>t);if(s.length)return s[0];const r=a.find(i=>i.key==="Fajr");if(!r)return null;const e=new Date(r.date);return e.setDate(e.getDate()+1),{...r,date:e,tomorrow:!0}}function $(a){const t=n.now.getTime(),s=a.filter(e=>!e.meta);let r=s[s.length-1];for(let e=0;e<s.length;e++)s[e].date.getTime()<=t&&(r=s[e]);return r}function T(a){return{Fajr:"dawn",Dhuhr:"noon",Asr:"afternoon",Maghrib:"dusk",Isha:"night"}[a]||"night"}async function S(a){const t=`https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(a)}&country=Turkey&method=13&school=1`,s=await fetch(t);if(!s.ok)throw new Error("Vakitler alınamadı");const e=(await s.json()).data;return{timings:e.timings,dateLabel:`${e.date.gregorian.day} ${e.date.gregorian.month.en} ${e.date.gregorian.year}`,hijri:`${e.date.hijri.day} ${e.date.hijri.month.en} ${e.date.hijri.year}`}}async function m(){n.loading=!0,n.error="",d();try{const a=await S(n.city);n.timings=a.timings,n.dateLabel=a.dateLabel,n.hijri=a.hijri,n.loading=!1}catch{n.loading=!1,n.error="Vakitler yüklenemedi. Bağlantını kontrol et."}d()}function I(a,t){n.city=a,n.label=t,localStorage.setItem("vakit-city",a),localStorage.setItem("vakit-label",t),m()}function d(){const a=v(),t=w(a),s=$(a),r=T((t==null?void 0:t.key)||(s==null?void 0:s.key)),e=t?b(t.date.getTime()-n.now.getTime()):null;document.body.dataset.sky=r,p.innerHTML=`
    <div class="sky" aria-hidden="true">
      <div class="sky-wash"></div>
      <div class="sky-orb"></div>
      <div class="sky-haze"></div>
      <div class="sky-grain"></div>
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
            ${f.map(o=>`<option value="${o.city}" ${o.city===n.city?"selected":""}>${o.label}</option>`).join("")}
          </select>
        </label>
      </header>

      ${n.loading?'<div class="status">Vakitler hazırlanıyor…</div>':n.error?`<div class="status error">${n.error}<button type="button" id="retry">Tekrar dene</button></div>`:`
        <section class="hero">
          <p class="hero-kicker">${t!=null&&t.tomorrow?"Yarın":"Sıradaki"} · ${(t==null?void 0:t.name)||"—"}</p>
          <h2 class="hero-name">${(t==null?void 0:t.name)||"—"}</h2>
          <div class="countdown" aria-live="polite">
            <div class="unit"><span>${(e==null?void 0:e.h)||"00"}</span><small>saat</small></div>
            <div class="sep">:</div>
            <div class="unit"><span>${(e==null?void 0:e.m)||"00"}</span><small>dk</small></div>
            <div class="sep">:</div>
            <div class="unit"><span>${(e==null?void 0:e.s)||"00"}</span><small>sn</small></div>
          </div>
          <p class="hero-sub">${n.label} · ${(t==null?void 0:t.time)||""}</p>
        </section>

        <section class="times" aria-label="Günün namaz vakitleri">
          <div class="times-head">
            <h3>Bugün</h3>
            <p>${n.dateLabel}</p>
          </div>
          <ul class="time-list">
            ${a.map(o=>{const u=t&&o.key===t.key&&!t.tomorrow,y=s&&o.key===s.key&&!o.meta,h=o.date.getTime()<=n.now.getTime()&&!u;return`
                  <li class="time-row ${o.meta?"is-meta":""} ${u?"is-next":""} ${y?"is-now":""} ${h?"is-passed":""}">
                    <span class="time-name">${o.name}</span>
                    <span class="time-clock">${o.time}</span>
                  </li>`}).join("")}
          </ul>
        </section>
        `}
    </main>
  `;const i=document.getElementById("city-select");i&&i.addEventListener("change",()=>{const o=i.selectedOptions[0];I(o.value,o.textContent)});const l=document.getElementById("retry");l&&l.addEventListener("click",m)}function j(){c&&clearInterval(c),c=setInterval(()=>{n.now=new Date,!n.loading&&!n.error&&n.timings&&d()},1e3)}m();j();
