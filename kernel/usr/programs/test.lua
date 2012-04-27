print()
print()
print()
print("Something not working?")
print("Never be afraid to try something new. Remember, amateurs built the ark; professionals built the titanic.")

local mode = ...
local count = 3
local procinfo =  {
    ["name"] = "test.lua"
}

if mode == "-e" then --throw error
    procinfo["main"] = function()
        local errorz = nonExistantVariable["meep"]
    end
else
    procinfo["hooks"] = {
        ["think"] =  function()
            count = count - 1
            print(tostring(count))
            if count <= 0 then
                print("If its any consolation though, I'm working!")
                print()
                print()
                procman.terminate()
            end
        end
    }
end

return procinfo