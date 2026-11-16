import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'foodz-rules-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

// ---------- helpers ----------
const as = (uid, claims = {}) =>
  env
    .authenticatedContext(uid, { email: `${uid}@foodz.test`, email_verified: true, ...claims })
    .firestore();
const guest = () => env.unauthenticatedContext().firestore();

const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

const seedUser = (uid, role = 'client', extra = {}) =>
  seed(`users/${uid}`, {
    name: 'Amine Benali',
    phone: '0555123456',
    email: `${uid}@foodz.test`,
    role,
    blocked: false,
    locale: 'fr',
    termsVersion: '1.0',
    ...extra,
  });

const newProfile = (uid, over = {}) => ({
  name: 'Samira Haddad',
  phone: '0661234567',
  email: `${uid}@foodz.test`,
  role: 'client',
  blocked: false,
  locale: 'ar',
  termsVersion: '1.0',
  termsAcceptedAt: serverTimestamp(),
  createdAt: serverTimestamp(),
  ...over,
});

const newOrder = (uid) => ({
  clientUid: uid,
  code: 'A7K2',
  status: 'placed',
  items: [{ dishId: 'chakhchoukha', name: 'Chakhchoukha', qty: 2, unitPrice: 900 }],
  subtotal: 1800,
  deliveryFee: 200,
  total: 2000,
  area: 'Bab Ezzouar',
  note: '',
  createdAt: serverTimestamp(),
  confirmedAt: null,
  confirmedBy: null,
  prepMinutes: null,
  readyAt: null,
  courierUid: null,
  rejectReason: null,
  updatedAt: serverTimestamp(),
});

const contact = { name: 'Samira Haddad', phone: '0661234567', address: '12 Rue Didouche Mourad, Alger' };

const placeOrder = (db, uid, id) => {
  const b = writeBatch(db);
  b.set(doc(db, `orders/${id}`), newOrder(uid));
  b.set(doc(db, `orders/${id}/private/contact`), contact);
  b.set(doc(db, `placedLocks/${uid}`), { orderId: id });
  return b.commit();
};

// Puts an order directly in the database (rules disabled) in a given state.
const seedOrder = (id, uid, status, extra = {}) =>
  seed(`orders/${id}`, {
    clientUid: uid,
    code: 'A7K2',
    status,
    items: [{ dishId: 'chakhchoukha', name: 'Chakhchoukha', qty: 1, unitPrice: 900 }],
    subtotal: 900,
    deliveryFee: 200,
    total: 1100,
    area: 'Bab Ezzouar',
    note: '',
    confirmedAt: null,
    confirmedBy: null,
    prepMinutes: null,
    readyAt: null,
    courierUid: null,
    rejectReason: null,
    ...extra,
  });

// ---------- public data ----------
test('guests can read menu and restaurant settings but not users', async () => {
  await seed('dishes/d1', { name: { ar: 'شخشوخة', fr: 'Chakhchoukha', en: 'Chakhchoukha' }, price: 900 });
  await seed('settings/app', { restaurantName: 'Foodz' });
  await assertSucceeds(getDoc(doc(guest(), 'dishes/d1')));
  await assertSucceeds(getDoc(doc(guest(), 'settings/app')));
  await seedUser('u1');
  await assertFails(getDoc(doc(guest(), 'users/u1')));
});

test('only admins can write dishes', async () => {
  await seedUser('cli');
  await seedUser('adm', 'admin');
  const dish = () => ({
    name: { ar: 'شخشوخة', fr: 'Chakhchoukha', en: 'Chakhchoukha' },
    price: 900,
    categoryId: 'plats',
    available: true,
    updatedAt: serverTimestamp(),
  });
  await assertFails(setDoc(doc(as('cli'), 'dishes/d1'), dish()));
  await assertSucceeds(setDoc(doc(as('adm'), 'dishes/d1'), dish()));
});

// ---------- profiles and roles ----------
test('user creates own client profile only', async () => {
  await assertSucceeds(setDoc(doc(as('u1'), 'users/u1'), newProfile('u1')));
  await assertFails(setDoc(doc(as('u2'), 'users/u2'), newProfile('u2', { role: 'owner' })));
  await assertFails(setDoc(doc(as('u3'), 'users/u4'), newProfile('u4')));
  await assertFails(setDoc(doc(as('u5'), 'users/u5'), newProfile('u5', { phone: '12345' })));
});

test('user A cannot read user B', async () => {
  await seedUser('a');
  await seedUser('b');
  await assertSucceeds(getDoc(doc(as('a'), 'users/a')));
  await assertFails(getDoc(doc(as('a'), 'users/b')));
});

test('a user cannot make themselves admin', async () => {
  await seedUser('a');
  await assertFails(updateDoc(doc(as('a'), 'users/a'), { role: 'admin' }));
  await assertSucceeds(updateDoc(doc(as('a'), 'users/a'), { name: 'Amine B.' }));
});

