fx_version 'cerulean'
game 'gta5'

author 'Capital RP'
description 'Loadingscreen'
version '1.0.0'
lua54 'yes'



client_scripts {
    'client/client.lua'
}



--[[ ui_page "html/index.html"
 ]]
  files {
    "html/config.json",
    "html/index.html",
    "html/style.css",
    "html/script.js",
    "html/images/*.jpg",
    "html/images/*.png",
    "html/music/*.mp3",
    "html/video/*.mp4",
    "html/music-player.js",
    "html/particles.js"

}

loadscreen 'html/index.html'
loadscreen_cursor 'yes'


escrow_ignore {
    'config.json',
    "fxmanifest.lua"
}


