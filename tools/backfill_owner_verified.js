#!/usr/bin/env node
'use strict';

const path = require('node:path');
const { cert, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldPath } = require('firebase-admin/firestore');

const PAGE_SIZE = 400;

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  if (args.some((argument) => argument !== '--dry-run') || args.length > 1) {
    throw new Error('Usage: node tools/backfill_owner_verified.js [--dry-run]');
  }

  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialsPath) {
    throw new Error(
      'Set GOOGLE_APPLICATION_CREDENTIALS to the service-account JSON path.',
    );
  }

  initializeApp({
    credential: cert(require(path.resolve(credentialsPath))),
  });

  const firestore = getFirestore();
  const ownerVerification = new Map();
  let lastDocument = null;
  let listingCount = 0;
  let changedCount = 0;
  let unchangedCount = 0;

  while (true) {
    let query = firestore
      .collection('listings')
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDocument) query = query.startAfter(lastDocument);

    const page = await query.get();
    if (page.empty) break;

    const updates = [];
    for (const listing of page.docs) {
      listingCount++;
      const ownerId = listing.get('ownerId');
      if (typeof ownerId !== 'string' || ownerId.length === 0) {
        throw new Error(`Listing ${listing.id} has no valid ownerId.`);
      }

      let verifiedPromise = ownerVerification.get(ownerId);
      if (!verifiedPromise) {
        verifiedPromise = firestore
          .collection('users')
          .doc(ownerId)
          .get()
          .then((profile) => {
            if (!profile.exists) {
              throw new Error(
                `Owner profile users/${ownerId} is missing (listing ${listing.id}).`,
              );
            }
            const value = profile.get('isVerified');
            if (value != null && typeof value !== 'boolean') {
              throw new Error(
                `users/${ownerId}.isVerified must be a boolean.`,
              );
            }
            return value === true;
          });
        ownerVerification.set(ownerId, verifiedPromise);
      }

      const expected = await verifiedPromise;
      if (listing.get('ownerVerified') === expected) {
        unchangedCount++;
      } else {
        changedCount++;
        updates.push({ reference: listing.ref, ownerVerified: expected });
      }
    }

    if (!dryRun && updates.length > 0) {
      const batch = firestore.batch();
      for (const update of updates) {
        batch.update(update.reference, { ownerVerified: update.ownerVerified });
      }
      await batch.commit();
    }

    lastDocument = page.docs[page.docs.length - 1];
    if (page.size < PAGE_SIZE) break;
  }

  console.log(
    `${dryRun ? 'Dry run' : 'Backfill'} complete: ` +
      `${listingCount} listings, ${changedCount} ${dryRun ? 'would change' : 'updated'}, ` +
      `${unchangedCount} unchanged.`,
  );
}

main().catch((error) => {
  console.error(`Owner verification backfill failed: ${error.message || error}`);
  process.exitCode = 1;
});
