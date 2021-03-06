#! /bin/bash

GD_DIR="$HOME/gdrive/" # Directory with Google Drive access
AS_DIR="$HOME/.autosave/" # Directory with autosave_gd working files
AS_INDEX="$AS_DIR/autosave.index" # autosave_gd index of tracking files
AS_HOOKS_DIR="$AS_DIR/hooks/" # Directory containing hook scripts to be executed before backup task
AS_LAST_BACKUP="$AS_DIR/last_backup" # File containing the date of last successful backup
AS_PASS='' # Password for symetric encryption (AES-256-CBC in use) / if empty, prompt at execution
PBKDF_ITER='100000' # PBKDF2 iteration count (default: 100000, higher = stronger)
host="" # Name of the current host
REMOTE_DIR="autosave_$host" # Directory on Google Drive holding backups
USE_EMBLEM=true # Add emblem on backuped files in file explorer

# do NOT edit this
date="$(date +%Y%m%d%H%M)" # Current date and time to sort backups (do NOT edit this)

# Detect if we run in GUI mode
GUI=false
if test "$1" = "--gui"
then
	GUI=true
	shift
fi

# make $GUI available for hook scripts
export GUI

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
} >&2

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

# display a progress bar in GUI mode
# read from stdin a number between 0 and 100 (percentage done)
# $1 title
# $2 text
progress_bar()
{
    if $GUI
    then
        zenity --progress --auto-close --no-cancel --title="$1" --text="$2"
    else
        cat - > /dev/null
    fi
}

# add files in arguments to index file and upload a backup of them
add()
{
    local i="0" len
    
    len="$#"
    mkfifo /tmp/as_progress_ipc
	progress_bar 'Backup - add' 'Adding files...' < /tmp/as_progress_ipc &
	exec 3> /tmp/as_progress_ipc

	for fic in "$@"
	do
		# Skip already tracked files
		if test -n "${AS_ENTRIES["$fic"]}"
		then
			echo "$fic already tracked ! Skipping..." >&2
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
			tar -zc --listed-incremental="$AS_DIR/$PRETTY_NAME" "$fic" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF_ITER" -pass pass:"$AS_PASS" | drive push -piped "$REMOTE_DIR/$REMOTE_NAME"
			
			cd - > /dev/null
			
			# Add the entry to index file and set an emblem to the file visible in Thunar
			AS_ENTRIES["$fic"]="$(date +%s)"
			$USE_EMBLEM && gio set "$fic" -t stringv metadata::emblems go-up
		else
			echo "$fic doesn't exist ! Skipping..." >&2
			continue
		fi
		((i++))
		bc <<< "scale=2;$i/$len*100"
	done >&3
	exec 3>&-
	rm -f /tmp/as_progress_ipc
	
	if $GUI
	then
		zenity --info --text="File(s) added successfully" --title="Backup"
	else
		echo "Done."
	fi
}

# run pre-backup script hooks in $AS_HOOKS_DIR
# Return 1 if a script return 1 (backup should be aborted), 0 otherwise
run_pre_hooks()
{
    local script i="0" len
    
    len="$(ls -1 $AS_HOOKS_DIR/pre_*.sh | wc -l)"
    mkfifo /tmp/as_progress_ipc
	progress_bar 'Backup - pre hooks' 'Running pre-backup hooks...' < /tmp/as_progress_ipc &
	exec 3> /tmp/as_progress_ipc
    
    for script in $AS_HOOKS_DIR/pre_*.sh
    do
        if test -f "$script" -a -x "$script"
        then
            "$script" > /dev/null
            if (($? == 1))
            then
                return 1
            fi
        fi
        ((i++))
        bc <<< "scale=2;$i/$len*100"
    done >&3
    exec 3>&-
    rm -f /tmp/as_progress_ipc
}

