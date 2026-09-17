local ffi=require('ffi')
local settings=assert(loadfile(assert(arg[1])..'/settings.lua'))()
local function u(n)return ffi.string(ffi.new('uint32_t[1]',n),4)end
local function p(n)return ffi.string(ffi.new('uint64_t[1]',n),8)end
local function f(n)return ffi.string(ffi.new('float[1]',n),4)end
local function number(b,t)local v=ffi.new(t..'[1]');ffi.copy(v,b,ffi.sizeof(v));return tonumber(v[0])end
local G,J,E,R,D=0x10000000,0x20000000,0x30000000,0x40000000,0x50000000
local function fixture()
    local mem,writes={},{}
    local function put(a,b)for i=1,#b do mem[a+i-1]=b:sub(i,i)end end
    local function read(a,n)local b={};for i=0,n-1 do if not mem[a+i] then return nil end;b[#b+1]=mem[a+i]end;return table.concat(b)end
    local function map(offset,address,key,index,empty)
        put(J+offset,p(address)..u(8)..u(empty)..u(2))
        for i=0,7 do put(address+8*i,u(empty)..u(0))end
        if key then put(address+8*((key*2)%8),u(key)..u(index))end
    end
    local identity=('cf66db1c4f0fc85e'):gsub('..',function(x)return string.char(tonumber(x,16))end)..u(524)..u(250)..u(5)
    put(G+0x276c8d0,p(J));put(G+0x276f0c0,p(E));put(E+0xf11890,p(R))
    put(J+4,u(32));put(J+12,u(1));put(J+152,u(0));put(J+160,p(D))
    map(32,J+0x1000,524,0,0);map(96,J+0x1100,nil,nil,0);map(128,J+0x1200,nil,nil,0xffffffff)
    put(J+56,p(J+0x1300));put(J+0x1300,p(J+0x1400));put(J+0x1400,identity)
    put(R,string.rep('\0',96));put(R,identity:sub(1,8)..u(0)..u(0))
    local component=string.rep('\0',153)..'\1'..'\1\1'..f(6)..string.rep('\0',120)
    assert(#component==280);put(R+96,component);put(D,string.rep('\0',560))
    local api={read=read,pointer=function(b,o)return number(b:sub((o or 0)+1,(o or 0)+8),'uint64_t')end,
        writable_data=function()return true end}
    api.write=function(a,b)writes[#writes+1]={a,b};put(a,b);return true end
    return api,{manager=J,pack=524,identity=identity,key='flight'},put,writes,component
end
local function duration(api,address)return number(api.read(address+156,4),'float')end
-- Predicate recovered from the native hover consumer: landing overrides expiry.
local function native_lift(active,landing,air,limit)
    assert(limit>0);return active and (limit>air or landing)
end
local api,target,put,writes,original=fixture();local state={}
assert(native_lift(true,false,2,6))
assert(settings.cancel(api,G,target,state));assert(state.lease and #writes==5)
assert(api.read(R+96,280)==original,'shared/squad settings changed')
local limit=duration(api,D);assert(limit>0 and limit<.002)
assert(not native_lift(true,false,2,limit),'manual press failed to enter native descent')
assert(native_lift(true,true,3,limit),'native landing brake disabled')
assert(settings.restore(api,G,state) and not state.lease and state.restorations==1)
assert(duration(api,D)==6 and native_lift(true,false,2,duration(api,D)),'next flight shortened')
assert(api.read(D,280)==original)
-- Reuse the override without touching its other fields or growing the table.
put(D+40,f(1.5));local count=#writes
assert(settings.cancel(api,G,target,state) and #writes==count+1)
settings.restore(api,G,state);assert(duration(api,D)==6 and api.read(D+40,4)==f(1.5))
-- Native compaction/relocation: restore follows both maps, never saved pointers.
settings.cancel(api,G,target,state)
put(D+280,api.read(D,280));put(D,string.rep('x',280))
put(J+0x1100,u(524)..u(1));put(J+0x1200+16,u(1)..u(524));put(J+152,u(2))
settings.restore(api,G,state);assert(duration(api,D+280)==6 and api.read(D,280)==string.rep('x',280))
-- A later external duration edit takes precedence over our saved value.
settings.cancel(api,G,target,state);put(D+280+156,f(8));settings.restore(api,G,state)
assert(duration(api,D+280)==8)
-- Recycled entity IDs must not receive restoration writes.
settings.cancel(api,G,target,state);put(J+0x1400+12,u(251));count=#writes
settings.restore(api,G,state);assert(#writes==count and not state.lease)
-- A partial creation write must roll back the data, both maps and count.
for failed=1,4 do
    api,target,put,writes=fixture();local before={}
    for _,range in ipairs({{D,280},{J+0x1100,64},{J+0x1200,64},{J+152,4}})do
        before[#before+1]={range[1],api.read(range[1],range[2])}
    end
    local write=api.write;local attempts=0
    api.write=function(a,b)attempts=attempts+1;if attempts==failed then put(a,b:sub(1,math.max(1,#b-1)));return false end;return write(a,b)end
    assert(not pcall(settings.cancel,api,G,target,{}))
    for _,v in ipairs(before)do assert(api.read(v[1],#v[2])==v[2],'partial creation not rolled back')end
end
-- A partial duration write is immediately rolled back as well.
api,target,put,writes=fixture();local write=api.write;local attempts=0;state={}
api.write=function(a,b)attempts=attempts+1;if attempts==5 then put(a,b:sub(1,3));return false end;return write(a,b)end
assert(not pcall(settings.cancel,api,G,target,state))
assert(not state.lease and duration(api,D)==6)
-- Retain cleanup state across a failed restoration, then retry successfully.
api,target,put,writes=fixture();state={};settings.cancel(api,G,target,state);write=api.write
api.write=function()return false end
assert(not pcall(settings.restore,api,G,state) and state.lease)
api.write=write;assert(settings.restore(api,G,state) and not state.lease and duration(api,D)==6)
-- A destroyed manager makes its old lease irrelevant, without dereferencing it.
settings.cancel(api,G,target,state);put(G+0x276c8d0,p(0));count=#writes
assert(settings.restore(api,G,state) and not state.lease and #writes==count)
-- Refuse full storage and non-data pages without changing anything.
api,target,put,writes=fixture();put(J+4,u(1));put(J+152,u(1))
assert(not settings.cancel(api,G,target,{}) and #writes==0)
api,target,put,writes=fixture();api.writable_data=function()return false end
assert(not pcall(settings.cancel,api,G,target,{}) and #writes==0)
-- Mission teardown can make the settings map temporarily unreadable while a
-- cancellation still needs restoring. Keep its lease and retry read-only.
api,target,put,writes=fixture();state={};settings.cancel(api,G,target,state)
local read=api.read;count=#writes
api.read=function(a,n)if a==J+96 then return nil end;return read(a,n)end
local ok,result=pcall(settings.restore,api,G,state)
assert(ok and result==false,'transient restoration read must not stop the hook')
assert(state.lease and #writes==count and state.restore_waits==1 and state.last_restore_error)
api.read=read;assert(settings.restore(api,G,state) and not state.lease and duration(api,D)==6)
-- If the old manager disappears during that wait, abandon its lease without
-- writing through stale addresses, even when the old records are unreadable.
settings.cancel(api,G,target,state);api.read=function(a,n)if a==J+96 then return nil end;return read(a,n)end
assert(not settings.restore(api,G,state));count=#writes;put(G+0x276c8d0,p(J+0x10000))
assert(settings.restore(api,G,state) and not state.lease and #writes==count)
-- Read-only preflight failure between snapshot and cancellation is retryable.
api,target,put,writes=fixture();state={};read=api.read
api.read=function(a,n)if a==J+96 then return nil end;return read(a,n)end
ok,result=pcall(settings.cancel,api,G,target,state)
assert(ok and result==false and not state.lease and #writes==0,'unavailable preflight must not stop the hook')
api.read=read;assert(settings.cancel(api,G,target,state));settings.restore(api,G,state)
assert(duration(api,D)==6)
-- Exercise deferred cleanup through the production update wrapper, retaining
-- the same hook while the next mission supplies a fresh flight identity.
local source=assert(arg[1]);local patch=assert(loadfile(source..'/hover_data.lua'))()
patch.policy=assert(loadfile(source..'/cancel.lua'))();patch.settings=settings
api,target,put,writes=fixture();read=api.read
target.guards={};target.active=true;target.flight=true;target.down=true
local sample=target;patch.snapshot=function()return sample,'waiting_for_mission'end
api.focused=function()return true end;api.time=function()return 1 end
api.module=function(name)return name and G or 2 end;api.module_hash=function(m)return tostring(m)end
local e=setmetatable({CowboyBingusModLoader={api=1,version=12},print=function()end,
    os={getenv=function()end}}, {__index=_G})
e._G=e;e.update=function(...)return ... end
setfenv(assert(loadfile(source..'/archive_loader.lua'))(),e)(function()return api end,patch,
    {revision='test',game_sha256=tostring(G),exe_sha256='2'})
local function tick()e.update(1/60)end
tick();target.down=false;tick();target.down=true;tick()
assert(e.HoverPackCancel.cancellations==1 and e.HoverPackCancel.lease)
sample=nil;api.read=function(a,n)if a==J+96 then return nil end;return read(a,n)end
count=#writes;tick();tick()
assert(e.HoverPackCancel.status=='restore_pending' and e.HoverPackCancel.lease and #writes==count)
api.read=read;tick()
assert(not e.HoverPackCancel.lease and duration(api,D)==6)
sample=target;target.key='second-mission';tick()
assert(e.HoverPackCancel.cancellations==1,'held activation cancelled the new mission flight')
target.down=false;tick();target.down=true;tick()
assert(e.HoverPackCancel.cancellations==2 and e.HoverPackCancel.lease)
target.active=false;target.flight=false;tick();assert(duration(api,D)==6 and not e.HoverPackCancel.lease)
print('PASS: pending restoration recovers through the installed hook before cancellation in the next mission')
print('PASS: native timeout/landing predicate, per-pack isolation, restoration/next flight, relocation, later edits, recycled IDs and partial-write rollback')
