# cutiescripts
A list of miscellaneous shell scripts that may prove useful under some circumstances, especially for resource-limited GNU/Linux systems.

### cpuhotplug86
A smart cpu hotplugging solution for the x86 family of processors.
Runs as a background daemon, comparing processor utilization to the number of cores available on a system.
Then it dynamically turns on/off hotpluggable cores.
May save a little power, especially on older hardware.

cpuhotplug86 places a config file in /etc/default/cpuhotplug86, allowing for further customisation of thresholds and the such.

### xwinhibernate
Opportunistically freezes processes of windows that are not currently visible on the current x11 session. Unfreezes them when they become visible again.
This has advantages for low-memory systems, as frozen processes are more easily swapped out to swap or zram. Kernel hacks such as UKSM may also be helped out by this.

There is a silly oversite with the Xorg devs assuming the clipboard is the responsibility of the application copied from, which breaks clipboard copying from frozen windows.
This script has a workaround, although it only works for text.

