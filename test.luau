--!strict

-- TODO double check test logic

local bit53 = require('./bit53')

local max53 = 2 ^ 53 - 1
local max32 = 2 ^ 32 - 1

local function tohex(n: number): string
  -- max53 in hex has string length 14
  -- #string.format('%X', max53) == 14
  return string.format('0x%014X', n)
end

print(tohex(0))

local passed, failed, i = 0, 0, 0

local function getLogMessage(kind: string, ok: boolean, subject: string, details: string?)
  return string.format(
    '%03d:%s:%s: %s%s',
    i,
    kind:upper(),
    if ok then 'PASSED' else 'FAILED',
    subject,
    if details ~= nil then (' - ' .. details:lower()) else ''
  )
end

local function assertEqual(a: number, b: number, msg: string)
  i += 1
  if a == b then
    passed += 1
  else
    failed += 1
    print(getLogMessage('ASSERT', false, tohex(a) .. ' ~= ' .. tohex(b), msg))
  end
end

local function assertTrue(cond: number | boolean, msg: string)
  i += 1
  local ok = not not cond
  if ok then
    passed += 1
  else
    failed += 1
    print(getLogMessage('ASSERT', ok, tostring(cond), msg))
  end
end

local function test(title: string, callback: () -> nil)
  local startPassed, startFailed = passed, failed
  local prefix = string.format(':: TEST: %s ...', title)
  print(prefix .. ' BEGIN')
  callback()
  print(prefix .. ' END')
  local length = (passed + failed) - (startPassed + startFailed)
  if length == 0 then error(string.format("No tests ran for '%s'", title)) end
  print(prefix .. string.format(' RESULT %s/%s', passed - startPassed, length))
end

test('band', function()
  assertEqual(bit53.band(), max53, 'band() should return max53')
  assertEqual(bit53.band(0), 0, 'band(0)')
  assertEqual(bit53.band(max53), max53, 'band(max53)')
  assertEqual(bit53.band(0xFF, 0xF0), 0xF0, 'band(0xFF, 0xF0)')
  assertEqual(bit53.band(0xFFFF, 0x00FF, 0x0F0F), 0x000F, 'band multiple')
end)

test('bnot', function()
  assertEqual(bit53.bnot(0), max53, 'bnot(0)')
  assertEqual(bit53.bnot(max53), 0, 'bnot(max53)')
  assertEqual(bit53.bnot(1), max53 - 1, 'bnot(1)')
  assertEqual(bit53.bnot(max53 - 1), 1, 'bnot(max53 - 1)')
end)

test('bor', function()
  assertEqual(bit53.bor(), 0, 'bor() should return 0')
  assertEqual(bit53.bor(0), 0, 'bor(0)')
  assertEqual(bit53.bor(max53), max53, 'bor(max53)')
  assertEqual(bit53.bor(0xF0, 0x0F), 0xFF, 'bor(0xF0, 0x0F)')
  assertEqual(bit53.bor(0xF000, 0x0F00, 0x00F0), 0xFFFF, 'bor multiple')
end)

test('bxor', function()
  assertEqual(bit53.bxor(), 0, 'bxor() should return 0')
  assertEqual(bit53.bxor(0), 0, 'bxor(0)')
  assertEqual(bit53.bxor(max53), max53, 'bxor(max53)')
  assertEqual(bit53.bxor(0xFF, 0xF0), 0x0F, 'bxor(0xFF, 0xF0)')
  assertEqual(bit53.bxor(0xFFFF, 0x00FF, 0x0F0F), 0xF0F0, 'bxor multiple')
end)

test('btest', function()
  assertTrue(bit53.btest(), 'btest() should return true')
  assertTrue(not bit53.btest(0), 'btest(0) should be false')
  assertTrue(bit53.btest(max53), 'btest(max53)')
  assertTrue(bit53.btest(1), 'btest(1)')
  assertTrue(not bit53.btest(0, 1), 'btest(0, 1)')
end)

