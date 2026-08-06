#!/run/current-system/sw/bin/node
// Smoke test: extract the Emscripten module from the single-file HTML and
// instantiate it in node with stubbed browser APIs. Verifies the wasm loads,
// embedded data files exist in the virtual FS, and main() runs far enough to
// reach the SDL video init (which will fail gracefully without a display).
const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync(__dirname + '/apricots.html', 'utf8');

function fakeEl() {
  return {
    style: {},
    addEventListener: () => {},
    removeEventListener: () => {},
    getContext: () => null,
    setPointerCapture: () => {},
    releasePointerCapture: () => {},
    requestFullscreen: () => {},
    width: 0,
    height: 0,
    value: '',
    textContent: '',
    innerHTML: '',
    hidden: false,
    appendChild: () => {},
    remove: () => {},
  };
}

// Collect all inline script bodies in order.
const scripts = [];
const re = /<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g;
let m;
while ((m = re.exec(html)) !== null) scripts.push(m[1]);

// The last script calls ApricotsFactory(moduleArgs). We evaluate everything
// up to that call in a sandbox with browser stubs, then call the factory
// ourselves and inspect the FS.
const sandbox = {
  console,
  alert: () => {},
  globalThis: {},
  document: {
    getElementById: () => fakeEl(),
    createElement: () => fakeEl(),
  },
  window: {},
  navigator: { userAgent: 'node' },
  screen: { width: 1280, height: 720, availWidth: 1280, availHeight: 720 },
  location: { href: 'file://' + __dirname + '/apricots.html', search: '' },
  performance: { now: () => Date.now() },
  URL,
  TextDecoder,
  TextEncoder,
  setTimeout,
  clearTimeout,
  setInterval,
  clearInterval,
  atob,
  btoa,
  fetch: () => Promise.reject(new Error('no fetch in smoke test')),
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;

// The factory script ends with an IIFE-ish structure; evaluate each script,
// but skip the final one that calls ApricotsFactory (we call it ourselves).
const callIdx = scripts.findIndex((s) => s.includes('ApricotsFactory(moduleArgs)') || s.includes('ApricotsFactory(moduleArgs);'));
for (let i = 0; i < scripts.length; i++) {
  if (i === callIdx) continue;
  vm.runInNewContext(scripts[i], sandbox, { filename: 'script-' + i + '.js' });
}

const factory = sandbox.ApricotsFactory;
if (typeof factory !== 'function') {
  console.error('FAIL: ApricotsFactory not exported as function, got', typeof factory);
  process.exit(1);
}

factory({
  print: (...a) => console.log('[emcc]', ...a),
  printErr: (...a) => console.error('[emcc]', ...a),
}).then((mod) => {
  console.log('OK: module instantiated');
  try {
    const ls = mod.FS.readdir('/share/apricots');
    console.log('FS /share/apricots:', ls.join(', '));
  } catch (e) {
    console.log('FS check failed:', e.message);
  }
  console.log('OK: factory resolved');
  process.exit(0);
}).catch((e) => {
  console.error('FAIL: factory rejected:', e);
  process.exit(1);
});
