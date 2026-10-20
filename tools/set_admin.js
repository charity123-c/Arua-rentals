#!/usr/bin/env node
'use strict';

const path = require('node:path');
const { cert, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

async function main() {
  const email = process.argv[2]?.trim();
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Usage: node tools/set_admin.js <admin-email>');
  }
  if (!credentialsPath) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to the service-account JSON path.',
    );
  }

  initializeApp({
    credential: cert(require(path.resolve(credentialsPath))),
  });

  const auth = getAuth();
  const firestore = getFirestore();
  const user = await auth.getUserByEmail(email);

  const profileRef = firestore.collection('users').doc(user.uid);
  const existing = await profileRef.get();
  const profile = {
    name: existing.get('name') || user.displayName || email.split('@')[0],
    email: user.email || email,
    phone: existing.get('phone') || '',
    role: 'admin',
    roleRequest: FieldValue.delete(),
    photoUrl: existing.get('photoUrl') ?? null,
    fcmTokens: existing.get('fcmTokens') || [],
    isVerified: true,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!existing.exists) {
    profile.createdAt = FieldValue.serverTimestamp();
  }
  await profileRef.set(profile, { merge: true });
  await auth.setCustomUserClaims(user.uid, {
    ...user.customClaims,
    admin: true,
  });

  console.log(`Admin access configured for ${user.email} (uid: ${user.uid}).`);
  console.log('The admin custom claim and users profile role are both set.');
}

main().catch((error) => {
  console.error(`Admin bootstrap failed: ${error.message || error}`);
  process.exitCode = 1;
});
