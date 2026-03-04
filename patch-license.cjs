#!/usr/bin/env node
/**
 * patch-license.cjs
 * Patches dist/index.js at build time to bypass ALL license validation.
 * Strategy: inject a process.exit bypass at the TOP of the file, plus
 * replace all valid:!1 occurrences near license-related code.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'dist', 'index.js');

let code;
try {
  code = fs.readFileSync(filePath, 'latin1');
} catch (e) {
  console.error('[patch-license] Could not read dist/index.js:', e.message);
  process.exit(1);
}

let totalReplacements = 0;
console.log(`[patch-license] File size: ${code.length} bytes`);

// ── Strategy 1: Inject process.exit bypass at the TOP of dist/index.js ───────
// This intercepts ANY process.exit(0) or process.exit(1) called during the
// license validation phase (first 30 seconds), preventing app crash.
const exitBypass = `;(function licenseBypass(){
  var _realExit = process.exit;
  var _active = true;
  process.exit = function(code) {
    if (_active) {
      console.log('[license-bypass] Intercepted process.exit(' + (code===undefined?0:code) + ') - startup continuing...');
      return;
    }
    return _realExit.apply(process, [code]);
  };
  // Restore real exit after 30 seconds (app fully started by then)
  setTimeout(function() {
    _active = false;
    process.exit = _realExit;
    console.log('[license-bypass] process.exit restored to normal');
  }, 30000).unref();
})();
`;

// Only inject if not already injected
if (code.indexOf('licenseBypass') === -1) {
  code = exitBypass + code;
  console.log('[patch-license] ✓ Strategy "process.exit bypass": injected at top of file');
  totalReplacements++;
} else {
  console.log('[patch-license] ℹ "process.exit bypass" already present, skipping');
}

// ── Strategy 2: Global replacement of valid:!1 near ALL license markers ───────
const licenseMarkers = [
  'missing IV or encrypted data',
  'License expired',
  'License file not found',
  'allowedIps',
  'validateLicense',
  'licenseExpired',
  'License validation failed',
];

let patchedPositions = new Set();

licenseMarkers.forEach(marker => {
  let searchFrom = 0;
  while (true) {
    const idx = code.indexOf(marker, searchFrom);
    if (idx === -1) break;
    searchFrom = idx + 1;

    const start = Math.max(0, idx - 8000);
    const end = Math.min(code.length, idx + 8000);

    // Skip if already patched this region
    const key = `${Math.floor(start / 1000)}`;
    if (patchedPositions.has(key)) continue;
    patchedPositions.add(key);

    const chunk = code.slice(start, end);
    let patched = chunk;

    // Replace validity flags
    patched = patched.replace(/valid:!1/g, 'valid:!0');
    patched = patched.replace(/valid: !1/g, 'valid:!0');
    patched = patched.replace(/valid:false/g, 'valid:true');
    patched = patched.replace(/valid: false/g, 'valid:true');

    // Replace throws near license errors with noops
    patched = patched.replace(
      /throw new Error\(["'][^"']*[Ll]icense[^"']*["']\)/g,
      '(console.log("[license-bypass] throw intercepted"))'
    );
    patched = patched.replace(
      /throw new Error\(["'][^"']*missing IV[^"']*["']\)/g,
      '(console.log("[license-bypass] IV throw intercepted"))'
    );

    // Replace process.exit near license code
    patched = patched.replace(/process\.exit\s*\(\s*[01]\s*\)/g, '(0)');

    if (patched !== chunk) {
      const cnt =
        (chunk.match(/valid:!1/g) || []).length +
        (chunk.match(/valid:false/g) || []).length +
        (chunk.match(/throw new Error\(["'][^"']*[Ll]icense[^"']*["']\)/g) || []).length +
        (chunk.match(/process\.exit\s*\(\s*[01]\s*\)/g) || []).length;
      code = code.slice(0, start) + patched + code.slice(end);
      totalReplacements += cnt;
      console.log(`[patch-license] ✓ Patched near "${marker}": ~${cnt} replacements`);
    }
  }
});

// ── Strategy 3: Replace the license return object pattern globally ────────────
// Match {valid:!1,reason:...,allowedIps:...} or similar
const patterns = [
  {
    regex: /\{valid:!1,reason:[^}]{0,200}allowedIps:[^}]{0,200}\}/g,
    replacement: '{valid:!0,reason:null,expiryDate:new Date("2099-01-01"),allowedIps:[]}',
    desc: 'license object pattern v1'
  },
  {
    regex: /\{valid:false,reason:[^}]{0,200}allowedIps:[^}]{0,200}\}/g,
    replacement: '{valid:true,reason:null,expiryDate:new Date("2099-01-01"),allowedIps:[]}',
    desc: 'license object pattern v2'
  },
];

patterns.forEach(({ regex, replacement, desc }) => {
  const matches = code.match(regex);
  if (matches && matches.length > 0) {
    code = code.replace(regex, replacement);
    console.log(`[patch-license] ✓ Strategy "${desc}": replaced ${matches.length}`);
    totalReplacements += matches.length;
  }
});

// ── Strategy 4: Override fs.readFileSync for license files ───────────────────
// Make license file reads return a value that won't cause "missing IV" errors
const fsOverride = `
;(function overrideLicenseFile(){
  try {
    var _fs = require('fs');
    var _origSync = _fs.readFileSync;
    _fs.readFileSync = function(p, opts) {
      var ps = String(p || '');
      if (ps.indexOf('.license') !== -1 || ps.indexOf('license') !== -1) {
        try { return _origSync.apply(this, arguments); } catch(e) {}
        // Return a fake license with IV:data format to pass format check
        return 'fakeivsixteenchars:fakedatathatshouldlookvaguleyvalid12345';
      }
      return _origSync.apply(this, arguments);
    };
  } catch(e) {}
})();
`;

if (code.indexOf('overrideLicenseFile') === -1) {
  // Inject after the first semicolon or at position 500 (after the process.exit bypass)
  const insertPos = code.indexOf('\n', 500);
  if (insertPos !== -1) {
    code = code.slice(0, insertPos) + fsOverride + code.slice(insertPos);
    console.log('[patch-license] ✓ Strategy "fs.readFileSync override": injected');
    totalReplacements++;
  }
}

// ── Write the patched file ────────────────────────────────────────────────────
fs.writeFileSync(filePath, code, 'latin1');

console.log(`[patch-license] ✅ Done! Applied ${totalReplacements} total replacement(s)`);
if (totalReplacements === 0) {
  console.log('[patch-license] ⚠️  Checking file for license markers...');
  licenseMarkers.forEach(m => {
    const idx = code.indexOf(m);
    console.log(`  "${m}": ${idx !== -1 ? 'FOUND at ' + idx : 'not found'}`);
  });
}
