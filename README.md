# cutiescripts
A list of miscellaneous shell scripts that may prove useful under some circumstances, especially for resource-limited GNU/Linux systems, or severely IPv6-challenged internet connections of the CG-NAT variety.

## cpuhotplug86
A smart cpu hotplugging solution for the x86 family of processors. This script needs to be run as root, obviously...

Runs as a background daemon, comparing processor utilization to the number of cores available on a system.
Then it dynamically turns on/off hotpluggable cores.
THis might save a little power, especially on older hardware.

NICE load can be ignored in configuration, preventing low-priority processes from triggering CPU hotplugging.

cpuhotplug86 places a config file in /etc/default/cpuhotplug86, allowing for further customisation of thresholds and the such.

## xwinhibernate
REMOVED - Use https://github.com/kernc/xsuspender instead!

## auto-ipv6wg
Automatically starts wireguard tunnel for IPv6 over IPv4 translation whenever necessary. Disabling it whenever native IPv6 comes back online again.
Useful in circumstances when one has multiple internet connections, wherein some lack native IPv6 support while others do not, and one doesn't wish for the wireguard tunnel to be always active (probably to save power).

e.g. My real-world circumstance where my home internet has native IPv6 connectivity (dual-stack with IPv4 behind CG-NAT), but my mobile connections only support IPv4 (behind SYMMETRIC CG-NAT no less... Not even Teredo would work over that!)

Wireguard should work over the worst of NAT environments, as long as the port isn't blocked (it shouldn't be, unless you are using work/school internet, or a crappy public Wi-Fi. I'd advise you use a mobile phone hotspot or a dedicated mobile hotspot device instead of those for personal use anyway.). This script should provide the same fallback IPv6 connectivity when roaming on networks without native IPv6 support, regardless of the technology (3G/4G/5G, 802.11, Ethernet, PPP, Dial-Up, etc... but probably not IPoAC (rfc1149, rfc2549, and rfc6214) due to severe latency issues.).

This script is run as an unprivileged user (i.e. not root), in a desktop session.
This is not compatible with most commercial VPN providers, or their software (which often block IPv6 anyway (leak prevention)). This is only for IPv6 translation purposes, and is not intended to offer any privacy or anonymity whatsoever.

For this to work, you need an IPv6-enabled wireguard VPN connection configured in NetworkManager, with autoconnect disabled. I would advise using a cheap IPv6-capable VPS (Digitalocean, Linode, etc...) for the wireguard server, as long as it has an IPv6 prefix assigned to it. If one has sufficient know-how, they can assign a separate IPv6 for each wireguard client. If a prefix isn't available, IPv6 NAT (ip6tables MASQUERADE) can be used for simplicity of setup, although this isn't recommended as it complicates the network topology (IPv6 has no shortage of addresses, one can easily obtain a 6to4 tunnel for their IPv4-only server if necessary).

> A server with a single /64 subnet can theoretically serve billions of clients this way, but should realistically be limited to less than 100,000 per server due to other potential bottlenecks. A load-balanced server cluster with a shared network subnet or a sufficient autoconfiguration protocol should work around this if one wishes to scale this up further.

Useful resources: https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-debian-11 https://wiki.archlinux.org/title/WireGuard 

As you can see, this requires a little knowledge of IPv6 networking, routing, and firewalling in order to be set up, but it works once configured.
