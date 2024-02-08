#!/bin/bash

# Scroll down for config variables... (below line 58)

# XWinHibernate
#
# Freezing windows when they are not needed. Requires Xorg, WILL NOT WORK ON WAYLAND!
#
# Required commands: kill, grep, sed, ps, xprop, xwininfo, wmctrl, sort, echo, sleep, xclip
#
# This script sends a STOP signal to windows that are not mapped to the current workspace,
# or those that are minimized, and sends a CONT signal to those that become visible once again.
#
# This script scans for these windows every second,
# so there may be up to a second of delay upon resume from a suspended state.
#
# This allows the system to more easily swap out these inactive processes from memory
# to disk or ZRAM when they are not used, leaving more memory  for the currently active tasks.
# This also helps reduce thrashing of the swap file/partition, or wasted CPU cycles on zram thrashing.
# Since a frozen process won't change it's memory, frozen processes can be more easily:
# - swapped out (swap memory, or zram (zstd compression highly recommended for maximum memory savings)
# - merged using uksmd (requires patched kernel. I recommend: https://pfkernel.natalenko.name )
#
# This is useful for low-memory systems, low-cpu systems, as well as systems with slow disks.
# This may also reduce resources on terminal servers, with multiple simultaneous VNC or RDP sessions.
# This is important, as certain apps are known for hogging unused memory,
# and running background processes when they are not used.
#
# I'M LOOKING AT YOU, WEB BROWSERS!!!
# NO MORE BACKGROUND LOADING AND JAVASCRIPT WHEN THE BROWSER WINDOW IS MINIMIZED!!!
# I swear that those web browsers are behaving like their own operating systems these days...
#
# This can save battery also.
#
# - A couple of things to note:
#
# - Media Playback
# Just be sure that the web browser is on the active workspace when you are playing music through it.
# This script will pause media playback on any window it freezes, so keep that in mind...
# - Solution:
#   Just set the media playback window to sticky (on all workspaces), and you should be fine...
#
# - Copy-Paste bug (you can blame the Xorg server for this one, WORKAROUND WILL BE ATTEMPTED)
# This might effect copy-paste functionality as well.
# After attempting to paste from a frozen app, switch to it, and back again.
# I don't know why the Xorg server doesn't just cache that sort of thing.
# Caching this information would actually make sense for them to do, so why didn't they do it?
# We just can't have nice things now, can we?
# It HAD to be the apps that take resposibility for the copy-paste functionality now, didn't it?
# A workaround will be attempted, but this might only work for copy-pasting text content.
# - Solution:
#   Making sure that both apps in the copy-paste exchange are on the same workspace, and are visible.
#   This should mitigate the copy-paste problem.
# Again, what were they thinking?
#

##########################################################
########             CONFIG SECTION               ########
##########################################################

#######################################
##  REFRESH_COUNT and REFRESH_DELAY  ##
#######################################
#
# Delay between refresh interval, and duration of said interval respectively.
#
# When $REFRESH_COUNT seconds have passed,
# This script will temporarily unfreeze frozen apps for $REFRESH_DELAY seconds
# Then it will freeze said apps again, and reset the time counter...
#
# This is useful for respecting apps that sustain background TCP connections, and the like...
#
# - Defaults:
# REFRESH_COUNT=60
# REFRESH_DELAY=5
#
REFRESH_COUNT=60
REFRESH_DELAY=1

