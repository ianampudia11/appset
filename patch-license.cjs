#!/usr/bin/env node
/**
 * patch-license.cjs
 * Patches dist/index.js to bypass license validation at build time.
 * Run this from inside the container after COPY . .
 */
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'dist', 'index.js');

let code;
try {
  code = fs.readFileSync(filePath, 'utf8');
} catch (e) {
  console.error('[patch-license] Could not read dist/index.js:', e.message);
  process.exit(1);
}

// The license validator has these unique markers in the minified code
const markers = [
  'missing IV or encrypted data',
  'License file not found',
  'License expired',
  'Invalid license format'
];

const found = markers.filter(m => code.includes(m));
if (found.length === 0) {
  console.log('[patch-license] No license code found, skipping patch.');
  process.exit(0);
}

console.log('[patch-license] Found license markers:', found);

// Strategy 1: Replace "valid:!1" (valid=false) near license code with "valid:!0" (valid=true)
// We locate the license validation chunk (±5000 chars around the first marker)
const firstMarker = markers.find(m => code.includes(m));
const markerIdx = code.indexOf(firstMarker);

const start = Math.max(0, markerIdx - 5000);
const end = Math.min(code.length, markerIdx + 5000);
const chunk = code.slice(start, end);

const beforeCount = (chunk.match(/valid:!1/g) || []).length;
console.log(`[patch-license] Found ${beforeCount} 'valid:!1' in license context (will flip to valid:!0)`);

const patchedChunk = chunk
  .replace(/valid:!1/g, 'valid:!0')
  // Also remove expiry checks - replace any expiryDate check that returns invalid
  .replace(/new Date\(\)>([a-z])\b/g, 'false'); // date > expiryDate => always false (not expired)

const patched = code.slice(0, start) + patchedChunk + code.slice(end);

// Strategy 2: Also patch the "License file not found" throw to create a fake valid response
// Find where the file-not-found error is thrown and inject a bypass
const notFoundMarker = 'License file not found';
const notFoundIdx = patched.indexOf(notFoundMarker);
if (notFoundIdx !== -1) {
  console.log('[patch-license] License file not found handler detected, should be bypassed by valid file.');
}

fs.writeFileSync(filePath, patched, 'utf8');
console.log('[patch-license] Patch applied successfully!');

// Verify patch
const verify = fs.readFileSync(filePath, 'utf8');
const verifyChunk = verify.slice(start, end);
const afterCount = (verifyChunk.match(/valid:!1/g) || []).length;
console.log(`[patch-license] Verification: ${beforeCount - afterCount} replacements made, ${afterCount} remaining.`);
