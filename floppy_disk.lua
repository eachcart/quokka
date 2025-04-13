-- Quokka flasher image for floppy disks.
-- Instructions:
-- 1. Connect a new blank floppy disk with File Mode & unloacked.
-- 2. Cd to /mnt/<floppy_disk>
-- 3. Wget this file via raw button.
-- 3.1 Press 'raw' button, copy link.
-- 3.2 Type wget and paste your link is shell.
-- 4. Type another command: 'mv floppy_disk.lua init.lua'.

-- Make sure you have installed Quokka or MineOS EFI and selected your floppy disk as bootable in PC where you need to install Quokka.

local component = component
local computer = computer

local eeprom = component.list("eeprom")()
local gpuAddress = component.list("gpu")()
local screenAddress = component.list("screen")()

component.invoke(gpuAddress, "bind", screenAddress)
component.invoke(gpuAddress, "setResolution", 80, 25)

local w, h = component.invoke(gpuAddress, "getResolution")

component.invoke(gpuAddress, "setBackground", 0xCC0000)
component.invoke(gpuAddress, "setForeground", 0xFFFFFF)
component.invoke(gpuAddress, "fill", 1, 1, w, h, " ")

local eraseText = "Erasing EEPROM..."
local flashText = "Flashing EEPROM..."
local x = math.floor((w - #eraseText) / 2)
local y = math.floor(h / 2)
local bottomText = "Do not power off PC, during updating EEPROM."
local bottomX = math.floor((w - #bottomText) / 2)
local bottomY = h - 1

component.invoke(gpuAddress, "set", x, y, eraseText)
component.invoke(gpuAddress, "set", bottomX, bottomY, bottomText)

local function sleep(seconds)
  local deadline = computer.uptime() + seconds
  repeat
    local remaining = deadline - computer.uptime()
    computer.pullSignal(remaining)
  until computer.uptime() >= deadline
end

component.invoke(eeprom, "set", [[
local c = component
local gpu = c and c.gpu
if gpu then
  gpu.set(1, 1, "if you see this, the program has not flashed the eeprom")
end
while true do
  computer.beep(1000, 0.1)
  computer.pullSignal(0.05)
end
]])
sleep(2.5)
component.invoke(gpuAddress, "set", x, y, flashText)
sleep(5)

component.invoke(eeprom, "set", [[local c=component local inv=c.invoke local d,o={},{} local function f(m)local u={"B","KiB","MiB","GiB"}local n=1 while m>1024 and u[n+1]do n=n+1 m=m/1024 end return string.format("%.2f",m).." "..u[n]end local function g(a)local s=inv(a,"readSector",1)for j=1,#s do if s:sub(j,j)=="\0"then s=s:sub(1,j-1)break end end return s end local p=c.list("eeprom")()computer.getBootAddress=function()return inv(p,"getData")end computer.setBootAddress=function(a)return inv(p,"setData",a)end local function h(a)if c.type(a)=="drive"then local k=load(g(a))return not not k elseif c.type(a)=="filesystem"then return(inv(a,"exists","OS.lua")and not inv(a,"isDirectory","OS.lua"))or((not inv(a,"exists","OS.lua"))and inv(a,"exists","init.lua")and not inv(a,"isDirectory","init.lua"))end return false end for a in c.list("drive")do if h(a)then d[#d+1]=a end end for a in c.list("filesystem")do if h(a)then o[#o+1]=a end end local s,t=c.list("screen")(),c.list("gpu")()inv(t,"bind",s)inv(t,"setResolution",inv(t,"maxResolution"))local w,h=inv(t,"getResolution")local stars={}for i=1,math.min(w*h//40,80)do stars[#stars+1]={math.random(1,w),math.random(1,h)}end local function clear()for y=1,h do inv(t,"setBackground",0x000000)inv(t,"fill",1,y,w,1," ")end for _,v in ipairs(stars)do inv(t,"setForeground",0xFFFFFF)inv(t,"set",v[1],v[2],"*")end end local function center(text,y)inv(t,"set",(w-#text)//2,y,text)end local function border(x,y,w,h)local shx=x+w+1 local shy=y+h+1 for i=0,h-1 do inv(t,"setBackground",0x1C1C1C)inv(t,"fill",shx,y+1+i,2,1," ")end for i=0,w+1 do inv(t,"setBackground",0x2A2A2A)inv(t,"fill",x+1+i,shy,1,1," ")end inv(t,"setBackground",0xBFBFBF)inv(t,"setForeground",0x000000)inv(t,"fill",x,y,w,h," ")end local entries={}for _,v in pairs(d)do entries[#entries+1]=v end for _,v in pairs(o)do entries[#entries+1]=v end local bootAddr=computer.getBootAddress()local selected=1 for i,v in ipairs(entries)do if v==bootAddr then selected=i break end end local function draw()clear()center("Quokka",2)center("Use ↑/↓ to choose, Enter to boot",3)center("Memory: "..f(computer.totalMemory()),4)local bw,bh=math.min(w-4,52),math.max(#entries+5,9)local bx,by=(w-bw)//2,(h-bh)//2+2 border(bx,by,bw,bh)for i,v in ipairs(entries)do local label=inv(v,"getLabel")or"Unkown"local text=string.format("[%d] %s",i,label)if i==selected then inv(t,"setForeground",0xFFFFFF)inv(t,"setBackground",0x000000)else inv(t,"setForeground",0x000000)inv(t,"setBackground",0xBFBFBF)end inv(t,"set",(w-#text)//2,by+1+i,text)end inv(t,"setForeground",0x000000)inv(t,"setBackground",0xBFBFBF)end local function boot(a)clear()center((inv(a,"getLabel")or"Unknown"),h//2)computer.setBootAddress(a)if c.type(a)=="filesystem"then local p=inv(a,"exists","/OS.lua")and"/OS.lua"or"/init.lua"local f,e=inv(a,"open",p)if not f then error(e)end local d=""repeat local c=inv(a,"read",f,math.huge)d=d..(c or"")until not c load(d)()elseif c.type(a)=="drive"then load(g(a))()end clear()end if #entries==0 then error("No bootable media found!")end if #entries==1 then boot(entries[1])end draw()while true do local ev,_,_,key=computer.pullSignal()if ev=="key_down"then if key==200 then selected=selected>1 and selected-1 or #entries elseif key==208 then selected=selected<#entries and selected+1 or 1 elseif key==28 then boot(entries[selected])end draw()elseif ev=="touch"then local _,_,_,y=computer.pullSignal()local offset=y-((h-(#entries+5))//2+2)if entries[offset]then if selected==offset then boot(entries[selected])else selected=offset end draw()end end end]])
component.invoke(eeprom, "setLabel", "Quokka")
component.invoke(eeprom, "makeReadonly", component.invoke(eeprom, 'getChecksum'))
computer.shutdown(true)
