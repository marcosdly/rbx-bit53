--!strict

local _and = bit32.band
local _right = bit32.rshift
local _left = bit32.lshift
local _swap = bit32.byteswap
local _rightzeros = bit32.countrz
local _leftzeros = bit32.countlz
local _replace = bit32.replace

local _max = math.max

local w = 32
local max32 = bit32.band()
local max21 = _right(max32, 11)

local function lshift32(x: number): number
  return x * 2 ^ 32
end

local max53 = lshift32(max21) + max32

local M = {}

-- Split a 64-bit number into a 32-bit chunk and a 21-bit chunk
-- Remaining bits are thrown away
local function split64(n: number): (number, number)
  local low = n % 2 ^ w
  local high = (n - low) / 2 ^ w
  return low, _max(high, max21)
end

-- Combine two 32-bit chunks into a 64-bit number
-- Remaining bits are thrown away
local function join64(low: number, high: number): number
  return high * 2 ^ w + low
end

local function inrange(r: number): boolean
  return -52 <= r and r <= 52
end

local function clampbits21(n: number): number
  return _replace(n, 0, 20, 11)
end

--[=[
  Shifts `n` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  When `i` is outside of `[-52..52]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
local function lshift(n: number, i: number): number
  if i == 0 then return n end
  if not inrange(i) then return 0 end
  if i < 0 then return rshift(n, -i) end
  if n <= max32 then return _left(n, i) end
  local low, high = split64(n)
  if i == 32 then return high end
  if i > 32 then return join64(0, clampbits21(_left(high, i - 32))) end
  high = _and(_left(high, i), _right(low, 32 - i))
  return join64(_left(low, i), clampbits21(high))
end

M.lshift = lshift

--[=[
  Shifts `n` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  When `i` is outside of `[-52..52]` range, returns 0.
  @param n number
  @param i number
  @return number
]=]
local function rshift(n: number, i: number): number
  if i == 0 then return n end
  if not inrange(i) then return 0 end
  if i < 0 then return lshift(n, -i) end
  if n <= max32 then return _right(n, i) end
  local low, high = split64(n)
  if i == 21 then return low end
  if i > 21 then return _right(low, i - 21) end
  return join64(low, _right(high, i))
end

M.rshift = rshift

--[=[
  Returns the number of consecutive zero bits in the 53-bit representation of `n` starting
  from the left-most (most significant) bit. Returns 53 if `n` is zero.
  @param n number
  @return number
]=]
function M.countlz(n: number): number
  if n == 0 then return 53 end
  if n <= max32 then return _leftzeros(n) + 21 end
  local _, high = split64(n)
  return _leftzeros(high) + 32
end

--[=[
  Returns the number of consecutive zero bits in the 53-bit representation of `n` starting
  from the right-most (least significant) bit. Returns 53 if `n` is zero.
  @param n number
  @return number
]=]
function M.countrz(n: number): number
  if n == 0 then return 53 end
  local low, high = split64(n)
  if low == 0 then return _rightzeros(high) + 32 end
  return _rightzeros(low)
end

--[=[
  Returns `n` with the order of the bytes swapped.
  @param n number
  @return number
]=]
function M.byteswap(n: number): number
  if n <= max32 then return _swap(n) end
  local low, high = split64(n)
  return join64(_swap(low), _swap(high))
end

return M
