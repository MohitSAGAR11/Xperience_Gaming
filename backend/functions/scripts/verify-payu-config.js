#!/usr/bin/env node

/**
 * PayU Configuration Verification Script
 * 
 * This script helps verify that PayU environment variables are correctly configured
 * for Firebase Functions Gen 2.
 * 
 * Usage:
 *   node scripts/verify-payu-config.js
 */

const { defineString, defineSecret } = require('firebase-functions/params');

console.log('🔍 PayU Configuration Verification\n');
console.log('=====================================\n');

// Note: This script can only check if parameters are defined, not their values
// Actual values are only available at runtime in Firebase Functions

const requiredParams = [
  { name: 'PAYU_MERCHANT_KEY', type: 'String', required: true },
  { name: 'PAYU_MERCHANT_SALT', type: 'Secret', required: true },
  { name: 'PAYU_BASE_URL', type: 'String', required: true },
  { name: 'PAYU_MODE', type: 'String', required: false, default: 'test' },
];

console.log('📋 Required Environment Variables:\n');

requiredParams.forEach(param => {
  const status = param.required ? '✅ REQUIRED' : '⚠️  OPTIONAL';
  const defaultValue = param.default ? ` (default: ${param.default})` : '';
  console.log(`  ${status} ${param.name} (${param.type})${defaultValue}`);
});

console.log('\n📝 Configuration Guide:\n');
console.log('1. Set environment variables using Firebase CLI:');
console.log('   firebase functions:config:set payu.merchant_key="YOUR_KEY"');
console.log('   firebase functions:config:set payu.base_url="https://secure.payu.in"');
console.log('   firebase functions:config:set payu.mode="live"');
console.log('   firebase functions:secrets:set PAYU_MERCHANT_SALT');
console.log('\n2. Or use Firebase Console:');
console.log('   Functions → Configuration → Environment Variables');
console.log('   Functions → Secrets');
console.log('\n3. PayU URLs:');
console.log('   Production: https://secure.payu.in');
console.log('   Test:       https://test.payu.in');
console.log('\n4. Verify configuration:');
console.log('   - Check backend logs when creating payment');
console.log('   - Look for "PayU Configuration Validated" message');
console.log('   - Verify PAYU_BASE_URL matches your credentials');
console.log('\n📖 For detailed instructions, see: backend/PAYU_CONFIGURATION.md\n');

