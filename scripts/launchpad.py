#!/usr/bin/env python3
import sys
import os
import subprocess
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
gi.require_version('GioUnix', '2.0')

from gi.repository import Gtk, Gdk, GtkLayerShell, GioUnix, GLib

class LaunchpadWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Launchpad")

        # LayerShell setup for Wayland overlay
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)

        self.connect("key-press-event", self.on_key_press)
        self.connect("button-press-event", self.on_background_click)

        # Styling
        css_provider = Gtk.CssProvider()
        css_data = """
        window {
            background-color: rgba(12, 14, 22, 0.85);
        }
        .search-entry {
            background-color: rgba(255, 255, 255, 0.12);
            color: #ffffff;
            border-radius: 20px;
            padding: 8px 16px;
            font-size: 15px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .app-btn {
            background: transparent;
            border: none;
            border-radius: 18px;
            padding: 12px;
        }
        .app-btn:hover {
            background: rgba(255, 255, 255, 0.15);
        }
        .app-label {
            color: #ffffff;
            font-size: 13px;
            font-weight: 600;
        }
        menu {
            background-color: #1e1e2e;
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 10px;
            padding: 4px;
        }
        menuitem {
            color: #cdd6f4;
            padding: 6px 12px;
            font-size: 13px;
        }
        menuitem:hover {
            background-color: #313244;
            color: #ffffff;
        }
        """
        css_provider.load_from_data(css_data.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        main_box.set_margin_top(50)
        main_box.set_margin_bottom(40)
        main_box.set_margin_start(80)
        main_box.set_margin_end(80)
        self.add(main_box)

        # Search Bar
        search_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        search_box.set_halign(Gtk.Align.CENTER)
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Search Applications...")
        self.search_entry.get_style_context().add_class("search-entry")
        self.search_entry.set_size_request(380, 42)
        self.search_entry.connect("search-changed", self.on_search_changed)
        self.search_entry.connect("activate", self.on_search_activate)
        search_box.pack_start(self.search_entry, False, False, 0)
        main_box.pack_start(search_box, False, False, 0)

        # Scrolled Window for Apps Grid
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        main_box.pack_start(scroll, True, True, 0)

        self.flowbox = Gtk.FlowBox()
        self.flowbox.set_valign(Gtk.Align.START)

        self.flowbox.set_max_children_per_line(6)
        self.flowbox.set_min_children_per_line(6)
        self.flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flowbox.set_row_spacing(24)
        self.flowbox.set_column_spacing(24)
        self.flowbox.set_halign(Gtk.Align.CENTER)
        scroll.add(self.flowbox)

        self.apps = []
        self.load_apps()
        self.search_entry.grab_focus()

    def load_apps(self):
        all_apps = GioUnix.DesktopAppInfo.get_all()
        sorted_apps = sorted(
            [a for a in all_apps if a.should_show()],
            key=lambda x: x.get_name().lower()
        )

        for app in sorted_apps:
            name = app.get_name()
            icon = app.get_icon()
            
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            box.set_size_request(110, 110)

            # Icon
            image = Gtk.Image()
            if icon:
                image.set_from_gicon(icon, Gtk.IconSize.DIALOG)
                image.set_pixel_size(64)
            else:
                image.set_from_icon_name("application-x-executable", Gtk.IconSize.DIALOG)
                image.set_pixel_size(64)
            box.pack_start(image, False, False, 0)

            # Label
            label = Gtk.Label(label=name)
            label.set_ellipsize(3)
            label.set_max_width_chars(12)
            label.get_style_context().add_class("app-label")
            box.pack_start(label, False, False, 0)

            btn = Gtk.Button()
            btn.add(box)
            btn.get_style_context().add_class("app-btn")

            # Connect left click to launch, right click for context menu
            btn.connect("button-press-event", self.on_app_button_press, app)
            
            self.flowbox.add(btn)
            self.apps.append((name.lower(), btn, app))

        self.show_all()

    def safe_launch(self, app):
        try:
            app.launch([], None)
        except Exception as e:
            cmd = app.get_commandline() or app.get_executable() or ""
            if cmd:
                subprocess.Popen(cmd, shell=True)

    def on_app_button_press(self, widget, event, app):
        if event.button == 1: # Left click
            self.safe_launch(app)
            Gtk.main_quit()
            return True
        elif event.button == 3: # Right click context menu
            self.show_context_menu(widget, event, app)
            return True
        return False

    def show_context_menu(self, widget, event, app):
        menu = Gtk.Menu()

        # Launch
        item_launch = Gtk.MenuItem(label=f"🚀 Launch {app.get_name()}")
        item_launch.connect("activate", lambda w: (self.safe_launch(app), Gtk.main_quit()))
        menu.append(item_launch)

        # Run in Terminal
        exec_cmd = app.get_executable() or ""
        if exec_cmd:
            item_term = Gtk.MenuItem(label="🖥️ Run in Terminal")
            item_term.connect("activate", lambda w: (subprocess.Popen(["kitty", "-e", exec_cmd]), Gtk.main_quit()))
            menu.append(item_term)

        # Open File Location
        desktop_file = app.get_filename()
        if desktop_file:
            item_file = Gtk.MenuItem(label="📁 Open File Location")
            item_file.connect("activate", lambda w: subprocess.Popen(["nautilus", os.path.dirname(desktop_file)]))
            menu.append(item_file)

        # Separator
        menu.append(Gtk.SeparatorMenuItem())

        # Uninstall / Delete Application
        item_delete = Gtk.MenuItem(label="🗑️ Uninstall / Delete Application")
        item_delete.connect("activate", lambda w: self.uninstall_app(app))
        menu.append(item_delete)

        menu.show_all()
        menu.popup_at_pointer(event)

    def uninstall_app(self, app):
        desktop_file = app.get_filename() or ""
        app_id = app.get_id() or ""
        app_name = app.get_name()

        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text=f"Uninstall {app_name}?"
        )
        dialog.format_secondary_text(f"Are you sure you want to remove {app_name} from your system?")
        response = dialog.run()
        dialog.destroy()

        if response == Gtk.ResponseType.OK:
            if "flatpak" in desktop_file:
                clean_id = app_id.replace(".desktop", "")
                subprocess.Popen(["kitty", "-e", "bash", "-c", f"flatpak uninstall -y {clean_id}; read -p 'Press Enter to exit...';"])
            elif desktop_file.startswith(os.path.expanduser("~")):
                try:
                    os.remove(desktop_file)
                except Exception as e:
                    print("Error removing desktop file:", e)
            else:
                pkg_name = app_id.replace(".desktop", "")
                cmd = f"echo 'Uninstalling {app_name}...'; sudo dnf remove -y $(rpm -qf '{desktop_file}' 2>/dev/null || echo '{pkg_name}'); read -p 'Press Enter to exit...';"
                subprocess.Popen(["kitty", "-e", "bash", "-c", cmd])
            Gtk.main_quit()

    def on_search_changed(self, entry):
        query = entry.get_text().lower()
        for name, widget, app in self.apps:
            if query in name:
                widget.show()
            else:
                widget.hide()

    def on_search_activate(self, entry):
        query = entry.get_text().lower()
        for name, widget, app in self.apps:
            if widget.is_visible():
                self.safe_launch(app)
                Gtk.main_quit()
                break

    def on_background_click(self, widget, event):
        if event.button == 1 and event.window == self.get_window():
            Gtk.main_quit()
            return True
        return False

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

if __name__ == "__main__":
    win = LaunchpadWindow()
    Gtk.main()
