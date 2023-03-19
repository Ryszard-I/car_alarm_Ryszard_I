M = {}

-- SOURCE: https://forums.x-plane.org/index.php?/forums/topic/183135-get-wav-file-duration-using-flywithlua/

-- helper function to get 32bit value from binary string
function binToNumber(string)
	return string.byte(string, 1) + string.byte(string, 2)*256 + string.byte(string, 3)*65536 + string.byte(string, 4)*16777216
end

function getWavFileLength(filePath)
	local file = io.open(filePath, "rb")
	local d = 0
	local size = 0
	local byteRate = 0
  	-- file could not be opened?
	if not file then 
		return false 
	end
  	-- unknown format? (Should always start with "RIFF")
	if file:read(4) ~= "RIFF" then 
		file:close()
		return false
	end
  	-- next 4 bytes should be the total length (in bytes)
	size = binToNumber(file:read(4))
  	-- next 4 bytes must always be "WAVE", otherwise unknown format
	if file:read(4) ~= "WAVE" then 
		file:close()
		return false
	end
  	-- next 4 bytes must always be "fmt ", otherwise unknown format
	if file:read(4) ~= "fmt " then
		file:close()
		return false
	end
  	-- skip next 12 bytes
	file:read(12)
  	-- next 4 bytes should be the byte rate (how many bytes per second)
	byteRate = binToNumber(file:read(4))
	file:close()
  	-- take total length minus length of header and divide it by bytes/second --> return length in seconds
	return (size - 42)/byteRate
end

M.getWavFileLength = getWavFileLength

return M