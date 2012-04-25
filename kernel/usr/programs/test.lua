print()
print()
print()
print("Something not working?")
print("Never be afraid to try something new. Remember, amateurs built the ark; professionals built the titanic.")

local count = 3
local function thinkfunc()
    count = count - 1
    print(tostring(count))
    if count <= 0 then
        print("If its any consolation though, I'm working!")
        print()
        print()
        procman.terminate()
    end
end

return {
    ["name"] = "test.lua",
    ["hooks"] = {
        ["think"] =  thinkfunc
    }
}