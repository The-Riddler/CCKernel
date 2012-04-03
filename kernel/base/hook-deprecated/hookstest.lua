local loaded_chunk = assert(loadfile("rom/riddler/modules/hook/hook.lua"), "Could not locate hooks library")
local hook = loaded_chunk()

print("Enableing debug")
hook:debugEnable(true)

print("--hooklib: "..tostring(hook))
for k,v in pairs(hook) do
  print(k.." "..tostring(v))
end

--[[
hook:add("redstone", "HookTest", function()
    local val = redstone.getInput("back")
    if val == true then 
        for i=1, 10 do
            print(tostring(i))
            os.sleep(1)
        end
    hook:stop()
    end
end)
]]--

hook:add("key", "shownum", function(key)
    print(key)
end)

hook:init()