#########################
##  TITLE_MATCH_REGEX  ##
#########################
#
# REGEX MATCH for matching specific windows
#
# This REGEX matches the window titles using Grep
#
# If one uses a wildcard to match every window, this script MUST NOT BE EXECUTED IN TERMINAL!
# Otherwise, you should be fine.
#
# This config defaults to common apps that are resource intensive when idle.
# e.g. Web browsers, workstation apps, etc...
#
# Be careful as to not to include recording/streaming apps in this. (e.g. Audacity, Ardour, OBS)
# Doing so will interrupt any ongoing recordings and livestreams. You might not want that to happen.
# File managers should also be excluded. Doing so will interrupt file transfers!
# Also be careful when doing video conferencing within the browser. That will get interrupted also!
# Any app that gets frozen will halt all activity, including potentially important ones.
# This also includes notifications, although you might already be using your phone for those anyway.
#
# Feel free to add to this list, anything else you wish to freeze.
# Also feel free to remove from this list, as is potentially useful for the following circumstances:
# - web browsers that you depend upon for video conferencing purposes, or important notifictions.
# - apps that need to do long background tasks (rendering a movie in Blender for example)
# - Email clients (for arrival notifications and background syncing)
# Look at WHITELIST_TITLE_MATCH_REGEX for whitelisting options...
#
# By default, matches the end of the window title.
# Format:
#   end-of-window-title     match-end-of-string
#            |                       |
#          Krita                     $
#            |    __________________/
#            |   /
# Result:  Krita$
#
# Matches are separated using colons (OR separator in regex)
#
# More complex regex matches may be used,
# however those more complex ones are best suited to whitelisting instead.
# (see WHITELIST_TITLE_MATCH_REGEX for that one)
#
TITLE_MATCH_REGEX="Mozilla Firefox$|Krita$|Blender$|GNU Image Manipulation Program$|Chromium$|Volume Control$"

###################################
##  WHITELIST_TITLE_MATCH_REGEX  ##
###################################
# WHITELIST REGEX for Window Title
#
# Similar to TITLE_MATCH_REGEX, but as a whitelist instead.
# Allows more granular control for windows that should NOT be frozen, under any circumstances.
# This takes precedent over TITLE_MATCH_REGEX.
#
# Default is a placeholder, not intended to match anything realistic.
# Replace the placeholder with the regex you wish to use for whitelisting purposes.
#
# Other than the default placeholder, the format is the exact same as with TITLE_MATCH_REGEX.
#
# Default:
# WHITELIST_TITLE_MATCH_REGEX="PLACEHOLDER_ThUnD3RB14D_5#+=-I[N-S]PACE_ACE_0[f-s]bADE$"
#
WHITELIST_TITLE_MATCH_REGEX="PLACEHOLDER_ThUnD3RB14D_5#+=-I[N-S]PACE_ACE_0[f-s]bADE$"


##### END CONFIG ##### END CONFIG ##### END CONFIG ##### END CONFIG ##### END CONFIG #####
#----------------------------------------------------------------------------------------#
#       !!!!DO NOT EDIT BELOW THIS LINE, UNLESS YOU KNOW WHAT YOU ARE DOING!!!!          #
#----------------------------------------------------------------------------------------#
##### START CODE ##### START CODE ##### START CODE ##### START CODE ##### START CODE #####

# Confirm Xorg session. We do not want to run on Wayland!
#
# DO NOT COMMENT THIS OUT IN A PATHETIC ATTEMPT TO RUN ON WAYLAND!
# YOU WILL QUITE BADLY BREAK THINGS UNLESS YOU REWRITE THIS ENTIRE SCRIPT FROM GROUND UP!
#
if [ $XDG_SESSION_TYPE == "x11" ]; then
  echo "
This is an X11 session. We can safely continue...

"
else
  echo "
This doesn't appear to be an X11 desktop session.
We can not continue, as we require an X11 session.

"
  [ $XDG_SESSION_TYPE == "wayland" ] && echo "This script is not compatible with Wayland! ABORT!
Any attempt to circumvent this warning WILL break things, and confuse you greatly, so don't even think about hacking this script to run in a wayland session!

"
  exit 1
fi
# End of session confirmation code...

# Check for missing commands
SHMFILE1=/dev/shm/xwinhibernate1-$USER-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 5; echo)
prerequisites=("kill" "grep" "sed" "ps" "xprop" "xwininfo" "wmctrl" "sort" "echo" "sleep" "xclip")
for item in "${prerequisites[@]}"
do
  if ! command -v $item &> /dev/null
  then
    echo "\"$item\" command could not be found."
    echo 1 > $SHMFILE1
  fi
done
if test -f $SHMFILE1; then
  echo "
One or more of the abovecommand line utilities can not be found. Please install them before continuing.
"
  rm -f $SHMFILE1
  exit 1
