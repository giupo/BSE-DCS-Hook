local config = {
    PKGNAME = "BSE-Export",
    VERSION = "0.2.0",

    -- this is the address towards who we are flooding with DCS data.
    -- usually this should be our middleware that exposes data as a REST API
    --
    -- This is where you wanna change the ip if the relay is not on the same
    -- host where DCS is running.
    
    relay_address = {
	    ip = "10.17.17.8",
        port = 6666
    },

    -- Number of packets (UDP packets) per frame allowed to send
    -- this is used to not flood and hung DCS waiting for I/O ops.
    max_send_ops = 256
}

return config
