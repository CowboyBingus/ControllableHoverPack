local policy=assert(loadfile(arg[1]..'/cancel.lua'))()
local rows=assert(loadfile(arg[1]..'/../tests/flight_replay.lua'))()
local state={};local calls={}
for _,s in ipairs(rows)do if policy.step(state,s)then calls[#calls+1]=s.t end end
assert(#calls==1 and math.abs(calls[1]-116.073)<.01)
print('PASS: captured vanilla hover/input replay requests one cancellation at the first repress, 0.6 seconds into flight')
