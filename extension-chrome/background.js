const NATIVE_HOST = "io.github.suborno251.camera_guard";

let sites = []; // [{site, mode: "allow"|"block"}]
let nativePort = null;
const activeByTab = {};

function connectNative() {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST);
    nativePort.onMessage.addListener((msg) => {
      if (msg.type === "sites") sites = msg.sites || [];
    });
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
    });
    nativePort.postMessage({ type: "get_sites" });
  } catch (e) {
    console.warn("Camera Guard: native host unavailable — install-chrome.sh / install-firefox.sh needs to be run.", e);
  }
}
connectNative();

function hostnameOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch (e) {
    return "";
  }
}

// No rule for a site = allowed by default. A "block" rule wins over nothing;
// an "allow" rule is mostly documentation (default is already allow).
function isAllowed(url) {
  const host = hostnameOf(url);
  const rule = sites.find((s) => host === s.site || host.endsWith("." + s.site));
  return !rule || rule.mode !== "block";
}

function reportActive(tab, url) {
  if (!nativePort) connectNative();
  if (!nativePort || !tab) return;
  nativePort.postMessage({
    type: "camera_active",
    tabId: tab.id,
    url,
    hostname: hostnameOf(url),
    browser: navigator.userAgent.includes("Firefox") ? "firefox" : "chromium",
  });
}

function reportInactive(tabId) {
  if (nativePort) nativePort.postMessage({ type: "camera_inactive", tabId });
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "camera-check") {
    const allow = isAllowed(msg.url);
    if (allow && sender.tab) {
      activeByTab[sender.tab.id] = { url: msg.url, since: Date.now() };
      reportActive(sender.tab, msg.url);
    }
    sendResponse({ allow });
    return true;
  }

  if (msg.type === "camera-stopped" && sender.tab) {
    delete activeByTab[sender.tab.id];
    reportInactive(sender.tab.id);
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  if (activeByTab[tabId]) {
    delete activeByTab[tabId];
    reportInactive(tabId);
  }
});

// Site list is edited from the Omarchy panel, not from the extension, so
// pull the latest copy periodically rather than only once at startup.
setInterval(() => {
  if (nativePort) nativePort.postMessage({ type: "get_sites" });
}, 5000);
