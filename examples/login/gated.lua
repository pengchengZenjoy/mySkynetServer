local msgserver = require "snax.msgserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"

local loginservice = tonumber(...)

local server = {}
local users = {}
local username_map = {}
local internal_id = 0

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
function server.login_handler(uid, secret)
	if users[uid] then
		error(string.format("%s is already login", uid))
	end

	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, id, servername)

	-- you can use a pool to alloc new agent
	local agent = skynet.newservice "msgagent"
	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = id,
	}

	-- trash subid (no used)
	skynet.call(agent, "lua", "login", uid, id, secret, username)

	users[uid] = u
	username_map[username] = u

	msgserver.login(username, secret)

	-- you should return unique subid
	return id
end

function server.enter_Room(uid, roomId)
	skynet.error("enter_Room gated uid="..tostring(uid))
	skynet.error("enter_Room gated roomId="..tostring(roomId))
	u = users[uid]
	if u then
		u.roomId = roomId
	end
end

function server.exit_Room(uid)
	skynet.error("exit_Room gated uid="..tostring(uid))
	u = users[uid]
	if u then
		u.roomId = nil
	end
end

-- call by agent
function server.logout_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.logout(u.username)
		users[uid] = nil
		username_map[u.username] = nil
		skynet.call(loginservice, "lua", "logout",uid, subid)
	end
end

-- call by login server
function server.kick_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		pcall(skynet.call, u.agent, "lua", "logout")
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		if u.roomId then
			pcall(skynet.call, u.roomId, "lua", "afk", u.uid)
			u.roomId = nil
		end
		skynet.call(u.agent, "lua", "afk")
	end
end

-- call by self (when recv a request from client)
function server.request_handler(username, msg)
	local u = username_map[username]
	--return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
	if u.roomId then
		local curRoomId = u.roomId
		if msg.msgId == "EXITROOM" then
			u.roomId = nil
		end
		return skynet.tostring(skynet.rawcall(curRoomId, "client", skynet.pack(u.uid, msg)))
	else
		return skynet.tostring(skynet.rawcall(u.agent, "client", skynet.pack(msg)))
	end
end

function server.broadcast_handler(msg)
	for fd,userInfo in pairs(users) do
		print("BROADCAST msg.msgId="..msg.msgId)
		print("BROADCAST userInfo.username="..userInfo.username)
		local fd = msgserver.getFd(userInfo.username)
		skynet.send(userInfo.agent, "lua", "broadCastMsg", fd, msg)
	end
end

-- call by self (when gate open)
function server.register_handler(name)
	servername = name
	skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
end

msgserver.start(server)

