-- json 

local json = {}

local Logger = require("logger")
local net = net or {
    lua2json = function(obj)
	Logger:info("called lua2json")
    end
}


function json:dump(obj)
    local data, err = pcall(function() net.lua2json(obj) end)
    if err ~= nil then
	Logger:info("Error dumping JSON data...")
    end

    return data
end


return json