test('owner promotes staff, but never creates a second owner; admin cannot promote', async () => {
  await seedUser('own', 'owner');
  await seedUser('adm', 'admin');
  await seedUser('cook');
  await assertSucceeds(updateDoc(doc(as('own'), 'users/cook'), { role: 'chef' }));
  await assertFails(updateDoc(doc(as('own'), 'users/cook'), { role: 'owner' }));
  await assertFails(updateDoc(doc(as('adm'), 'users/cook'), { role: 'delivery' }));
});

test('staff powers need a verified email', async () => {
  await seedUser('own', 'owner');
  await seedUser('cook');
  const unverified = as('own', { email_verified: false });
  await assertFails(updateDoc(doc(unverified, 'users/cook'), { role: 'chef' }));
});

// ---------- orders ----------
test('client places one order; a second unconfirmed order is refused', async () => {
  await seedUser('cli');
  const db = as('cli');
  await assertSucceeds(placeOrder(db, 'cli', 'o1'));
  await assertFails(placeOrder(db, 'cli', 'o2'));
});

test('blocked client cannot place an order', async () => {
  await seedUser('cli', 'client', { blocked: true });
  await assertFails(placeOrder(as('cli'), 'cli', 'o1'));
});

test('client cannot read another client order', async () => {
  await seedUser('a');
  await seedUser('b');
  await seedOrder('o1', 'a', 'placed');
  await assertSucceeds(getDoc(doc(as('a'), 'orders/o1')));
  await assertFails(getDoc(doc(as('b'), 'orders/o1')));
});

test('admin confirms and the lock is released in the same batch', async () => {
  await seedUser('cli');
  await seedUser('adm', 'admin');
  await placeOrder(as('cli'), 'cli', 'o1');
  const db = as('adm');

  const bad = writeBatch(db);
  bad.update(doc(db, 'orders/o1'), {
    status: 'confirmed',
    confirmedAt: serverTimestamp(),
    confirmedBy: 'adm',
    updatedAt: serverTimestamp(),
  });
  await assertFails(bad.commit()); // lock still exists

  const good = writeBatch(db);
  good.update(doc(db, 'orders/o1'), {
    status: 'confirmed',
    confirmedAt: serverTimestamp(),
    confirmedBy: 'adm',
    updatedAt: serverTimestamp(),
  });
  good.delete(doc(db, 'placedLocks/cli'));
  await assertSucceeds(good.commit());
});

test('chef sees confirmed orders but never customer contact details', async () => {
  await seedUser('chef1', 'chef');
  await seedUser('cli');
  await seedOrder('o1', 'cli', 'placed');
  await seedOrder('o2', 'cli', 'confirmed');
  await seed('orders/o2/private/contact', contact);
  const db = as('chef1');
  await assertFails(getDoc(doc(db, 'orders/o1')));
  await assertSucceeds(getDoc(doc(db, 'orders/o2')));
  await assertFails(getDoc(doc(db, 'orders/o2/private/contact')));
});

test('chef moves confirmed -> preparing -> ready', async () => {
  await seedUser('chef1', 'chef');
  await seedOrder('o1', 'cli', 'confirmed');
  const db = as('chef1');
  await assertSucceeds(
    updateDoc(doc(db, 'orders/o1'), { status: 'preparing', prepMinutes: 20, updatedAt: serverTimestamp() }),
  );
  await assertSucceeds(
    updateDoc(doc(db, 'orders/o1'), { status: 'ready', readyAt: serverTimestamp(), updatedAt: serverTimestamp() }),
  );
});

test('courier reads contact only after claiming the order', async () => {
  await seedUser('cour', 'delivery');
  await seedUser('cli');
  await seedOrder('o1', 'cli', 'ready');
  await seed('orders/o1/private/contact', contact);
  const db = as('cour');
  await assertFails(getDoc(doc(db, 'orders/o1/private/contact')));
  await assertSucceeds(
    updateDoc(doc(db, 'orders/o1'), { status: 'out_for_delivery', courierUid: 'cour', updatedAt: serverTimestamp() }),
  );
  await assertSucceeds(getDoc(doc(db, 'orders/o1/private/contact')));
});

test('courier cannot confirm an order', async () => {
  await seedUser('cour', 'delivery');
  await seedOrder('o1', 'cli', 'placed');
  await assertFails(
    updateDoc(doc(as('cour'), 'orders/o1'), {
      status: 'confirmed',
      confirmedAt: serverTimestamp(),
      confirmedBy: 'cour',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('customer can erase contact details only once the order is finished', async () => {
  await seedUser('cli');
  await seedOrder('active', 'cli', 'out_for_delivery');
  await seedOrder('done', 'cli', 'delivered');
  await seed('orders/active/private/contact', contact);
  await seed('orders/done/private/contact', contact);
  const db = as('cli');
  await assertFails(deleteDoc(doc(db, 'orders/active/private/contact')));
  await assertSucceeds(deleteDoc(doc(db, 'orders/done/private/contact')));
});
