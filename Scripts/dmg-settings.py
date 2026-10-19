# dmgbuild settings for CPStack. Values in `defines` come from build-dmg.sh (-D key=value).
import os.path

app = defines["app"]
app_name = os.path.basename(app)

format = "UDZO"
compression_level = 9
filesystem = "APFS"
size = None

files = [app]
symlinks = {"Applications": "/Applications"}

icon = defines["icon"]
background = defines["background"]

# Must match the icon centers drawn in Scripts/make-dmg-background.swift.
window_rect = ((200, 140), (640, 400))
icon_size = 112
text_size = 13
icon_locations = {
    app_name: (170, 200),
    "Applications": (470, 200),
}

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
show_icon_preview = False
arrange_by = None
label_pos = "bottom"
