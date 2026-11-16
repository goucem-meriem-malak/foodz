// Creates web/firebase-messaging-sw.js from env.json, so browsers can receive
// push notifications while the tab is closed. The output is git-ignored.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const envPath = new URL('env.json', root);
if (!existsSync(envPath)) {
  console.error('env.json not found. Copy env.example.json to env.json and fill it in first.');
  process.exit(1);
}
if (!existsSync(new URL('web/', root))) {
  console.error('No web/ folder yet. Run the "flutter create" command from SETUP.md first.');
  process.exit(1);
}

const env = JSON.parse(readFileSync(envPath, 'utf8'));
const required = ['FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_APP_ID_WEB'];
const missing = required.filter((k) => !env[k]);
if (missing.length) {
  console.error(`env.json is missing: ${missing.join(', ')}`);
  process.exit(1);
}

const config = {
  apiKey: env.FIREBASE_API_KEY,
  authDomain: env.FIREBASE_AUTH_DOMAIN || `${env.FIREBASE_PROJECT_ID}.firebaseapp.com`,
  projectId: env.FIREBASE_PROJECT_ID,
  messagingSenderId: env.FIREBASE_MESSAGING_SENDER_ID,
  appId: env.FIREBASE_APP_ID_WEB,
};

const sw = `importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
firebase.initializeApp(${JSON.stringify(config)});
firebase.messaging();
`;
writeFileSync(new URL('web/firebase-messaging-sw.js', root), sw);
console.log('Wrote web/firebase-messaging-sw.js');
