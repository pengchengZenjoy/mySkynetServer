local skynet = require "skynet"

skynet.start(function()
	local FIRRoomList = skynet.newservice("FIRRoomList")
	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated", loginserver)

	skynet.call(gate, "lua", "open" , {
		address = "172.17.56.192",
		port = 8018,
		maxclient = 64,
		servername = "sample",
	})
	--skynet.newservice("simpledb")
	--skynet.newservice("testhttpd")
end)
