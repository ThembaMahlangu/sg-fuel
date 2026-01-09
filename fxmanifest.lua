fx_version 'cerulean'
game 'gta5'

author 'sgMAGLERA'
version '1.0.0'
description 'Player Owned Gas Stations combination of LegacyFuel and qb-fuel'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/translations.js',
    'html/style.css'
}

shared_scripts {
	'@qb-core/shared/locale.lua',
    '@ox_lib/init.lua',
    'config.lua',
	'locales/*.lua',
}

client_scripts {
    'client/exports.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

provide 'LegacyFuel'
provide 'qb-fuel'

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'html/*.html',
    'html/*.js',
    'html/*.css',
    'install/*.lua',
    'client/*.lua',
    'server/*.lua',
}