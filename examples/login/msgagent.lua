local skynet = require "skynet"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
}

local gate
local userid, subid

local function send_package(msgTb)
	skynet.ret(skynet.pack(msgTb))
end

local CMD = {}

function CMD.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	skynet.error(string.format("%s is login", uid))
	gate = source
	userid = uid
	subid = sid
	-- you may load user data from database
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", userid, subid)
	end
	skynet.exit()
end

function CMD.logout(source)
	-- NOTICE: The logout MAY be reentry
	skynet.error(string.format("%s is logout", userid))
	logout()
end

function CMD.afk(source)
	-- the connection is broken, but the user may back
	skynet.error(string.format("AFK"))
end

function CMD.broadCastMsg(source, fd, data)
	skynet.error("broadCastMsg 数据编码：msgid="..data.msgId)
    skynet.error("broadCastMsg 数据编码：chatContent="..data.chatInfo.chatContent)
	-- todo: do something before exit
	local pb_body = {
        msgId = "CHAT",
        chatList = {
	        {
	        	chatContent = data.chatInfo.chatContent
	    	}
    	}
    }
	--local sendMsg = protobuf.encode("s2c.S2CMsg",pb_body)
	--socketdriver.send(fd, netpack.pack(sendMsg))
	skynet.send(gate, "lua", "sendMsg", fd, pb_body)
end

local function request(messageTb)
	messageTb = skynet.unpack(messageTb)
	msgId = messageTb.msgId
	skynet.error("msgagent userid="..tostring(userid))
	skynet.error("msgagent messageTb.msgId="..tostring(messageTb.msgId))
	
    if msgId == "CHAT" then
    	local chatContent = messageTb.chatInfo.chatContent
    	if chatContent == "clear all" then
    		local r = skynet.call("SIMPLEDB", "lua", "clearAll")
    	else
	    	local r = skynet.send("SIMPLEDB", "lua", "insertChat", messageTb.chatInfo.chatContent)
	    	skynet.send(gate, "lua", "broadcast", messageTb)
	    end
	    local info = {}
	    info.cancelResult = true
	    skynet.ret(skynet.pack(info))
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
	    local msgTb = {
	        msgId = "CHATLIST",
	        chatList = newChatObj
	    }
		send_package(msgTb)
	elseif msgId == "GETROOMLIST" then
		local curRoomList = skynet.call("FIRRoomList", "lua", "getRoomList")
		local myRootList = {}
		for k,v in ipairs(curRoomList) do
			skynet.error("roomList type(v)="..type(v))
			skynet.error("roomList v="..tostring(v))
			table.insert(myRootList, v)
		end
		local msgTb = {
	        msgId = "ROOMLIST",
	        roomList = myRootList
	    }
		send_package(msgTb)
	elseif msgId == "ENTERROOM" then
		local curRoomId = messageTb.roomId
		skynet.error("ENTERROOM roomId="..curRoomId)
		--local curRoomList = skynet.call(curRoomId, "lua", "enterRoom", )
		local msgTb = {
	        msgId = "ENTERROOMSUCCESS",
	        roomId = curRoomId
	    }
		send_package(msgTb)
    end
end

skynet.start(function()

	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(source, ...)))
	end)

	skynet.dispatch("client", function(_,_, messageTb)
		-- the simple echo service
		request(messageTb)
	end)
end)
