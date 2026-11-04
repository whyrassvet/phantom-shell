# Customize

Open **Settings** with `Super+U`. In **Appearance > Bar**, choose Flat,
Floating, Islands or One island for the Phantom bar. Additional bar settings
are still being ported. The retained `waybar-set` commands control the legacy
Waybar configuration, not the Phantom bar.

## Theme
```bash
rice-colors list             # all schemes
rice-colors mode ocean       # auto, grey, navy, mono, slate, stone, steel, ash, ink, ocean, sky, ...
```

## Notifications (Phantom)
```bash
rice-notify set pos_x left|center|right
rice-notify set popup_style glass|solid|minimal|pill|accent|glow|island|light
rice-notify test             # send a test notification
```

## Idle & Lockscreen (hypridle + hyprlock)
```bash
rice-lock set lock_after 5          # minutes, 0 = never
rice-lock set suspend_after 30
rice-lock set clock big|stacked|minimal
rice-lock set background screenshot|wallpaper|color
rice-lock restore                   # give back your original hyprlock.conf and hypridle.conf
```

## Hot corner
```bash
rice-hotcorner list sections awake,record,shot,toggles,media
rice-hotcorner list toggles wifi,bluetooth,dnd,gaming,mic,settings,wallpaper,lock
rice-hotcorner open          # open the panel now (bind it to a key if you like)
rice-hotcorner shot region   # screenshot of a region
rice-hotcorner record full   # start recording (run "record stop" to stop)
```

The hot corner is fixed at the bottom right; the old `corner` setting no longer
changes its position.