else
  echo "All required command-line utilities are installed. Continuing..."
fi

# We can start the script now...
echo "Starting xwinhibernate...

We will freeze any hidden programs with titles matching this regex:
$TITLE_MATCH_REGEX

Wit the exception of those matching this regex:
$WHITELIST_TITLE_MATCH_REGEX

These regex's can be changed by editing this script. Just be sure to back it up before editing!

"
# Initialize SHM files...
SHMFILE_BASE=/dev/shm/xwinhibernate1-$USER-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 5; echo)
SHMFILE1=$SHMFILE_BASE"_cache1"
SHMFILE2=$SHMFILE_BASE"_cache2"
SHMFILE3=$SHMFILE_BASE"_cache3"
SHMFILE4=$SHMFILE_BASE"_counter"
SHMFILE5=$SHMFILE_BASE"_screensaver_state"

# TRAP termination signals, for cleanup, and unfreezing all windows upon exit...
cleanup()
{
  wait
  rm -f $SHMFILE1
  rm -f $SHMFILE2
  rm -f $SHMFILE3
  rm -f $SHMFILE4
  rm -f $SHMFILE5 
  echo ""
  echo "Received termination signal. Restoring all windows..."
  wmctrl -l | grep -E "$TITLE_MATCH_REGEX" | awk '{print $1}' | \
  while read line; do
    THAW_PID=$(xprop -id $line | grep "_NET_WM_PID" | grep -oE "[0-9]*");
    echo "THAWING PID=$THAW_PID"
    kill -CONT $THAW_PID;
  done
  echo "done."
  exit 0
}
trap cleanup SIGINT SIGTERM


clipboard-workaround()
{
   printf "Attempting clipboard workaround... "

   # If command doesn't complete within 0.5 seconds, assume inaccessible clipboard pointer, and skip...
   CLIPCONTENTS=$(timeout 0.5 xclip -selection c -rmlastnl -o 2>/dev/null)

   if [ -z "$CLIPCONTENTS" ]
   then
     echo "Clipboard data empty or unsupported. Skip..."
   else
     echo "$CLIPCONTENTS"| sed -z '$ s/\n$//' | timeout 0.5 xclip -selection c
     echo "Done."
   fi
}

screensaver_check()
{
  # xscreensaver
  if pgrep -x "xscreensaver" > /dev/null; then
    if xscreensaver-command -time 2>&1 | grep -q "screen non-blanked"; then return 0
    else return 1
    fi
  fi
}

echo 0 > $SHMFILE4

while true; do
 # Clean SHMFILE1 and SHMFILE3...
 rm -f $SHMFILE1
 rm -f $SHMFILE3

 # Get active window IDs, parse their titles using grep, extract window ID, and loop over them...
 wmctrl -l | grep -E "$TITLE_MATCH_REGEX" | grep -vE "$WHITELIST_TITLE_MATCH_REGEX" | \
 awk '{print $1}' | \
 while read line
 do
  # Default to loaded/unfreeze, in case something goes horribly wrong...
  SETPROCSTATE="S"

#  echo eee $line
  # Calculate the PID from the window ID
  WIN_PID=$(xprop -id $line | grep "_NET_WM_PID" | grep -oE "[0-9]*")
  # Calculate our expectation. If window is unmapped, we unload it, and vice-versa...
  if xwininfo -id $line | grep -q Map\ State:\ IsUnMapped; then
    SETPROCSTATE="T"
  else
    SETPROCSTATE="S"
  fi

  # Send our expectation to SHMFILE1
  echo "$WIN_PID-$SETPROCSTATE" >> $SHMFILE1
 done < "${1:-/dev/stdin}"

 # DEDUPLICATION HANDLER
 # SHMFILE1 contains suspend data
 sort -u $SHMFILE1 > $SHMFILE2
 # SHMFILE2 contains deduped suspend data (pass 1)
 cat $SHMFILE2 | grep -oE "[0-9]*" | uniq -d > $SHMFILE1
 # SHMFILE1 contains remaining dupes. These must be conflicting setprocstates
 # Maybe a process has at least 2 windows in foreground and background simultaneously...
 # Defaulting to keeping said process alive, to avoid disruption...
  while read p; do
