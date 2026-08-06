#!/run/current-system/sw/bin/node
// Headless-chromium test of the Apricots WASM build via CDP.
// Starts chromium with a remote debugging port, connects, loads the page,
// clicks "Start", waits, and reports console messages + a screenshot.
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');

const HTML_PATH = path.join(__dirname, 'apricots.html');
const SHOT_PATH = path.join(__dirname, 'screenshot.png');

function get(host, port, endpoint) {
  return new Promise((resolve, reject) => {
    http.get({ host, port, path: endpoint }, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => {
        try { resolve(JSON.parse(d)); } catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

function jsonRpc(ws, method, params = {}) {
  const id = Math.floor(Math.random() * 1e9);
  return new Promise((resolve, reject) => {
    const onMsg = (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id === id) { ws.removeEventListener('message', onMsg); resolve(m); }
    };
    ws.addEventListener('message', onMsg);
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => reject(new Error('timeout on ' + method)), 30000);
  });
}

async function main() {
  const chrome = spawn('chromium', [
    '--headless=new',
    '--no-sandbox',
    '--disable-gpu',
    '--remote-debugging-port=0',
    '--user-data-dir=' + path.join('/tmp', 'chr-' + Date.now()),
    '--autoplay-policy=no-user-gesture-required',
    'about:blank',
  ]);
  const devWsUrl = await new Promise((resolve, reject) => {
    chrome.stderr.on('data', (d) => {
      const m = String(d).match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (m) resolve(m[1]);
    });
    chrome.on('exit', (c) => reject(new Error('chromium exited: ' + c)));
    setTimeout(() => reject(new Error('timed out waiting for devtools')), 20000);
  });

  // Connect to the page target (browser-level ws doesn't support Page.* domains)
  let pageWsUrl = devWsUrl;
  {
    const parsed = new URL(devWsUrl);
    const devtoolsHttp = parsed.protocol === 'ws:' ? 'http://' + parsed.host : 'https://' + parsed.host;
    for (let i = 0; i < 50; i++) {
      try {
        const list = await get(parsed.hostname, +parsed.port, '/json/list');
        const page = list.find((t) => t.type === 'page');
        if (page && page.webSocketDebuggerUrl) { pageWsUrl = page.webSocketDebuggerUrl; break; }
      } catch (e) { /* retry */ }
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  console.log('Connecting page ws:', pageWsUrl);
  const ws = new WebSocket(pageWsUrl);
  await new Promise((res) => (ws.onopen = res));

  const consoleErrs = [];
  ws.addEventListener('message', (ev) => {
    const m = JSON.parse(ev.data);
    if (m.method === 'Runtime.consoleAPICalled') {
      const t = m.params.type;
      const text = (m.params.args || []).map((a) => a.value ?? a.description ?? '').join(' ');
      if (['error', 'warning', 'assert'].includes(t)) consoleErrs.push(t + ': ' + text);
    }
    if (m.method === 'Runtime.exceptionThrown') {
      consoleErrs.push('EXCEPTION: ' + JSON.stringify(m.params.exceptionDetails));
    }
    if (m.method === 'Log.entryAdded') {
      const e = m.params.entry;
      if (e.level === 'error') consoleErrs.push('LOG: ' + e.text);
    }
  });

  await jsonRpc(ws, 'Page.enable');
  await jsonRpc(ws, 'Runtime.enable');
  await jsonRpc(ws, 'Log.enable');
  await jsonRpc(ws, 'Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
  await jsonRpc(ws, 'Page.navigate', { url: 'file://' + HTML_PATH });
  await new Promise((res) => setTimeout(res, 3000));

  // Click Start
  await jsonRpc(ws, 'Runtime.evaluate', {
    expression: `document.getElementById('startbtn').click()`,
  });
  await new Promise((res) => setTimeout(res, 8000));

  // Grab a screenshot of the canvas
  try {
    const shot = await jsonRpc(ws, 'Page.captureScreenshot', { format: 'png' });
    if (shot.result && shot.result.data) {
      fs.writeFileSync(SHOT_PATH, Buffer.from(shot.result.data, 'base64'));
      console.log('Screenshot saved:', SHOT_PATH);
    } else {
      console.log('Screenshot unavailable:', JSON.stringify(shot).slice(0, 200));
    }
  } catch (e) {
    console.log('Screenshot failed (probably main loop busy):', e.message);
  }

  const evalRes = await jsonRpc(ws, 'Runtime.evaluate', {
    expression: `(async () => {
      const mod = window.__apricotsModule;
      let fs = 'no module';
      let wavCheck = '';
      let bufferCheck = '';
      if (mod) {
        try {
          fs = mod.FS.readdir('/share/apricots').filter(f => !['.','..'].includes(f)).join(',');
        } catch (e) { fs = 'FS error: ' + e.message; }
        try {
          const st = mod.FS.stat('/share/apricots/engine.wav');
          wavCheck = 'engine.wav size=' + st.size;
        } catch (e) { wavCheck = 'stat err: ' + e.message; }
      }
      return JSON.stringify({
        title: document.title,
        canvasW: document.getElementById('canvas') ? document.getElementById('canvas').width : -1,
        canvasH: document.getElementById('canvas') ? document.getElementById('canvas').height : -1,
        startHidden: document.getElementById('start').classList.contains('hidden'),
        status: document.getElementById('status').textContent,
        fs: fs,
        wavCheck: wavCheck,
      });
    })()`,
    awaitPromise: true,
    returnByValue: true,
  });

  console.log('Eval:', JSON.stringify(evalRes.result.result.value));
  console.log('Console errors:', JSON.stringify(consoleErrs, null, 2));
  console.log('Screenshot saved:', SHOT_PATH);

  ws.close();
  chrome.kill('SIGKILL');
}

main().catch((e) => { console.error('TEST FAILED:', e); process.exit(1); });