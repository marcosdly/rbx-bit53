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

return M
