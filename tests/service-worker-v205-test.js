const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const handlers = {}, saved = new Map(), deleted = [];
let network;
const cache = {put: async (key, value) => saved.set(typeof key === 'string' ? key : key.url, value)};
const context = {
  URL, Response,
  fetch: async () => { if (network instanceof Error) throw network; return network; },
  caches: {
    open: async () => cache,
    match: async key => saved.get(typeof key === 'string' ? key : key.url),
    keys: async () => ['unrelated-app', 'interval-cosmos-old', 'interval-cosmos-v2-0-5-alpha10-25'],
    delete: async key => deleted.push(key),
  },
  self: {location: {origin: 'https://example.test', href: 'https://example.test/cosmos/sw.js'},
    addEventListener: (name, handler) => handlers[name] = handler,
    clients: {claim: async () => {}}, skipWaiting: async () => {}},
};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'sw.js'), 'utf8'), context);
async function request(route, response, mode = 'navigate') {
  network = response;
  let result; const pending = [];
  handlers.fetch({request: {method: 'GET', url: `https://example.test/cosmos/${route}`, mode},
    respondWith: value => result = value, waitUntil: value => pending.push(value)});
  const resolved = await result;
  await Promise.all(pending);
  return resolved;
}
(async () => {
  const html = text => new Response(text, {headers: {'content-type': 'text/html'}});
  await request('', html('app'));
  assert.equal(await saved.get('./index.html').clone().text(), 'app');
  await request('missing', new Response('missing', {status: 404}));
  await request('other.html', html('other'));
  await request('', new Response('unavailable', {status: 503}));
  await request('', new Response('{}', {headers: {'content-type': 'application/json'}}));
  assert.equal(await saved.get('./index.html').clone().text(), 'app');
  assert.equal(await (await request('?launch=1', new Error('offline'))).text(), 'app');
  assert.equal((await request('other.html', new Error('offline'))).type, 'error');
  await request('index.html?launch=2', html('updated'));
  assert.equal(await saved.get('./index.html').clone().text(), 'updated');
  await request('app.js?v=2', new Response('bad', {status: 500}), 'cors');
  assert(!saved.has('https://example.test/cosmos/app.js?v=2'));
  await request('app.js', new Response('missing', {status: 404}), 'cors');
  assert(!saved.has('https://example.test/cosmos/app.js'));
  await request('cloud-config.js', new Response('public configuration'), 'cors');
  await request('cloud-config.js', new Response('unavailable', {status:503}), 'cors');
  assert.equal(await (await request('cloud-config.js', new Error('offline'), 'cors')).text(), 'public configuration');
  let activated; handlers.activate({waitUntil: p => activated = p}); await activated;
  assert.deepEqual(deleted, ['interval-cosmos-old', 'interval-cosmos-v2-0-5-alpha10-25']);
  console.log('PASS app-only navigation cache, offline fallback, HTTP errors, and scoped cleanup');
})().catch(error => {console.error(error); process.exitCode = 1;});
