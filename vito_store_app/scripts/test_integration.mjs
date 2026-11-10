#!/usr/bin/env node
/**
 * Test de integracion end-to-end de la app Flutter contra el backend real
 * (`vito-api`). Megaplan Fase 0.2.
 *
 * Flujo: health → login → me → productos → detalle → wishlist → carrito →
 * shipping-options → [orden] → history → notificaciones → blog → chatbot anónimo.
 *
 * Salida: PASS/SKIP/FAIL por etapa + exit code 1 si falla algo.
 *
 * Uso:
 *   node scripts/test_integration.mjs
 *   node scripts/test_integration.mjs --skip-order      (sin crear orden real)
 *   VITO_BASE=http://127.0.0.1:3001/api node scripts/test_integration.mjs
 *   VITO_EMAIL=... VITO_PASSWORD=... node scripts/test_integration.mjs
 *
 * Notas:
 * - Si el login pide código 2FA (`requiresLoginCode`), el script emite un token
 *   JWT equivalente vía `docker exec -i vito-api node -` (jsonwebtoken firmado
 *   con JWT_SECRET del contenedor, authVersion leida de la BD).
 * - La etapa de orden crea una orden REAL en la BD de pruebas: usa --skip-order
 *   para omitirla.
 */

import { spawnSync } from 'node:child_process';

const BASE = (process.env.VITO_BASE || 'http://127.0.0.1:3001/api').replace(/\/+$/, '');
const EMAIL = process.env.VITO_EMAIL || 'app-integration-test@vitotest.com';
const PASSWORD = process.env.VITO_PASSWORD || 'TestApp1234!';
const USER_ID = process.env.VITO_USER_ID || 'cmw78oy0u002b13v4425j1d7i';
const SKIP_ORDER = process.argv.includes('--skip-order');
const TIMEOUT_MS = 15_000;

/** @type {{name: string, status: 'PASS'|'FAIL'|'SKIP', detail?: string}[]} */
const results = [];
let token = null;

function record(name, status, detail) {
  results.push({ name, status, detail });
  const icon = status === 'PASS' ? '✓' : status === 'FAIL' ? '✗' : '–';
  console.log(`${icon} [${status}] ${name}${detail ? ` — ${detail}` : ''}`);
}

