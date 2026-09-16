local source=assert(arg[1])
local function environment(loader)
    local e=setmetatable({CowboyBingusModLoader=loader,print=function()end,os={getenv=function()end}}, {__index=_G})
    e._G=e;e.update=function(...)return ... end;e.shutdown=function(...)return ... end;return e
end
local calls,cleanups=0,0
local a={time=function()return 1 end,module=function(name)return name and 1 or 2 end,module_hash=function(m)return tostring(m)end}
local patch={apply=function(_,_,_,state,dt)assert(dt==1/60);calls=calls+1;return 'watching_hover'end,
    cleanup=function(_,_,state)cleanups=cleanups+1;state.lease=nil;return true end}
local function install(e,api)
    setfenv(assert(loadfile(source..'/archive_loader.lua'))(),e)(api or function()return a end,patch,
        {revision='test',game_sha256='1',exe_sha256='2'})
end
for _,loader in ipairs({false,{}, {api=0,version=12},{api=1,version=11},{api='1',version=12}})do
    local e=environment(loader);local before=e.update;install(e);assert(e.update==before and not e.HoverPackCancel.active)
end
local e=environment({api=1,version=12});install(e);local before=e.update;install(e);assert(e.update==before)
local x,y,z=e.update(1/60,nil,3);assert(x==1/60 and y==nil and z==3 and calls==1)
assert(select('#',e.update(1/60,nil,3))==3)
local n=calls;e.shutdown();e.update(1/60);assert(calls==n and e.HoverPackCancel.status=='stopped' and cleanups==1)
e=environment({api=1,version=12});e.update=function()error('original failed')end;install(e)
assert(not pcall(e.update,1/60));assert(calls==n and e.HoverPackCancel.status=='original_update_failed')
assert(cleanups==2)
e=environment({api=1,version=12});install(e);patch.apply=function()error('stale actor')end
e.update(1/60);assert(not e.HoverPackCancel.active and e.HoverPackCancel.status:find('stale actor',1,true))
assert(cleanups==3)
patch.apply=function()calls=calls+1 end;e.update(1/60);assert(calls==n)
e=environment({api=1,version=12});before=e.update;install(e,function()error('hash failed')end);assert(e.update==before)
print('PASS: loader version/hash gates, single update boundary, return values, duplicate load, failure isolation and shutdown')
