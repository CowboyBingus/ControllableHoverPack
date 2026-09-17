return function(create_api,patch,build)
    if rawget(_G,'HoverPackCancel') then return end
    local state={revision=build.revision,cancellations=0,updates=0,active=false}
    rawset(_G,'HoverPackCancel',state)
    local api,last_report
    local function report(status,force)
        state.status=status
        local now=api and api.time() or 0
        if not force and last_report and now-last_report<2 then return end
        last_report=now
        print('[ControllableHoverPack] '..build.revision..': '..status)
        pcall(function()
            local logger=rawget(_G,'CowboyBingusModLoader')
            local f=logger and logger.open_log and logger.open_log('ControllableHoverPack.log');if not f then return end
            f:write(build.revision..'\n'..status..'\n')
            for _,key in ipairs({'updates','cancellations','restorations','snapshot_waits','settings_waits','restore_waits'}) do
                f:write(key..'='..tostring(state[key] or 0)..'\n')
            end
            for _,key in ipairs({'snapshot_status','mission_type','last_snapshot_error','last_settings_error','last_restore_error'}) do
                f:write(key..'='..tostring(state[key] or 'none')..'\n')
            end
            f:close()
        end)
    end
    local ok,adapter,game,exe=pcall(function()
        local loader=rawget(_G,'CowboyBingusModLoader')
        assert(type(loader)=='table' and type(loader.api)=='number' and loader.api>=1
            and type(loader.version)=='number' and loader.version>=12,'Bingus Shared Loader v11 / API 1 is required')
        local a=create_api();local g,e=a.module('game.dll'),a.module(nil)
        assert(g and e,'Required modules unavailable')
        assert(a.module_hash(g)==build.game_sha256 and a.module_hash(e)==build.exe_sha256,'Unsupported game build')
        assert(type(update)=='function','Game update unavailable')
        return a,g,e
    end)
    if not ok then report(tostring(adapter),true);return end
    api=adapter
    local previous,previous_shutdown,stopped=update,shutdown,false
    local function cleanup()
        local ok,result=pcall(patch.cleanup,api,game,state)
        if not ok then report('restore_failed: '..tostring(result),true)end
    end
    local function after(dt,called,...)
        if not called then stopped=true;state.active=false;cleanup();report('original_update_failed',true);error((...),0) end
        if stopped and state.lease then cleanup()end
        if not stopped then
            state.updates=state.updates+1
            local worked,status=pcall(patch.apply,api,game,exe,state,dt)
            if not worked then stopped=true;cleanup()end
            state.active=worked and (status=='watching_hover' or status=='native_descent')
            report(tostring(status),not worked)
        end
        return ...
    end
    update=function(dt,...)return after(dt,pcall(previous,dt,...))end
    shutdown=function(...)
        stopped=true;state.active=false;cleanup();report('stopped',true)
        if previous_shutdown then return previous_shutdown(...)end
    end
    report('waiting_for_mission',true)
end
