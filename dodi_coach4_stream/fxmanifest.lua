fx_version 'adamant'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'dodi_coach4_stream'
author 'Dodiban Scripts'
description 'COACH4 client patch gate + Lua car profiles (no yft stream — crashes on spawn)'
version '1.2.1'

shared_script 'config.lua'

-- Do NOT stream coach4.yft here: RedM crashes on spawn (artist-fruit-spaghetti).
-- The client meta patch in client_patch/citizen is the supported path.

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

ui_page 'html/index.html'

client_scripts {
    'client/meta_lib.lua',
    'client/gate.lua',
    'client/verify.lua',
}

server_scripts {
    'server/gate.lua',
}
