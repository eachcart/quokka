local component = component
local computer = computer

local function sleep(sec)
  local t = computer.uptime()
  while computer.uptime() - t < sec do
    computer.pullSignal(0.05)
  end
end

local gpuAddress = next(component.list("gpu"))
local screenAddress = next(component.list("screen"))
if not gpuAddress or not screenAddress then
  return
end
local gpu = component.proxy(gpuAddress)
gpu.bind(screenAddress)
gpu.setBackground(0x1E1E1E)
gpu.setForeground(0xFFFFFF)
local w, h = gpu.getResolution()
gpu.fill(1, 1, w, h, " ")

local function center(text, y)
  local x = math.floor((w - #text) / 2)
  gpu.set(x, y, text)
end

center("Quokka EEPROM", math.floor(h / 2))
sleep(1)

local fsAddress = next(component.list("filesystem"))
if not fsAddress then
  center("No filesystem found", h)
  sleep(3)
  return
end
local fs = component.proxy(fsAddress)

_G.bootfs = fs
computer.getBootAddress = function() return fsAddress end

local function readFile(path)
  local handle, err = fs.open(path, "r")
  if not handle then return nil, err end
  local data = ""
  repeat
    local chunk = fs.read(handle, math.huge)
    data = data .. (chunk or "")
  until not chunk
  fs.close(handle)
  return data
end

local function loadfile(path)
  local content, err = readFile(path)
  if not content then return nil, err end
  return load(content, "=" .. path)
end

local function dofile(path)
  local f, err = loadfile(path)
  if not f then error(err) end
  return f()
end

_G.loadfile = loadfile
_G.dofile = dofile

if fs.exists("/init.lua") then
  gpu.set(1, h, "/init.lua found, loading...")
  dofile("/init.lua")
elseif fs.exists("/OS.lua") then
  gpu.set(1, h, "/OS.lua found, loading...")
  dofile("/OS.lua")
else
  gpu.set(1, h, "No /init.lua or /OS.lua found")
end

computer.shutdown(true)
