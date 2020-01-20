# autosave_gd
Backup files and directories to Google Drive securely

# Description
This tool keep a list of backuped files and directories in order to backup them with only one command.

Backup are compressed and encrypted with AES 256 bits in CBC mode before being uploaded to Google Drive. Only differences are uploaded thanks to `tar --listed-incremental` option.

# Requierements
- `drive` (https://github.com/odeke-em/drive) (for Google Drive uploading)
- `openssl >= 1.1.1` (for encryption)
- `zenity` command (for GUI)
- `gio` utility (for emblem on backuped files/directories)

*Optional :*

- `thunar` file manager (for actions from right click on files/directories)

# Install
This tool was designed to run on **Xubuntu 18.04** but can run on other system as well if dependencies are installed.

- Place the script in a directory included in your `$PATH` (like `$HOME/bin`)
- Configure variables `AS_DIR`, `AS_PASS` and so on, at the beginning of the script
- Create directories configured previously
- Configure `drive` with `drive init` in the relevant directory (refer to the `drive`'s doc)

*Emblem functionality setup for XFCE* :

- Place the `emblem-go-up.png` file (or any icon file of your choice) of the `emblems/` directory of your current theme in `/usr/share/icons/`, then run `gtk-update-icon-cache .` in the root directory of your current theme

*Action from right click setup in Thunar* :

- Go in `Edit` -> `Configure custom actions...` in Thunar and add these new entries:
- `Name`=`Backup`, `Command`=`autosave_gd.sh --gui --add %F`
- `Name`=`Untrack`, `Command`=`autosave_gd.sh --gui --untrack %F`

You can setup a keyboard shortcut to execute `autosave_gd.sh --gui --backup` to trigger a backup.

# Usage
You can mark files with `--add` to be backuped.

When `autosave_gd.sh` is called with `--backup` argument, files listed previously are backuped.

`--untrack` option is for untrack them.

The `-f` switch serve to force the upload of a new *"base"* backup.

The `--gui` flag serve to use `zenity` to display progress and prompt in graphical windows.

## From the command line
```
Usage: autosave_gd.sh [--gui] [-f] <option> [<absolute path to files>]
--add      Add file(s) to the index and upload a backup
--untrack  Delete file(s) from the index but keep backup
--backup   Perform a backup of files in the index
```

## From Thunar
Right click on files and/or directories you want to backup or untrack, then select the action.

## Restoring backups
In order to restore backups, you should:

- Create an empty working directory
- Download backups files (`*.enc`) in that directory
- Place `restore_as.sh` in that directory and execute it
- `restore_as.sh` script will prompt for the password and then decrypt and extract backups in that directory
