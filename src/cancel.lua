local M={}
-- A new flight must observe release before a fresh press can cancel it.
function M.step(state,s)
    if not s or not s.flight then
        state.key=nil;state.armed=false;state.down=false;state.sent=false
        return false
    end
    if state.key~=s.key then
        state.key=s.key;state.armed=not s.down;state.down=s.down;state.sent=false
        return false
    end
    local press=s.down and not state.down
    state.down=s.down
    if not s.down then state.armed=true end
    if state.armed and press and not state.sent then
        state.sent=true
        return true
    end
    return false
end
return M
