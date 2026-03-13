fx_version "cerulean"

description "Capital RP Interactions"
author "Capital RP"
version '1.0.0'

lua54 'yes'

games {
  "gta5",
  "rdr3"
}

ui_page 'web/build/index.html'

shared_scripts {
  "@ox_lib/init.lua",
  "config.lua"
}

client_script {
  "client/utils.lua",
  "client/laptopDui.lua",
  "client/client.lua"
}
server_script {
  "server/server.lua",
}

files {
    'web/build/index.html',
    'web/build/**/*',
    'web/public/**/*',
}



data_file 'DLC_ITYP_REQUEST' 'stream/clamp.ytyp'