test('extract', function()
  assertEqual(bit53.extract(0xFF, 0), 1, 'extract bit 0 from 0xFF')
  assertEqual(bit53.extract(0xFF, 3), 1, 'extract bit 3 from 0xFF')
  assertEqual(bit53.extract(0xFF, 7), 1, 'extract bit 7 from 0xFF')
  assertEqual(bit53.extract(0xFF, 8), 0, 'extract bit 8 from 0xFF')
  assertEqual(bit53.extract(max53, 52), 0, 'extract bit 52 from max53')
  assertEqual(bit53.extract(max53, 0), 1, 'extract bit 0 from max53')
  assertEqual(bit53.extract(0x123456789ABCDEF, 0, 4), 0xF, 'extract 4 bits from 0')
  assertEqual(bit53.extract(0x123456789ABCDEF, 4, 4), 0xE, 'extract 4 bits from 4')
  -- Test cross 32-bit boundary
  local testNum = bit53.lshift(0x1FFFFF, 32) + 0xFFFFFFFF
  assertEqual(bit53.extract(testNum, 30, 5), 0x1F, 'extract across boundary')
end)

test('replace', function()
  assertEqual(bit53.replace(0, 0, 1), 1, 'replace bit 0 to 1 in 0')
  assertEqual(bit53.replace(1, 0, 0), 0, 'replace bit 0 to 0 in 1')
  assertEqual(bit53.replace(0xFF, 3, 0), 0xF7, 'replace bit 3 to 0 in 0xFF')
  assertEqual(bit53.replace(0, 52, 1), bit53.lshift(1, 52), 'replace bit 52 to 1')
  assertEqual(bit53.replace(max53, 0, 0), max53 - 1, 'replace bit 0 to 0 in max53')
  assertEqual(bit53.replace(0, 0, 1, 4), 0xF, 'replace 4 bits to 1')
  assertEqual(bit53.replace(0xFFFF, 4, 0, 4), 0xFF0F, 'replace 4 bits to 0')
end)

test('lshift', function()
  assertEqual(bit53.lshift(1, 1), 2, 'lshift 1 by 1')
  assertEqual(bit53.lshift(1, 52), bit53.lshift(1, 52), 'lshift 1 by 52')
  assertEqual(bit53.lshift(max53, 1), 0, 'lshift max53 by 1 (overflow)')
  assertEqual(bit53.lshift(0xFFFFFFFF, 32), bit53.lshift(0x1FFFFF, 32), 'lshift across boundary')
  assertEqual(bit53.lshift(1, -1), 0, 'lshift by negative (right shift)')
  assertEqual(bit53.lshift(1, 53), 0, 'lshift by 53')
end)

test('rshift', function()
  assertEqual(bit53.rshift(2, 1), 1, 'rshift 2 by 1')
  assertEqual(bit53.rshift(bit53.lshift(1, 52), 52), 1, 'rshift back')
  assertEqual(bit53.rshift(max53, 53), 0, 'rshift max53 by 53')
  assertEqual(bit53.rshift(1, -1), 2, 'rshift by negative (left shift)')
  assertEqual(bit53.rshift(1, 53), 0, 'rshift by 53')
end)

test('arshift', function()
  assertEqual(bit53.arshift(2, 1), 1, 'arshift 2 by 1')
  assertEqual(bit53.arshift(-1, 1), -1, 'arshift negative')
  assertEqual(bit53.arshift(max53, 1), max53, 'arshift max53 by 1 (sign bit)')
  assertEqual(bit53.arshift(0, 53), 0, 'arshift 0 by 53')
  assertEqual(bit53.arshift(max53, 53), max53, 'arshift max53 by 53')
end)

test('lrotate', function()
  assertEqual(bit53.lrotate(1, 1), 2, 'lrotate 1 by 1')
  assertEqual(bit53.lrotate(1, 53), 1, 'lrotate 1 by 53 (full cycle)')
  assertEqual(bit53.lrotate(max53, 1), max53, 'lrotate max53 by 1')
  assertEqual(bit53.lrotate(1, -1), bit53.rrotate(1, 1), 'lrotate by negative')
end)

test('rrotate', function()
  assertEqual(bit53.rrotate(2, 1), 1, 'rrotate 2 by 1')
  assertEqual(bit53.rrotate(1, 53), 1, 'rrotate 1 by 53')
  assertEqual(bit53.rrotate(max53, 1), max53, 'rrotate max53 by 1')
  assertEqual(bit53.rrotate(1, -1), bit53.lrotate(1, 1), 'rrotate by negative')
end)

