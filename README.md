# cutiescripts
A list of miscellaneous shell scripts that may prove useful under some circumstances, especially for resource-limited GNU/Linux systems.

### cpuhotplug86
A smart cpu hotplugging solution for the x86 family of processors. This script needs to be run as root, obviously...

Runs as a background daemon, comparing processor utilization to the number of cores available on a system.
Then it dynamically turns on/off hotpluggable cores.
May save a little power, especially on older hardware.

cpuhotplug86 places a config file in /etc/default/cpuhotplug86, allowing for further customisation of thresholds and the such.

### xwinhibernate
X11 ONLY, NO WAYLAND SUPPORT!
Opportunistically freezes processes of windows that are not currently visible on the current x11 session. Unfreezes them when they become visible again.

This has advantages for low-memory systems, as frozen processes are more easily swapped out to swap or zram. Kernel hacks such as UKSM may also be helped out by this.

This script is run as an unprivileged user (i.e. not root), in a desktop session. Tested in XFCE, works like a charm. Should also work in other Xorg setups, including things like Compiz.

There is a silly oversite with the Xorg devs assuming the clipboard is the responsibility of the application copied from, which breaks clipboard copying from frozen windows.
This script has a workaround, although it only works for text.

### auto-ipv6wg
Automatically starts wireguard tunnel for IPv6 over IPv4 translation whenever necessary. Disabling it whenever native IPv6 comes back online again.

Useful in circumstances when one has multiple internet connections, and some lack native IPv6 support.

e.g. My real-world circumstance of my home internet having dual-stack IPv4/IPv6 connectivity, but my mobile connections only support IPv4 (behind SYMMETRIC CG-NAT no less... Not even Teredo would work over that!)

Wireguard should work over the worst of NAT environments, as long as the port isn't blocked (it shouldn't be, unless you are using work/school internet, or a crappy public Wi-Fi. I'd advise you use a mobile phone hotspot instead of those for personal use.)

This script is run as an unprivileged user (i.e. not root), in a desktop session.

For this to work, you need a wireguard VPN connection configured in NetworkManager, with autoconnect disabled. I would advise using a cheap IPv6-capable VPS (Digitalocean, Linode, etc...) for the wireguard server, as long as it has an IPv6 prefix assigned to it. If one has sufficient know-how, they can assign a separate IPv6 for each wireguard client. If a prefix isn't available, IPv6 NAT (ip6tables MASQUERADE) can be used for simplicity of setup, although this isn't recommended.

As you can see, this requires knowledge of IPv6 networking, routing, and firewalling in order to be set up, but it works once configured.
