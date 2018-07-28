# autosave_gd
Backup files and directories to Google Drive securely

# Requierements
- `drive` (https://github.com/odeke-em/drive)
- `openssl`
- `zenity`
- `gio` utility
- `thunar` file manager

# Install
This tool was designed to run on **Xubuntu 18.04** but can run on other system as well if dependencies are installed.

- Place the script in a directory included in your `$PATH` (like `$HOME/bin`)
- Configure variables `AS_DIR`, `AS_PASS` and so on, at the beginning of the script
*For XFCE*:
- Place the `emblem-go-up.png` file in the `emblems/` directory of your current theme in `/usr/share/icons/`, then run `gtk-update-icon-cache .` in the root directory of your current theme
- Go in `Edit` -> `Configure custom actions...` in Thunar and add these new entries:
  - `Name`=`Backup`, `Command`=`autosave_gd.sh --gui --add %F`
  - `Name`=`Untrack`, `Command`=`autosave_gd.sh --gui --untrack %F`

# Usage
## From the command line
```
Usage: autosave_gd.sh [--gui] [-f] <option> [<absolute path to files>]
--add      Add file(s) to the index and upload a backup
--untrack  Delete file(s) from the index but keep backup
--backup   Perform a backup of files in the index
```

## From Thunar
Right click on files and/or directories you want to backup or untrack, then select the action.
