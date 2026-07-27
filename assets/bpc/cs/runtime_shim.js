// Shim chrome.runtime so BPC contentScript.js + cs_local can run in QuaX's
// WebView. The Flutter side delivers bg2csData via __bpcDeliver and answers
// sendMessage requests through the bpcRuntime JavaScript handler.
(function () {
  if (window.__quaxBpcShim) return;
  window.__quaxBpcShim = true;

  var listeners = [];
  var runtime = {
    getManifest: function () {
      return { key: 'quax-bpc', version: '4.4.0.0', manifest_version: 3 };
    },
    onMessage: {
      addListener: function (fn) {
        if (typeof fn === 'function') listeners.push(fn);
      },
      removeListener: function (fn) {
        listeners = listeners.filter(function (x) { return x !== fn; });
      }
    },
    sendMessage: function (msg) {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('bpcRuntime', msg);
        }
      } catch (_) {}
      return Promise.resolve();
    },
    lastError: null
  };

  window.chrome = window.chrome || {};
  window.chrome.runtime = runtime;
  window.browser = window.chrome;

  window.__bpcDeliver = function (request) {
    listeners.slice().forEach(function (fn) {
      try { fn(request, {}); } catch (err) { console.log(err); }
    });
  };
})();
