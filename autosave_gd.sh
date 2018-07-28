#! /bin/bash

GD_DIR="$HOME/gdrive/" # Directory with Google Drive access
AS_DIR="$HOME/.autosave/" # Directory with autosave_gd working files
AS_INDEX="$AS_DIR/autosave.index" # autosave_gd index of tracking files
AS_PASS="" # Password for symetric encryption (AES-256-CBC in use)
REMOTE_DIR="" # Directory on Google Drive holding backups
host="" # Name of the current host
date="$(date +%Y%m%d_%Hh%M)" # Current date and time to sort backups

# Detect if we run in GUI mode
GUI=false
if test "$1" = "--gui"
then
	GUI=true
	shift
fi

# Detect if we force the backup process
FORCE="0"
if test "$1" = "-f"
then
	FORCE="1"
	shift
fi

# print usage on stderr
usage()
{
	if $GUI
	then
		zenity --error --text="Invalid command: $0 $*"
	else
		echo "Usage: $0 [--gui] [-f] <option> [<absolute path to files>]"
		echo "--add      Add file(s) to the index and upload a backup"
		echo "--untrack  Delete file(s) from the index but keep backup"
		echo "--backup   Perform a backup of files in the index"
	fi
} > /dev/stderr

# check the prensence of Google Drive directory in GD_DIR,
# access right on the Google account
# and Internet connectivity
# return 1 if some fails, 0 otherwise
verify_dir()
{
	if ! test -d "$GD_DIR/.gd"
	then
		return 1
	fi
	
	cd "$GD_DIR"
	if ! drive about > /dev/null 2>&1
	then
		return 1
	fi
	
	cd - > /dev/null
	
	return 0
}

# load index file AS_INDEX in associative array AS_ENTRIES
# return 1 if file is created here, 0 otherwise
load_index()
{
	local fic btime
	
	if ! test -f "$AS_INDEX"
	then
		touch "$AS_INDEX"
		return 1
	fi
	
	while read line
	do
		fic="${line%/*}"
		btime="${line##*/}"
		AS_ENTRIES["$fic"]="$btime"
	done < "$AS_INDEX"
	
	return 0
}

# get the last modification date of files in directory in first argument
# take a directory, print the date in seconds since epoch
last_modif()
{
	local files="$(find "$1")" max=0 file time

	while read file
	do
		time="$(stat --format=%Y "$file")"
		if ((time > max))
		then
			max="$time"
		fi
	done <<< "$files"

	echo "$max"
}

# add files in arguments to index file and upload a backup of them
add()
{
	for fic in "$@"
	do
		# Skip already tracked files
		if test -n "${AS_ENTRIES["$fic"]}"
		then
			echo "$fic already tracked ! Skipping..." > /dev/stderr
			continue
		fi
		
		# Check if file to backup exist
		if test -e "$fic"
		then
			cd "$GD_DIR"
			
			PRETTY_NAME="$(echo "$fic" | tr '/' '.')"
			
			# Name the remote backup file with "base-" prefix if it's the first backup
			if test -f "$AS_DIR/$PRETTY_NAME"
			then
				REMOTE_NAME="$date-$host-$PRETTY_NAME.tgz.enc"
			else
				REMOTE_NAME="base-$date-$host-$PRETTY_NAME.tgz.enc"
			fi
			
			# Compress, cipher and upload the backup
			tar -zc --listed-incremental="$AS_DIR/$PRETTY_NAME" "$fic" | openssl enc -aes-256-cbc -salt -pass pass:"$AS_PASS" | drive push -piped "$REMOTE_DIR/$REMOTE_NAME"
			
			cd - > /dev/null
			
			# Add the entry to index file and set an emblem to the file visible in Thunar
			AS_ENTRIES["$fic"]="$(date +%s)"
			gio set "$fic" -t stringv metadata::emblems go-up
		else
			echo "$fic doesn't exist ! Skipping..." > /dev/stderr
			continue
		fi
	done
	
	if $GUI
	then
		zenity --info --text="File(s) added successfully" --title="Backup"
	else
		echo "Done."
	fi
}

# upload a backup of files in index file modified since last backup
backup()
{
	local report=""

	if $GUI
	then
		notify-send -i info "Backup started" -t 5000
	fi
	
	for fic in "${!AS_ENTRIES[@]}"
	do
		if test -e "$fic"
		then
			if test "$FORCE" = "1" -o "${AS_ENTRIES["$fic"]}" -lt "$(last_modif "$fic")"
			then
				cd "$GD_DIR"
				
				PRETTY_NAME="$(echo "$fic" | tr '/' '.')"
				REMOTE_NAME="$date-$host-$PRETTY_NAME.tgz.enc"
				
				# Compress, cipher and upload the backup
				tar -zc --listed-incremental="$AS_DIR/$PRETTY_NAME" "$fic" | openssl enc -aes-256-cbc -salt -pass pass:"$AS_PASS" | drive push -piped "$REMOTE_DIR/$REMOTE_NAME"
				
				cd - > /dev/null
				AS_ENTRIES["$fic"]="$(date +%s)"
				report="$report$fic\n"
			fi
		else
			echo "$fic doesn't exist anymore ! Skipping..." > /dev/stderr
			continue
		fi
	done
	
	if $GUI
	then
		notify-send -i info "Backup done" "$report" -t 300000
	else
		echo "Done."
	fi
}

# remove files in arguments from index file
untrack()
{
	for fic in "$@"
	do
		# Remove file from the index and unset its emblem visible in Thunar
		# But doesn't remove its incremental tracking file for future re-add
		unset AS_ENTRIES["$fic"]
		gio set "$fic" -t unset metadata::emblems
	done
	
	if $GUI
	then
		zenity --info --text="File(s) untracked successfully" --title="Backup"
	else
		echo "Done."
	fi
}

if (($# == 0))
then
	usage "$@"
	exit 1
fi

declare -A AS_ENTRIES
load_index

if test "$1" = "--untrack"
then
	shift
	untrack "$@"
else
	if ! verify_dir
	then
		if $GUI
		then
			zenity --error --title="Backup" --text="No drive directory at $GD_DIR or no internet connection"
		else
			echo "No drive directory at $GD_DIR or no internet connection" > /dev/stderr
		fi
		exit 1
	fi
	
	case "$1" in
		--add) shift; add "$@";;
		--backup) backup;;
		*) usage "$@"; exit 1;;
	esac
fi

# dump AS_ENTRIES to index file
echo -n > "$AS_INDEX"
for fic in "${!AS_ENTRIES[@]}"
do
	echo "$fic/${AS_ENTRIES["$fic"]}" >> "$AS_INDEX"
done

exit 0
