local source=assert(arg[1])
local policy=assert(loadfile(source..'/cancel.lua'))()
local function sample(down,key,flight)return {down=down,key=key or 'local',flight=flight~=false}end
local s={}
assert(not policy.step(s,sample(true))) -- activation hold
assert(not policy.step(s,sample(true)))
assert(not policy.step(s,sample(false)))
assert(policy.step(s,sample(true)))
assert(not policy.step(s,sample(true)))
assert(not policy.step(s,sample(false)))
assert(not policy.step(s,sample(true))) -- one command per flight
assert(not policy.step(s,nil))
assert(not policy.step(s,sample(true))) -- focus/read recovery cannot synthesize a press
assert(not policy.step(s,sample(false)))
assert(policy.step(s,sample(true)))
assert(not policy.step(s,sample(true,'replacement')))
assert(not policy.step(s,sample(false,'replacement')))
assert(policy.step(s,sample(true,'replacement')))
assert(not policy.step(s,sample(false,nil,false)))
assert(not policy.step(s,sample(false)))
assert(policy.step(s,sample(true)))
print('PASS: activation hold, release/repress, one cancellation per flight, focus/read recovery, replacement, next flight')
