(() => {
  'use strict';
  if (window.__seyirRemote) return;
  let selected = null;
  let editing = null;
  let inputLocked = false;
  let videoExpanded = false;
  let previousScroll = [0,0];
  function expandVideo() {
    const video=[...document.querySelectorAll('video')].sort((a,b)=>b.clientWidth*b.clientHeight-a.clientWidth*a.clientHeight)[0];
    if(!video) return false;
    if(videoExpanded) return true;
    const player=video.closest('#movie_player,.html5-video-player') || video;
    previousScroll=[scrollX,scrollY];
    player.setAttribute('data-seyir-video-root','');
    for(let node=player;node;node=node.parentElement)node.setAttribute('data-seyir-video-path','');
    const style=document.createElement('style');style.id='seyir-video-style';
    style.textContent='[data-seyir-video-path]{transform:none!important;filter:none!important;perspective:none!important;overflow:visible!important;contain:none!important}[data-seyir-video-path]:not([data-seyir-video-root])>:not([data-seyir-video-path]){visibility:hidden!important}[data-seyir-video-root],[data-seyir-video-root] *{visibility:visible!important}[data-seyir-video-root]{position:fixed!important;inset:0!important;width:100vw!important;height:100vh!important;max-width:none!important;max-height:none!important;margin:0!important;z-index:2147483646!important;background:#000!important}[data-seyir-video-root] video,video[data-seyir-video-root]{position:absolute!important;inset:0!important;width:100%!important;height:100%!important;object-fit:contain!important}';
    document.documentElement.appendChild(style);videoExpanded=true;
    window.webkit?.messageHandlers?.seyirInput?.postMessage({fullscreen:true});return true;
  }
  function exitVideo() {
    document.getElementById('seyir-video-style')?.remove();
    document.querySelectorAll('[data-seyir-video-path],[data-seyir-video-root]').forEach(el=>{el.removeAttribute('data-seyir-video-path');el.removeAttribute('data-seyir-video-root');});
    if(videoExpanded)scrollTo(...previousScroll);videoExpanded=false;
  }
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
    if(inputLocked)return;
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
    if(inputLocked)return;
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
  function pointerMove(x, y) {
    if(inputLocked)return;
    const px=Math.max(0,Math.min(innerWidth-1,x*innerWidth));
    const py=Math.max(0,Math.min(innerHeight-1,y*innerHeight));
    ring.style.display='none';
    const target=document.elementFromPoint(px,py);
    if(target) target.dispatchEvent(new MouseEvent('mousemove',{bubbles:true,clientX:px,clientY:py}));
  }
  function pointerClick(x,y) {
    if(inputLocked)return;
    const target=document.elementFromPoint(Math.max(0,Math.min(innerWidth-1,x*innerWidth)),Math.max(0,Math.min(innerHeight-1,y*innerHeight)));
    if(!target) return;
    selected=target.closest('a,button,input,textarea,select,[role=button]') || target;
    activate();
    ring.style.display='none';
  }
  addEventListener('scroll', paint, { passive: true });
  addEventListener('resize', paint, { passive: true });
  document.addEventListener('click',event=>{
    if(inputLocked){event.preventDefault();event.stopImmediatePropagation();return;}
    if(event.target.closest?.('.ytp-fullscreen-button')){event.preventDefault();event.stopImmediatePropagation();if(videoExpanded){exitVideo();window.webkit?.messageHandlers?.seyirInput?.postMessage({fullscreen:false});}else expandVideo();}
  },true);
  Object.defineProperty(window, '__seyirRemote', { value: { move, activate, setText, togglePlayback, pointerMove, pointerClick, expandVideo, exitVideo, setInputLocked(value){inputLocked=!!value;ring.style.display='none';} }, configurable: false });
})();
