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
hook:init()