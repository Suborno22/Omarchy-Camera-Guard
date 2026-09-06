// Runs in the page's own JS world, before the page's own scripts, so we can
// wrap getUserMedia before anything else calls it. Can't use chrome.* APIs
// here directly (MAIN world has no extension access) — talks to content.js
// over window.postMessage instead.
(function () {
  const md = navigator.mediaDevices;
  if (!md || !md.getUserMedia) return;
  const original = md.getUserMedia.bind(md);

  md.getUserMedia = function (constraints) {
    const wantsVideo = !!(constraints && constraints.video);
    if (!wantsVideo) return original(constraints);

    return new Promise((resolve, reject) => {
      const reqId = "camguard-" + Math.random().toString(36).slice(2);

      function onMessage(event) {
        if (event.source !== window) return;
        const data = event.data;
        if (!data || data.__camguardReply !== reqId) return;
        window.removeEventListener("message", onMessage);

        if (data.allow) {
          original(constraints).then(resolve, reject);
        } else {
          reject(new DOMException("Camera blocked by Camera Guard for this site", "NotAllowedError"));
        }
      }

      window.addEventListener("message", onMessage);
      window.postMessage({ __camguardRequest: reqId, url: location.href }, "*");
    });
  };
})();
