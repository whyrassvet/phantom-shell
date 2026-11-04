# Customize

Everything is in **Settings** (`SUPER+U`). The same actions exist as commands:

```bash
waybar-set style flat|floating|islands|island
waybar-set group none|pills|segmented
waybar-set opacity 0.9
waybar-set island-width 1000      # width of "One island"
waybar-set power-nudge 14         # gap left of the power button
waybar-set power-size 18          # power button icon size
waybar-set distro-icon on|off     # logo that matches your distro
waybar-set autohide on|off
```

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
rice-hotcorner set corner bottom-right|bottom-left|top-right|top-left
rice-hotcorner list sections awake,record,shot,toggles,media
rice-hotcorner list toggles wifi,bluetooth,dnd,gaming,mic,settings,wallpaper,lock
rice-hotcorner open          # open the panel now (bind it to a key if you like)
rice-hotcorner shot region   # screenshot of a region
rice-hotcorner record full   # start recording (run "record stop" to stop)
```
