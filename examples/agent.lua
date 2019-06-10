local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local protobuf = require "protobuf"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd

function REQUEST:get()
	print("get", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	print("set", self.what, self.value)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

local function request(msg, sz)
	--[[local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end]]
	local data = protobuf.decode("c2s.C2SMsg",msg)
	skynet.error("agent 数据编码：msgid="..data.msgId)
    skynet.error("agent 数据编码：chatContent="..data.chatInfo.chatContent)
    local msgId = data.msgId
    if msgId == "CHAT" then
    	local chatContent = data.chatInfo.chatContent
    	if chatContent == "clear all" then
    		local r = skynet.call("SIMPLEDB", "lua", "clearAll")
    	else
    		local r = skynet.call("SIMPLEDB", "lua", "insertChat", chatContent)
    		skynet.call(WATCHDOG, "lua", "BROADCAST", data)
    	end
    elseif msgId == "GETCHATLIST" then
    	local chatList = skynet.call("SIMPLEDB", "lua", "GETCHATLIST", nil)
		local newChatObj = {}
	    for i=1, #chatList do
	    	local chatInfo = chatList[i]
	    	skynet.error("GETCHATLIST chatInfo.chat_id="..chatInfo.chat_id)
	    	skynet.error("GETCHATLIST chatInfo.chat_content="..chatInfo.chat_content)
	    	local info = {}
			info.chatContent = chatInfo.chat_content
	    	table.insert(newChatObj, info)
	    end
	    local pb_body = protobuf.encode("s2c.S2CMsg",
	    {
	        msgId = "CHATLIST",
	        chatList = newChatObj
	    })
		send_package(pb_body)
    end

    --[[local pb_body = protobuf.encode("s2c.S2CMsg",
    {
        msgId = "CHATLIST",
        chatList = {
	        {
	        	chatContent = "s2c chat list content11"
	    	},
	    	{
	        	chatContent = "s2c chat list content22"
	    	}
    	}
    })
    skynet.error("agent pb_body="..pb_body)
    skynet.error("agent #pb_body="..#pb_body)
    send_package(pb_body)]]
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	--[[unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,]]
	unpack = function (msg, sz)
		return skynet.tostring(msg, sz),sz
	end,
	dispatch = function (fd, _, msg,sz)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		skynet.trace()
		print("pc77 msg=", msg)
		print("pc77 sz=", sz)
		if true then --type == "REQUEST" then
			--local ok, result  = pcall(request, ...)
			request(msg, sz)
			--[[if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end]]
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	--host = sprotoloader.load(1):host "package"
	--send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			--send_package(send_request "heartbeat")
			--send_package("heartbeat")
			skynet.sleep(500)
		end
	end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

function CMD.broadCastMsg(data)
	skynet.error("broadCastMsg 数据编码：msgid="..data.msgId)
    skynet.error("broadCastMsg 数据编码：chatContent="..data.chatInfo.chatContent)
	-- todo: do something before exit
	local pb_body = protobuf.encode("s2c.S2CMsg",
    {
        msgId = "CHAT",
        chatList = {
	        {
	        	chatContent = data.chatInfo.chatContent
	    	}
    	}
    })
	send_package(pb_body)
end

skynet.start(function()
	protobuf.register_file "./protos/C2SMsg.pb"
	protobuf.register_file "./protos/S2CMsg.pb"

	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
