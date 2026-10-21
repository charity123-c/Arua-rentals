#!/usr/bin/env node
'use strict';

const path = require('node:path');
const { cert, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');

const DEFAULT_CATEGORIES = ['Rentals', 'Plumbing', 'Electrical', 'Cleaning'];
const DEFAULT_AREAS = [
  'Arua City',
  'Arua Hill',
  'Ayivu',
  'Awindiri',
  'Ediofe',
  'Mvara',
  'Oli',
  'Odravu',
  'Pajulu',
  'River Oli',
  'Senior Quarters',
];
const IMAGE_URLS = [
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=75',
  'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=900&q=75',
];
const SAMPLE_LISTINGS = [
  ['property', 'Family house for rent', 'A spacious family home with a secure compound and reliable water.', 650000, 'month', 3, 2],
  ['property', 'Two-bedroom home near town', 'Well-kept home with a sitting room, kitchen and parking space.', 480000, 'month', 2, 1],
  ['property', 'Affordable single room', 'Clean, private room with electricity and shared water access.', 120000, 'month', 1, 1],
  ['property', 'Modern self-contained unit', 'Private unit with tiled floors, ensuite bathroom and gated entry.', 350000, 'month', 1, 1],
  ['service', 'Plumbing repairs and installation', 'Experienced plumber for leaks, taps, toilets and new installations.', 50000, 'job'],
  ['service', 'Home electrical repairs', 'Safe troubleshooting, wiring repairs and light fitting installation.', 60000, 'job'],
  ['service', 'Reliable home cleaning', 'Detailed one-time or regular cleaning for homes and small offices.', 40000, 'job'],
  ['service', 'Furniture and house moving', 'Careful local moving service for household items within Arua.', 80000, 'job'],
  ['property', 'Bright two-bedroom rental', 'Bright rooms, a practical kitchen and easy access to local shops.', 550000, 'month', 2, 1],
  ['property', 'Private room with ensuite', 'Quiet room with a private bathroom and a lockable entrance.', 220000, 'month', 1, 1],
  ['service', 'Water tank and pipe fitting', 'Installation and repair of household water tanks and pipework.', 70000, 'job'],
  ['service', 'House painting service', 'Interior and exterior painting with careful surface preparation.', 90000, 'job'],
  ['property', 'Large family rental with yard', 'Family-sized home with a spacious yard and room for parking.', 800000, 'month', 4, 2],
  ['service', 'Deep cleaning for move-in', 'Move-in and move-out cleaning for vacant houses and apartments.', 100000, 'job'],
  ['property', 'Simple one-bedroom apartment', 'Convenient apartment with a bedroom, sitting room and kitchen.', 300000, 'month', 1, 1],
];

function generateListingSearchKeywords(title, category, area) {
  const keywords = new Set();
  for (const source of [title, category, area]) {
    for (const rawToken of source.toLowerCase().split(/[^a-z0-9]+/)) {
      const token = rawToken.trim();
      if (!token) continue;
      for (let length = 1; length <= token.length; length += 1) {
        keywords.add(token.substring(0, length));
      }
    }
  }
  return [...keywords].sort();
}

function configuredLabels(document, fallback) {
  const items = document?.items;
  if (!Array.isArray(items)) return fallback;
  const labels = items
    .filter((item) => item && item.active === true && typeof item.label === 'string')
    .map((item) => item.label.trim())
    .filter(Boolean);
  return labels.length ? labels : fallback;
}

async function clearSeededListings(firestore) {
  const seeded = await firestore.collection('listings').where('seeded', '==', true).get();
  for (let offset = 0; offset < seeded.docs.length; offset += 450) {
    const batch = firestore.batch();
    for (const document of seeded.docs.slice(offset, offset + 450)) {
      batch.delete(document.ref);
    }
    await batch.commit();
  }
  console.log(`Deleted ${seeded.size} seeded listing(s).`);
}

async function main() {
  const email = process.argv[2]?.trim();
  const clear = process.argv.includes('--clear');
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Usage: node tools/seed_listings.js <admin-email> [--clear]');
  }
  if (process.argv.slice(3).some((argument) => argument !== '--clear')) {
    throw new Error('The only supported option is --clear.');
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
  const admin = await auth.getUserByEmail(email);
  if (admin.customClaims?.admin !== true) {
    throw new Error(`The Firebase Auth user ${email} does not have the admin claim.`);
  }
  if (clear) await clearSeededListings(firestore);

  const [categorySnapshot, areaSnapshot, adminProfile] = await Promise.all([
    firestore.collection('config').doc('categories').get(),
    firestore.collection('config').doc('areas').get(),
    firestore.collection('users').doc(admin.uid).get(),
  ]);
  const categories = configuredLabels(categorySnapshot.data(), DEFAULT_CATEGORIES);
  const areas = configuredLabels(areaSnapshot.data(), DEFAULT_AREAS);
  const profile = adminProfile.data();
  const ownerName = typeof profile?.name === 'string' && profile.name.trim()
    ? profile.name.trim()
    : admin.displayName || email.split('@')[0];
  const ownerPhone = typeof profile?.phone === 'string' ? profile.phone : '';

  const batch = firestore.batch();
  for (const [index, sample] of SAMPLE_LISTINGS.entries()) {
    const [type, title, description, priceUgx, priceUnit, bedrooms, bathrooms] = sample;
    const category = categories[index % categories.length];
    const area = areas[index % areas.length];
    const imageUrl = IMAGE_URLS[index % IMAGE_URLS.length];
    const listingRef = firestore.collection('listings').doc();
    batch.set(listingRef, {
      ownerId: admin.uid,
      ownerName,
      ownerPhone,
      type,
      category,
      title,
      titleLower: title.toLowerCase(),
      description,
      priceUgx,
      priceUnit,
      area,
      ...(bedrooms ? { bedrooms, bathrooms } : {}),
      amenities: type === 'property' ? ['Electricity', 'Water access'] : [],
      imageUrls: [imageUrl],
      thumbnailUrl: imageUrl,
      status: 'approved',
      ratingAvg: 0,
      ratingCount: 0,
      ownerVerified: profile?.isVerified === true,
      searchKeywords: generateListingSearchKeywords(title, category, area),
      isFeatured: index < 3,
      seeded: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Created ${SAMPLE_LISTINGS.length} approved sample listings for ${email}.`);
}

main().catch((error) => {
  console.error(`Listing seed failed: ${error.message || error}`);
  process.exitCode = 1;
});