test('countlz', function()
  assertEqual(bit53.countlz(0), 53, 'countlz(0)')
  assertEqual(bit53.countlz(1), 52, 'countlz(1)')
  assertEqual(bit53.countlz(max53), 0, 'countlz(max53)')
  assertEqual(bit53.countlz(0x80000000), 0, 'countlz high bit set')
end)

test('countrz', function()
  assertEqual(bit53.countrz(0), 53, 'countrz(0)')
  assertEqual(bit53.countrz(1), 0, 'countrz(1)')
  assertEqual(bit53.countrz(2), 1, 'countrz(2)')
  assertEqual(bit53.countrz(max53), 0, 'countrz(max53)')
  assertEqual(bit53.countrz(bit53.lshift(1, 32)), 32, 'countrz with high bits')
end)

test('byteswap', function()
  assertEqual(bit53.byteswap(0x12345678), 0x78563412, 'byteswap 32-bit')
  assertEqual(
    bit53.byteswap(max53),
    bit53.byteswap(max32) + bit53.lshift(bit53.byteswap(bit53.rshift(max53, 32)), 32),
    'byteswap 53-bit'
  )
end)

test('bit32 compatibility', function()
  assertEqual(bit32.band(0xFF, 0xF0), bit53.band(0xFF, 0xF0), 'band same for both')
  assertEqual(bit32.bor(0xF0, 0x0F), bit53.bor(0xF0, 0x0F), 'bor same for both')
  assertEqual(bit32.bxor(0xFF, 0xF0), bit53.bxor(0xFF, 0xF0), 'bxor same for both')
  assertEqual(bit32.bnot(0xFF), bit53.bnot(0xFF), 'bnot same for both (32-bit)')
  assertEqual(bit32.lshift(1, 5), bit53.lshift(1, 5), 'lshift same for both')
  assertEqual(bit32.rshift(32, 3), bit53.rshift(32, 3), 'rshift same for both')
  assertEqual(bit32.arshift(-8, 2), bit53.arshift(-8, 2), 'arshift same for both')
  assertEqual(bit32.lrotate(0x12345678, 8), bit53.lrotate(0x12345678, 8), 'lrotate same for both')
  assertEqual(bit32.rrotate(0x12345678, 8), bit53.rrotate(0x12345678, 8), 'rrotate same for both')
  assertEqual(bit32.extract(0xFF, 3), bit53.extract(0xFF, 3), 'extract same for both')
  assertEqual(bit32.replace(0xFF, 3, 0), bit53.replace(0xFF, 3, 0), 'replace same for both')
  assertEqual(bit32.countlz(0x00FF), bit53.countlz(0x00FF), 'countlz same for both')
  assertEqual(bit32.countrz(0xFF00), bit53.countrz(0xFF00), 'countrz same for both')
  assertEqual(bit32.byteswap(0x12345678), bit53.byteswap(0x12345678), 'byteswap same for both')
end)

test('bit53 fundamental differences', function()
  -- Tests that fail for bit32 but succeed for bit53 (using 53-bit values)
  assertEqual(bit53.band(max53), max53, 'bit53 band max53 (bit32 would truncate)')
  assertEqual(bit53.bor(max53), max53, 'bit53 bor max53')
  assertEqual(bit53.bxor(max53), max53, 'bit53 bxor max53')
  assertEqual(bit53.bnot(max53), 0, 'bit53 bnot max53')
  assertEqual(bit53.lshift(1, 52), 2 ^ 52, 'bit53 lshift 1 by 52 (bit32 would be 0)')
  assertEqual(bit53.rshift(2 ^ 52, 52), 1, 'bit53 rshift 2^52 by 52')
  assertEqual(bit53.arshift(max53, 1), max53, 'bit53 arshift max53 by 1')
  assertEqual(bit53.extract(max53, 52), 0, 'bit53 extract bit 52 from max53')
  assertEqual(bit53.replace(max53, 52, 1), max53 + 2 ^ 52, 'bit53 replace bit 52 to 1 in max53')
  assertEqual(bit53.countlz(2 ^ 52), 0, 'bit53 countlz 2^52')
  assertEqual(bit53.countrz(2 ^ 52), 52, 'bit53 countrz 2^52')
end)

print(
  string.format(':: RESULT: %d/%d (PASSED %d, FAILED %d)', passed, passed + failed, passed, failed)
)
