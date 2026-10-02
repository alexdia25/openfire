Open Fire
=========

Open Fire plays Return Fire (1996) on the open-source openfire engine. It ships WITHOUT any
Return Fire content: you need your own copy of the PC (Windows 95) game.

1. Keep OpenFire.exe (or OpenFire.x86_64) and OpenFire.pck together in one folder.
2. Run it. On first launch, choose the folder Return Fire is installed in (and, optionally, the
   game CD's .iso or drive for the music). The files are converted once, on this computer, and
   never leave it.
3. Re-run the import any time from Settings > Game files...

Where your data is stored
-------------------------
The converted game data is NOT stored next to the game. It goes in Godot's per-user data folder:

  Windows:  %APPDATA%\Godot\app_userdata\Return Fire\packs\original_pc
  Linux:    ~/.local/share/godot/app_userdata/Return Fire/packs/original_pc
            (or $XDG_DATA_HOME/godot/... if you set it)

Your settings and the folders you picked last are in the same "Return Fire" folder
(settings.cfg, open_fire.cfg). Deleting the game does not delete any of this.

Removing it
-----------
Run remove_pack_data.bat (Windows) or remove_pack_data.sh (Linux). It asks first, then deletes
only the converted game data (packs\original_pc), leaving your settings. The next launch will
offer the import again. To remove everything, delete the whole "Return Fire" folder shown above.

Source and issues: https://github.com/alexdia25/openfire
