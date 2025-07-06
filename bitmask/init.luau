--!strict

--- Default to 1KB in bytes
local maxbytes: number = 1024

--- Default to 1KB in bits
local maxbits: number = 8192

--- 1GB in bits
local BUFFER_LIMIT = 8589934592

local M = {}

-- type checking
--[=[
  @readonly
]=]
M.maxbytes = maxbytes
--[=[
  @readonly
]=]
M.maxbits = maxbits
--[=[
  @readonly
]=]
M.BUFFER_LIMIT = BUFFER_LIMIT

setmetatable(M, {
  __index = function(_, key)
    if key == 'maxbytes' then
      return maxbytes
    elseif key == 'maxbits' then
      return maxbits
    elseif key == 'BUFFER_LIMIT' then
      return BUFFER_LIMIT
    else
      return rawget(M, key)
    end
  end,
})

--[=[
  Sets the maximum number of bits that can be used in bitmask operations globally. The default is 1KB.
  The maximum number of bits is `8 * 1024^3` (1GB), and the minimum is `1` (1B). Errors if `bits` is
  outside the range `[1..8*1024^3]`. The amount is then rounded up to the nearest byte, due to buffers
  being byte-aligned, and thus, the maximum number of bits is `bits` rounded up to the nearest multiple
  of `8`.
  @param bits number
]=]
function M.setmaxbits(bits: number)
  if bits < 1 or bits > BUFFER_LIMIT then
    error('maxbits must be in the range [1..' .. maxbits .. ']')
  end
  maxbytes = math.ceil(bits / 8)
  maxbits = maxbytes * 8
end

--[=[
  Performs a bitwise `and` of all input buffers and returns the result. If called with a
  single argument, returns it as is. Errors if called with no arguments. Errors if the summed size
  of all buffers is zero. If the result is zero, returns a buffer of size zero.
  @param ... buffer
  @return buffer
]=]
function M.band(...: buffer): buffer
  if #... == 0 then error('band requires at least one argument') end
  if #... == 1 then return table.unpack(...) end

  -- Maximum buffer size to determines result size
  local maxsize = 0
  for _, buf in ... do
    maxsize = math.max(maxsize, buffer.len(buf))
  end

  if maxsize == 0 then error('band requires at least one non-empty buffer') end
  if maxsize > maxbytes then
    error('band result size cannot exceed global soft-limit of ' .. maxbytes .. ' bytes')
  end

  local result = buffer.create(maxsize)

  -- Perform bitwise AND operation using uint32 chunks
  local byteindex = 0
  while byteindex < maxsize do
    local uint32 = 0xFFFFFFFF -- Start with all bits set
    for _, buf in ... do
      local len = buffer.len(buf)
      -- Whole buffer has length up to sizeof uint32
      if byteindex + 3 < len then
        uint32 = bit32.band(uint32, buffer.readu32(buf, byteindex))
        continue
      end

      -- Index is out of bounds, meaning 32-bit word is partially out of bounds
      -- Read byite by byte and AND with the partial value
      if byteindex < len then
        local partial = 0 -- uint32 with all bits set to 0
        for j = 0, math.min(3, len - byteindex - 1) do
          partial = bit32.bor(partial, bit32.lshift(buffer.readu8(buf, byteindex + j), j * 8))
        end
        uint32 = bit32.band(uint32, partial)
        continue
      end

      -- AND with 0 if buffer is shorter
      uint32 = 0
      break
    end

    -- Write result back to buffer
    if byteindex + 3 < maxsize then
      buffer.writeu32(result, byteindex, uint32)
    else
      -- Handle partial uint32 at end of result buffer
      for j = 0, maxsize - byteindex - 1 do
        buffer.writeu8(result, byteindex + j, bit32.band(bit32.rshift(uint32, j * 8), 0xFF))
      end
    end

    -- Jump by sizeof uint32
    byteindex += 4
  end

  return result
end

--[=[
  Performs a bitwise `or` of all input buffers and returns the result. If called with a
  single argument, returns it as is. Errors if called with no arguments. Errors if the summed size
  of all buffers is zero. If the result is zero, returns a buffer of size zero.
  @param ... buffer
  @return buffer
]=]
function M.bor(...: buffer): buffer
  if #... == 0 then error('bor requires at least one argument') end
  if #... == 1 then return table.unpack(...) end

  -- Maximum buffer size to determines result size
  local maxsize = 0
  for _, buf in ... do
    maxsize = math.max(maxsize, buffer.len(buf))
  end

  if maxsize == 0 then error('bor requires at least one non-empty buffer') end
  if maxsize > maxbytes then
    error('bor result size cannot exceed global soft-limit of ' .. maxbytes .. ' bytes')
  end

  local result = buffer.create(maxsize)

  -- Perform bitwise OR operation using uint32 chunks
  local byteindex = 0
  while byteindex < maxsize do
    local uint32 = 0 -- Start with all bits cleared
    for _, buf in ... do
      local len = buffer.len(buf)
      if byteindex + 3 < len then
        uint32 = bit32.bor(uint32, buffer.readu32(buf, byteindex))
        continue
      end

      -- Index is out of bounds, meaning 32-bit word is partially out of bounds
      if byteindex < len then
        local partial = 0
        for j = 0, math.min(3, len - byteindex - 1) do
          partial = bit32.bor(partial, bit32.lshift(buffer.readu8(buf, byteindex + j), j * 8))
        end
        uint32 = bit32.bor(uint32, partial)
        continue
      end
      -- If buffer is shorter, do nothing (OR with 0)
    end

    -- Write result back to buffer
    if byteindex + 3 < maxsize then
      buffer.writeu32(result, byteindex, uint32)
    else
      -- Handle partial uint32 at end of result buffer
      for j = 0, maxsize - byteindex - 1 do
        buffer.writeu8(result, byteindex + j, bit32.band(bit32.rshift(uint32, j * 8), 0xFF))
      end
    end

    -- Jump by sizeof uint32
    byteindex += 4
  end

  return result
