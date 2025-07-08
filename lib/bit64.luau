--!strict

local BITWIDTH = 64
local HALFWIDTH = 32

-- Split a 64-bit number into two 32-bit chunks
local function split64(n: number): (number, number)
  local low = n % 2 ^ HALFWIDTH
  local high = (n - low) / 2 ^ HALFWIDTH
  return low, high
end

-- Combine two 32-bit chunks into a 64-bit number
local function combine64(low: number, high: number): number
  return high * 2 ^ HALFWIDTH + low
end

local ZEROBYTE = 0 -- for explicitness
local MAX32 = bit32.bnot(0)
local MAX64 = combine64(MAX32, MAX32)

local M = {}

--[=[
  Performs a bitwise `and` of all input numbers and returns the result. If the function
  is called with no arguments, an integer with all bits set to 1 is returned.
  @param ... number
  @return number
]=]
function M.band(...: number): number
  if #... == 0 then return MAX64 end
  if #... == 1 then return table.unpack(...) end

  local low, high = split64(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split64(table.unpack(..., i))
    low = bit32.band(low, l)
    high = bit32.band(high, h)
  end
  return combine64(low, high)
end

--[=[
  Performs a bitwise `not` on the input number and returns the result.
  @param n number
  @return number
]=]
function M.bnot(n: number): number
  local low, high = split64(n)
  low = bit32.bnot(low)
  high = bit32.bnot(high)
  return combine64(low, high)
end

--[=[
  Performs a bitwise `or` of all input numbers and returns the result. If the function is
  called with no arguments, zero is returned.
  @param ... number
  @return number
]=]
function M.bor(...: number): number
  if #... == 0 then return ZEROBYTE end
  if #... == 1 then return table.unpack(...) end

  local low, high = split64(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split64(table.unpack(..., i))
    low = bit32.bor(low, l)
    high = bit32.bor(high, h)
  end
  return combine64(low, high)
end

--[=[
  Performs a bitwise `xor` of all input numbers and returns the result. If the function
  is called with no arguments, zero is returned.
  @param ... number
  @return number
]=]
function M.bxor(...: number): number
  if #... == 0 then return ZEROBYTE end
  if #... == 1 then return table.unpack(...) end

  local low, high = split64(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split64(table.unpack(..., i))
    low = bit32.bxor(low, l)
    high = bit32.bxor(high, h)
  end
  return combine64(low, high)
end

--[=[
  Performs a bitwise `and` of all input numbers, and return `true` if the result is not zero.
  If the function is called with no arguments, true is returned.
  @param ... number
  @return boolean
]=]
function M.btest(...: number): boolean
  return if #... == 0 then true else M.band(...) ~= ZEROBYTE
end

--[=[
  Extracts bits of `n` at position `f` with a width of `w`, and returns the resulting number.
  `w` defaults to `1`, so a two-argument version of `extract` returns the bit value at position `f`.
  Bits are indexed starting at 0. Errors if `f` and `f+w-1` are not between 0 and 63.
  @param n number
  @param f number
  @param w number?
  @return number
]=]
function M.extract(n: number, f: number, w: number?): number
  w = w or 1
  if f < 0 or f + w >= BITWIDTH then error('Field out of bounds: ' .. f .. ' to 63') end

  local low, high = split64(n)

  if f < HALFWIDTH and f + w - 1 > HALFWIDTH then
    -- Field crosses the boundary between low and high parts
    local lowPart = bit32.extract(low, f, HALFWIDTH - f)
    local highPart = bit32.extract(high, 0, f + w - HALFWIDTH)
    local mask = bit32.lshift(highPart, HALFWIDTH - f)
    return bit32.bor(lowPart, mask)
  end

  return if f < HALFWIDTH then bit32.extract(low, f, w) else bit32.extract(high, f - HALFWIDTH, w)
end

--[=[
  Replaces bits of `n` at position `f` and width `w` with `r`, and returns the resulting number.
  `w` defaults to `1`, so a three-argument version of `replace` changes one bit at position `f`
  to `r` (which should be 0 or 1) and returns the result. Bits are indexed starting at 0. Errors
  if `f` and `f+w-1` are not between 0 and 63.
  @param n number
  @param f number
  @param r number
  @param w number?
  @return number
]=]
function M.replace(n: number, f: number, r: number, w: number?): number
  w = w or 1
  if f < 0 or f + w >= BITWIDTH then error('Field out of bounds: ' .. f .. ' to 63') end

  local low, high = split64(n)

  if f < HALFWIDTH and f + w - 1 > HALFWIDTH then
    -- Field crosses the boundary between low and high parts
    local lowPart = bit32.replace(low, f, r, HALFWIDTH - f)

    local field = bit32.lshift(r, HALFWIDTH - f)
    local width = f + w - HALFWIDTH
    local highPart = bit32.replace(high, 0, field, width)

    return combine64(lowPart, highPart)
  end

  if f < HALFWIDTH then
    low = bit32.replace(low, f, r, w)
  else
    high = bit32.replace(high, f - HALFWIDTH, r, w)
  end

  return combine64(low, high)
end

--[=[
  Shifts `n` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  When `i` is outside of `[-63..63]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.lshift(n: number, i: number): number
  if i <= -BITWIDTH or i >= BITWIDTH then return ZEROBYTE end
  if i < 0 then return M.rshift(n, math.abs(i)) end

  local low, high = split64(n)

  if i >= HALFWIDTH then
    high = low
    low = ZEROBYTE
  else
    low = bit32.lshift(low, i) + bit32.rshift(high, HALFWIDTH - i)
    high = bit32.lshift(high, i)
  end

  return combine64(low, high)
end

--[=[
  Shifts `n` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  When `i` is outside of `[-63..63]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.rshift(n: number, i: number): number
  if i <= -BITWIDTH or i >= BITWIDTH then return ZEROBYTE end
  if i < 0 then return M.lshift(n, math.abs(i)) end

  local low, high = split64(n)

  if i >= HALFWIDTH then
    low = high
    high = ZEROBYTE
  else
    low = bit32.rshift(low, i) + bit32.lshift(high, HALFWIDTH - i)
    high = bit32.rshift(high, i)
  end

  return combine64(low, high)
end

--[=[
  Shifts `n` by `i` bits to the right (if `i` is negative, a left shift is performed instead). The
  most significant bit of `n` is propagated during the shift. When `i` is larger than 63, returns a
  number with all bits set to the sign bit of `n`. When `i` is smaller than `-63`, 0 is returned.
  @param n number
  @param i number
  @return number
]=]
function M.arshift(n: number, i: number): number
  if i <= -BITWIDTH then return ZEROBYTE end
  if i >= BITWIDTH then
    -- All bits set to sign bit
    local sign = bit32.extract(split64(n))
    return if sign == 1 then MAX64 else ZEROBYTE
  end

  local result = M.rshift(n, i)
  local _, high = split64(n)

  -- propagate the sign bit of n
  local sign = bit32.extract(high, 31)
  if sign == 1 and i > 0 then
    -- Fill shifted-in bits with 1s
    local fillmask = M.lshift(MAX64, BITWIDTH - i)
    result = M.bor(result, fillmask)
  end
  return result
end

--[=[
  Rotates `n` to the left by `i` bits (if `i` is negative, a right rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the right.
  @param n number
  @param i number
  @return number
]=]
function M.lrotate(n: number, i: number): number
  if i < 0 then return M.rrotate(n, math.abs(i)) end

  local delta = i % BITWIDTH
  if delta == 0 then return n end

  local low, high = split64(n)
  local rLow: number, rHigh: number

  if delta >= HALFWIDTH then
    -- Rotate high part into low part
    rLow = bit32.lshift(high, delta - HALFWIDTH) + bit32.rshift(low, BITWIDTH - delta)
    rHigh = bit32.lshift(low, delta - HALFWIDTH)
  else
    -- Rotate within the same part
    rLow = bit32.lshift(low, delta) + bit32.rshift(high, HALFWIDTH - delta)
    rHigh = bit32.lshift(high, delta) + bit32.rshift(low, HALFWIDTH - delta)
  end

  return combine64(rLow, rHigh)
end

--[=[
  Rotates `n` to the right by `i` bits (if `i` is negative, a left rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the left.
  @param n number
  @param i number
  @return number
]=]
function M.rrotate(n: number, i: number): number
  if i < 0 then return M.lrotate(n, math.abs(i)) end

  local delta = i % BITWIDTH
  if delta == 0 then return n end

  local low, high = split64(n)
  local rLow: number, rHigh: number

  if delta >= HALFWIDTH then
    -- Rotate low part into high part
    rLow = bit32.lshift(high, BITWIDTH - delta) + bit32.rshift(low, delta - HALFWIDTH)
    rHigh = bit32.lshift(low, BITWIDTH - delta) + bit32.rshift(high, delta - HALFWIDTH)
  else
    -- Rotate within the same part
    rLow = bit32.lshift(low, HALFWIDTH - delta) + bit32.rshift(high, delta)
    rHigh = bit32.lshift(high, HALFWIDTH - delta) + bit32.rshift(low, delta)
  end

  return combine64(rLow, rHigh)
end

--[=[
  Returns the number of consecutive zero bits in the 64-bit representation of `n` starting
  from the left-most (most significant) bit. Returns 64 if `n` is zero.
  @param n number
  @return number
]=]
function M.countlz(n: number): number
  if n == ZEROBYTE then return BITWIDTH end

  local low, high = split64(n)

  return if high == ZEROBYTE then HALFWIDTH + bit32.countlz(low) else bit32.countlz(high)
end

--[=[
  Returns the number of consecutive zero bits in the 64-bit representation of `n` starting
  from the right-most (least significant) bit. Returns 64 if `n` is zero.
  @param n number
  @return number
]=]
function M.countrz(n: number): number
  if n == 0 then return BITWIDTH end

  local low, high = split64(n)

  return if low == ZEROBYTE then HALFWIDTH + bit32.countrz(high) else bit32.countrz(low)
end

--[=[
  Returns n with the order of the bytes swapped.
  @param n number
  @return number
]=]
function M.byteswap(n: number): number
  local low, high = split64(n)
  return combine64(bit32.byteswap(low), bit32.byteswap(high))
end

return M
