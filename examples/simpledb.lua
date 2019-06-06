local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

require "skynet.manager"	-- import skynet.register
local db = {}

local mysqlDb

local command = {}

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

function command.GET(key)
	return db[key]
end

function command.SET(key, value)
	local last = db[key]
	db[key] = value
	return last
end

function command.INSERTCHAT(chatContent)
	skynet.error("insertChat chatContent=",chatContent)
	local insertStr = "insert into chatlist (chat_content) values (\""..chatContent.."\")"
	res = mysqlDb:query(insertStr)
	print ( dump( res ) )
end

function command.GETCHATLIST()
	local chatList = mysqlDb:query("select * from chatlist order by chat_id asc")
	print ( dump( chatList ) )
	return chatList
end

skynet.start(function()
	local function on_connect(mysqlDb)
		mysqlDb:query("set charset utf8");
	end
	mysqlDb = mysql.connect({
		host="127.0.0.1",
		port=3306,
		database="skynet",
		user="root",
		password="12345678",
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
	if not mysqlDb then
		print("failed to connect")
	end

	skynet.dispatch("lua", function(session, address, cmd, ...)
		cmd = cmd:upper()
		if cmd == "PING" then
			assert(session == 0)
			local str = (...)
			if #str > 20 then
				str = str:sub(1,20) .. "...(" .. #str .. ")"
			end
			skynet.error(string.format("%s ping %s", skynet.address(address), str))
			return
		end
		local f = command[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
--	skynet.traceproto("lua", false)	-- true off tracelog
	skynet.register "SIMPLEDB"
end)
