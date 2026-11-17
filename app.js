// Shared code for every page. Load order on each page:
//   1. supabase-js (CDN)  2. config.js  3. app.js
/* global supabase, SUPABASE_URL, SUPABASE_KEY */

const db = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const ROLE_LABEL = { owner: 'Boss', manager: 'Manager', staff: 'Staff' };

// ---------- Shared look ----------
(function addBaseStyles() {
  const css = `
    :root { --bg:#f4f6f8; --card:#fff; --text:#1f2933; --muted:#616e7c; --line:#e4e7eb;
            --brand:#1d4ed8; --red:#dc2626; --red-bg:#fee2e2; --orange:#d97706; --orange-bg:#ffedd5;
            --green:#15803d; --green-bg:#dcfce7; }
    * { box-sizing:border-box; }
    body { margin:0; font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
           background:var(--bg); color:var(--text); font-size:16px; }
    .wrap { max-width:960px; margin:0 auto; padding:16px; }
    .card { background:var(--card); border-radius:12px; padding:20px; box-shadow:0 2px 10px rgba(0,0,0,.06); margin-bottom:16px; }
    h1 { font-size:1.4rem; margin:0 0 4px; } h2 { font-size:1.15rem; margin:0 0 12px; }
    .muted { color:var(--muted); }
    label { display:block; font-weight:600; margin:12px 0 4px; }
    input, select, textarea { width:100%; padding:10px 12px; font-size:16px; border:1px solid #cbd2d9; border-radius:8px; background:#fff; }
    button { cursor:pointer; font-size:16px; padding:10px 16px; border-radius:8px; border:1px solid transparent; }
    .btn { background:var(--brand); color:#fff; } .btn:disabled { opacity:.6; cursor:wait; }
    .btn-light { background:#fff; color:var(--text); border-color:#cbd2d9; }
    .btn-full { width:100%; margin-top:16px; }
    .msg { padding:10px 12px; border-radius:8px; margin-top:12px; display:none; }
    .msg.error { display:block; background:var(--red-bg); color:var(--red); }
    .msg.ok { display:block; background:var(--green-bg); color:var(--green); }
    .topbar { background:#fff; border-bottom:1px solid var(--line); }
    .topbar .wrap { display:flex; align-items:center; justify-content:space-between; gap:12px; padding-top:10px; padding-bottom:10px; }
    .brand { font-weight:700; } .who { font-size:.9rem; color:var(--muted); }
    .hidden { display:none !important; }
  `;
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);
})();

// ---------- Formatting ----------
// Money: RM 1,234.50
function formatRM(n) {
  const v = Number(n || 0);
  return 'RM ' + v.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// Date: 17 Nov 2026
function formatDate(d) {
  if (!d) return '';
  const date = typeof d === 'string' && d.length === 10 ? new Date(d + 'T00:00:00') : new Date(d);
  if (isNaN(date)) return '';
  return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

// ---------- Messages ----------
function friendlyError(err) {
  const m = (err && (err.message || err.error_description || String(err))) || '';
  if (/Invalid login credentials/i.test(m)) return 'Wrong email or password. Please try again.';
  if (/Email not confirmed/i.test(m)) return 'Please open the confirmation email we sent you, then log in.';
  if (/User already registered/i.test(m)) return 'This email already has an account. Please log in instead.';
  if (/Password should be at least/i.test(m)) return 'Password is too short. Please use at least 6 characters.';
  if (/rate limit|too many/i.test(m)) return 'Too many tries. Please wait a few minutes and try again.';
  if (/Failed to fetch|NetworkError/i.test(m)) return 'Cannot connect. Please check your internet and try again.';
  if (/row-level security|permission denied/i.test(m)) return 'You are not allowed to do this.';
  return 'Something went wrong. Please try again. (' + m + ')';
}

function showMsg(el, text, type) {
  el.textContent = text;
  el.className = 'msg ' + (type || 'error');
}
function hideMsg(el) { el.className = 'msg'; el.textContent = ''; }

// ---------- Login / role ----------
async function getMe() {
  const { data: { session } } = await db.auth.getSession();
  if (!session) return null;
  const { data: profile } = await db.from('profiles')
    .select('id, email, full_name, role, active')
    .eq('id', session.user.id)
    .maybeSingle();
  return { user: session.user, profile };
}

// Use at the top of every page except index.html.
// allowed = list of roles, e.g. ['owner','manager']. Others go back to index.html.
async function requireRole(allowed) {
  const me = await getMe();
  if (!me || !me.profile || !me.profile.active || !allowed.includes(me.profile.role)) {
    window.location.replace('index.html');
    return null;
  }
  return me;
}

async function logout() {
  await db.auth.signOut();
  window.location.replace('index.html');
}

// Simple top bar with name, role and Log out button.
function renderTopbar(me) {
  const bar = document.createElement('div');
  bar.className = 'topbar';
  const name = (me.profile && me.profile.full_name) || me.user.email;
  const role = me.profile ? ROLE_LABEL[me.profile.role] || '' : '';
  bar.innerHTML = '<div class="wrap"><a href="index.html" class="brand" style="color:inherit;text-decoration:none">YONGHUAT SYSTEM</a>' +
    '<div><span class="who"></span> <button class="btn-light" type="button">Log out</button></div></div>';
  bar.querySelector('.who').textContent = name + (role ? ' · ' + role : '');
  bar.querySelector('button').addEventListener('click', logout);
  document.body.prepend(bar);
}
