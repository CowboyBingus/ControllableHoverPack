local ffi=require('ffi')
local source=assert(arg[1]);local patch=assert(loadfile(source..'/hover_data.lua'))()
patch.policy=assert(loadfile(source..'/cancel.lua'))()
local rows={};local function put(a,b)for i=1,#b do rows[a+i-1]=b:sub(i,i)end end
local function u(x)return ffi.string(ffi.new('uint32_t[1]',x),4)end
local function p(x)return ffi.string(ffi.new('uint64_t[1]',x),8)end
local function f(x)return ffi.string(ffi.new('float[1]',x),4)end
local function zero(a,n)put(a,string.rep('\0',n))end
local function ent(a,hex,id,unit,owned)
    put(a,hex:gsub('..',function(x)return string.char(tonumber(x,16))end):reverse()..u(id)..u(unit)..u(5)..u(owned and 1 or 0))
end
local G=0x10000000;local nextmap=0x20000000
local function map(a,key,index)
    local t=nextmap;nextmap=nextmap+0x100
    put(a,p(t)..u(8)..u(0xffffffff)..u(1))
    for i=0,7 do put(t+8*i,u(0xffffffff)..u(0xffffffff))end
    put(t+8*(key%8),u(key)..u(index))
end
local mode,pm,em,am,eq,jm,attach=0x30000000,0x31000000,0x32000000,0x34000000,0x35000000,0x36000000,0x37000000
for rva,a in pairs({[0x276c3d0]=mode,[0x276c190]=pm,[0x276f0c0]=em,[0x276ca30]=am,[0x276c468]=eq,[0x276c8d0]=jm,[0x276cad0]=attach})do put(G+rva,p(a))end
zero(mode,0x44);put(mode+8,u(1));put(mode+0x40,u(1))
put(pm+0x84,u(2)..u(2));put(pm+0xe8,p(0x40000000));ent(0x40000000,'1111111111111111',10,99,true)
put(pm+0x3a8,u(391));map(em+0xf21a88,391,2)
local avatar=em+0xf31ad8+48;ent(avatar,'4d1c334d294dfa97',513,391,true)
map(am+0xf8,513,1);put(am+0x6c,u(2));put(am+0x118,p(avatar)) -- local index ONE
map(eq+40,513,1);put(eq+64,p(0x41000000));put(0x41000008,p(avatar));put(eq+80,p(0x42000000));put(0x42000000+48+12,u(524))
map(jm+32,524,1);put(jm+16,u(2)..u(2));put(jm+56,p(0x43000000));put(0x43000008,p(0x44000000));ent(0x44000000,'5ec80f4f1cdb66cf',524,250,true)
map(attach+32,524,1);put(attach+64,p(0x45000000));put(0x45000000+48+4,u(513))
local flags=am+0x53d900+0x1238+0xf80;zero(flags,24);put(flags+8,u(0x80000004))
put(jm+80,p(0x46000000));put(0x46000005,'\1\0\1\0\1')
local input=am+0x150+0xa7aec+0x1b68+15*32;zero(input,32)
local focused=true;local commands=0;local missing
local api={focused=function()return focused end}
api.pointer=function(b,o)if not b then return nil end;local v=ffi.new('uint64_t[1]');ffi.copy(v,b:sub((o or 0)+1),8);return tonumber(v[0])~=0 and tonumber(v[0]) or nil end
api.read=function(a,n)
    if missing==a then return nil end
    local b={};for i=0,n-1 do if not rows[a+i] then return nil end;b[#b+1]=rows[a+i]end;return table.concat(b)
end
patch.settings={cancel=function(_,_,s)assert(s.manager==jm and s.pack==524);commands=commands+1;return true end,
    restore=function(_,_,state)state.lease=nil;return true end}
local state={}
local snap=assert(patch.snapshot(api,G));assert(snap.flight and not snap.down and snap.pack==524)
assert(patch.current(api,snap))
-- Mission +0x40 is a type, not a boolean. Type 2 was captured live during
-- Evacuate High-Value Assets; the native player path accepts types 1 through 7.
for kind=1,7 do
    put(mode+0x40,u(kind));assert(patch.snapshot(api,G),'valid mission type rejected: '..kind)
end
for _,kind in ipairs({0,8,0xffffffff})do
    put(mode+0x40,u(kind));assert(select(2,patch.snapshot(api,G))=='waiting_for_mission')
end
put(mode+0x40,u(2));put(mode+8,u(0));assert(select(2,patch.snapshot(api,G))=='waiting_for_mission')
put(mode+8,u(1)) -- run all remaining ownership/input guards in mission type 2
put(input+8,f(.3));patch.apply(api,G,0,state,1/60);assert(commands==0)
put(input+8,f(0));patch.apply(api,G,0,state,1/60)
put(input+8,f(.01));assert(patch.apply(api,G,0,state)=='cancel_requested');assert(commands==1)
patch.apply(api,G,0,state);assert(commands==1)
focused=false;patch.apply(api,G,0,state);focused=true;patch.apply(api,G,0,state);assert(commands==1)
-- Owner mismatch, wrong resource, missing live data, and local-not-zero all use production reader.
put(0x45000000+48+4,u(999));assert(select(2,patch.snapshot(api,G))=='pack_not_attached');patch.apply(api,G,0,state)
put(0x45000000+48+4,u(513));ent(0x44000000,'073270650f859dd0',524,250,true);assert(select(2,patch.snapshot(api,G))=='not_hover_pack')
ent(0x44000000,'5ec80f4f1cdb66cf',524,250,true)
missing=pm+0xe8;assert(patch.apply(api,G,0,state)=='waiting_for_read');missing=nil
patch.apply(api,G,0,state);assert(commands==1)
put(input+8,f(0));patch.apply(api,G,0,state);put(input+8,f(.01));patch.apply(api,G,0,state);assert(commands==2)
-- Native action inhibited during ragdoll, swim, ordinary grounded movement.
for _,offset in ipairs({12,8})do
 local old=api.read(flags+offset,4);put(flags+offset,u(offset==12 and 2 or 0x90000004));assert(not patch.snapshot(api,G).flight);put(flags+offset,old)
end
put(0x46000005,'\0\0\1\0\0');assert(not patch.snapshot(api,G).flight)
-- Landing assistance remains an active flight, but is not a new cancel window.
put(0x46000005,'\1\1\1\0\1');snap=patch.snapshot(api,G);assert(snap.active and not snap.flight)
state.lease={key=snap.key};focused=false
assert(patch.apply(api,G,0,state)=='native_descent' and state.lease)
put(0x46000005,'\0\0\1\0\0');patch.apply(api,G,0,state);assert(not state.lease)
focused=true
-- +0x14 is the locally simulated prefix, inside the +0x10 active prefix.
put(jm+16,u(3)..u(2));assert(patch.snapshot(api,G).pack==524)
put(jm+16,u(3)..u(1));assert(select(2,patch.snapshot(api,G))=='pack_not_owned')
put(jm+16,u(2)..u(2))
-- Fresh guard validation rejects a replacement attachment before the native call.
put(0x46000005,'\1\0\1\0\1');snap=patch.snapshot(api,G);put(0x45000000+48+4,u(999));assert(not patch.current(api,snap))
-- Keep the production hook installed across mission teardown and re-entry.
-- A registry can temporarily disagree with an entity while it is removed.
put(0x45000000+48+4,u(513));put(input+8,f(0))
api.time=function()return 1 end
api.module=function(name)return name and G or 2 end
api.module_hash=function(m)return tostring(m)end
local e=setmetatable({CowboyBingusModLoader={api=1,version=12},print=function()end,
    os={getenv=function()end}}, {__index=_G})
e._G=e;e.update=function(...)return ... end
setfenv(assert(loadfile(source..'/archive_loader.lua'))(),e)(function()return api end,patch,
    {revision='test',game_sha256=tostring(G),exe_sha256='2'})
local function tick()e.update(1/60)end
local function flight()
    put(0x46000005,'\0\0\1\0\0');tick()
    put(0x46000005,'\1\0\1\0\1');put(input+8,f(.3));tick()
    put(input+8,f(0));tick()
    local before=commands;put(input+8,f(.01));tick()
    assert(commands==before+1,'cancellation stopped after mission transition')
end
flight()
for kind=1,7 do put(mode+0x40,u(kind));flight()end
put(mode+0x40,u(2))
for _,transition in ipairs({
    {am+0x6c,u(0),'avatar registry removal'},
    {0x44000000+8,u(525),'pack registry replacement'},
    {eq+64,p(0),'equipment pointer unavailable'},
    {pm+0x84,u(0)..u(0),'local player removed'},
    {mode+0x40,u(0),'return to ship'},
})do
    local address,bytes=transition[1],transition[2];local original=api.read(address,#bytes)
    put(address,bytes);local before=commands;tick();tick()
    assert(commands==before,'cancellation during '..transition[3])
    put(address,original)
    -- Mission re-entry replaces the pack generation, without reinstalling Lua.
    put(0x44000000+16,u(5+commands));flight()
end
-- A persistent invalid registry remains read-only, then recovers when valid.
local original=api.read(am+0x6c,4);put(am+0x6c,u(0));local before=commands
for i=1,20 do tick()end
assert(commands==before);put(am+0x6c,original);flight()
assert(e.HoverPackCancel.snapshot_waits>=2 and e.HoverPackCancel.last_snapshot_error)
print('PASS: installed production hook recovers through repeated mission/player/pack transitions without reload')
print('PASS: production snapshot at local index one, exact pack/holder, input, recovery, focus, ordinary pack, grounded/ragdoll/swim and stale guards')
