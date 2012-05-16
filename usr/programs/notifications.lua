local oldterm = term

local screen = {}
local sizex, sizey = oldterm.getSize()
local notifications = {}
local nextNotification = 0
local notificationHadEnteries = false

local function writeToScreen(str)
    local x, y = oldterm.getCursorPos()
    local remaining = sizex-x
    
    if string.len(str) > remaining then
        str = string.sub(str, 1, remaining+1)
    end
    
    local pos = x+((y-1)*sizex)
    for char in string.gmatch(str, ".") do 
        screen[pos] = char
        pos = pos + 1
    end
    oldterm.write(str)
end
    
local function setPos(x, y)
    --pos = x+(sizey*y)
    oldterm.setCursorPos(x, y)
end

local function clear()
    screen = {}
    oldterm.clear()
end

local function scroll(num)
    for i = 1, num*sizex do
        table.remove(screen, 1)
    end
    oldterm.scroll(num)
end

local function write( sText )
	local w,h = term.getSize()		
	local x,y = term.getCursorPos()
	--term.write("POS: "..x.." "..y)
	local nLinesPrinted = 0
	local function newLine()
		if y + 1 <= h then
			term.setCursorPos(1, y + 1)
		else
			term.scroll(1)
			term.setCursorPos(1, h)
		end
		x, y = term.getCursorPos()
		nLinesPrinted = nLinesPrinted + 1
	end
	
	-- Print the line with proper word wrapping
	while string.len(sText) > 0 do
		local whitespace = string.match( sText, "^[ \t]+" )
		if whitespace then
			-- Print whitespace
			term.write( whitespace )
			x,y = term.getCursorPos()
			sText = string.sub( sText, string.len(whitespace) + 1 )
		end
		
		local newline = string.match( sText, "^\n" )
		if newline then
			-- Print newlines
			newLine()
			sText = string.sub( sText, 2 )
		end
		
		local text = string.match( sText, "^[^ \t\n]+" )
		if text then
			sText = string.sub( sText, string.len(text) + 1 )
			if string.len(text) > w then
				-- Print a multiline word				
				while string.len( text ) > 0 do
				if x > w then
					newLine()
				end
					term.write( text )
					text = string.sub( text, (w-x) + 2 )
					x,y = term.getCursorPos()
				end
			else
				-- Print a word normally
				if x + string.len(text) > w then
					newLine()
				end
				term.write( text )
				x,y = term.getCursorPos()
			end
		end
	end
	
	return nLinesPrinted
end

local function print( ... )
	local nLinesPrinted = 0
	for n,v in ipairs( { ... } ) do
		nLinesPrinted = nLinesPrinted + write( tostring( v ) )
	end
	nLinesPrinted = nLinesPrinted + write( "\n" )
	return nLinesPrinted
end


local function redrawScreen()
    local x, y = oldterm.getCursorPos()
    
    local ypos = 1
    oldterm.clear()
    for k, v in pairs(screen) do
        local ypos = math.floor(k/sizex)
        local xpos = k-(sizex*ypos)
        
        oldterm.setCursorPos(xpos, ypos+1)
        oldterm.write(v)
    end
    
    oldterm.setCursorPos(x, y)
end

local function thinkHook()
    if os.clock() >= nextNotification then
        local text = table.remove(notifications)
        if  text ~= nil then
            notificationHadEnteries = true
            nextNotification = os.clock() + 3
            
            local Xper = 0.40
            local Yper = 0.30
            
            local width = math.ceil(sizex*Xper)
            local height = math.ceil(sizey*Yper)
            
            for i=1, height do
                oldterm.setCursorPos(sizex-width, i)
                local str = "|"
                if i ~= height then
                    str = str..string.rep(" ",width)
                end
                oldterm.write(str)
            end
            
            for i=1, width do
                oldterm.write("_")
            end
        elseif notificationHadEnteries == true then
            notificationHadEnteries = false
            redrawScreen()
        end
    end
end

local function addNotification(str)
    table.insert(notifications, str)
end

local newterm = {
    ["write"] = writeToScreen,
    ["setCursorPos"] = setPos,
    ["getCursorPos"] = oldterm.getCursorPos,
    ["getSize"] = oldterm.getSize,
    ["clear"] = clear,
    ["setCursorBlink"] = oldterm.setCursorBlink
}

_G["term"] = newterm
_G["write"] = write
_G["print"] = print
_G["notify"] = addNotification

oldterm.clear()
oldterm.setCursorPos(1,1)

return {
    ["name"] = "notification manager",
    ["hooks"] = {
        ["think"] = thinkHook
    }
}

