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

-- Routine gameplay must not write diagnostics unless explicitly enabled.
for _,diagnostics in ipairs({false,true})do
    local now,opens,profiles=0,0,0
    local e=setmetatable({print=function()end},{__index=_G});e._G=e
    e.CowboyBingusDiagnostics=diagnostics
    e.CowboyBingusModLoader={api=1,version=99,open_log=function()
        opens=opens+1;return {write=function()end,close=function()end}
    end}
    e.update=function()return 1,nil,3 end;e.shutdown=function()return 4,nil,6 end
    local api={time=function()return now end,module=function(n)return n or 'exe'end,
        module_hash=function()return 'hash'end,bind=function()return {}end,read=function()return ''end}
    local patch={interval=1/30,apply=function()return 'waiting_for_mission' end,
        profiler={new=function()profiles=profiles+1;return {}end},stop=function()return true end,cleanup=function()return true end}
    setfenv(assert(loadfile(source..'/archive_loader.lua')),e)()(function()return api end,patch,
        {revision='fixture',game_sha256='hash',exe_sha256='hash'})
    local startup=opens
    for i=1,600 do now=i/60;local a,b,c=e.update(1/60);assert(a==1 and b==nil and c==3)end
    assert(diagnostics and opens>startup or not diagnostics and opens==startup,'routine log writes require opt-in')

    e.shutdown();assert(opens>startup,'shutdown report remains available')
end
print('PASS: silent default, opt-in diagnostics, shutdown report and callback returns')
