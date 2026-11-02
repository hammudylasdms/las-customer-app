/// Presentation only: keeps the portal's forms, links, permissions and data.
const portalPresentation = r'''
(() => {
  if (!document.querySelector('.navend form[action="/customer/logout"]')) return;
  if (document.getElementById('las-app-style')) return;
  const style = document.createElement('style'); style.id = 'las-app-style';
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
  document.head.append(style);
  const main = document.querySelector('#content'); if (!main) return;
  const query = new URLSearchParams(location.search);
  const tile = (href, title, description) => {
    const link=document.createElement('a');link.href=href;
    const label=document.createElement('span');label.textContent=title;link.append(label);
    const sub=document.createElement('small');sub.textContent=description;link.append(sub);return link;
  };
  if (location.pathname === '/customer/dashboard' && query.get('app_view') !== 'orders') {
    const grid=main.querySelector('.order-grid'); if(!grid)return;
    const cards=Array.from(grid.querySelectorAll('.vehicle'));
    // The server supplies each status and already enforces customer ownership.
    const current=cards.filter(card=>!['Invoiced','Cancelled'].includes(card.querySelector('.status')?.textContent.trim()));
    if(!current.length){location.replace('/customer/appointments?app_home=1');return;}
    const heading=main.querySelector('h1');if(heading)heading.textContent='YOUR WORKSHOP VISIT';
    const intro=main.querySelector('.sub');if(intro)intro.textContent='Your current order, documents and service updates.';
    const first=current[0];grid.replaceChildren(first);
    const status=first.querySelector('.status');
    if(status){const hero=document.createElement('p');hero.className='las-hero';hero.textContent=status.textContent;grid.before(hero);}
    const other=cards.filter(card=>card!==first);
    if(other.length){const details=document.createElement('details');details.className='las-others';const summary=document.createElement('summary');summary.textContent='Other orders ('+other.length+')';details.append(summary,...other);grid.after(details);}
    const orderLink=first.querySelector('a[href^="/customer/orders/"]');
    if(orderLink){const tiles=document.createElement('div');tiles.className='las-tiles';tiles.append(
      tile(orderLink.getAttribute('href'),'Order details','Status and service progress'),
      tile(orderLink.getAttribute('href'),'Photos & documents','Shared by your service team'),
      tile('/customer/messages','Service advisor','Messages and questions'),
      tile('/customer/archive','Service history','Previous visits and documents'));
      grid.after(tiles);}
  }
  if(location.pathname==='/customer/appointments' && query.get('app_home')==='1'){
    const heading=document.createElement('h1');heading.textContent='NEXT SERVICE?';
    const intro=document.createElement('p');intro.textContent='No open order. Choose your vehicle and book your next visit.';
    main.prepend(heading,intro);
  }
})();
''';
