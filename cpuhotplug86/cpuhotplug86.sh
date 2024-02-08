#!/bin/bash
VER=1.0

# defaults:
CONSOLE_DEBUG=0
POLLING_INTERVAL=1
CPU_MAX_THRESH=67
CPU_MIN_THRESH=33
CPU_MINPROCS_ACTIVE=1
IGNORE_NICE_LOAD=0
#WHITELIST_X11="Krita"
#X11_USER=

CONFIG_FILE=/etc/default/cpuhotplug86

# Create config file if it doesn't already exist...
create_config_file()
{
  echo "
Creating config file..."
  echo "
#####################################
# cpuhotplug86 - Configuration File #
#####################################
#     Edit this as you see fit.     #
#####################################

# Run this in the background, and unneeded CPU cores get powered down.
# If CPU gets loaded, more cores are enabled based on the load.
# This should save some electrical power. Great for battery-powered devices.
# This may also opportunistically enable/disable SMT on hyper-threaded cores, in some cases...

# DEBUG MODE
# If set, Shows debug information.
# Useful for testing configuration.
#
# Set to 1 for debug mode
# Set to 2 for more comprehensive debug mode
#
# - Default:
# CONSOLE_DEBUG=0
#
CONSOLE_DEBUG=0

# Polling Interval
# Should be greater than or equal to 1
POLLING_INTERVAL=1

# CPU Threshold
# Maximum/Minimum CPU use per processor to trigger a processor to be hotplugged.
#
# If cpu usage per processor is greater than CPU_MAX_THRESH:
#  - a cpu will be powered up, if one is available.
# If cpu usage per active  processor is less than CPU_MIN_THRESH:
#  - a cpu will be powered down.
#
# This hotplug script will try to keep utilization of active CPUS to this range.
# Powering down those that are not needed beyond this range,
# and powering up those that are needed to match this range.
#
# when low single-digit numbers of processors are active,
#   this script might need multiple iterations of POLLING_INTERVAL
#   in order to eventually match demand.
#
# IGNORE_NICE_LOAD: power-saving feature for laptops.
#                   If set to 1, will ignore low-priority processes for usage calculation.
#                   Set to 0 to include nice load in usage calculation (performance mode).
#
# - Defaults:
# CPU_MAX_THRESH=67
# CPU_MIN_THRESH=33
# CPU_MINPROCS_ACTIVE=1
# IGNORE_NICE_LOAD=0
#
CPU_MAX_THRESH=67
CPU_MIN_THRESH=33
CPU_MINPROCS_ACTIVE=1
IGNORE_NICE_LOAD=0

#################################################
#    DANGER ZONE BELOW: EXPERIMENTAL FEATURES   #
#################################################
#            DO NOT CHANGE UNLESS YOU           #
#            KNOW WHAT YOU ARE DOING!           #
#################################################

# X11 Window names to whitelist
#
# CAUTION: Config parsing not finished properly.
#           - Uses comment-out for disabling!!!
# CAUTION: DOES NOT WORK FOR WAYLAND DESKTOP ENVIRONMENTS!!!
# CAUTION: XAUTHORITY and DISPLAY need to be set.
#
# Scans DISPLAY=:0 (uses grep -E on "xdotool getwindowfocus getwindowname" output)
# to find currently running window.
# Useful for apps that have trouble detecting disabled processors (i.e. Krita).
# This is also useful for any workstation apps or games where max performance is preferable.
# This will ensure that ALL CPUs are available while these applications are in the foreground.
#
# Comment it out if you don't need it, or if it isn't applicable in your situation (Wayland, or other).
# Default is disabled (commented out)
#
# E.G. WHITELIST_X11="Krita"
#
# - Default:
# # WHITELIST_X11="Krita"
#
# WHITELIST_X11="Krita"
# X11_USER="<x11-user>"
# DISPLAY=:0
# XAUTHORITY=/home/$X11_USER/.Xauthority

#END CONFIGURATION
" > $CONFIG_FILE
  echo "Config file created.
"
}
test -f $CONFIG_FILE || create_config_file


# Check for missing commands
SHMFILE1=/dev/shm/cpuhotplug86-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 5; echo)
prerequisites=("awk" "grep" "ps" "top" "tail" "nproc")
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


# Load config file
source $CONFIG_FILE

# Start the hotplug script proper...
echo "
cpuhotplug86 - Version $VER
Intelligent CPU hotplugging for the x86 family of processors.
(and maybe other processors too...)
"
CPUUSAGE_SHMFILE=/dev/shm/cpuusage-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
X11CHECK_SHMFILE=/dev/shm/x11check-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)

# TRAPS ARE NOT GAY!!!
# Trap termination for cleanup...
# If script is terminated using SIGINT, enable all processors on exit.
cleanup()
{
  wait
  echo ""
  rm -f $CPUUSAGE_SHMFILE
  rm -f $X11CHECK_SHMFILE
  echo ""
  echo "Enabling all processors on script termination..."
  for file in /sys/devices/system/cpu/cpu*/online; do echo 1 > $file; done
  echo "done."
  exit 0
}
trap cleanup SIGINT SIGTERM

# Enable all available processors, and count them...
PROC_HOTPLUG_FILES=()

HOTPLUGGABLE_PROCS=0
for file in /sys/devices/system/cpu/cpu*/online; do
  echo 1 > $file;
  if echo $file | grep -q "/sys/devices/system/cpu/cpu0"; then
    echo "$file is hotpluggable!!!"
    echo "Since we need a designated master processor (cpu0), will not hotplug this processor."
  else
    PROC_HOTPLUG_FILES+=($file)
    HOTPLUGGABLE_PROCS=$((HOTPLUGGABLE_PROCS + 1))
  fi
