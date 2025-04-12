local component = require("component")
local computer = require("computer")
local internet = component.internet

local function sleep(sec)
  local t = computer.uptime()
  while computer.uptime() - t < sec do
    computer.pullSignal(0.1)
  end
end

local function downloadFile(url, path)
  local handle, err = internet.request(url)
  if not handle then
    print("[ Error: " .. err .. " ]")
    return false
  end

  local fsAddress = next(component.list("filesystem"))
  if not fsAddress then
    print("[ Error: No filesystem found ]")
    return false
  end
  local fs = component.proxy(fsAddress)

  local file, err = fs.open(path, "w")
  if not file then
    print("[ Error: " .. err .. " ]")
    return false
  end

  repeat
    local chunk, err = handle.read(1024)
    if chunk then
      fs.write(file, chunk)
    end
  until not chunk

  fs.close(file)
  handle.close()

  return true
end

local eepromFileUrl = "https://raw.githubusercontent.com/eachcart/quokka/refs/heads/main/assets/eeprom.lua"
local flasherFileUrl = "https://raw.githubusercontent.com/eachcart/quokka/refs/heads/main/assets/flash.lua"
local savePathEeprom = "/quokka/efi/eeprom.lua"
local savePathFlasher = "/quokka/efi/flasher.lua"

print("[ Downloading eeprom.lua . . . ]")
local success = downloadFile(eepromFileUrl, savePathEeprom)
if not success then
  print("[ Error: Download of eeprom.lua failed ]")
  return
end

print("[ Downloading flasher.lua . . . ]")
success = downloadFile(flasherFileUrl, savePathFlasher)
if not success then
  print("[ Error: Download of flasher.lua failed ]")
  return
end

local function flashFile(filePath)
  local fsAddress = next(component.list("filesystem"))
  if not fsAddress then
    print("[ Error: No filesystem found ]")
    return
  end
  local fs = component.proxy(fsAddress)

  local handle, err = fs.open(filePath, "r")
  if not handle then
    print("[ Error: Unable to open file " .. filePath .. " ]")
    return
  end

  local data = ""
  while true do
    local chunk = fs.read(handle, 256)
    if not chunk then break end
    data = data .. chunk
  end
  fs.close(handle)

  local eepromAddress = next(component.list("eeprom"))
  if not eepromAddress then
    print("[ Error: No EEPROM found ]")
    return
  end

  local eeprom = component.proxy(eepromAddress)
  eeprom.set(data)
  eeprom.setLabel("Flasher Script")

  print("[ Flashing Complete! Rebooting . . . ]")
  computer.beep(1500, 0.2)
  sleep(0.1)
  computer.beep(1800, 0.2)
  sleep(2)
  computer.shutdown(true)
end

flashFile(savePathFlasher)
