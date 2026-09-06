// Bridges the MAIN-world inject.js (no extension API access) to the
// background script (has nativeMessaging access) and back again.
window.addEventListener("message", (event) => {
  if (event.source !== window) return;
  const data = event.data;
  if (!data || !data.__camguardRequest) return;

  chrome.runtime.sendMessage({ type: "camera-check", url: data.url }, (response) => {
    window.postMessage(
      { __camguardReply: data.__camguardRequest, allow: response ? response.allow : true },
      "*"
    );
  });
});

// Let the background script know when this page goes away, so the "in use"
// status shown in the Omarchy panel doesn't get stuck on.
window.addEventListener("pagehide", () => {
  chrome.runtime.sendMessage({ type: "camera-stopped" });
});