done
sleep 1
TOTALPROCS=$(nproc)
NONHOTPLUG_PROCS=$((TOTALPROCS - HOTPLUGGABLE_PROCS))
echo "${PROC_HOTPLUG_FILES[*]}"

if [ $HOTPLUGGABLE_PROCS == 0 ]; then
  echo "
ERROR: This system does not have any hotpluggable processors!!!
Can not do anything. Aborting...
"
  exit 1
fi
echo "
System has $TOTALPROCS processors.
$NONHOTPLUG_PROCS of these processors are not hotpluggable. Using these procs as masters.
$HOTPLUGGABLE_PROCS of these processors are hotpluggable. Using these procs as slaves.
At least $CPU_MINPROCS_ACTIVE processors will be kept alive at any given time."
printf "NICE CPU load (low-priority processes) will be "
if [ $IGNORE_NICE_LOAD == 1 ]; then printf "EXCLUDED"
else printf "INCLUDED"
fi
echo " in CPU utilization calculations.
"
echo "Running hotplug script..."
echo ""

# proc 0 is always on. Others are enabled based on load

#[[ -v WHITELIST_X11 ]] && sudo -n DISPLAY=$DISPLAY -u X11_USER

while true
do
  # Sleep command for polling interval...
  #sleep $POLLING_INTERVAL&
  # Get CPU usage (old)
  #echo "$[100-$(vmstat $POLLING_INTERVAL 2|tail -1|awk '{print $15}')] * $(nproc)" | bc > $CPUUSAGE_SHMFILE&

  # Get CPU usage (include nice load)
  get_cpuload_withnice()
  {
    CPUSAGE=$(top -bn2 -d1 | grep '%Cpu' | tail -1 | awk '{print (100-($8))}' | awk '{printf("%d\n",$1 + 0.5)}')
    echo "$CPUSAGE * $(nproc)" | bc > $CPUUSAGE_SHMFILE
  }


  # Get CPU usage (ignore nice load)
  get_cpuload_nonice()
  {
    CPUSAGE=$(top -bn2 -d1 | grep '%Cpu' | tail -1 | awk '{print (100-($8+$6))}' | awk '{printf("%d\n",$1 + 0.5)}')
    echo "$CPUSAGE * $(nproc)" | bc > $CPUUSAGE_SHMFILE
  }

  if [ $IGNORE_NICE_LOAD == 1 ]; then get_cpuload_nonice
  else get_cpuload_withnice
  fi&

  # Check for active window in whitelist...
  [[ -v WHITELIST_X11 ]] && if DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY xdotool getwindowfocus getwindowname | grep -E "$WHITELIST_X11" 2>&1 > /dev/null; then
    echo 1 > $X11CHECK_SHMFILE
  else
    rm -f $X11CHECK_SHMFILE
  fi &

  wait
  CPUTILIZATION=$(cat $CPUUSAGE_SHMFILE)
  if [ -f $X11CHECK_SHMFILE ]; then
    for file in /sys/devices/system/cpu/cpu*/online; do echo 1 > $file; done
    [ $CONSOLE_DEBUG -gt 0 ] && echo "ALL CPUs enabled. (WHITELIST_X11)
"
    # Wait until sleep command is finished.
    wait
    continue
  fi

  CPU_MAXCAP=0
  CPU_MINCAP=0
  # skip cpu core 0 (master is always on)
  CPUITER=1

  # Assume powersave mode on lid closed (if any)
  [ -f /proc/acpi/button/lid/LID/state ] && cat /proc/acpi/button/lid/LID/state | grep closed && CPUTILIZATION=10

  HOTPLUG_CPUITER=0
  while [ $CPUITER -lt $TOTALPROCS ]; do
    CPU_MAXCAP=$((CPU_MAXCAP+CPU_MAX_THRESH))
    CPU_MINCAP=$((CPU_MINCAP+CPU_MIN_THRESH))
    if [ $CPUITER -gt $(($NONHOTPLUG_PROCS - 1)) ]; then
      CURRENT_PROC=${PROC_HOTPLUG_FILES[HOTPLUG_CPUITER]}
#      echo $CURRENT_PROC
      if [ $CPUTILIZATION -gt $CPU_MAXCAP ]; then
# | [ $CPUITER -lt $CPU_MINPROCS_ACTIVE ]; then
#      echo "1 > /sys/devices/system/cpu/cpu$CPUITER/online";
        echo 1 > $CURRENT_PROC;
        [ $CONSOLE_DEBUG -gt 1 ] && echo $CURRENT_PROC ONLINE
      elif [ $CPUITER -lt $CPU_MINPROCS_ACTIVE ]; then
        echo 1 > $CURRENT_PROC;
        [ $CONSOLE_DEBUG -gt 1 ] && echo $CURRENT_PROC ONLINE
      elif [ $CPUTILIZATION -lt $CPU_MINCAP ]; then
#      echo "0 > /sys/devices/system/cpu/cpu$CPUITER/online";
        echo 0 > $CURRENT_PROC;
        [ $CONSOLE_DEBUG -gt 1 ] && echo $CURRENT_PROC OFFLINE
      else
        [ $CONSOLE_DEBUG -gt 1 ] && echo $CURRENT_PROC UNCHANGED
      fi
      HOTPLUG_CPUITER=$((HOTPLUG_CPUITER+1))
    fi
    CPUITER=$((CPUITER+1))
  done
  [ $CONSOLE_DEBUG -gt 0 ] && echo "$CONSOLE_DEBUG CPU USAGE: $CPUTILIZATION. $(nproc)/$TOTALPROCS CPUs enabled.
"
  # Wait until sleep command is finished.
  wait
done

cleanup