#    echo $p-T
    grep -v "$p-T" $SHMFILE2 > $SHMFILE3
    cat $SHMFILE3 > $SHMFILE2
  done <$SHMFILE1
 # SHMFILE2 contains deduped suspend data (pass 2)
 #
 # SHMFILE2 should now contain all deduped processes, and what to do with them...
 # We loop over every line in SHMFILE2...
 rm -f $SHMFILE3

# SCREENSAVER=0

 # screensaver detection
 screensaver_check && SCREENSAVER="0" || SCREENSAVER="1"
# if [ $(cat $SHMFILE3) == 1 ]; then echo qqql; fi
# SCREENSAVER=$(screensaver_check)

 while read WINPROC_COMMAND; do
  # We parse our variables out from the line in our SHM file...
  WIN_PID=$(echo "$WINPROC_COMMAND" | cut -d "-" -f 1)
  SETPROCSTATE=$(echo "$WINPROC_COMMAND" | cut -d "-" -f 2)
  #echo "$WINPROC_COMMAND $WIN_PID"


  COUNT=$(cat $SHMFILE4)

  # Now we can compare our procstates, and send STOP/CONT signals as necessary.
  #
  # Treating procstates R D and S as active/running.
  # Treating procstate T as stopped/frozen.
  # We will check the PROCSTATE of the process,
  # If it doesn't match our calculated expectation,
  # We will change it to suit our needs.
  PROCSTATE=$(ps -q "$WIN_PID" -o state --no-headers)

#  SCREENSAVER=$(cat $SHMFILE5)
  if [[ "$PROCSTATE" =~ [RDS] ]] && [ "$SETPROCSTATE" == "T" ]; then
   # Refresh clipboard (workaround for dumbass decision by Xorg to depend on app for clipboard), SMH.
   if ! test -f $SHMFILE3; then
     clipboard-workaround
     echo 1 > $SHMFILE3
   fi
   echo "Freezing PID $WIN_PID, as it is no longer visible..."
   # Freeze the app
   kill -STOP $WIN_PID
  elif [[ "$PROCSTATE" =~ [RDS] ]] && [ "$SCREENSAVER" == "1" ]; then
  # Refresh clipboard (workaround for dumbass decision by Xorg to depend on app for clipboard), SMH.
   if ! test -f $SHMFILE3; then
     clipboard-workaround
     echo 1 > $SHMFILE3
   fi
   echo "FREEZING PID $WIN_PID, as screensaver is active..."
   kill -STOP $WIN_PID
  elif [ "$PROCSTATE" == "T" ] && [ "$SETPROCSTATE" == "S" ] && [ "$SCREENSAVER" == "0" ]; then
   echo "Thawing PID $WIN_PID, as it is now visible..."
   kill -CONT $WIN_PID
  fi
  #echo "$WIN_PID $PROCSTATE $SETPROCSTATE"
 done <$SHMFILE2

 sleep 1

 COUNT=$(cat $SHMFILE4)
 COUNT=$((COUNT+1))
 if [ $COUNT -ge $REFRESH_COUNT ]; then
   COUNT=0
   printf "Periodic sync: Unfreezing frozen apps for $REFRESH_DELAY seconds... "
   wmctrl -l | grep -E "$TITLE_MATCH_REGEX" | awk '{print $1}' | \
   while read line; do
#     echo 1 "$line"
     THAW_PID=$(xprop -id $line | grep "_NET_WM_PID" | grep -oE "[0-9]*");
     kill -CONT $THAW_PID;
   done
   sleep $REFRESH_DELAY
   echo "Done."
 fi
 echo $COUNT > $SHMFILE4
 #echo $COUNT
done

# If the lines below get executed, something must have gone horribly wrong...
echo "

xwinhibernate script error.
Something went wrong: main loop has failed catastrophically.

Nothing to do, except cleanup...

"

# Run cleanup if we get to this point somehow...
cleanup
exit 1
