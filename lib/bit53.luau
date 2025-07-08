--[=[
  All functions in the `bit53` library treat input numbers as 53-bit unsigned integers
  in `[0..4294967295]` range. The bit positions start at 0 where 0 corresponds to the
  least significant bit.
]=]

--!strict

local FULL_WIDTH = 53
local UINT32_WIDTH = 32
local ZEROBYTE = 0 -- for explicitness
local MAX53 = 9_007_199_254_740_991

local M = {}

-- Split a 64-bit number into a 32-bit chunk and a 21-bit chunk
-- Remaining bits are thrown away
local function split(n: number): (number, number)
  local low = n % 2 ^ UINT32_WIDTH
  local high = (n - low) / 2 ^ UINT32_WIDTH
  high = bit32.replace(high, 0, 21, 11) -- Ensure high part is 21 bits
  return low, high
end

-- Combine two 32-bit chunks into a 53-bit number
-- Remaining bits are thrown away
local function combine(low: number, high: number): number
  high = bit32.replace(high, 0, 21, 11) -- Ensure high part is 21 bits
  return high * 2 ^ UINT32_WIDTH + low
end

--[=[
  Performs a bitwise `and` of all input numbers and returns the result. If the function
  is called with no arguments, an integer with all bits set to 1 is returned.
  @param ... number
  @return number
]=]
function M.band(...: number): number
  if #... == 0 then return MAX53 end
  if #... == 1 then return table.unpack(...) end

  local low, high = split(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split(table.unpack(..., i))
    low = bit32.band(low, l)
    high = bit32.band(high, h)
  end
  return combine(low, high)
end

--[=[
  Performs a bitwise `not` on the input number and returns the result.
  @param n number
  @return number
]=]
function M.bnot(n: number): number
  local low, high = split(n)
  low = bit32.bnot(low)
  high = bit32.bnot(high)
  return combine(low, high)
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

  local low, high = split(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split(table.unpack(..., i))
    low = bit32.bor(low, l)
    high = bit32.bor(high, h)
  end
  return combine(low, high)
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

  local low, high = split(table.unpack(..., 1))
  for i = 2, #... do
    local l, h = split(table.unpack(..., i))
    low = bit32.bxor(low, l)
    high = bit32.bxor(high, h)
  end
  return combine(low, high)
end

--[=[
  Performs a bitwise `and` of all input numbers, and return `true` if the result is not zero.
  If the function is called with no arguments, true is returned.
  @param ... number
  @return boolean
]=]
function M.btest(...: number): boolean
  return M.band(...) ~= ZEROBYTE
end

--[=[
  Extracts bits of `n` at position `f` with a width of `w`, and returns the resulting number.
  `w` defaults to `1`, so a two-argument version of `extract` returns the bit value at position `f`.
  Bits are indexed starting at 0. Errors if `f` and `f+w-1` are not between 0 and 52.
  @param n number
  @param f number
  @param w number?
  @return number
]=]
function M.extract(n: number, f: number, w: number?): number
  w = w or 1
  if f < 0 or f + w >= FULL_WIDTH then error('Field out of bounds: ' .. f .. ' to 52') end

  local low, high = split(n)

  if f >= UINT32_WIDTH then
    -- Field is entirely in the high part
    return bit32.extract(high, f - UINT32_WIDTH, w)
  end

  if f < UINT32_WIDTH then
    -- Field is entirely in the low part
    return bit32.extract(low, f, w)
  end

  -- Field crosses the boundary between low and high parts
  local extracted_high = bit32.extract(high, 0, f + w - UINT32_WIDTH)
  if f + w >= UINT32_WIDTH then
    -- Result is greater than 32 bits, so just change high part
    return combine(low, extracted_high)
  end

  local extracted_low = bit32.extract(low, f, UINT32_WIDTH - f)
  extracted_high = bit32.lshift(extracted_high, UINT32_WIDTH - f)
  return bit32.bor(extracted_low, extracted_high) -- combine
end

--[=[
  Replaces bits of `n` at position `f` and width `w` with `r`, and returns the resulting number.
  `w` defaults to `1`, so a three-argument version of `replace` changes one bit at position `f`
  to `r` (which should be 0 or 1) and returns the result. Bits are indexed starting at 0. Errors
  if `f` and `f+w-1` are not between 0 and 52.
  @param n number
  @param f number
  @param r number
  @param w number?
  @return number
]=]
function M.replace(n: number, f: number, r: number, w: number?): number
  w = w or 1
  if f < 0 or f + w >= FULL_WIDTH then error('Field out of bounds: ' .. f .. ' to 52') end

  local low, high = split(n)

  if f < UINT32_WIDTH and f + w - 1 > UINT32_WIDTH then
    -- Field crosses the boundary between low and high parts
    local lowPart = bit32.replace(low, f, r, UINT32_WIDTH - f)

    local field = bit32.lshift(r, UINT32_WIDTH - f)
    local width = f + w - UINT32_WIDTH
    local highPart = bit32.replace(high, 0, field, width)

    return combine(lowPart, highPart)
  end

  if f < UINT32_WIDTH then
    low = bit32.replace(low, f, r, w)
  else
    high = bit32.replace(high, f - UINT32_WIDTH, r, w)
  end

  return combine(low, high)
end

--[=[
  Shifts `n` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  When `i` is outside of `[-52..52]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.lshift(n: number, i: number): number
  if i <= -FULL_WIDTH or i >= FULL_WIDTH then return ZEROBYTE end
  if i < 0 then return M.rshift(n, math.abs(i)) end

  local low, high = split(n)

  if i >= UINT32_WIDTH then
    high = low
    low = ZEROBYTE
  else
    low = bit32.lshift(low, i) + bit32.rshift(high, UINT32_WIDTH - i)
    high = bit32.lshift(high, i)
  end

  return combine(low, high)
end

--[=[
  Shifts `n` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  When `i` is outside of `[-52..52]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.rshift(n: number, i: number): number
  if i <= -FULL_WIDTH or i >= FULL_WIDTH then return ZEROBYTE end
  if i < 0 then return M.lshift(n, math.abs(i)) end

  local low, high = split(n)

  if i >= UINT32_WIDTH then
    low = high
    high = ZEROBYTE
  else
    low = bit32.rshift(low, i) + bit32.lshift(high, UINT32_WIDTH - i)
    high = bit32.rshift(high, i)
  end

  return combine(low, high)
end

--[=[
  Shifts `n` by `i` bits to the right (if `i` is negative, a left shift is performed instead). The
  most significant bit of `n` is propagated during the shift. When `i` is larger than 52, returns a
  number with all bits set to the sign bit of `n`. When `i` is smaller than `-52`, 0 is returned.
  @param n number
  @param i number
  @return number
]=]
function M.arshift(n: number, i: number): number
  if i <= -FULL_WIDTH then return ZEROBYTE end
  if i >= FULL_WIDTH then
    -- All bits set to sign bit
    local sign = bit32.extract(split(n))
    return if sign == 1 then MAX53 else ZEROBYTE
  end

  local result = M.rshift(n, i)
  local _, high = split(n)

  -- propagate the sign bit of n
  local sign = bit32.extract(high, 31)
  if sign == 1 and i > 0 then
    -- Fill shifted-in bits with 1s
    local fillmask = M.lshift(MAX53, FULL_WIDTH - i)
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

  local delta = i % FULL_WIDTH
  if delta == 0 then return n end

  local low, high = split(n)
  local rLow: number, rHigh: number

  if delta >= UINT32_WIDTH then
    -- Rotate high part into low part
    rLow = bit32.lshift(high, delta - UINT32_WIDTH) + bit32.rshift(low, FULL_WIDTH - delta)
    rHigh = bit32.lshift(low, delta - UINT32_WIDTH)
  else
    -- Rotate within the same part
    rLow = bit32.lshift(low, delta) + bit32.rshift(high, UINT32_WIDTH - delta)
    rHigh = bit32.lshift(high, delta) + bit32.rshift(low, UINT32_WIDTH - delta)
  end

  return combine(rLow, rHigh)
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

  local delta = i % FULL_WIDTH
  if delta == 0 then return n end

  local low, high = split(n)
  local rLow: number, rHigh: number

  if delta >= UINT32_WIDTH then
    -- Rotate low part into high part
    rLow = bit32.lshift(high, FULL_WIDTH - delta) + bit32.rshift(low, delta - UINT32_WIDTH)
    rHigh = bit32.lshift(low, FULL_WIDTH - delta) + bit32.rshift(high, delta - UINT32_WIDTH)
  else
    -- Rotate within the same part
    rLow = bit32.lshift(low, UINT32_WIDTH - delta) + bit32.rshift(high, delta)
    rHigh = bit32.lshift(high, UINT32_WIDTH - delta) + bit32.rshift(low, delta)
  end

  return combine(rLow, rHigh)
end

--[=[
  Returns the number of consecutive zero bits in the 53-bit representation of `n` starting
  from the left-most (most significant) bit. Returns 53 if `n` is zero.
  @param n number
  @return number
]=]
function M.countlz(n: number): number
  if n == ZEROBYTE then return FULL_WIDTH end

  local low, high = split(n)

  return if high == ZEROBYTE then UINT32_WIDTH + bit32.countlz(low) else bit32.countlz(high)
end

--[=[
  Returns the number of consecutive zero bits in the 53-bit representation of `n` starting
  from the right-most (least significant) bit. Returns 53 if `n` is zero.
  @param n number
  @return number
]=]
function M.countrz(n: number): number
  if n == ZEROBYTE then return FULL_WIDTH end

  local low, high = split(n)

  return if low == ZEROBYTE then UINT32_WIDTH + bit32.countrz(high) else bit32.countrz(low)
end

--[=[
  Returns `n` with the order of the bytes swapped.
  @param n number
  @return number
]=]
function M.byteswap(n: number): number
  local low, high = split(n)
  return combine(bit32.byteswap(low), bit32.byteswap(high))
end

return M
