local include = assert(loadfile("rom/lib/include/include.lua"))()

--include.debug = true

local hook = include:add("hook")
local net = include:add("net")

hook:debugEnable(true)
net.debug = true

redstone.setBundledOutput("back", 0)

local datatosend ={3, 5, 7, 9, 11, 13, 15}
local num = 0
for i=0, 256 do
    table.insert(datatosend, num)
    num = num + 1
    if num >= 15 then num = 0 end
end

net:sendTable("back", datatosend)

net:setHook()
hook:init()