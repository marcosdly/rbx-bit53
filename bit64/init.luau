--[=[
  Module that implements arbitrary bitwise operations using plain arithmetic (brute force),
  instead of explicit bitshifting. These operations are unsafe in nature because the result
  of the calculations depend on the interpreter's imposed limitations, e.g. every number in
  Roblox being `float64`, which limits integers to 53 bits, so number representation can't
  be guaranteed if you don't account for implementation details.
]=]

local M = {}

local bitwidth = 64 -- max width of the bitmask, in bits
local max_uint64 = 0xFFFFFFFFFFFFFFFF
M.max_uint64 = max_uint64 -- export

--[=[
  Performs a bitwise `and` of all input numbers and returns the result. If called without
  arguments, returns a 64bit number with all bits set to 1. If called with a single argument,
  return it as is.
  @param ... number
  @return number
]=]
function M.band(...: number): number
  if #... == 0 then
    local _32ones = bit32.bnot(0)
    return M.band(_32ones, _32ones * 2 ^ 32)
  end
  if #... == 1 then return table.unpack(...) end

  local result = 0
  for i = 1, #... - 1 do
    local bitA, bitB = table.unpack(..., i, i + 1)
    local power = 1

    -- Arithmetic loop
    while bitA > 0 or bitB > 0 do
      -- AND logic: 0&0=0, 0&1=0, 1&0=0, 1&1=1
      if (bitA % 2 == 1) and (bitB % 2 == 1) then
        result += power
      end
      bitA //= 2
      bitB //= 2
      power *= 2
    end
  end
  return result
end

--[=[
  Performs a bitwise `or` of all input numbers and returns the result. If called without arguments,
  returns zero. If called with a single argument, return it as is.
  @param ... number
  @return number
]=]
function M.bor(...: number): number
  if #... == 0 then return 0 end
  if #... == 1 then return table.unpack(...) end

  local result = 0
  for i = 1, #... - 1 do
    local bitA, bitB = table.unpack(..., i, i + 1)
    local power = 1

    -- Arithmetic loop
    while bitA > 0 or bitB > 0 do
      -- OR logic: 0|0=0, 0|1=1, 1|0=1, 1|1=1
      if (bitA % 2 == 1) or (bitB % 2 == 1) then
        result += power
      end

      bitA //= 2
      bitB //= 2
      power *= 2
    end
  end
  return result
end

--[=[
  Performs a bitwise `xor` of all input numbers and returns the result. If called without arguments,
  returns zero. If called with a single argument, return it as is.
  @param ... number
  @return number
]=]
function M.bxor(...: number): number
  if #... == 0 then return 0 end
  if #... == 1 then return table.unpack(...) end

  local result = 0
  for i = 1, #... - 1 do
    local bitA, bitB = table.unpack(..., i, i + 1)
    local power = 1

    -- Arithmetic loop
    while bitA > 0 or bitB > 0 do
      -- XOR logic: 0^0=0, 0^1=1, 1^0=1, 1^1=0
      if (bitA % 2) ~= (bitB % 2) then
        result += power
      end

      bitA //= 2
      bitB //= 2
      power *= 2
    end
  end
  return result
end

--[=[
  Performs a bitwise`and` of all input numbers, and return `true` if the result is not zero.
  If called without arguments, returns `true`.
  @param ... number
  @return number
]=]
function M.btest(...: number): boolean
  return M.band(...) ~= 0
end

