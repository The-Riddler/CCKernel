for k,v in pairs(colors) do
  local val = rs.testBundledInput("back", v)
  print(k.." - "..tostring(val))
  os.sleep(0.5)
end

print("Sum "..rs.getBundledInput("back"))
