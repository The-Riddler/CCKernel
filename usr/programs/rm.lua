local targs = {...}

if not type(targs[1]) == "string" then
    error("Invalid argument type")
end

local ok, err = kernel.fs.delete(targs[1])

if ok then
    print("Deleted: "..targs[1])
else
    print("Could not delete: "..targs[1]..", "..tostring(err))
end