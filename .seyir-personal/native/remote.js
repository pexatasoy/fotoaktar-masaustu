(() => {
  'use strict';
  if (window.__seyirRemote) return;
  let selected = null;
  let editing = null;
  const ring = document.createElement('div');
  ring.setAttribute('aria-hidden', 'true');
  Object.assign(ring.style, { position: 'fixed', pointerEvents: 'none', zIndex: '2147483647', border: '3px solid #d7edb8', borderRadius: '8px', boxShadow: '0 0 0 2px #111', display: 'none' });
  document.documentElement.appendChild(ring);
  const candidates = () => [...document.querySelectorAll('a[href],button,input:not([type=hidden]),textarea,select,[role=button],[tabindex]')].filter(el => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return !el.disabled && el.getAttribute('aria-hidden') !== 'true' && r.width > 3 && r.height > 3 && s.visibility !== 'hidden' && s.display !== 'none' && r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth;
  });
  const paint = () => {
    if (!selected?.isConnected) { ring.style.display = 'none'; selected = null; return; }
    const r = selected.getBoundingClientRect();
    Object.assign(ring.style, { display: 'block', left: `${r.left - 4}px`, top: `${r.top - 4}px`, width: `${r.width + 8}px`, height: `${r.height + 8}px`, boxSizing: 'border-box' });
  };
  function move(dx, dy) {
    const list = candidates();
    if (!list.length) { scrollBy({ top: dy * innerHeight * .65, left: dx * innerWidth * .65, behavior: 'smooth' }); return; }
    if (!selected?.isConnected) selected = list[0];
    else {
      const origin = selected.getBoundingClientRect();
      const ox = origin.left + origin.width / 2, oy = origin.top + origin.height / 2;
      const ranked = list.filter(el => el !== selected).map(el => {
        const r = el.getBoundingClientRect();
        const x = r.left + r.width / 2 - ox, y = r.top + r.height / 2 - oy;
        const along = x * dx + y * dy, across = Math.abs(x * dy - y * dx);
        return { el, score: along > 4 ? along + across * 2.5 : Infinity };
      }).sort((a, b) => a.score - b.score);
      if (ranked[0]?.score < Infinity) selected = ranked[0].el;
      else { scrollBy({ top: dy * innerHeight * .65, left: dx * innerWidth * .65, behavior: 'smooth' }); return; }
    }
    selected.focus({ preventScroll: true }); paint();
  }
  function activate() {
    if (!selected) { move(0, 1); return; }
    if (selected.matches('input:not([type=button]):not([type=submit]):not([type=checkbox]):not([type=radio]),textarea')) {
      editing = selected;
      window.webkit?.messageHandlers?.seyirInput?.postMessage({ value: editing.value || '', secure: editing.type === 'password' });
    } else selected.click();
  }
  function setText(value) {
    if (!editing?.isConnected) return;
    const proto = editing instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(editing, value);
    editing.dispatchEvent(new Event('input', { bubbles: true }));
    editing.dispatchEvent(new Event('change', { bubbles: true }));
    editing = null;
  }
  function togglePlayback() {
    const video = [...document.querySelectorAll('video')].sort((a,b) => b.clientWidth*b.clientHeight-a.clientWidth*a.clientHeight)[0];
    if (video) { if(video.paused) video.play().catch(() => {}); else video.pause(); }
  }
  addEventListener('scroll', paint, { passive: true });
  addEventListener('resize', paint, { passive: true });
  Object.defineProperty(window, '__seyirRemote', { value: { move, activate, setText, togglePlayback }, configurable: false });
})();
