local include = assert(loadfile("rom/lib/include/include.lua"))()

--include.debug = true

local hook = include:add("hook")
local net = include:add("net")

hook:debugEnable(true)
net.debug = true

redstone.setBundledOutput("back", 0)

net:sendTable("back", {3, 5, 7, 9, 11, 13, 15})

net:setHook()
hook:init()