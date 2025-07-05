--!strict

-- 1GB in bytes
local maxbytes = 1024 ^ 3

--- 1GB in bits
local maxbits = 8 * 1024 ^ 3

local M = {}

M.maxbits = maxbits
M.maxbytes = maxbytes

--- Abstract declarations for bitmask library functions

--- Performs a bitwise `and` of all input numbers and returns the result.
--- If the function is called with no arguments, a single byte buffer with all bits set to 1
--- is returned.
-- @param ... buffer
-- @return buffer
function M.band(...: buffer): buffer
  error('not implemented')
end

--- Performs a bitwise or of all input buffers and returns the result. If the function
--- is called with no arguments, a single byte buffer with all bits set to zero is returned.
-- @param buf buffer
-- @param ... number
-- @return buffer
function M.bor(buf: buffer): buffer
  error('not implemented')
end

--- Performs a bitwise `xor` (exclusive or) of all input numbers and returns the result.
--- If the function is called with no arguments, is called with no arguments, a single
--- byte buffer with all bits set to zero is returned.
-- @param buf buffer
-- @param ... buffer
-- @return buffer
function M.bxor(...: buffer): buffer
  error('not implemented')
end

--- Returns a bitwise negation of the input buffer.
-- @param buf buffer
-- @return buffer
function M.bnot(buf: buffer): buffer
  error('not implemented')
end

--- Perform a bitwise `and` of all input numbers, and return true if the result is not zero.
--- If the function is called with no arguments, `true` is returned.
-- @param ... buffer
-- @return boolean
function M.btest(...: buffer): boolean
  error('not implemented')
end

--- Shifts `buf` by `i` bits to the right (if `i` is negative, a left shift is performed instead).
--- The most significant bit of `buf` is propagated during the shift. When `i` is zero,
--- returns `buf` as is. If size of `buf` after shifting is greater than `bitmask.MAX_BIT_LIMIT`,
--- an overflow error is returned. If size of `buf` after shifting is zero or less,
--- return a single byte buffer with all bits set to zero.
-- @param buf buffer
-- @param i number
-- @return buffer
function M.arshift(buf: buffer, i: number): buffer
  error('not implemented')
end

-- @param buf buffer
-- @param i number
-- @return buffer
function M.lshift(buf: buffer, i: number): buffer
  error('abstract')
end

-- @param buf buffer
-- @param i number
-- @return buffer
function M.rshift(buf: buffer, i: number): buffer
  error('abstract')
end

--- Rotates `buf` to the left by `i` bits (if `i` is negative, a right rotate is performed instead);
--- the bits that are shifted past the bit width are shifted back from the right.
-- @param buf buffer
-- @param i number
-- @return buffer
function M.lrotate(buf: buffer, i: number): buffer
  error('not implemented')
end

--- Rotates `buf` to the right by `i` bits (if `i` is negative, a left rotate is performed instead);
--- the bits that are shifted past the bit width are shifted back from the left.
-- @param buf buffer
-- @param i number
-- @return buffer
function M.rrotate(buf: buffer, i: number): buffer
  error('not implemented')
end

--- Extracts bits of `buf` at position `field` with a width of `width`, and returns the resulting buffer.
--- `width` defaults to 1, so a two-argument version of extract returns the bit value at position `field`.
--- Bits are indexed starting at 0. Errors if `field` and `field+width-1` are not between 0 and
--- `bitmask.MAX_BIT_LIMIT`.
-- @param buf buffer
-- @param f number
-- @param w number
-- @return number
function M.extract(buf: buffer, f: number, w: number?): buffer
  error('not implemented')
end

-- @param buf buffer
-- @param f number
-- @param f number
-- @param w number
-- @return buffer
function M.replace(buf: buffer, r: number, f: number, w: number?): buffer
  error('abstract')
end

--- Returns the number of consecutive zero bits in `buf` starting from the left-most
--- (most significant) bit. Returns zero if `buf` has size zero.
-- @param buf buffer
-- @return number
function M.countlz(buf: buffer): number
  error('not implemented')
end

--- Returns the number of consecutive zero bits in `buf` starting from the right-most
--- (least significant) bit. Returns zero if `buf` has size zero.
-- @param buf buffer
-- @return number
function M.countrz(buf: buffer): number
  error('not implemented')
end

--- Returns `buf` with the order of bytes swaped.
-- @param buf buffer
-- @return buffer
function M.byteswap(buf: buffer): buffer
  error('not implemented')
end

return M
