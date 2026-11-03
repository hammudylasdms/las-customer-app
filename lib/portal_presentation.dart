/// Presentation only: keeps the portal's forms, links, permissions and data.
const portalPresentation = r'''
(() => {
  if (!document.querySelector('.navend form[action="/customer/logout"]')) return;
  if (document.getElementById('las-app-style')) return;
  const style = document.createElement('style'); style.id = 'las-app-style';
  const page = location.pathname;
  const messagesPage = page === '/customer/messages';
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
    .las-tiles small{font-size:13px;font-weight:400;color:#b8bcc2;margin-top:8px}
    .las-hero{font-size:44px!important;font-weight:800;line-height:1.08;letter-spacing:-1px;margin:8px 0 24px!important;color:white!important}
    .las-primary{display:block;background:#007aff;color:white;padding:18px;border-radius:14px;text-align:center;text-decoration:none;font-weight:700;margin-top:18px}
    .las-others{margin:18px 0}.las-others summary{padding:16px;background:#252729;border-radius:14px}
  `;
  if (!messagesPage) style.textContent += `
    #messages,.messages,a[href='/customer/messages']{display:none!important}
  `;
  if (simplifiedPage) style.textContent += `
    .balance-card,.news-area,.toast{display:none!important}
    #content > p:has(a[href='/customer/archive']){display:none!important}
  `;
  document.head.append(style);
  const main = document.querySelector('#content'); if (!main) return;
  // Translate raw order-status codes only, never financial document labels.
  const normalizeStatuses = () => main.querySelectorAll('.status').forEach(status => {
    if (status.textContent.trim().toUpperCase() === 'CREDIT_NOTE') status.textContent = 'Invoiced';
  });
  normalizeStatuses();
  new MutationObserver(normalizeStatuses).observe(main, {childList:true,subtree:true});
  const query = new URLSearchParams(location.search);
  const tile = (href, title, description) => {
    const link=document.createElement('a');link.href=href;
    const label=document.createElement('span');label.textContent=title;link.append(label);
    const sub=document.createElement('small');sub.textContent=description;link.append(sub);return link;
  };
  if (page === '/customer/dashboard' && query.get('app_view') === 'orders') {
    const grid = main.querySelector('.order-grid');
    if (grid) {
      grid.querySelectorAll('.vehicle').forEach(card => {
        if (['Invoiced','Cancelled'].includes(card.querySelector('.status')?.textContent.trim())) card.remove();
      });
      if (!grid.children.length) {
        const empty = document.createElement('p'); empty.textContent = 'No current orders.'; grid.append(empty);
      }
    }
    const title=main.querySelector('h1'); if(title)title.textContent='Current Orders';
  }
  if (location.pathname === '/customer/dashboard' && query.get('app_view') !== 'orders') {
    const grid=main.querySelector('.order-grid');
    const cards=Array.from(grid?.querySelectorAll('.vehicle') || []);
    const current=cards.filter(card=>!['Invoiced','Cancelled'].includes(card.querySelector('.status')?.textContent.trim()));
    const first=current[0];
    const orderHref=first?.querySelector('a[href^="/customer/orders/"]')?.getAttribute('href');
    const home=document.createElement('div');home.id='las-overview';
    const heading=document.createElement('h1');heading.textContent=first?'YOUR WORKSHOP VISIT':'MY LAS';
    const intro=document.createElement('p');intro.textContent=first?'Your current order and service updates.':'No current order. Your next visit and service history are just a tap away.';
    home.append(heading,intro);
    if(first) {
      const status=first.querySelector('.status');
      if(status){const hero=document.createElement('p');hero.className='las-hero';hero.textContent=status.textContent;home.append(hero);}
      home.append(first);
    }
    const tiles=document.createElement('div');tiles.className='las-tiles';
    const appointment=tile('/customer/appointments','Request an Appointment','Choose your vehicle and preferred time');
    if(!first)tiles.append(appointment);
    tiles.append(
      tile(orderHref || '/customer/dashboard?app_view=orders','Order Details',first?'Status and service progress':'No current orders'),
      tile(orderHref ? orderHref+'#las-photos' : '/customer/archive','my Photos/Videos',first?'Photos and workshop videos':'Select a previous visit to view its media'),
      tile(orderHref ? orderHref+'#las-advisor' : '/customer/archive','my Service Advisor',first?'Your service contact':'View the advisor for a previous visit'),
      tile('/customer/archive','my Service History','Previous visits and documents'),
      tile('/customer/mobile/auth/payments','Pay my Bill / Make Downpayment','Open invoices, payment options and Add funds'));
    if(first)tiles.append(appointment);
    home.append(tiles);
    const other=current.slice(1);
    if(other.length){const details=document.createElement('details');details.className='las-others';const summary=document.createElement('summary');summary.textContent='Other orders ('+other.length+')';details.append(summary,...other);home.append(details);}
    main.replaceChildren(home);
  }
  if (/^\/customer\/orders\/\d+$/.test(page)) {
    const markSections = () => {
      main.querySelectorAll('section.panel').forEach(section => {
        const heading = section.querySelector('h2');
        if (heading?.textContent === 'Your workshop videos') {
          heading.textContent = 'Photos & Videos';
        }
        if (heading?.textContent === 'Photos & Videos') section.id = 'las-photos';
        if (section.querySelector('.detail') && heading?.textContent === 'Current status') section.id = 'las-advisor';
      });
    };
    markSections();
    new MutationObserver(markSections).observe(main, {childList:true,subtree:true});
    if (['#las-photos','#las-advisor'].includes(location.hash)) {
      document.getElementById(location.hash.slice(1))?.scrollIntoView({block:'start'});
    }
  }
  // Keep appointment entry as a neutral tile; hide the redundant legacy CTA.
  main.querySelectorAll('a.button[href="/customer/appointments"]').forEach(link => link.style.setProperty('display','none','important'));
})();
''';
