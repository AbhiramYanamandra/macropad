const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('configurator/index.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1].replace('initState(); bindGlobal(); renderAll(); renderLog();', '');
for (const path of process.argv.slice(2)) {
  const original = JSON.parse(fs.readFileSync(path, 'utf8'));
  const input = JSON.parse(JSON.stringify(original));
  const context = vm.createContext({ input,
    document: {createElement: () => ({getContext: () => ({})})},
    localStorage: {getItem: () => null, setItem: () => {}}, setTimeout: () => 0, clearTimeout: () => {}
  });
  vm.runInContext(script, context);
  const loaded = vm.runInContext('S.cfg = normalize(input); JSON.stringify(S.cfg)', context);
  assert.deepEqual(JSON.parse(loaded), original, 'Browser import changed the native-written keymap');
  console.log('Browser normalizer imports native output unchanged:', path);
}
