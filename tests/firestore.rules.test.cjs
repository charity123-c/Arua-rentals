const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { after, before, test } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDocs,
  getDoc,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: 'demo-arua-city-finder-rules',
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

function profile(email, overrides = {}) {
  return {
    name: 'Test User',
    email,
    phone: '+256701234567',
    role: 'tenant',
    photoUrl: null,
    fcmTokens: [],
    isVerified: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function roleRequest(uid, overrides = {}) {
  return {
    uid,
    requestedRole: 'landlord',
    status: 'pending',
    name: 'Test User',
    email: `${uid}@example.com`,
    phone: '+256701234567',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function listing(ownerId, status, overrides = {}) {
  return {
    ownerId,
    ownerName: 'Test Owner',
    ownerPhone: '+256701234567',
    type: 'property',
    category: 'Rentals',
    title: 'Test listing',
    titleLower: 'test listing',
    description: 'Test listing description.',
    priceUgx: 350000,
    priceUnit: 'month',
    area: 'Oli',
    amenities: [],
    imageUrls: [],
    thumbnailUrl: 'https://example.test/listing.jpg',
    status,
    ratingAvg: 0,
    ratingCount: 0,
    searchKeywords: [],
    isFeatured: false,
    ownerVerified: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedDocuments(callback) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

test('users can create and read only their own tenant profile', async () => {
  const ownerDb = testEnvironment
    .authenticatedContext('owner', { email: 'owner@example.com' })
    .firestore();
  const otherDb = testEnvironment
    .authenticatedContext('other', { email: 'other@example.com' })
    .firestore();
  const ownerProfile = doc(ownerDb, 'users/owner');

  await assertSucceeds(setDoc(ownerProfile, profile('owner@example.com')));
  await assertSucceeds(getDoc(ownerProfile));
  await assertFails(getDoc(doc(otherDb, 'users/owner')));
  await assertFails(
    setDoc(
      doc(otherDb, 'users/owner'),
      profile('owner@example.com', { name: 'Changed by another user' }),
    ),
  );
});

test('clients cannot create or update a user to admin role', async () => {
  const db = testEnvironment
    .authenticatedContext('role-user', { email: 'role@example.com' })
    .firestore();
  const userProfile = doc(db, 'users/role-user');

  await assertFails(
    setDoc(userProfile, profile('role@example.com', { role: 'admin' })),
  );
  await setDoc(userProfile, profile('role@example.com'));
  await assertFails(updateDoc(userProfile, { role: 'admin' }));
});

test('a tenant can create a pending role request but cannot approve it', async () => {
  const db = testEnvironment
    .authenticatedContext('requester', { email: 'requester@example.com' })
    .firestore();
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'users/requester'),
    profile('requester@example.com', { roleRequest: 'landlord' }),
  );
  batch.set(
    doc(db, 'role_requests/requester'),
    roleRequest('requester'),
  );
  await assertSucceeds(batch.commit());

  await assertFails(
    updateDoc(doc(db, 'role_requests/requester'), {
      status: 'approved',
      reviewedBy: 'requester',
      reviewedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(db, 'users/requester'), {
      role: 'landlord',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('a tenant cannot attach a role request without its pending request record', async () => {
  const db = testEnvironment
    .authenticatedContext('orphan-request')
    .firestore();
  await assertFails(
    setDoc(
      doc(db, 'users/orphan-request'),
      profile('orphan@example.com', { roleRequest: 'provider' }),
    ),
  );
});

test('only a token admin can review role requests and update assigned roles', async () => {
  await seedDocuments(async (db) => {
    await setDoc(doc(db, 'users/requester'), {
      name: 'Test User',
      email: 'requester@example.com',
      phone: '+256701234567',
      role: 'tenant',
      roleRequest: 'landlord',
      isVerified: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await setDoc(
      doc(db, 'role_requests/requester'),
      roleRequest('requester'),
    );
  });

  const adminDb = testEnvironment
    .authenticatedContext('admin', { admin: true })
    .firestore();
  const batch = writeBatch(adminDb);
  batch.update(doc(adminDb, 'role_requests/requester'), {
    status: 'approved',
    reviewedBy: 'admin',
    reviewedAt: serverTimestamp(),
  });
  batch.update(doc(adminDb, 'users/requester'), {
    role: 'landlord',
    roleRequest: null,
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  const tenantDb = testEnvironment
    .authenticatedContext('not-admin', { admin: false })
    .firestore();
  await assertFails(
    updateDoc(doc(tenantDb, 'users/requester'), { isVerified: true }),
  );
});

test('only token admins can read all users', async () => {
  await seedDocuments(async (db) => {
    await setDoc(doc(db, 'users/target'), profile('target@example.com'));
  });
  const tenantDb = testEnvironment
    .authenticatedContext('tenant-reader')
    .firestore();
  const adminDb = testEnvironment
    .authenticatedContext('admin-reader', { admin: true })
    .firestore();

  await assertFails(getDoc(doc(tenantDb, 'users/target')));
  await assertSucceeds(getDoc(doc(adminDb, 'users/target')));
});

test('listing reads are restricted to approved items, owners, or admins', async () => {
  await seedDocuments(async (db) => {
    await setDoc(doc(db, 'listings/approved'), {
      ownerId: 'landlord',
      status: 'approved',
    });

    await setDoc(doc(db, 'listings/pending'), {
      ownerId: 'landlord',
      status: 'pending',
    });
  });

  const guestDb = testEnvironment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guestDb, 'listings/approved')));
  await assertFails(getDoc(doc(guestDb, 'listings/pending')));

  const ownerDb = testEnvironment
    .authenticatedContext('landlord')
    .firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'listings/pending')));

  const adminDb = testEnvironment
    .authenticatedContext('admin', { admin: true })
    .firestore();
  await assertSucceeds(getDoc(doc(adminDb, 'listings/pending')));
  await assertSucceeds(
    setDoc(doc(adminDb, 'listings/admin-created'), listing('admin', 'approved')),
  );
});

test('signed-out visitors can read approved listing queries and config only', async () => {
  await seedDocuments(async (db) => {
    await setDoc(doc(db, 'listings/public-approved'), listing('public-owner', 'approved'));
    await setDoc(doc(db, 'listings/private-pending'), listing('public-owner', 'pending'));
    await setDoc(doc(db, 'config/categories'), {
      items: [{ id: 'rentals', label: 'Rentals', active: true }],
    });
  });
  const guestDb = testEnvironment.unauthenticatedContext().firestore();

  const approved = await assertSucceeds(
    getDocs(
      query(
        collection(guestDb, 'listings'),
        where('status', '==', 'approved'),
        where('ownerId', '==', 'public-owner'),
      ),
    ),
  );
  assert.ok(approved.docs.some((item) => item.id == 'public-approved'));
  assert.ok(approved.docs.every((item) => item.get('status') == 'approved'));
  await assertFails(getDocs(collection(guestDb, 'listings')));
  await assertSucceeds(getDoc(doc(guestDb, 'config/categories')));
  await assertFails(
    setDoc(doc(guestDb, 'config/guest-write'), { items: [] }),
  );
});

test('only landlord or provider profiles may create pending listings', async () => {
  await seedDocuments(async (db) => {
    await setDoc(
      doc(db, 'users/landlord'),
      profile('landlord@example.com', { role: 'landlord' }),
    );
  });
  const landlordDb = testEnvironment
    .authenticatedContext('landlord')
    .firestore();
  await assertSucceeds(
    setDoc(doc(landlordDb, 'listings/new-listing'), listing('landlord', 'pending')),
  );
  await assertFails(
    setDoc(doc(landlordDb, 'listings/approved-by-owner'), listing('landlord', 'approved')),
  );

  const tenantDb = testEnvironment.authenticatedContext('tenant').firestore();
  await assertFails(
    setDoc(doc(tenantDb, 'listings/tenant-listing'), listing('tenant', 'pending')),
  );
});

test('owners cannot set ownerVerified; administrators can', async () => {
  await seedDocuments(async (db) => {
    await setDoc(
      doc(db, 'users/verified-owner'),
      profile('owner@example.com', { role: 'landlord' }),
    );
    await setDoc(
      doc(db, 'listings/protected-verification'),
      listing('verified-owner', 'pending'),
    );
  });
  const ownerDb = testEnvironment
    .authenticatedContext('verified-owner', { email: 'owner@example.com' })
    .firestore();
  const adminDb = testEnvironment
    .authenticatedContext('verification-admin', { admin: true })
    .firestore();

  await assertFails(
    updateDoc(doc(ownerDb, 'listings/protected-verification'), {
      ownerVerified: true,
    }),
  );
  await assertFails(
    setDoc(
      doc(ownerDb, 'listings/forged-verification'),
      listing('verified-owner', 'pending', { ownerVerified: true }),
    ),
  );
  await assertSucceeds(
    updateDoc(doc(adminDb, 'listings/protected-verification'), {
      ownerVerified: true,
    }),
  );
});

test('users can update only whitelisted profile fields and admins cannot grant admin', async () => {
  await seedDocuments(async (db) => {
    await setDoc(doc(db, 'users/editable'), {
      ...profile('editable@example.com'),
      role: 'tenant',
    });
  });
  const ownerDb = testEnvironment
    .authenticatedContext('editable', { email: 'editable@example.com' })
    .firestore();
  await assertSucceeds(
    updateDoc(doc(ownerDb, 'users/editable'), { name: 'Updated Name' }),
  );
  await assertFails(
    updateDoc(doc(ownerDb, 'users/editable'), {
      role: 'provider',
      updatedAt: serverTimestamp(),
    }),
  );

  const adminDb = testEnvironment
    .authenticatedContext('admin', { admin: true })
    .firestore();
  await assertFails(
    updateDoc(doc(adminDb, 'users/editable'), { role: 'admin' }),
  );
});

test('unlisted collections remain denied by default', async () => {
  const db = testEnvironment
    .authenticatedContext('signed-in')
    .firestore();
  await assertFails(
    setDoc(doc(db, 'payments/client-write'), { status: 'paid' }),
  );
});
