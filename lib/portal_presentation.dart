/// Presentation only: keeps the portal's forms, links, permissions and data.
const portalPresentation = r'''
(async () => {
  if (!document.querySelector('.navend form[action="/customer/logout"]')) return;
  if (document.getElementById('las-app-style')) return;
  const style = document.createElement('style'); style.id = 'las-app-style';
  const page = location.pathname;
  const appQuery=new URLSearchParams(location.search);
  const isOverview=page==='/customer/dashboard'&&!appQuery.has('app_view')&&!appQuery.has('app_section');
  const messagesPage = page === '/customer/messages' || appQuery.get('app_section') === 'advisor';
  const simplifiedPage = page === '/customer/dashboard' || page === '/customer/appointments' || messagesPage || /^\/customer\/orders\/\d+$/.test(page);
  style.textContent = `
    :root{color-scheme:dark;--blue:#007aff}
    html,body{background:#17191b!important;color:#f5f5f7!important}
    .header,.navline,.footer,.mobile-signout{display:none!important}
    .wrap{width:100%!important;max-width:900px!important;margin:0 auto!important;padding:24px 20px 32px!important}
    h1{font-size:42px!important;line-height:1.08!important;letter-spacing:-1px;color:white!important}
    h2,h3,label,strong{color:#fff!important}
    p,.meta,.sub,.eyebrow{color:#b8bcc2!important}
    a{color:#79b6ff} article,.card,.vehicle,.panel,section,.booking-card{background:#252729!important;border:1px solid #35383c!important;border-radius:18px!important;box-shadow:none!important;color:white!important}
    input,textarea,select{background:#303338!important;color:#fff!important;border-color:#626870!important;border-radius:12px!important}
    button,.button{border-radius:12px!important}
    .button,button[type=submit]{background:#007aff!important;color:white!important}
    table,td,th{color:#f5f5f7!important;border-color:#41454b!important}
    .order-grid{display:grid!important;grid-template-columns:1fr!important;gap:14px!important}
    .las-tiles{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:20px}
    .las-tiles a{display:flex;flex-direction:column;justify-content:space-between;min-height:105px;padding:18px;background:#252729;border:1px solid #35383c;border-radius:16px;color:white;text-decoration:none;font-size:17px;font-weight:600}
    .las-detail-link > small{display:block;margin-top:4px}
    .las-tiles small{font-size:13px;font-weight:400;color:#b8bcc2;margin-top:8px}
    .las-hero{font-size:44px!important;font-weight:800;line-height:1.08;letter-spacing:-1px;margin:8px 0 24px!important;color:white!important}
    .las-primary{display:block;background:#007aff;color:white;padding:18px;border-radius:14px;text-align:center;text-decoration:none;font-weight:700;margin-top:18px}
    .las-others{margin:18px 0}.las-others summary{padding:16px;background:#252729;border-radius:14px}
  `;
  if (!messagesPage) style.textContent += `
    #messages,.messages,#content a[href='/customer/messages']{display:none!important}
  `;
  if (simplifiedPage) style.textContent += `
    .toast{display:none!important}
    ${isOverview ? '' : '.balance-card,.news-area{display:none!important}'}
    #content > p:has(a[href='/customer/archive']){display:none!important}
  `;
  document.head.append(style);
  const main = document.querySelector('#content'); if (!main) return;
  // Translate raw order-status codes only, never financial document labels.
  const normalizeStatuses = () => main.querySelectorAll('.status, .order-progress-head strong').forEach(status => {
    if (status.textContent.trim() === 'SERVICE_ADVISOR_TAKEN') status.textContent = 'Service advisor assigned';
    if (status.textContent.trim().toUpperCase() === 'CREDIT_NOTE') status.textContent = 'Invoiced';
  });
  normalizeStatuses();
  new MutationObserver(normalizeStatuses).observe(main, {childList:true,subtree:true});
  const query=new URLSearchParams(location.search), section=query.get('app_section');
  const overview=page==='/customer/dashboard' && !query.has('app_view') && !section;
  const el=(tag,text,cls)=>{const e=document.createElement(tag);if(text)e.textContent=text;if(cls)e.className=cls;return e;};
  const tile=(href,title,sub)=>{const a=el('a',null,'las-detail-link');a.href=href;a.append(el('span',title),el('small',sub));return a;};
  const closed=o=>['INVOICED','CANCELLED','CREDIT_NOTE'].includes(o.status);
  let data=null;
  try{
    const id=/^\/customer\/orders\/(\d+)$/.exec(page)?.[1];
    const r=await fetch('/customer/mobile/auth/experience'+(id?'?order_id='+id:''),{credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(12000)});
    if(r.status===401){location.replace('/customer');return;}if(!r.ok)throw Error();data=await r.json();
  }catch(_){main.prepend(el('p','Some information could not be loaded. Please reopen this page.'));}
  const orders=data?.orders||[],current=orders.filter(o=>!closed(o)),first=current[0];
  const vehicle=v=>{
    const card=el('article',null,'las-vehicle');card.append(el('div','YOUR VEHICLE','eyebrow'));
    const row=el('div',null,'las-vehicle-row'),text=el('div');
    if(v.logo){const img=el('img');img.src=v.logo;img.alt=v.brand||'';row.append(img);}
    text.append(el('h2',[v.brand,v.model].filter(Boolean).join(' - ')),el('p',v.license_plate||'Registration not available'));
    row.append(text);card.append(row);return card;
  };
  if(overview){
    const balance=main.querySelector('.balance-card'),news=main.querySelector('.news-area');
    const home=el('div');home.append(el('div','Your customer portal','eyebrow'),el('h1','Welcome back.'),el('p','Your workshop visits, documents and updates. All in one place.','sub'));
    if(balance&&!balance.classList.contains('settled')){
      const amount=balance.querySelector('.balance-actions > b')?.textContent;
      if(amount){const row=el('div',null,'las-balance');row.append(el('span','Account balance'),el('strong',(balance.classList.contains('credit')?'+ ':'− ')+amount,balance.classList.contains('credit')?'las-credit':'las-due'));home.append(row);}
    }
    if(news){
      const latest=el('section',null,'news-area');
      latest.append(el('h2','News'));
      const list=el('div','Loading news…');latest.append(list);home.append(latest);
      const renderNews=items=>{
        const links=items.slice().sort((a,b)=>Number(b.news_id)-Number(a.news_id)).slice(0,3).map(item=>{
          const link=el('a',item.message);
          if(/appointment/i.test(item.message)) link.href='/customer/appointments#my-appointments';
          else if(/withdrawn/i.test(item.message)&&item.order_id) link.href='/customer/orders/'+item.order_id;
          else if(item.document_id) link.href='/customer/documents/'+item.document_id;
          else if(/message/i.test(item.message)) link.href='/customer/messages';
          else if(item.order_id) link.href='/customer/orders/'+item.order_id;
          else link.href='/customer/account';
          return link;
        });
        list.replaceChildren(...links);
        if(!links.length)list.textContent='No new updates.';
      };
      // Reuse the portal's authenticated live feed and its existing polling.
      const originalFetch=window.fetch.bind(window);
      const livePath='/customer/live';
      window.fetch=async(...args)=>{
        const response=await originalFetch(...args);
        if(response.ok && new URL(response.url,location.href).pathname===livePath)
          response.clone().json().then(payload=>renderNews(payload.news)).catch(()=>{});
        return response;
      };
      originalFetch(livePath,{credentials:'same-origin',cache:'no-store'}).then(r=>r.json()).then(payload=>renderNews(payload.news)).catch(()=>{list.textContent='News could not be loaded.';});
    }
    if(data){data.vehicles.forEach(v=>home.append(vehicle(v)));if(!data.vehicles.length)home.append(el('p','No vehicle is registered to your account yet.'));}
    else home.append(el('p','Your vehicles are temporarily unavailable.'));
    if(first){const active=tile('/customer/orders/'+first.order_id,'Current Order · '+first.order_number,'View your workshop progress');active.className='las-current-order';home.append(active);}
    const tiles=el('div',null,'las-tiles'),base=first?'/customer/orders/'+first.order_id:'/customer/dashboard';
    const appointment=tile('/customer/appointments','Request an Appointment','Choose your vehicle and preferred time');appointment.className='las-appointment';
    tiles.append(appointment,tile(base+'?app_section=photos','my Photos/Videos','Your workshop media'),tile(base+'?app_section=advisor','my Service Advisor','We are here to help'),tile('/customer/dashboard?app_section=history','my Service History','Completed visits and documents'),tile('/customer/mobile/auth/payments','Pay my Bill / Make Downpayment','Open invoices and Add funds'));
    home.append(tiles);main.replaceChildren(home);
  }
  if(page==='/customer/dashboard' && query.get('app_view')==='orders'){
    const home=el('div');home.append(el('h1','Current Orders'));
    if(!data)home.append(el('p','Orders could not be loaded. Please try again.'));
    else if(!current.length)home.append(el('p','No current orders.'));
    else current.forEach(o=>{const card=vehicle(o);card.append(tile('/customer/orders/'+o.order_id,'Order '+o.order_number,'View order'));home.append(card);});
    main.replaceChildren(home);
  }
  if(section==='history'){
    const home=el('div');home.append(el('h1','my Service History'));
    if(!data)home.append(el('p','Service history could not be loaded. Please try again.'));
    else {const history=orders.filter(closed);history.forEach(o=>{const card=vehicle(o);card.prepend(el('p','Order '+o.order_number+' · '+(o.status==='CANCELLED'?'Cancelled':'Invoiced')));card.append(tile('/customer/orders/'+o.order_id,'View order & documents','Invoice and payment receipts'));home.append(card);});if(!history.length)home.append(el('p','No completed orders yet.'));}
    main.replaceChildren(home);
  }
  if(section==='photos'||section==='advisor'){
    style.textContent+='#order-content > :not(.las-focus){display:none!important}';
    const focus=()=>{
      const container=main.querySelector('#order-content')||main;if(container.querySelector('.las-focus'))return;
      const panel=el('section',null,'panel las-focus');
      if(section==='photos'){
        panel.append(el('h1','my Photos/Videos'));
        const source=Array.from(container.querySelectorAll('section.panel')).find(s=>s.querySelector('h2')?.textContent==='Your workshop videos');
        const media=source&&!source.hidden?Array.from(source.querySelectorAll('article')):[];
        if(media.length)media.forEach(m=>panel.append(m));else panel.append(el('p','No current photos / videos.'));
      }else{
        const order=orders.find(o=>o.order_id===Number(page.split('/').pop()));
        const name=order?.advisor_name||container.querySelector('.detail strong')?.textContent;
        panel.append(el('h1','my Service Advisor'),el('h2',name||'LAS Service Team'),el('p',name?'Your service advisor is here to help with your workshop visit. Send us a message below — we will be happy to assist you.':'We are here to help. A service advisor will be assigned when your workshop order is created.'));
        const tel=el('a','Tel: +971 50 881 4512');tel.href='tel:+971508814512';const email=el('a','office@lastoptechnik.com');email.href='mailto:office@lastoptechnik.com';panel.append(tel,el('br'),email);
      }
      if(container===main){const chat=main.querySelector('#messages');main.replaceChildren(panel);if(chat&&section==='advisor')main.append(chat);}else container.prepend(panel);
    };
    focus();const content=main.querySelector('#order-content');if(content)new MutationObserver(focus).observe(content,{childList:true});
  }
  if(/^\/customer\/orders\/\d+$/.test(page)&&!section&&data){
    const receipts=el('section',null,'panel');receipts.append(el('h2','Invoices & payment receipts'));
    data.documents.filter(d=>['INVOICE','CREDIT_NOTE'].includes(d.document_type)).forEach(d=>receipts.append(tile('/customer/account/documents/'+d.document_id,d.document_type==='INVOICE'?'Invoice':'Credit note',d.file_name)));
    data.receipts.forEach(r=>receipts.append(tile('/customer/receipts/'+encodeURIComponent(r.receipt_number),'Payment receipt '+r.receipt_number,'AED '+Number(r.amount).toFixed(2))));
    if(!data.receipts.length)receipts.append(el('p','No payment receipts are available for this order yet.'));main.append(receipts);
  }
  if(page==='/customer/appointments'){
    const heading=Array.from(main.querySelectorAll('h2.section-title')).find(h=>h.textContent.trim().toLowerCase()==='my appointments');
    if(heading){
      heading.id='my-appointments';
      const cards=[];let next=heading.nextElementSibling;
      while(next?.matches('article.vehicle')){cards.push(next);next=next.nextElementSibling;}
      // The booking page already sorts by appointment date and time, newest first.
      const first=cards[0];cards.slice(1).forEach(card=>card.remove());
      const match=first?.querySelector('h2')?.textContent.match(/(\d{2})\.(\d{2})\.(\d{4})/);
      if(match){
        const date=Date.UTC(+match[3],+match[2]-1,+match[1]);
        const gulf=new Date(Date.now()+4*3600000);
        const today=Date.UTC(gulf.getUTCFullYear(),gulf.getUTCMonth(),gulf.getUTCDate());
        if(today-date>14*86400000)first.replaceWith(el('p','No recent appointments.'));
      }
      if(location.hash==='#my-appointments')heading.scrollIntoView();
    }
  }
  const applyTheme=value=>{document.documentElement.dataset.lasTheme=value;try{localStorage.setItem('las-theme',value);}catch(_){}window.LasAppearance?.postMessage(value);};
  const switcher=el('div',null,'las-appearance'),label=el('label','Appearance '),select=el('select');
  for(const [value,text] of [['dark','Dark'],['light','Light']]){const option=el('option',text);option.value=value;select.append(option);}
  let saved='dark';try{saved=localStorage.getItem('las-theme')||'dark';}catch(_){}select.value=saved;select.onchange=()=>applyTheme(select.value);label.append(select);switcher.append(label);if(page==='/customer/account'){
    main.append(switcher);
    const legal = el('section', null, 'panel las-legal');
    legal.append(el('h2', 'Legal'));
    for (const [label, url] of [
      ['Privacy Policy', 'https://lastoptechnik.com/en/privacy/'],
      ['Terms and Conditions', 'https://lastoptechnik.com/en/terms/'],
    ]) {
      const link = el('a', label);
      link.href = url;
      legal.append(link);
    }
    main.append(legal);
  }
  applyTheme(saved);
  style.textContent+=`
    .las-legal{margin:20px 0;padding:18px}.las-legal a{display:flex;align-items:center;min-height:44px}.las-legal a+a{border-top:1px solid #8886}
    .las-appearance{max-width:900px;margin:auto;padding:12px 20px;text-align:right}.las-appearance select{width:auto;padding:8px;margin-left:8px}
    .las-balance{display:flex;justify-content:space-between;align-items:center;padding:18px 0;border-bottom:1px solid #555}.las-balance .las-credit{color:#25b875!important}.las-balance .las-due{color:#ff6363!important}
    .las-vehicle{padding:24px;margin:18px 0}.las-vehicle-row{display:flex;align-items:center;gap:20px;margin-top:20px}.las-vehicle-row img{width:58px;height:58px;object-fit:contain}.las-vehicle h2{font-size:18px!important;margin:0}.las-vehicle p{margin:8px 0 0}.las-tiles{grid-template-columns:repeat(2,minmax(0,1fr))!important}.las-tiles a:last-child{grid-column:1/-1}.las-tiles a{overflow-wrap:break-word}.news-area a{display:block;padding:9px 0}.las-tiles .las-appointment{background:#007aff!important;color:white!important}.las-appointment small{color:white!important}
    .las-current-order{display:block;padding:20px;background:#252729;border-radius:16px}.las-current-order small{display:block;margin-top:8px}.news-area{padding:16px!important;margin:16px 0!important}.news-area h2{font-size:17px!important;margin:0 0 8px}.panel>a{display:block;margin:12px 0}
    html[data-las-theme=light]{color-scheme:light!important}html[data-las-theme=light],html[data-las-theme=light] body{background:#f3f5f7!important;color:#1c2430!important}
    html[data-las-theme=light] h1,html[data-las-theme=light] h2,html[data-las-theme=light] h3,html[data-las-theme=light] label,html[data-las-theme=light] strong{color:#1c2430!important}
    html[data-las-theme=light] p,html[data-las-theme=light] .meta,html[data-las-theme=light] .sub,html[data-las-theme=light] .eyebrow{color:#525d6c!important}
    html[data-las-theme=light] article,html[data-las-theme=light] section,html[data-las-theme=light] .panel,html[data-las-theme=light] .card,html[data-las-theme=light] .las-tiles a,html[data-las-theme=light] .las-current-order{background:white!important;color:#1c2430!important;border-color:#d6dce4!important}
    html[data-las-theme=light] input,html[data-las-theme=light] textarea,html[data-las-theme=light] select{background:white!important;color:#1c2430!important;border-color:#abb4c0!important}
    html[data-las-theme=light] .las-tiles small{color:#525d6c}html[data-las-theme=light] .las-tiles .las-appointment,html[data-las-theme=light] .las-appointment small{color:white!important;background:#007aff!important}
    html[data-las-theme=light] .las-credit{color:#087c49!important}html[data-las-theme=light] .las-due{color:#c02b35!important}html[data-las-theme=light] td,html[data-las-theme=light] th{color:#1c2430!important}
  `;
})();
''';
