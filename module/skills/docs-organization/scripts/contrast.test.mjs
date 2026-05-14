import { test } from 'node:test';
import assert from 'node:assert/strict';
import { relativeLuminance, contrastRatio, parseHex } from './contrast.mjs';

test('parseHex: parses 6-digit hex', () => {
  assert.deepEqual(parseHex('#ffffff'), { r: 255, g: 255, b: 255 });
  assert.deepEqual(parseHex('#000000'), { r: 0, g: 0, b: 0 });
  assert.deepEqual(parseHex('#5b8def'), { r: 0x5b, g: 0x8d, b: 0xef });
});

test('parseHex: parses 3-digit hex', () => {
  assert.deepEqual(parseHex('#fff'), { r: 255, g: 255, b: 255 });
  assert.deepEqual(parseHex('#000'), { r: 0, g: 0, b: 0 });
});

test('parseHex: rejects malformed input', () => {
  assert.throws(() => parseHex('not-a-color'));
  assert.throws(() => parseHex('#gg0000'));
  assert.throws(() => parseHex('#1234'));
});

test('relativeLuminance: white is 1.0', () => {
  assert.ok(Math.abs(relativeLuminance({ r: 255, g: 255, b: 255 }) - 1.0) < 1e-9);
});

test('relativeLuminance: black is 0.0', () => {
  assert.ok(Math.abs(relativeLuminance({ r: 0, g: 0, b: 0 }) - 0.0) < 1e-9);
});

test('contrastRatio: black on white is 21:1', () => {
  const ratio = contrastRatio('#000000', '#ffffff');
  assert.ok(Math.abs(ratio - 21) < 1e-6, `expected ~21, got ${ratio}`);
});

test('contrastRatio: white on white is 1:1', () => {
  assert.equal(contrastRatio('#ffffff', '#ffffff'), 1);
});

test('contrastRatio: order-independent', () => {
  assert.equal(
    contrastRatio('#5b8def', '#ffffff'),
    contrastRatio('#ffffff', '#5b8def')
  );
});

test('contrastRatio: known AA threshold case', () => {
  // #767676 on white = 4.54:1 per WCAG examples
  const ratio = contrastRatio('#767676', '#ffffff');
  assert.ok(ratio >= 4.5 && ratio < 4.6, `expected ~4.54, got ${ratio}`);
});
