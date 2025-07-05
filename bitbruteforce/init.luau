--[=[
  Module that implements arbitrary bitwise operations using plain arithmetic, instead of
  explicit bitshifting. This operations are unsafe in nature because the result of the
  calculations depend on the interpreter's imposed limitations, e.g. every number in 
  Roblox being `float64`, which limits integers to 53 bits.
]=]

local M = {}

--[=[
  Unsafe, arithmetic based, brute force bitwise `and`. If called without arguments,
  returns zero. If called with a single argument, return it as is.
  @param ... number
  @return number
]=]
function M.band(...: number): number
  if #... == 0 then return 0 end
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
  Unsafe, arithmetic based, brute force bitwise `or`. If called without arguments,
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
  Unsafe, arithmetic based, brute force bitwise `xor`. If called without arguments,
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
  Perform an unsafe, arithmetic based, brute force bitwise `and`, then return true if
  called without arguments.
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
  if f < 0 or f + w - 1 > 63 then error('Field out of bounds: ' .. f .. ' to ' .. f + w - 1) end

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

return M
