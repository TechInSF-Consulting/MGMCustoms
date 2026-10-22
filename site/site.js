// Google Analytics loads only after the visitor accepts. Choice is kept in localStorage;
// "Cookie settings" in the footer reopens the bar.
const GA_ID = 'GT-WF6WRVH5';
const KEY = 'mgm-consent';
const bar = document.querySelector('.consent');

const store = {
  get() { try { return localStorage.getItem(KEY); } catch { return null; } },
  set(v) { try { localStorage.setItem(KEY, v); } catch {} },
};

function loadGA() {
  if (window.gtag) return window.gtag('consent', 'update', { analytics_storage: 'granted' });
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () { dataLayer.push(arguments); };
  gtag('js', new Date());
  gtag('config', GA_ID);
  const s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA_ID;
  document.head.append(s);
}

function stopGA() {
  if (window.gtag) gtag('consent', 'update', { analytics_storage: 'denied' });
  // drop GA cookies on this domain and its parent
  for (const c of document.cookie.split(';')) {
    const name = c.split('=')[0].trim();
    if (name.startsWith('_ga')) for (const d of [location.hostname, '.' + location.hostname.replace(/^www\./, '')])
      document.cookie = `${name}=; Max-Age=0; path=/; domain=${d}`;
  }
}

const choice = store.get();
if (choice === 'granted') loadGA();
else if (!choice && bar) bar.hidden = false;

document.addEventListener('click', e => {
  const btn = e.target.closest('[data-consent], [data-consent-open]');
  if (!btn || !bar) return;
  if (btn.hasAttribute('data-consent-open')) { bar.hidden = false; bar.querySelector('button').focus(); return; }
  const v = btn.dataset.consent;
  store.set(v);
  v === 'granted' ? loadGA() : stopGA();
  bar.hidden = true;
});

// Contact map: swap the preview for the Google Maps Embed iframe on tap, so no Google
// scripts or cookies load unless the visitor asks. Without a key yet, open Google Maps instead.
for (const m of document.querySelectorAll('[data-map]')) m.querySelector('button').addEventListener('click', () => {
  const q = encodeURIComponent(m.dataset.q);
  if (!m.dataset.key) return window.open('https://www.google.com/maps/search/?api=1&query=' + q, '_blank', 'noopener');
  const f = document.createElement('iframe');
  f.src = `https://www.google.com/maps/embed/v1/place?key=${encodeURIComponent(m.dataset.key)}&q=${q}`;
  f.title = 'Map of ' + m.dataset.q;
  f.allowFullscreen = true;
  f.referrerPolicy = 'strict-origin-when-cross-origin';
  m.classList.add('live');
  m.replaceChildren(f);
  f.focus();
});

// ponytail: forms are placeholders until a backend is chosen (PLAN.md, open questions 2-3).
// Replace this block with the real POST once there's an endpoint.
for (const f of document.querySelectorAll('form[data-form]')) f.addEventListener('submit', e => {
  e.preventDefault();
  const status = f.querySelector('[role=status]');
  if (!f.checkValidity()) {
    status.textContent = 'Please fill in the required fields.';
    f.querySelector(':invalid').focus();
    return;
  }
  status.textContent = "Online submission isn't connected yet. Please call (415) 362-8435.";
});
