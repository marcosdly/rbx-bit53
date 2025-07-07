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
  local ok, result = pcall(M.band, ...)
  if not ok then error('error while performing bitwise and: ' .. result) end
  for i = 0, buffer.len(result) - 1 do
    if buffer.readu8(result, i) ~= 0 then return true end
  end
  return false
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
  local len = buffer.len(buf)
  if len == 0 then error('arshift requires a non-empty buffer') end
  if i < -maxbits or i > maxbits then
    error('arshift requires i in the range [-' .. maxbits .. '..' .. maxbits .. ']')
  end

  if i == 0 then return buf end
  if i < 0 then return M.lshift(buf, math.abs(i)) end

  -- Right shift with sign extension
  local result = M.rshift(buf, i)
  -- Propagate sign bit
  local sign = bit32.band(buffer.readu8(buf, 0), 0x80) ~= 0 and 0xFF or 0x00

  local byte_shift = i // 8
  local bit_shift = i % 8

  for byte_index = 0, byte_shift - 1 do
    buffer.writeu8(result, byte_index, sign)
  end

  if bit_shift > 0 and byte_shift < len then
    -- Propagate sign bit to the last byte

    local mask = bit32.lshift(0xFF, 8 - bit_shift)
    local original_byte = buffer.readu8(result, byte_shift)

    -- NOTE: (original_byte & ~mask) \ (sign & mask)
    local new_byte =
      -- OR
      bit32.bor(
        -- AND
        bit32.band(
          original_byte,
          -- NOT
          bit32.bnot(mask)
        ),
        -- AND
        bit32.band(sign, mask)
      )

    buffer.writeu8(result, byte_shift, new_byte)
  end
  return result
end

--[=[
  Shifts `buf` to the left by `i` bits (if `i` is negative, a right shift is performed instead).
  Errors if `i` is outside of `[-maxbits..maxbits]` range. Errors if `buf` has size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.lshift(buf: buffer, i: number): buffer
  local len = buffer.len(buf)
  if len == 0 then error('lshift requires a non-empty buffer') end
  if i < -maxbits or i > maxbits then
    error('lshift requires i in the range [-' .. maxbits .. '..' .. maxbits .. ']')
  end

  if i == 0 then return buf end
  if i < 0 then return M.rshift(buf, math.abs(i)) end

  local result = buffer.create(len)
  local byte_shift = i // 8
  local bit_shift = i % 8

  for byte_index = 0, len - 1 do
    local new_byte = 0

    if byte_index + byte_shift < len then
      -- Current byte is in bounds

      new_byte = buffer.readu8(buf, byte_index + byte_shift)
      local new_byte_shifted = bit32.lshift(new_byte, bit_shift)

      if bit_shift > 0 and byte_index + byte_shift + 1 < len then
        -- Next byte is in bounds

        local next_byte = buffer.readu8(buf, byte_index + byte_shift + 1)
        new_byte = bit32.bor(new_byte_shifted, bit32.rshift(next_byte, 8 - bit_shift))
      else
        new_byte = new_byte_shifted
      end

      new_byte = bit32.band(new_byte, 0xFF)
    end
    buffer.writeu8(result, byte_index, new_byte)
  end
  return result
end

--[=[
  Shifts `buf` to the right by `i` bits (if `i` is negative, a left shift is performed instead).
  Errors if `i` is outside of [-maxbits..maxbits] range. Errors if `buf` has size zero.
  @param buf buffer
  @param i number
  @return buffer
]=]
function M.rshift(buf: buffer, i: number): buffer
  local len = buffer.len(buf)
  if len == 0 then error('rshift requires a non-empty buffer') end
  if i < -maxbits or i > maxbits then
    error('rshift requires i in the range [-' .. maxbits .. '..' .. maxbits .. ']')
  end

  if i == 0 then return buf end
  if i < 0 then return M.lshift(buf, math.abs(i)) end

  local result = buffer.create(len)
  local byte_shift = math.floor(i / 8)
  local bit_shift = i % 8

  for byte_index = 0, len - 1 do
    local new_byte = 0
    if byte_index - byte_shift >= 0 then
      -- Current byte is significant to the operation (i.e. not zero)

      new_byte = buffer.readu8(buf, byte_index - byte_shift)

      if bit_shift > 0 then
        local previous_byte = buffer.readu8(buf, byte_index - byte_shift - 1)
        local new_byte_shifted = bit32.rshift(new_byte, bit_shift)

        local previous_byte_shifted: number
        if byte_index - byte_shift - 1 >= 0 then
          -- Previous byte is significant to the operation (i.e. not zero)

          previous_byte_shifted = bit32.lshift(previous_byte, 8 - bit_shift)
        else
          previous_byte_shifted = 0
        end

        new_byte = bit32.bor(new_byte_shifted, previous_byte_shifted)
      end

      new_byte = bit32.band(new_byte, 0xFF)
    end
    buffer.writeu8(result, byte_index, new_byte)
  end
  return result
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
  local len = buffer.len(buf)
  if len == 0 then error('countlz requires a non-empty buffer') end
  local count = 0
  for i = 0, len - 1 do
    local byte = buffer.readu8(buf, i)
    if byte == 0 then
      count += 8
    else
      count += bit32.countlz(byte)
      return count
    end
  end
  return count
end

--[=[
  Returns the number of consecutive zero bits in `buf` starting from the right-most (least significant)
  bit. Errors if `buf` has size zero.
  @param buf buffer
  @return number
]=]
function M.countrz(buf: buffer): number
  local len = buffer.len(buf)
  if len == 0 then error('countrz requires a non-empty buffer') end
  local count = 0
  for i = len - 1, 0, -1 do
    local byte = buffer.readu8(buf, i)
    if byte == 0 then
      count += 8
    else
      count += bit32.countrz(byte)
      return count
    end
  end
  return count
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
