// Web Crypto API & IndexedDB Implementation for Flutter Interop

const DB_NAME = 'SecureChatStorage';
const STORE_NAME = 'keys';
const DB_VERSION = 1;

// Initialize IndexedDB
async function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id' });
      }
    };

    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject('IndexedDB error: ' + event.target.error);
  });
}

// Store functionality with Extractable: false security
async function storeKey(id, key) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction([STORE_NAME], 'readwrite');
    const store = transaction.objectStore(STORE_NAME);
    const request = store.put({ id: id, key: key });

    request.onsuccess = () => resolve(true);
    request.onerror = () => reject('Error storing key');
  });
}

// 1. Generate Session Key (AES-GCM)
async function generateSessionKey() {
  try {
    const key = await window.crypto.subtle.generateKey(
      {
        name: "AES-GCM",
        length: 256
      },
      true, // must be extractable to be wrapped, but we can store it as non-extractable later if needed
      ["encrypt", "decrypt"]
    );
    return key;
  } catch (e) {
    console.error("Key generation failed", e);
    throw e;
  }
}

// 2. Encrypt Text
async function encryptText(text, sessionKey) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const iv = window.crypto.getRandomValues(new Uint8Array(12)); // 96-bit IV for AES-GCM

  const encryptedData = await window.crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: iv
    },
    sessionKey,
    data
  );

  return {
    ciphertext: new Uint8Array(encryptedData),
    iv: iv
  };
}

// 3. Wrap Key (Encrypt Session Key with Receiver's Public Key)
async function wrapKey(sessionKey, receiverPublicKey) {
  // Import the receiver's public key (assuming SPKI format for now)
  // In a real app, receiverPublicKey might be passed as a JWK or ArrayBuffer
  // For this example, we assume receiverPublicKey IS ALREADY a CryptoKey object.
  // If it's pure bytes, we'd need to importKey first.
  
  const wrappedKey = await window.crypto.subtle.wrapKey(
    "raw",
    sessionKey,
    receiverPublicKey,
    {
      name: "RSA-OAEP"
    }
  );

  return new Uint8Array(wrappedKey);
}

// Helper: Import Public Key (RSA-OAEP) from SPKI (ArrayBuffer)
async function importPublicKey(spkiData) {
  return await window.crypto.subtle.importKey(
    "spki",
    spkiData,
    {
      name: "RSA-OAEP",
      hash: "SHA-256"
    },
    true,
    ["wrapKey"]
  );
}


// Expose to window for Flutter
window.flutterCrypto = {
  generateSessionKey: generateSessionKey,
  encryptText: encryptText,
  wrapKey: wrapKey,
  importPublicKey: importPublicKey,
  storeKey: storeKey
};
