fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

author 'OsmiumOP | discord - osmiumop'
description 'Stock Market System'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/stocks.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/stocks.lua'
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/styles.css',
    'web/build/app.js',
    'stockhistory.json'
}

escrow_ignore {
    'stockhistory.json',
    'config.lua',
    'readme.md',
}

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib'
}
dependency '/assetpacks'