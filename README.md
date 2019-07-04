这是个斗地主项目  
skynet服务器，cocos2dx-lua客户端  
先进入3rd git clone https://github.com/jemalloc/jemalloc.git  
再到mySkynetServer目录下 make 'linux'(或者其他平台名称)  
还需要编译pbc项目生成protobuf.so拷贝到luaclib下.git地址(https://github.com/cloudwu/pbc.git)  
修改examples/login/logind.lua 的server.host为本机地址  
服务器运行方式./skynet examples/config.login  
客户端地址https://github.com/pengchengZenjoy/cocosluaSkynetClient.git  