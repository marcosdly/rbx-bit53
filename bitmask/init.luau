--!strict

-- 1GB in bytes
local MAX_BYTE_LIMIT = 1024 ^ 3

--- 1GB in bits
local MAX_BIT_LIMIT = 8 * 1024 ^ 3

local bitmask = { MAX_BIT_LIMIT = MAX_BIT_LIMIT, MAX_BYTE_LIMIT = MAX_BYTE_LIMIT }

--- Abstract declarations for bitmask library functions

--- Performs a bitwise `and` of all input numbers and returns the result.
--- If the function is called with no arguments, a single byte buffer with all bits set to 1
--- is returned.
-- @param ... buffer \ number
-- @return buffer
function bitmask.band(...: buffer): buffer
	error("not implemented")
end

--- Performs a bitwise or of all input buffers and returns the result. If the function
--- is called with no arguments, a single byte buffer with all bits set to zero is returned.
-- @param buf buffer
-- @param ... number
-- @return buffer
function bitmask.bor(buf: buffer): buffer
	error("not implemented")
end

--- Performs a bitwise `xor` (exclusive or) of all input numbers and returns the result.
--- If the function is called with no arguments, is called with no arguments, a single
--- byte buffer with all bits set to zero is returned.
-- @param buf buffer
-- @param ... number
-- @return buffer
function bitmask.bxor(...: buffer): buffer
	error("not implemented")
end

--- Returns a bitwise negation of the input buffer.
-- @param buf buffer
-- @return buffer
function bitmask.bnot(buf: buffer): buffer
	error("not implemented")
end

--- Perform a bitwise `and` of all input numbers, and return true if the result is not zero.
--- If the function is called with no arguments, `true` is returned.
-- @param ... buffer
-- @return boolean
function bitmask.btest(...: buffer): boolean
	error("not implemented")
end

--- Shifts `buf` by `i` bits to the right (if `i` is negative, a left shift is performed instead).
--- The most significant bit of `buf` is propagated during the shift. When `i` is zero,
--- returns `buf` as is. If size of `buf` after shifting is greater than `bitmask.MAX_BIT_LIMIT`,
--- an overflow error is returned. If size of `buf` after shifting is zero or less,
--- return a single byte buffer with all bits set to zero.
-- @param buf buffer
-- @param i number
-- @return buffer
function bitmask.arshift(buf: buffer, i: number): buffer
	error("not implemented")
end

-- @param buf buffer
-- @param i number
-- @return buffer
function bitmask.lshift(buf: buffer, i: number): buffer
	error("abstract")
end

-- @param buf buffer
-- @param i number
-- @return buffer
function bitmask.rshift(buf: buffer, i: number): buffer
	error("abstract")
end

--- Rotates `buf` to the left by `i` bits (if `i` is negative, a right rotate is performed instead);
--- the bits that are shifted past the bit width are shifted back from the right.
-- @param buf buffer
-- @param i number
-- @return buffer
function bitmask.lrotate(buf: buffer, i: number): buffer
	error("not implemented")
end

--- Rotates `buf` to the right by `i` bits (if `i` is negative, a left rotate is performed instead);
--- the bits that are shifted past the bit width are shifted back from the left.
-- @param buf buffer
-- @param i number
-- @return buffer
function bitmask.rrotate(buf: buffer, i: number): buffer
	error("not implemented")
end

--- Extracts bits of `buf` at position `field` with a width of `width`, and returns the resulting buffer.
--- `width` defaults to 1, so a two-argument version of extract returns the bit value at position `field`.
--- Bits are indexed starting at 0. Errors if `field` and `field+width-1` are not between 0 and
--- `bitmask.MAX_BIT_LIMIT`.
-- @param buf buffer
-- @param field number
-- @param width number
-- @return number
function bitmask.extract(buf: buffer, field: number, width: number?): buffer
	error("not implemented")
end

--- Extract a single bit from `buf`. Returns either zero or 1 as a number.
-- @param buf buffer
-- @param field number
-- @return number
function bitmask.getbit(buf: buffer, field: number): number
	error("not implemented")
end

--- Extract a single bit from `buf` as boolean.
-- @param buf buffer
-- @param field number
-- @return boolean
function bitmask.getboolean(buf: buffer, field: number): boolean
	error("not implemented")
end

--- Sets all bits of `buf` to `bitvalue`, a number that is either zero or 1.
-- @param buf buffer
-- @param biivalue number
-- @return buffer
function bitmask.fill(buf: buffer, bitvalue: number): buffer
	error("not implemented")
end

-- @param buf buffer
-- @param bitvalue number
-- @param field number
-- @param width number
-- @return buffer
function bitmask.replace(buf: buffer, bitvalue: number, field: number, width: number?): buffer
	error("abstract")
end

--- Returns the number of consecutive zero bits in `buf` starting from the left-most
--- (most significant) bit. Returns zero if `buf` has size zero.
-- @param buf buffer
-- @return number
function bitmask.countlz(buf: buffer): number
	error("not implemented")
end

--- Returns the number of consecutive zero bits in `buf` starting from the right-most
--- (least significant) bit. Returns zero if `buf` has size zero.
-- @param buf buffer
-- @return number
function bitmask.countrz(buf: buffer): number
	error("not implemented")
end

--- Returns `buf` with the order of bytes swaped.
-- @param buf buffer
-- @return buffer
function bitmask.byteswap(buf: buffer): buffer
	error("not implemented")
end

return bitmask
