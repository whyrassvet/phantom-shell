-- keybinds that belong to DarkShadow's Shell (installed by install.sh, loaded from hyprland.lua)
local bin = os.getenv("HOME") .. "/.local/bin/"

-- wallpaper picker: unbind first so only ONE menu opens even if another config also binds SUPER + W
hl.unbind("SUPER + W")
-- the Wallpaper tab of the dashboard (or the old picker when the dashboard is off)
hl.bind("SUPER + W", hl.dsp.exec_cmd(bin .. "rice-dashboard wallpaper"))

-- volume, microphone and brightness: laptop Fn keys and headset +/- buttons
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(bin .. "rice-media up"),          { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(bin .. "rice-media down"),        { locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(bin .. "rice-media mute"),        { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(bin .. "rice-media mic"),         { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(bin .. "rice-media bright-up"),   { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(bin .. "rice-media bright-down"), { locked = true })

-- screenshots and screen recording
hl.unbind("SUPER + SHIFT + S") -- replaces Hyprland's special-workspace binding
hl.bind("SUPER + SHIFT + S",   hl.dsp.exec_cmd(bin .. "rice-hotcorner shot region"))
hl.bind("Print",               hl.dsp.exec_cmd(bin .. "rice-hotcorner shot full"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd(bin .. "rice-hotcorner shot full"))
hl.bind("SUPER + SHIFT + R",   hl.dsp.exec_cmd(bin .. "rice-hotcorner record region"))   -- press again to stop
hl.bind("SUPER + A",           hl.dsp.exec_cmd(bin .. "rice-hotcorner open"))
-- widget editor on the desktop (Esc or Done to finish)
hl.bind("SUPER + ALT + W",     hl.dsp.exec_cmd(bin .. "desktop-set edit toggle"))
-- dashboard (also: point at the middle of the bar edge)
hl.bind("SUPER + ALT + D",     hl.dsp.exec_cmd(bin .. "rice-dashboard open"))
