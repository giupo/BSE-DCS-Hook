-- json 

local json = {}

local Logger = require("logger")
local net = net or { -- @diagnostic disable-line: undefined-global
    lua2json = function(obj)
	    Logger:info("called lua2json")
        return ""
    end
}

function json:dump(obj)
    return net.lua2json(obj)
end

return json
