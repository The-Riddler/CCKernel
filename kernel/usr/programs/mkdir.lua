local targs = {...}

if not type(targs[1]) == "string" then
    error("Invalid argument type")
end

local ok, err = kernel.fs.mkdir(targs[1])

if ok then
    print("Created: "..targs[1])
else
    print("Could not create directory: "..targs[1]..", "..tostring(err))
end