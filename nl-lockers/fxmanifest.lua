fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'nl-lockers'
description 'Rentable storage lockers — personal interiors, keypad, upgrades, laptop management'
author      'NoLimits'
version     '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/dataview.lua',
    'client/framework.lua',
    'client/inventory_bridge.lua',
    'client/dui.lua',
    'client/gizmo.lua',
    'client/keypad.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/framework.lua',
    'server/inventory_bridge.lua',
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/**/*',
    'keypad/**/*',
    'stream/*.ytyp',

    'locales/*.json',
}

data_file 'DLC_ITYP_REQUEST' 'stream/ex_int_warehouse_small_dlc.ytyp'

escrow_ignore {
    'config.lua',
    'shared/**/*.lua',
    'client/**/*.lua',
    'server/**/*.lua',
    'nui/**/*',
    'keypad/**/*',
    'stream/**/*',
    'locales/**/*.json',
}

dependency '/assetpacks'