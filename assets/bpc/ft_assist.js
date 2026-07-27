// FT.com hard-paywall assist for the in-app BPC engine.
//
// Chrome BPC only runs getArchive when #barrier-page is present. FT often
// shows Cloudflare "Security Verification" instead, so nothing runs. When that
// happens (or the barrier is still up after the content script's retries),
// kick the same archive fetch the locale script uses.
(function () {
  if (window.__quaxBpcFtAssist) return;
  window.__quaxBpcFtAssist = true;

  function isFt() {
    var host = (location.hostname || '').replace(/^www\./, '');
    return host === 'ft.com' || host.endsWith('.ft.com');
  }

  function isBlocked() {
    if ((document.title || '') === 'Security Verification') return true;
    if (document.querySelector('div.cloudflare-wrapper')) return true;
    return !!document.querySelector('div#barrier-page');
  }

  function hasArticle() {
    return !!(
      document.querySelector('div[style*="article-body"]') ||
      document.querySelector('article#site-content div.article__content-body')
    );
  }

  function run() {
    if (!isFt() || !isBlocked() || hasArticle()) return;
    if (typeof getArchive !== 'function') return;
    if (window.__quaxBpcFtAssistRan) return;
    window.__quaxBpcFtAssistRan = true;

    var barrier = document.querySelector('div#barrier-page');
    if (!barrier && document.body) {
      barrier = document.createElement('div');
      barrier.id = 'barrier-page';
      barrier.style.display = 'none';
      document.body.appendChild(barrier);
    }

    var url = location.href;
    // Same selectors as contentScript_en.js for ft.com.
    getArchive(
      url,
      'div#barrier-page',
      '',
      'div.n-layout__row--content',
      '',
      'div[style*="article-body"]',
      'body'
    );
  }

  setTimeout(run, 1200);
  setTimeout(run, 2800);
  setTimeout(run, 5000);
})();