end

--[=[
  Performs a bitwise `xor` (exclusive or) of all input buffers and returns the result. If called with
  a single arguments, returns it as is. Errors if called with no arguments. Errors if the summed size
  of all buffers is zero. If the result is zero, returns a buffer of size zero.
  @param ... buffer
  @return buffer
]=]
function M.bxor(...: buffer): buffer
  error('not implemented')
end

--[=[
  Returns a bitwise negation of the input buffer. Errors if `buf` has size zero.
  @param buf buffer
  @return buffer
]=]
function M.bnot(buf: buffer): buffer
  if buffer.len(buf) == 0 then error('bnot requires a non-empty buffer') end

  local byteindex = 0
  local len = buffer.len(buf)
  local result = buffer.create(len)

  while byteindex < len do
    if byteindex + 3 < len then
      -- Fully inbounds
      local uint32 = buffer.readu32(buf, byteindex)
      buffer.writeu32(result, byteindex, bit32.bnot(uint32))
      byteindex = byteindex + 4 -- Jump by uint32
    else
      -- Partially out of bounds
      local uint8 = buffer.readu8(buf, byteindex)
      buffer.writeu8(result, byteindex, bit32.band(bit32.bnot(uint8), 0xFF))
      byteindex = byteindex + 1 -- Jump by uint8
    end
  end
  return result
end

--[=[
  Perform a bitwise `and` of all input numbers, and return `true` if the result is not zero.
  Errors if called with no arguments. Errors if the summed size of all buffers is zero.
  @param ... buffer
  @return boolean
]=]
function M.btest(...: buffer): boolean
  error('not implemented')
end

--[=[
  Shifts `buf` by `i` bits to the right (if `i` is negative, a left shift is performed instead).
  The most significant bit of `buf` is propagated during the shift. When `i` is zero,
  returns `buf` as is. Errors if `i` is outside the range `[-maxbits..maxbits]`. Errors if `buf` has
  size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.arshift(buf: buffer, i: number): buffer
  error('not implemented')
end

--[=[
  Shifts `buf` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  Errors if `i` is outside of `[-maxbits..maxbits]` range. Errors if `buf` has size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.lshift(buf: buffer, i: number): buffer
  error('not implemented')
end

--[=[
  Shifts `buf` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  Errors if `i` is outside of [-maxbits..maxbits] range. Errors if `buf` has size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.rshift(buf: buffer, i: number): buffer
  error('not implemented')
end

--[=[
  Rotates `buf` to the left by `i` bits (if `i` is negative, a right rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the right. Errors if `buf` has
  size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.lrotate(buf: buffer, i: number): buffer
  error('not implemented')
end

--[=[
  Rotates `buf` to the right by `i` bits (if `i` is negative, a left rotate is performed instead);
  the bits that are shifted past the bit width are shifted back from the left. Errors if `buf` has size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.rrotate(buf: buffer, i: number): buffer
  error('not implemented')
end

--[=[
  Extracts bits of `buf` at position `f` with a width of `w`, and returns the resulting buffer.
  `w` defaults to 1, so a two-argument version of extract returns the bit value at position `f`.
  Bits are indexed starting at `0`. Errors if `f` and `f+w-1` are not in the range `[0..maxbits]`.
  Errors if `buf` has size zero.
  @param buf buffer
  @param f number
  @param w number?
  @return buffer
]=]
function M.extract(buf: buffer, f: number, w: number?): buffer
  error('not implemented')
end

--[=[
  Replaces bits of `buf` at position `f` and width `w` with `r`, and returns the resulting buffer.
  `w` defaults to 1, so a three-argument version of replace changes one bit at position `f` to `r`
  (which should be `0` or `1`) and returns the result. Bits are indexed starting at `0`.
  Errors if `f` and `f+w-1` are not in the range `[0..maxbits]`. Errors if `buf` has size zero.
  @param buf buffer
  @param f number
  @param f number
  @param w number?
  @return buffer
]=]
function M.replace(buf: buffer, r: number, f: number, w: number?): buffer
  error('not implemented')
end

--[=[
  Returns the number of consecutive zero bits in `buf` starting from the left-most (most significant)
  bit. Errors if `buf` has size zero.
  @param buf buffer
  @return number
]=]
function M.countlz(buf: buffer): number
  error('not implemented')
end

--[=[
  Returns the number of consecutive zero bits in `buf` starting from the right-most (least significant)
  bit. Errors if `buf` has size zero.
  @param buf buffer
  @return number
]=]
function M.countrz(buf: buffer): number
  error('not implemented')
end

--[=[
  Returns `buf` with the order of bytes swaped. Errors if `buf` has size zero.
  @param buf buffer
  @return buffer
]=]
function M.byteswap(buf: buffer): buffer
  error('not implemented')
end

return M
