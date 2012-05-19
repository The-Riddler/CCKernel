local filename, side = ...
print(table.concat({ ... }, "-"))
if not fs.exists(filename) or fs.isDir(filename) then
    error("Argument is not a file:"..filename)
end

if not peripheral.isPresent(side) or peripheral.getType(side) ~= "monitor" then
    error("No monitor on side: "..side)
end

local monitor = peripheral.wrap(side)
local width, height = monitor.getSize()
monitor.setCursorPos(1,1)
monitor.write("tail initialized: "..width..","..height)

local function think()
    local file = fs.open(filename, "r")
    local lines = {}
    local line = ""
    repeat
        line = file.readLine()
        if line ~= nil then
            table.insert(lines, line)
        end
    until line == nil
    
    file.close()
    for i=0, math.min(height, #lines)-1 do
        monitor.setCursorPos(1, height-i)
        monitor.write(lines[#lines-i])
    end
end

return {
    ["name"] = "tail "..filename,
    ["hooks"] = {
        ["think"] = think
    }
}