# run post-backup script hooks in $AS_HOOKS_DIR
run_post_hooks()
{
    local script i="0" len
    
    len="$(ls -1 $AS_HOOKS_DIR/post_*.sh | wc -l)"
    mkfifo /tmp/as_progress_ipc
	progress_bar 'Backup - post hooks' 'Running post-backup hooks...' < /tmp/as_progress_ipc &
	exec 3> /tmp/as_progress_ipc
    
    for script in $AS_HOOKS_DIR/post_*.sh
    do
        if test -f "$script" -a -x "$script"
        then
            "$script" > /dev/null
        fi
        ((i++))
        bc <<< "scale=2;$i/$len*100"
    done >&3
    exec 3>&-
	rm -f /tmp/as_progress_ipc
}

# upload a backup of files in index file modified since last backup
backup()
{
	local report="" i="0" len

	if $GUI
	then
		notify-send -i info "Backup started" -t 5000
	fi
	
	if ! run_pre_hooks
	then
    	if $GUI
        then
	        notify-send -i error "Backup aborted (hook returned 1)" -t 300000
        else
            echo "Backup aborted (hook returned 1)" >&2
        fi
        
        return 1
    fi
	
	len="${#AS_ENTRIES[@]}"
	mkfifo /tmp/as_progress_ipc
	progress_bar 'Backup' 'Backup in progress...' < /tmp/as_progress_ipc &
	exec 3> /tmp/as_progress_ipc
	
	for fic in "${!AS_ENTRIES[@]}"
	do
		if test -e "$fic"
		then
			if test "$FORCE" = "1" -o "${AS_ENTRIES["$fic"]}" -lt "$(last_modif "$fic")"
			then
				cd "$GD_DIR"
				
				PRETTY_NAME="$(echo "$fic" | tr '/' '.')"
				# In case of forcing the backup operation, upload a full "base" backup
				if test "$FORCE" = "1"
				then
					REMOTE_NAME="base-$date-$host-$PRETTY_NAME.tgz.enc"
					rm -f "$AS_DIR/$PRETTY_NAME"
				else
					REMOTE_NAME="$date-$host-$PRETTY_NAME.tgz.enc"
				fi
				
				# Compress, cipher and upload the backup
				tar -zc --listed-incremental="$AS_DIR/$PRETTY_NAME" "$fic" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF_ITER" -pass pass:"$AS_PASS" | drive push -piped "$REMOTE_DIR/$REMOTE_NAME"
				
				cd - > /dev/null
				AS_ENTRIES["$fic"]="$(date +%s)"
				report="$report$fic\n"
			fi
		else
			echo "$fic doesn't exist anymore ! Skipping..." >&2
			continue
		fi
		((i++))
		bc <<< "scale=2;$i/$len*100"
	done >&3
	exec 3>&-
	rm -f /tmp/as_progress_ipc
	
	run_post_hooks
	
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
		$USE_EMBLEM && gio set "$fic" -t unset metadata::emblems
	done
	
	if $GUI
	then
		zenity --info --text="File(s) untracked successfully" --title="Backup"
	else
		echo "Done."
	fi
}

# prompt for a password if none set
prompt_password()
{
    if test -z "$AS_PASS"
    then
        if $GUI
        then
            AS_PASS="$(zenity --password --title='Backup')" || return 1
        else
            read -r -s -p "Enter backup password: " AS_PASS || return 1
        fi
    fi
}

if (($# == 0))
then
	usage "$@"
	exit 1
fi

error=false
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
			echo "No drive directory at $GD_DIR or no internet connection" >&2
		fi
		exit 1
	fi
	
	case "$1" in
		--add) shift; if ! prompt_password; then exit 1; fi; add "$@";;
		--backup) if ! prompt_password; then exit 1; fi; if ! backup; then error=true; else date "+%Y%m%d" > "$AS_LAST_BACKUP"; fi ;;
		*) usage "$@"; exit 1;;
	esac
fi

# dump AS_ENTRIES to index file
echo -n > "$AS_INDEX"
for fic in "${!AS_ENTRIES[@]}"
do
	echo "$fic/${AS_ENTRIES["$fic"]}" >> "$AS_INDEX"
done

if $error
then
    exit 1
else
    exit 0
fi