/** fetch con timeout; devuelve {status, ok, data} */
async function call(method, path, { token: bearer, body } = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const resp = await fetch(`${BASE}${path}`, {
      method,
      signal: ctrl.signal,
      headers: {
        'Content-Type': 'application/json',
        ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    let data = null;
    try { data = await resp.json(); } catch { /* vacío */ }
    return { status: resp.status, ok: resp.ok, data };
  } finally {
    clearTimeout(t);
  }
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

/** Emite un token válido vía docker exec (fallback si el login pide 2FA). */
function mintTokenViaDocker() {
  // Consulta authVersion real del usuario para que el JWT pase la validacion
  // del backend (sin `authVersion` equivocado responden 401).
  const script = `
    (async () => {
      const jwt = require('jsonwebtoken');
      const { PrismaClient } = require('@prisma/client');
      const prisma = new PrismaClient();
      const user = await prisma.user.findUnique({
        where: { email: ${JSON.stringify(EMAIL)} },
        select: { id: true, authVersion: true },
      });
      await prisma.$disconnect();
      if (!user) { console.error('USER_NOT_FOUND'); process.exit(1); }
      const token = jwt.sign(
        { userId: user.id, email: ${JSON.stringify(EMAIL)}, role: 'USER', authVersion: user.authVersion ?? 0 },
        process.env.JWT_SECRET,
        { expiresIn: '2h', issuer: 'vito-api', audience: 'vito-api', algorithm: 'HS256' }
      );
      console.log(token);
    })().catch((e) => { console.error(e.message || String(e)); process.exit(1); });
  `;
  const res = spawnSync('docker', ['exec', '-i', 'vito-api', 'node', '-'], {
    input: script,
    encoding: 'utf8',
    timeout: 30_000,
  });
  const out = `${(res.stdout || '').trim()}`;
  if (res.status !== 0 || !out || out.includes('\n')) {
    throw new Error(
      `docker mint falló (exit ${res.status}): ${(res.stderr || '(sin stderr)').trim()}`,
    );
  }
  return out;
}

// ================================================================
// Etapas del test
// ================================================================

async function stageHealth() {
  const r = await call('GET', '/health');
  const maint = r.data?.data?.maintenance;
  assert(r.ok && r.data, `GET /health ${r.status}`);
  assert(maint && typeof maint.active === 'boolean', 'health sin data.maintenance.active');
  record('health (publico)', 'PASS', `maintenance.active=${maint.active}`);
}

async function stageMe() {
  const r = await call('GET', '/account/me', { token });
  assert(r.ok && r.data?.id, `GET /account/me ${r.status} ${r.data?.error ?? ''}`);
  assert(r.data.email === EMAIL, `perfil de otro usuario: ${r.data.email}`);
  record('account/me (objeto directo, sin wrapper)', 'PASS', `${r.data.email}`);
}

async function stageProducts() {
  const list = await call('GET', '/products?take=5&skip=0');
  // Contrato: {success, data:{products, total}} o data directa; tolerar ambas.
  const inner = list.data?.data ?? list.data;
  const products = inner?.products ?? inner?.items;
  assert(list.ok && Array.isArray(products) && products.length > 0,
    `GET /products ${list.status} sin items`);
  const [first] = products;
  const id = first.id;
  assert(typeof id === 'string' && id.length > 0, 'producto sin id');
  const detail = await call('GET', `/products/${id}`);
  const dInner = detail.data?.data ?? detail.data;
  assert(detail.ok && dInner?.id === id, `GET /products/:id ${detail.status}`);

  // Conteos por categoria (los ids estáticos de la app DEBEN filtrar).
  const counts = await call('GET', '/products/counts');
  assert(counts.ok, `GET /products/counts ${counts.status}`);
  record('products + detail + counts', 'PASS',
    `total=${inner?.total ?? '?'}, first=${id}, counts ok`);
  return id;
}

async function stageWishlist(productId) {
  const add = await call('POST', '/wishlist', { token, body: { productId } });
  assert(add.status === 201 && add.data?.success, `POST /wishlist ${add.status} ${add.data?.error ?? ''}`);
  const list = await call('GET', '/wishlist', { token });
  const items = list.data?.data;
  assert(list.ok && Array.isArray(items), `GET /wishlist ${list.status}`);
  assert(items.some((i) => i.productId === productId), ' itemId no aparece en GET /wishlist');
  const del = await call('DELETE', `/wishlist/${productId}`, { token });
  assert(del.ok, `DELETE /wishlist/:productId ${del.status}`);
  record('wishlist add→list→remove', 'PASS', `productId=${productId}`);
}

async function stageCart() {
  // Producto barato para no inflar el total (el backend recalcula).
  const list = await call('GET', '/products?take=20&skip=0');
  const inner = list.data?.data ?? list.data;
  const products = inner?.products ?? [];
  const sorted = [...products].sort((a, b) => {
    const pa = Number(a.price ?? a.pricing?.price ?? 1e9);
    const pb = Number(b.price ?? b.pricing?.price ?? 1e9);
    return (isFinite(pa) ? pa : 1e9) - (isFinite(pb) ? pb : 1e9);
  });
  const target = sorted[0] ?? null;
  assert(target?.id, 'no hay productos elegibles para carrito');
  const add = await call('POST', '/cart/items', { token, body: { productId: target.id, quantity: 1 } });
  assert(add.ok, `POST /cart/items ${add.status} ${add.data?.error ?? ''}`);
  const get = await call('GET', '/cart', { token });
  // Contrato real: {cart:{items:[...]}, totals} sin wrapper success/data.
  const cart = get.data?.cart;
  const items = cart?.items ?? [];
  assert(get.ok && Array.isArray(items) && items.length > 0,
    `GET /cart ${get.status} sin items (${JSON.stringify(get.data).slice(0, 160)})`);
  assert(
    items.some((i) => i.productId === target.id),
    `el item ${target.id} no esta en el carrito`,
  );
  record('cart add→get', 'PASS', `productId=${target.id} items=${items.length}`);
  return target.id;
}

const SHIPPING_MEX = {
  recipient: 'Test App',
  phone: '8111163774',
  street: 'Av. Test',
  exteriorNumber: '100',
  neighborhood: 'Centro',
  city: 'Monterrey',
  state: 'Nuevo Leon',
  postalCode: '64000',
  country: 'MEX', // contrato: hasta 3 chars, uppercase === 'MEX' y CP de 5 digitos
};

async function stageShipping() {
  const r = await call('POST', '/orders/shipping-options', {
    token,
    body: { shippingDetails: SHIPPING_MEX },
  });
  const inner = r.data?.data ?? r.data;
  assert(r.ok && inner && Array.isArray(inner.options),
    `POST /orders/shipping-options ${r.status} ${r.data?.error ?? ''}`);
  const pick = inner.options[0];
  record('shipping-options', 'PASS',
    `requiresSelection=${inner.requiresSelection}, options=${inner.options.length}`);
  return pick?.quoteToken ?? null;
}

async function stageOrder(quoteToken) {
  const details = SHIPPING_MEX;
  const address = `${details.street} ${details.exteriorNumber}, ${details.neighborhood}, ${details.city}, ${details.state}, CP ${details.postalCode}, Mexico`;
  const body = {
    shippingAddress: address,
    billingAddress: address,
    shippingDetails: details,
    ...(quoteToken ? { shippingQuoteToken: quoteToken } : {}),
  };
  const r = await call('POST', '/orders', { token, body });
  // 201 {success, data:{order}}
  const order = r.data?.data?.order ?? r.data?.order;
  assert(r.ok && order?.id, `POST /orders ${r.status} ${r.data?.error ?? ''} ${JSON.stringify(r.data).slice(0, 300)}`);
  record('order create (real, BD de pruebas)', 'PASS', `order=${order.orderNumber ?? order.id}, total=${order.total ?? '?'}`);
}

async function stageHistory() {
  const r = await call('GET', '/history', { token });
  const inner = r.data?.data ?? r.data ?? {};
  assert(r.ok && inner && typeof inner === 'object', `GET /history ${r.status}`);
  const hasLists = ['orders', 'serviceRequests', 'specializedQuotes', 'invoiceRequests']
    .every((k) => Array.isArray(inner[k]));
  assert(hasLists, `GET /history sin las 4 listas: ${Object.keys(inner).join(',')}`);
  record('history unificado (4 listas + summary)', 'PASS',
    `orders=${inner.orders.length}, quotes=${inner.specializedQuotes.length}`);
}

async function stageNotifications() {
  const list = await call('GET', '/notifications', { token });
  assert(list.ok, `GET /notifications ${list.status}`);
  const unread = await call('GET', '/notifications/unread-count', { token });
  assert(unread.ok, `GET /notifications/unread-count ${unread.status}`);
  record('notifications + unread-count', 'PASS');
}

async function stageBlog() {
  const posts = await call('GET', '/blog/posts?page=1&limit=2');
  // Sin wrapper: {posts, pagination}
  assert(posts.ok && Array.isArray(posts.data?.posts),
    `GET /blog/posts ${posts.status} (${JSON.stringify(posts.data).slice(0, 120)})`);
  const cats = await call('GET', '/blog/categories');
  assert(cats.ok && Array.isArray(cats.data), `GET /blog/categories ${cats.status}`);
  record('blog posts + categories (sin wrapper)', 'PASS',
    `posts=${posts.data.posts.length}, total=${posts.data.pagination?.total}, cats=${cats.data.length}`);
}

async function stageChatbotAnon() {
  const r = await call('POST', '/chatbot/assistant/app-query', {
    body: { sessionId: 'integration-test', message: 'Hola, que servicios ofrecen?' },
  });
  const reply = r.data?.data ?? r.data;
  assert(r.ok && reply && (reply.reply || reply.answer || reply.message),
    `POST /chatbot/assistant/app-query ${r.status} ${JSON.stringify(r.data).slice(0, 160)}`);
  record('chatbot anonimo app-query (publico por IP)', 'PASS');
}

// ================================================================

async function main() {
  console.log(`Base: ${BASE}`);
  console.log(''.padEnd(74, '='));

  const run = async (name, fn) => {
    try {
      await fn();
    } catch (e) {
      record(name, 'FAIL', e.message.slice(0, 240));
    }
  };

  await run('health (publico)', stageHealth);
  if (!token) {
    try {
      const r = await call('POST', '/account/login', { body: { email: EMAIL, password: PASSWORD } });
      if (r.data?.requiresLoginCode === true) {
        token = mintTokenViaDocker();
        record('login (2FA requerido, token via docker exec)', 'PASS', 'token de 2h creado');
      } else {
        assert(r.ok && r.data?.tokens?.accessToken, `POST /account/login ${r.status} ${r.data?.error ?? ''}`);
        token = r.data.tokens.accessToken;
        record('login', 'PASS', 'accesToken');
      }
    } catch (e) {
      record('login', 'FAIL', e.message.slice(0, 240));
    }
  }

  if (!token) {
    record('token', 'FAIL', 'Sin token: las etapas privadas no corren');
  } else {
    let productId = null;
    let quoteToken = null;
    await run('account/me', stageMe);
    await run('products + detail + counts', async () => { productId = await stageProducts(); });
    if (productId) await run('wishlist add→list→remove', () => stageWishlist(productId));
    await run('cart add→get', stageCart);
    await run('shipping-options', async () => { quoteToken = await stageShipping(); });
    if (SKIP_ORDER) {
      record('order create (real, BD de pruebas)', 'SKIP', '--skip-order');
    } else {
      await run('order create (real, BD de pruebas)', () => stageOrder(quoteToken));
    }
    await run('history unificado', stageHistory);
    await run('notifications + unread-count', stageNotifications);
  }

  await run('blog posts + categories', stageBlog);
  await run('chatbot anonimo app-query', stageChatbotAnon);

  console.log(''.padEnd(74, '='));
  const pass = results.filter((r) => r.status === 'PASS').length;
  const fail = results.filter((r) => r.status === 'FAIL').length;
  const skip = results.filter((r) => r.status === 'SKIP').length;
  console.log(`Resultado: ${pass} PASS · ${fail} FAIL · ${skip} SKIP`);
  const failed = results.filter((r) => r.status === 'FAIL');
  if (failed.length > 0) {
    console.log('Fallos:');
    for (const f of failed) console.log(`  - ${f.name}: ${f.detail ?? ''}`);
  }
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('Error inesperado del runner:', e);
  process.exit(1);
});
