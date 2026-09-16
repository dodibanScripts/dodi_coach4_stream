CreateThread(function()
    Wait(5000)
    MetaLib.printMetaDebug()
    if MetaLib.hasCarMeta() then
        print('^2[dodi_coach4_stream]^7 meta COACH4 OK — gate opens.')
    else
        print('^1[dodi_coach4_stream]^7 NO meta detected — /coach4_meta_debug')
    end
end)
