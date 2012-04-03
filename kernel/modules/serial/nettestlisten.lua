local include = assert(loadfile("rom/lib/include/include.lua"))()

--include.debug = true

local hook = include:add("hook")
local net = include:add("net")

hook:debugEnable(true)
net.debug = true

redstone.setBundledOutput("back", 0)

net:intCrossover("back", 1)
--net:listen("back")
net:setHook()

hook:add("netdataback0", "netlistentest", function(data) term.write("Got data: ") for k,v in pairs(data) do term.write(tostring(v)..",") end hook:stop() end)
hook:init()