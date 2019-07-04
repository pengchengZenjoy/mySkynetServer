local skynet = require "skynet"

skynet.start(function()
	local GameRoomList = skynet.newservice("GameRoomList")
	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated", loginserver)

	skynet.call(gate, "lua", "open" , {
		port = 8018,
		maxclient = 64,
		servername = "sample",
	})
	--skynet.newservice("simpledb")
	--skynet.newservice("testhttpd")
end)
