--[[
 * Copyright (c) 2015-2020 Iryont <https://github.com/iryont/lua-struct>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
]]
local M={}

local struct = {}

function struct.unpack(format, stream, pos)
    local vars = {}
    local iterator = pos or 1
    local endianness = true
  
    for i = 1, format:len() do
      local opt = format:sub(i, i)
  
      if opt == '<' then
        endianness = true
      elseif opt == '>' then
        endianness = false
      elseif opt:find('[bBhHiIlL]') then
        local n = opt:find('[hH]') and 2 or opt:find('[iI]') and 4 or opt:find('[lL]') and 8 or 1
        local signed = opt:lower() == opt
  
        local val = 0
        for j = 1, n do
          local byte = string.byte(stream:sub(iterator, iterator))
          if endianness then
            val = val + byte * (2 ^ ((j - 1) * 8))
          else
            val = val + byte * (2 ^ ((n - j) * 8))
          end
          iterator = iterator + 1
        end
  
        if signed and val >= 2 ^ (n * 8 - 1) then
          val = val - 2 ^ (n * 8)
        end
  
        table.insert(vars, math.floor(val))
      elseif opt:find('[fd]') then
        local n = (opt == 'd') and 8 or 4
        local x = stream:sub(iterator, iterator + n - 1)
        iterator = iterator + n
  
        if not endianness then
          x = string.reverse(x)
        end
  
        local sign = 1
        local mantissa = string.byte(x, (opt == 'd') and 7 or 3) % ((opt == 'd') and 16 or 128)
        for i = n - 2, 1, -1 do
          mantissa = mantissa * (2 ^ 8) + string.byte(x, i)
        end
  
        if string.byte(x, n) > 127 then
          sign = -1
        end
  
        local exponent = (string.byte(x, n) % 128) * ((opt == 'd') and 16 or 2) + math.floor(string.byte(x, n - 1) / ((opt == 'd') and 16 or 128))
        if exponent == 0 then
          table.insert(vars, 0.0)
        else
          mantissa = (math.ldexp(mantissa, (opt == 'd') and -52 or -23) + 1) * sign
          table.insert(vars, math.ldexp(mantissa, exponent - ((opt == 'd') and 1023 or 127)))
        end
      elseif opt == 's' then
        local bytes = {}
        for j = iterator, stream:len() do
          if stream:sub(j,j) == string.char(0) or  stream:sub(j) == '' then
            break
          end
  
          table.insert(bytes, stream:sub(j, j))
        end
  
        local str = table.concat(bytes)
        iterator = iterator + str:len() + 1
        table.insert(vars, str)
      elseif opt == 'c' then
        local n = format:sub(i + 1):match('%d+')
        local len = tonumber(n)
        if len <= 0 then
          len = table.remove(vars)
        end
  
        table.insert(vars, stream:sub(iterator, iterator + len - 1))
        iterator = iterator + len
        i = i + n:len()
      end
    end
  
    return unpack(vars)
  end

local function checkLocalFile(folder, file)
    if not FS:fileExists(file) then
      local testfn = folder .. file
      if FS:fileExists(testfn) then
        return testfn
      end
    end
    return file
  end
  
local function getSFXLength3(filepath)
    local f = assert(io.open(filepath, "rb"))
    riff, size, fformat = struct.unpack('<4sI4s', f:read(12))
    print("Riff: "..tostring(riff)..", Chunk Size: "..tostring(size)..", format: "..tostring(fformat))

    chunk_header = f:read(8)
    subchunkid, subchunksize = struct.unpack('<4sI', chunk_header)

    aformat, channels, samplerate, byterate, blockalign, bps = struct.unpack('HHIIHH', f:read(16))
    -- bitrate = (samplerate * channels * bps) / 1024
    bitrate = 1000
    print("Format: "..tostring(aformat)..", Channels: "..tostring(channels)..", Sample Rate: "..tostring(samplerate).."Kbps: "..tostring(bitrate))
    -- f:read(4)
    -- print('File sample rate: '..tostring(f:read(4)))
    -- f:read(2)
    -- print('File bits per sample: '..tostring(f:read(2)))
    f:close()
end

local function getSFXLength(filepath)
    local f = assert(io.open(filepath, "rb"))
    print(f)
    local wav_header_size = 44
    -- read in 16 bytes at a time
    local block = 44
    local bytes = f:read(block)
    -- if not bytes then break end
    
    -- for _, b in pairs{string.byte(bytes, 1, -1)} do
    --     print(string.format("%02X ", b))
    -- end
    
    print(string.rep(" ", block - string.len(bytes)))
    print(" "..string.gsub(bytes, "%c", ".").."\n")
    f:close()

    print('\x10')
    print(string.byte('\x10'))
end

local function getSFXLength2(filepath)
    if not FS:fileExists(filepath) then
        print("FILE DOESN'T EXIST UNDER THE PATH: "..filepath)
    else
        local file = readFile(filepath)
        print('FILE READ!')
        print(type(file))
        print(file)
        local f = assert(io.open(filepath, "r"))
        local t = f:read("*all")
        f:close()
        print(t)

    end
end

local function audioUtilsTest()
    print('audioUtils test')
end

M.getSFXLength = getSFXLength
M.audioUtilsTest = audioUtilsTest
M.getSFXLength2 = getSFXLength2
M.getSFXLength3 = getSFXLength3

return M