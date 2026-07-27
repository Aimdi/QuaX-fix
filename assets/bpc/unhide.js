// Generic paywall unhide, injected at document end by the in-app BPC engine.
// Not a port of every site-specific content script — those need chrome.runtime
// messaging. This covers the common overlay / overflow / blur patterns and AMP
// subscription hides that many BPC rules rely on after scripts are blocked.
(function () {
  if (window.__quaxBpcUnhide) return;
  window.__quaxBpcUnhide = true;

  var SELECTORS = [
    '[class*="paywall"]',
    '[class*="Paywall"]',
    '[id*="paywall"]',
    '[class*="piano-"]',
    '[id*="piano-"]',
    '[class*="tp-modal"]',
    '[class*="tp-backdrop"]',
    '.fc-ab-root',
    '.fc-dialog-container',
    '[class*="regwall"]',
    '[class*="subscribe-wall"]',
    '[class*="subscription-wall"]',
    '[class*="gateway-content"]',
    '[data-testid*="paywall"]',
    'div[class*="Overlay"][class*="Persistent"]'
  ];

  function hide(el) {
    try {
      el.style.setProperty('display', 'none', 'important');
      el.setAttribute('hidden', 'true');
    } catch (_) {}
  }

  function unhideArticle() {
    SELECTORS.forEach(function (sel) {
      document.querySelectorAll(sel).forEach(hide);
    });

    ['overflow', 'position'].forEach(function (prop) {
      try {
        document.documentElement.style.setProperty(prop, 'visible', 'important');
        document.body.style.setProperty(prop, 'visible', 'important');
      } catch (_) {}
    });
    try {
      document.documentElement.style.setProperty('height', 'auto', 'important');
      document.body.style.setProperty('height', 'auto', 'important');
      document.documentElement.style.setProperty('filter', 'none', 'important');
      document.body.style.setProperty('filter', 'none', 'important');
    } catch (_) {}

    document.querySelectorAll('[style*="blur"], [class*="blur"]').forEach(function (el) {
      try {
        el.style.setProperty('filter', 'none', 'important');
      } catch (_) {}
    });

    // AMP subscription / access hides
    document.querySelectorAll('[amp-access][amp-access-hide], [subscriptions-section="content"][hidden]').forEach(function (el) {
      el.removeAttribute('amp-access-hide');
      el.removeAttribute('hidden');
      try { el.style.setProperty('display', 'block', 'important'); } catch (_) {}
    });
    document.querySelectorAll('div[subscriptions-dialog], div[amp-access="NOT subscribed"]').forEach(hide);
  }

  unhideArticle();
  var obs = new MutationObserver(function () { unhideArticle(); });
  if (document.documentElement) {
    obs.observe(document.documentElement, { childList: true, subtree: true });
  }
  setTimeout(unhideArticle, 500);
  setTimeout(unhideArticle, 1500);
  setTimeout(unhideArticle, 3000);
})();
