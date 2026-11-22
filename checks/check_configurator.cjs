// Logic checks for the actual app script, with DOM rendering stubbed out.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('configurator/index.html', 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1]
  .replace('initState(); bindGlobal(); renderAll(); renderLog();', '');
const elements = new Map();
function element(selector) {
  if (!elements.has(selector)) elements.set(selector, {
    innerHTML: '', textContent: '',
    querySelectorAll: () => [],
    querySelector: element,
  });
  return elements.get(selector);
}
const context = vm.createContext({
  assert, input: JSON.parse(fs.readFileSync('keymap.json', 'utf8')),
  document: {querySelector: element, createElement: () => ({getContext: () => ({})})},
  localStorage: {getItem: () => null, setItem: () => {}},
  setTimeout: () => 0, clearTimeout: () => {},
});
vm.runInContext(script, context);
vm.runInContext(`
  renderAll = renderDevice = renderLists = renderInspector = renderHeader = renderLog = () => {};
  initState();
  assert.equal(S.cfg.settings.knob, false);
  assert.ok(S.cfg.combos.some(c => c.keys.join(',')==='6,8'));
  S.cfg = normalize(input);
  openSettings();
  assert.ok($('#modalRoot').innerHTML.includes('Knob fitted'));
  assert.ok(!$('#modalRoot').innerHTML.match(/id="sknob" checked/));
  $('#sknob').onchange({target:{checked:true}});
  assert.equal(S.cfg.settings.knob, true);
  $('#sknob').onchange({target:{checked:false}});
  S.mode = 'try';
  for (const expected of [1,2,0,1,2,0]) {
    simDown(6, true); simDown(8, true); evalCombos(); simUp(6); simUp(8);
    assert.equal(activeLayer(), expected);
  }
  assert.equal(S.log.filter(l => l.src==='Combo 7+9').length, 6);
  for (const position of [6,8]) {
    const before = S.log.length;
    simDown(position, true); simUp(position);
    assert.equal(S.log.length, before+1);
    assert.equal(S.log[0].src, 'Key '+(position+1));
  }
  simDown(0, true); simDown(2, true); evalCombos(); simUp(0); simUp(2);
  assert.equal(S.log[0].src, 'Combo 1+3');
  assert.equal(S.cfg.combos[0].action.label, 'LOCK');
  encoder('press'); assert.equal(activeLayer(), 0);
  S.cfg.settings.knob=true;
  encoder('cw'); // non-layer encoder action
  assert.equal(activeLayer(), 0);
  S.cfg.settings.knob=false;
  fire({type:'layer', mode:'to', layer:'prev'}, 'test');
  assert.equal(activeLayer(), 2);
  fire({type:'layer', mode:'to', layer:'next'}, 'test');
  assert.equal(activeLayer(), 0);
  const saved = JSON.parse(configJSON());
  assert.equal(saved.settings.knob, false);
  assert.ok(saved.combos.some(c => c.keys.join(',')==='6,8' && c.action.layer==='next'));
  const legacy = clone(input); delete legacy.settings.knob;
  legacy.combos = []; assert.equal(normalize(legacy).settings.knob, false);
  assert.ok(legacy.combos.some(c => c.keys.join(',')==='6,8'));
`, context);
console.log('configurator defaults, toggle, combo cycling, single keys and export: ok (DOM rendering stubbed)');
