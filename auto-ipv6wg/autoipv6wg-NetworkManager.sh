#!/bin/bash

# We will check if native IPv6 is available. If not, then we fire up the tunnel.
# Once IPv6 becomes available again, or if IPv4 internet disconnects, we shut down the tunnel...
#
# Enter connection name, and interface name in the below variables...
# NM_CONN_NAME identifies the connection in NetworkManager.
# IFACE_NAME is used to identify the tunnel interface using ip -6 a and ip -6 r

NM_CONN_NAME="wg-ipv6"
IFACE_NAME="wgv6"

# END CONFIG
#
# Do not edit below this line unless you know what you are doing...

# This script is pretty basic. It should be trivial to modify this for systemd-networkd if necessary.

wg-up()
{
  nmcli c up "$NM_CONN_NAME" > /dev/null
}

wg-down()
{
  nmcli c down "$NM_CONN_NAME" > /dev/null
}


cleanup()
{
  wg-down
  exit 0
}

while true; do
  if ip -4 route | grep -q default; then
    if ip -6 route | grep default | grep -vq "$IFACE_NAME"; then
      if ip -6 route | grep -q "$IFACE_NAME"; then
        wg-down
        echo "Deactivate IPv6 over Wireguard (native IPv6 available)..."
      fi
    else
      if ! ip -6 route | grep -q "$IFACE_NAME"; then
        wg-up
        echo "Activate IPv6 over Wireguard (no native IPv6 connection, native IPv4 available)..."
      fi
    fi
  else
    if ip -6 route | grep -q "$IFACE_NAME"; then
      wg-down
      echo "Deactivate IPv6 over Wireguard (no IPv4 connection)..."
    fi
  fi
  sleep 5
done