--[=[
  Extracts bits of `n` at position `f` with a width of `w`, and returns the resulting number.
  `w` defaults to 1, so a two-argument version of extract returns the bit value at position `f`.
  Bits are indexed starting at 0. Errors if `f` and `f+w-1` are not between 0 and 63.
  @param n number
  @param f number
  @param w number?
  @return number
]=]
function M.extract(n: number, f: number, w: number?): number
  w = w or 1
  if f < 0 or f + w > bitwidth then
    error('Field out of bounds: ' .. f .. ' to ' .. bitwidth - 1)
  end

  -- Arithmetic loop
  local result, power = 0, 1
  for i = 0, w - 1 do
    local bit = (n // (10 ^ (f + i))) % 2
    if bit == 1 then
      result += power
    end
    power *= 2
  end
  return result
end

--[=[
  Replaces bits of `n` at position `f` and width `w` with `r`, and returns the resulting number.
  `w` defaults to `1`, so a three-argument version of replace changes one bit at position `f` to `r`
  (which should be `0` or `1`) and returns the result. Bits are indexed starting at `0`.
  Errors if `f` and `f+w-1` are not between `0` and `63`.
]=]
function M.replace(n: number, f: number, r: number, w: number?): number
  w = w or 1
  if f < 0 or f + w > bitwidth then
    error('Field out of bounds: ' .. f .. ' to ' .. bitwidth - 1)
  end

  -- Clear the bits in the range [f, f+w-1]
  local mask = (2 ^ w - 1) * (2 ^ f)
  n = n - (n % (2 ^ f)) + (n % (2 ^ (f + w)))

  -- Set the bits in the range [f, f+w-1] to `r`
  return n + (r * mask)
end

--[=[
  Rotates `n` to the left by `i` bits (if `i` is negative, a right rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the right.
  @param n number
  @param i number
  @return number
]=]
function M.lrotate(n: number, i: number): number
  i = i % bitwidth
  if i < 0 then i = bitwidth + i end

  local left = n // (2 ^ (bitwidth - i))
  local right = n % (2 ^ (bitwidth - i))
  return (right * (2 ^ i)) + left
end

--[=[
  Shifts `n` by `i` bits to the right (if `i` is negative, a left shift is performed instead).
  The most significant bit of `n` is propagated during the shift. When `i` is larger than `63`, returns
  an integer with all bits set to the sign bit of `n`. When `i` is smaller than `-63`, `0` is returned.
  @param n number
  @param i number
  @return number
]=]
function M.arshift(n: number, i: number): number
  if i < -bitwidth or i > bitwidth then return 0 end
  if i < 0 then return M.lshift(n, -i) end

  local signBit = (n // (2 ^ (bitwidth - 1))) % 2
  local result = n // (2 ^ i)

  -- If the sign bit is set, propagate it
  if signBit == 1 then
    result += (2 ^ (bitwidth - i)) - 1
  end

  return result
end

--[=[
  Rotates `n` to the right by `i` bits (if `i` is negative, a left rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the left.
  @param n number
  @param i number
  @return number
]=]
function M.rrotate(n: number, i: number): number
  i = i % bitwidth
  if i < 0 then i = bitwidth + i end

  local right = n // (2 ^ i)
  local left = n % (2 ^ i)
  return (left * (2 ^ (bitwidth - i))) + right
end

--[=[
  Shifts `n` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  When i is outside of `[-63..63]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.lshift(n: number, i: number): number
  if i < -bitwidth or i > bitwidth then return 0 end
  if i < 0 then return M.rshift(n, -i) end
  return n * (2 ^ i)
end

--[=[
  Shifts `n` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  When i is outside of `[-63..63]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
function M.rshift(n: number, i: number): number
  if i < -bitwidth or i > bitwidth then return 0 end
  if i < 0 then return M.lshift(n, -i) end
  return n // (2 ^ i)
end

--[=[
  Returns the number of consecutive zero bits in the 64-bit representation of `n` starting from the
  left-most (most significant) bit. Returns `64` if `n` is zero.
  @param n number
  @return number
]=]
function M.countlz(n: number): number
  if n == 0 then return bitwidth end

  local count = 0
  for i = bitwidth - 1, 0, -1 do
    if (n // (2 ^ i)) % 2 == 0 then
      count += 1
    else
      break
    end
  end
  return count
end

--[=[
  Returns the number of consecutive zero bits in the 64-bit representation of `n` starting from the
  right-most (least significant) bit. Returns `64` if `n` is zero.
  @param n number
  @return number
]=]
function M.countrz(n: number): number
  if n == 0 then return bitwidth end

  local count = 0
  for i = 0, bitwidth - 1 do
    if (n // (2 ^ i)) % 2 == 0 then
      count += 1
    else
      break
    end
  end
  return count
end

--[=[
  Returns the 64-bit representation of `n` with the order of the bytes swapped.
  @param n number
  @return number
]=]
function M.byteswap(n: number): number
  local swapped = 0
  for i = 0, bitwidth - 1, 8 do
    local byte = (n // (2 ^ i)) % 256
    swapped += byte * (2 ^ (bitwidth - 8 - i))
  end
  return swapped
end

--[=[
  Generator that returns 64-bit numbers from `1 << 0` to `1 << (w - 1)`. These numbers are similar to
  enum int flags, meaning a single bit is set to `1` and all other bits are `0`.
  If `w` is not provided, defaults to `64`. If `w` is `0`, returns an empty iterator.
  If `w` is negative, returns an iterator that starts at `1 << 63` and ends at `1 << (63 + w)`.
  Errors if `w` is outside of `[-63..63]` range.
  @param w number?
  @return () -> number
]=]
function M.iota(w: number?): () -> number
  w = w or bitwidth
  if w == 0 then
    return function()
      return nil
    end
  end
  if w > bitwidth or w < -bitwidth then error('Width out of bounds: ' .. tostring(w)) end

  local i, limit, step
  if w > 0 then
    i, limit, step = 0, w - 1, 1
  else
    i, limit, step = bitwidth - 1, bitwidth + w, -1
  end

  return function()
    if (step > 0 and i > limit) or (step < 0 and i < limit) then return nil end
    local value = 2 ^ i
    i = i + step
    return value
  end
end

return M
