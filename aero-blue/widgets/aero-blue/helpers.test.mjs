import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { shellQuote, commandFor, parsePayload, percentage, formatBytes, temperature, weatherSymbol, focusRemaining, clockDuration, monthCells, panelPosition } from './lib/helpers.js';

test('shell arguments survive hostile text as literal data', () => {
  for (const input of ["Tonight's task", '$(printf INJECTION)', '`printf INJECTION`', 'one; echo bad', 'line\ntwo', '', 'a\\b', 'a"b']) {
    const result = spawnSync('/bin/sh', ['-c', `printf %s ${shellQuote(input)}`], { encoding: 'utf8' });
    assert.equal(result.status, 0);
    assert.equal(result.stdout, input);
  }
});

test('commands require configured absolute runtime fields and quote every argument', () => {
  assert.equal(commandFor({}, ['widget-data']), null);
  assert.equal(commandFor({ python: 'python3', cli: '/aero.py' }, ['widget-data']), null);
  const command = commandFor({ python: '/some path/python3', cli: "/a'b/aero.py" }, ['productivity', 'add', '$(echo bad)']);
  assert.equal(command, "'/some path/python3' '/a'\\''b/aero.py' 'productivity' 'add' '$(echo bad)'");
});

test('malformed data is surfaced rather than converted into fake readings', () => {
  assert.ok(parsePayload('broken').error);
  assert.ok(parsePayload('[]').error);
  assert.ok(parsePayload('null').error);
  assert.equal(parsePayload('{"system":{"cpuPercent":23}}').system.cpuPercent, 23);
  assert.equal(percentage(null), 'Unavailable');
  assert.equal(percentage(NaN), 'Unavailable');
  assert.equal(percentage(0), '0%');
  assert.equal(formatBytes(null), 'Unavailable');
  assert.equal(formatBytes(1024 ** 3), '1.0 GB');
  assert.equal(temperature(null), '—');
  assert.equal(temperature(72, 'fahrenheit'), '72°F');
});

test('weather mapping distinguishes clear, snow, thunder, unknown', () => {
  assert.equal(weatherSymbol(null), '◌');
  assert.equal(weatherSymbol(0), '☀');
  assert.equal(weatherSymbol(73), '❄');
  assert.equal(weatherSymbol(95), 'ϟ');
});

test('focus state uses persisted absolute end time and never runs below zero', () => {
  assert.equal(focusRemaining({ endsAt: 100001 }, 40000), 61);
  assert.equal(clockDuration(61), '01:01');
  assert.equal(focusRemaining({ endsAt: 20 }, 30), 0);
  assert.equal(focusRemaining({ endsAt: null }, 30), null);
  assert.equal(focusRemaining({ endsAt: 'invalid' }, 30), null);
});

test('month grid includes leap day and proper week padding', () => {
  const leap = monthCells(new Date(2024, 1, 15));
  assert.equal(leap.filter(Boolean).length, 29);
  assert.equal(leap.indexOf(1), 4);
  assert.equal(leap.length % 7, 0);
  assert.equal(monthCells(new Date(2025, 1, 1)).filter(Boolean).length, 28);
});

test('position settings remain finite and within supported dimensions', () => {
  assert.deepEqual(panelPosition({ x: -10, y: NaN, width: 10000 }), { left: 0, top: 48, width: 900 });
  assert.deepEqual(panelPosition({ x: 100, y: 230, width: 320 }), { left: 100, top: 230, width: 320 });
});
