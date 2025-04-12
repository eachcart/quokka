local component = component
local computer = computer

local function sleep(sec)
  local t = computer.uptime()
  while computer.uptime() - t < sec do
    computer.pullSignal(0.1)
  end
end

local gpuAddress = next(component.list("gpu"))
local screenAddress = next(component.list("screen"))

if not gpuAddress or not screenAddress then
  return
end

local gpu = component.proxy(gpuAddress)
gpu.bind(screenAddress)
gpu.setBackground(0xCC0000)
gpu.setForeground(0xFFFFFF) 
local w, h = gpu.getResolution()

local function centerText(y, text)
  local x = math.floor(w / 2 - #text / 2)
  gpu.fill(1, y, w, 1, " ")
  gpu.set(x, y, text)
end

centerText(math.floor(h / 2), "Quokka EEPROM Flasher")

local fsAddress = next(component.list("filesystem"))
if not fsAddress then
  centerText(h, "[ Error: No filesystem found ]")
  sleep(3)
  return
end
local fs = component.proxy(fsAddress)

local function tryOpenFile(path)
  local handle, reason = fs.open(path, "r")
  if not handle then
    return nil, reason
  end
  return handle
end

centerText(h, "[ Flashing firmware . . . ]")
local handle, err = tryOpenFile("/quokka/efi/eeprom.lua")

if not handle then
  centerText(h, "[ Error: " .. tostring(err) .. ", trying to reboot ]")
  sleep(3)
  computer.shutdown(true)
end

local data = ""
while true do
  local chunk = fs.read(handle, 256)
  if not chunk then break end
  data = data .. chunk
  if #data > 4096 then
    fs.close(handle)
    centerText(h, "[ Error: EEPROM too big (>4KB) ]")
    sleep(5)
    return
  end
end
fs.close(handle)

local eepromAddress = next(component.list("eeprom"))
if not eepromAddress then
  centerText(h, "[ Error: No EEPROM found ]")
  sleep(3)
  return
end

local eeprom = component.proxy(eepromAddress)
eeprom.set(data)
eeprom.setLabel("Quokka Firmware")

centerText(h, "[ Flashing Complete! ]")
computer.beep(1500, 0.2)
sleep(0.1)
computer.beep(1800, 0.2)
sleep(2)
computer.shutdown(true)
