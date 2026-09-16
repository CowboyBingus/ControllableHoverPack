local ffi,bit=require('ffi'),require('bit')
local M={}
local function value(b,o,t)local x=ffi.new(t..'[1]');ffi.copy(x,b:sub(o+1),ffi.sizeof(x));return tonumber(x[0])end
local function u(b,o)return value(b,o,'uint32_t')end
local function resource(hex)return hex:gsub('..',function(x)return string.char(tonumber(x,16))end):reverse()end
local AVATAR=resource('4d1c334d294dfa97')
local HOVER=resource('5ec80f4f1cdb66cf')
function M.current(api,s)
    for _,g in ipairs(s.guards)do if api.read(g.address,#g.bytes)~=g.bytes then return false end end
    return true
end
function M.snapshot(api,game)
    local s={guards={},reads=0}
    local function wait(reason)error({hover_wait=true,reason=reason},0)end
    local function read(a,n,guard)
        s.reads=s.reads+1;assert(s.reads<=160,'Hover read budget exceeded')
        local b=api.read(a,n);if not b or #b~=n then wait('waiting_for_read')end
        if guard then s.guards[#s.guards+1]={address=a,bytes=b}end
        return b
    end
    local function ptr(b,o)
        local p=api.pointer(b,o or 0);if not p then wait('waiting_for_pointer')end;return p
    end
    local function global(rva)return ptr(read(game+rva,8,true))end
    local function lookup(h,key,limit)
        local cap,empty,mult=u(h,8),u(h,12),u(h,16)
        if cap==0 then return nil end
        assert(cap<=limit and bit.band(cap,cap-1)==0,'Unsupported hover map')
        local product=tonumber(ffi.cast('uint32_t',ffi.new('uint64_t',key)*ffi.new('uint64_t',mult)))
        local data=ptr(h)
        for probe=0,math.min(cap,64)-1 do
            local row=read(data+8*bit.band(product+probe,cap-1),8,true)
            if u(row,0)==key then local i=u(row,4);if i~=0xffffffff then return i end;return nil end
            if u(row,0)==empty then return nil end
        end
    end
    local mode=read(global(0x276c3d0),0x44,true)
    if u(mode,8)==0 or u(mode,0x40)~=1 then return nil,'waiting_for_mission'end
    local pm=global(0x276c190);local counts=read(pm+0x84,8,true)
    assert(u(counts,0)<=4 and u(counts,4)<=4,'Unsupported player count')
    if u(counts,0)==0 or u(counts,4)==0 then return nil,'waiting_for_player'end
    local player=read(ptr(read(pm+0xe8,8,true)),24,true)
    if bit.band(player:byte(21),1)==0 then return nil,'waiting_for_player'end
    local unit=u(read(pm+0x3a8,4,true),0)
    if unit==0x7fff then return nil,'waiting_for_avatar'end
    local owner=global(0x276f0c0)
    local ei=lookup(read(owner+0xf21a88,20,true),unit,1048576)
    if not ei then return nil,'waiting_for_avatar'end
    assert(ei<262144,'Unsupported entity index')
    local avatar=read(owner+0xf31ad8+ei*24,24,true)
    if avatar:sub(1,8)~=AVATAR or bit.band(avatar:byte(21),1)==0 then return nil,'waiting_for_avatar'end
    local eid=u(avatar,8);local am=global(0x276ca30)
    local ai=lookup(read(am+0xf8,20,true),eid,64)
    if not ai then return nil,'waiting_for_avatar'end
    local count=u(read(am+0x6c,4,true),0)
    assert(count<=8 and ai<count,'Unsupported avatar index')
    assert(read(ptr(read(am+0x110+ai*8,8,true)),24,true)==avatar,'Avatar identity mismatch')
    -- Equipped backpack, then reverse ownership: never choose the first pack.
    local equipment=global(0x276c468)
    local qi=lookup(read(equipment+40,20,true),eid,8192)
    if not qi then return nil,'no_backpack'end
    assert(qi<4096,'Unsupported equipment index')
    assert(read(ptr(read(ptr(read(equipment+64,8,true))+qi*8,8,true)),24,true)==avatar,'Equipment identity mismatch')
    local pack_id=u(read(ptr(read(equipment+80,8,true))+qi*48+12,4,true),0)
    if pack_id==0 or pack_id==0xffffffff then return nil,'no_backpack'end
    local jm=global(0x276c8d0)
    local ji=lookup(read(jm+32,20,true),pack_id,128)
    if not ji then return nil,'no_jump_pack'end
    local counts_j=read(jm+16,8,true);local total,owned=u(counts_j,0),u(counts_j,4)
    assert(owned<=total and total<=64,'Unsupported jump-pack registry')
    if ji>=owned then return nil,'pack_not_owned'end
    local entity=read(ptr(read(ptr(read(jm+56,8,true))+ji*8,8,true)),24,true)
    assert(u(entity,8)==pack_id,'Pack identity mismatch')
    if entity:sub(1,8)~=HOVER then return nil,'not_hover_pack'end
    if bit.band(entity:byte(21),1)==0 then return nil,'pack_not_owned'end
    local attach=global(0x276cad0)
    local bi=lookup(read(attach+32,20,true),pack_id,8192)
    if not bi then return nil,'pack_not_attached'end
    assert(bi<4096,'Unsupported attachment index')
    if u(read(ptr(read(attach+64,8,true))+bi*48+4,4,true),0)~=eid then return nil,'pack_not_attached'end
    local flags=read(am+0x53d900+ai*0x1238+0xf80,24,true)
    local ps=read(ptr(read(jm+80,8,true))+ji*5,5,true)
    for i=1,5 do assert(ps:byte(i)<=1,'Unsupported pack flags')end
    -- The native input helper maps pair (2,15) to slot 15. +8 is its held time.
    local input=read(am+0x150+ai*0xa7aec+0x1b68+15*32,32,true)
    local held=value(input,8,'float')
    assert(held==held and held>=0 and held<86400,'Invalid jump input')
    s.down=held>0
    s.active=ps:byte(1)==1
    s.flight=s.active and ps:byte(2)==0 and ps:byte(5)==1 and bit.band(u(flags,8),0x80000000)~=0
        and bit.band(u(flags,12),6)==0 and bit.band(u(flags,8),0x10000000)==0
    s.key=avatar..entity..tostring(jm);s.manager=jm;s.pack=pack_id;s.identity=entity:sub(1,20)
    return s
end
function M.apply(api,game,exe,state)
    local ok,s,reason=pcall(M.snapshot,api,game)
    if not ok then
        if type(s)=='table' and s.hover_wait then reason=s.reason;s=nil else error(s,0)end
    end
    if state.lease then
        if s and s.key==state.lease.key and s.active then return 'native_descent' end
        if not M.settings.restore(api,game,state) then return 'restore_pending' end
        M.policy.step(state,nil)
    end
    if not api.focused() then M.policy.step(state,nil);return 'waiting_for_game_focus'end
    if not s then M.policy.step(state,nil);return reason end
    if not M.current(api,s) then M.policy.step(state,nil);return 'snapshot_changed'end
    if not M.policy.step(state,s) then return s.flight and 'watching_hover' or 'waiting_for_hover'end
    if not api.focused() or not M.current(api,s) then
        M.policy.step(state,nil);return 'snapshot_changed'
    end
    if not M.settings.cancel(api,game,s,state) then return 'snapshot_changed'end
    state.cancellations=(state.cancellations or 0)+1
    return 'cancel_requested'
end
function M.cleanup(api,game,state)return M.settings.restore(api,game,state)end
return M
