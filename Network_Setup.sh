#!/bin/bash
# =====================================================================
# VLAN HOPPING LAB (Double Tagging Attack) - FULL SCRIPT
# Instructor Lab Script - Kali Linux + Open vSwitch
# ---------------------------------------------------------------------
# Topology:
#   S1 (OVS) : Node B + Node D (attacker)
#   S2 (OVS) : Node A + Node C
#
# VLAN Assignments:
#   VLAN 1    -> Native VLAN (untagged)
#   VLAN 100 -> Node A / Node B
#   VLAN 200 -> Node C / Node B (Target)
#
# Everything is brought UP automatically.
# =====================================================================

for v in $(ip -br link show | awk '{print $1}' | grep -E 'veth|@'); do
  sudo ip link del ${v%@*} 2>/dev/null || true
done





set -e

# --- 0. Pre-requisites Check ---
echo "[*] Checking for required tools: ovs-vsctl, ip, python3, scapy..."
if ! command -v ovs-vsctl &> /dev/null || ! command -v ip &> /dev/null || ! command -v python3 &> /dev/null; then
    echo "[!] Error: Missing required tools (ovs-vsctl, ip, python3). Please install them."
    exit 1
fi

if ! python3 -c "from scapy.all import Ether" &> /dev/null; then
    echo "[!] Error: Python package 'scapy' not found. Please install it: pip install scapy"
    exit 1
fi

# ------------------------------------------------------------
# 1. Cleanup
# ------------------------------------------------------------
echo "[+] Cleaning previous lab setup (Network Namespaces and OVS Bridges)..."
for ns in nodeA nodeB nodeC nodeD; do
    ip netns del $ns 2>/dev/null || true
done
ovs-vsctl --if-exists del-br S1
ovs-vsctl --if-exists del-br S2

# ------------------------------------------------------------
# 2. Create Network Namespaces
# ------------------------------------------------------------
echo "[+] Creating namespaces..."
for ns in nodeA nodeB nodeC nodeD; do
    ip netns add $ns
done

# ------------------------------------------------------------
# 3. Create veth pairs
# ------------------------------------------------------------
echo "[+] Creating veth pairs..."
ip link add vethA type veth peer name brA
ip link add vethB type veth peer name brB
ip link add vethC type veth peer name brC
ip link add vethD type veth peer name brD
ip link add s1-s2 type veth peer name s2-s1

# ------------------------------------------------------------
# 4. Assign interfaces to namespaces
# ------------------------------------------------------------
ip link set vethA netns nodeA
ip link set vethB netns nodeB
ip link set vethC netns nodeC
ip link set vethD netns nodeD

# ------------------------------------------------------------
# 5. Create OVS Bridges and Attach Ports
# ------------------------------------------------------------
echo "[+] Creating OVS bridges and attaching ports..."
ovs-vsctl add-br S1
ovs-vsctl add-br S2

ovs-vsctl add-port S1 brB
ovs-vsctl add-port S1 brD
ovs-vsctl add-port S1 s1-s2

ovs-vsctl add-port S2 brA
ovs-vsctl add-port S2 brC
ovs-vsctl add-port S2 s2-s1

# ------------------------------------------------------------
# 6. Bring OVS bridges and ports UP
# ------------------------------------------------------------
echo "[+] Bringing OVS bridges and links UP..."
for intf in S1 S2 brA brB brC brD s1-s2 s2-s1; do
    ip link set $intf up 2>/dev/null || true
done

# ------------------------------------------------------------
# 7. Configure VLANs on OVS
# ------------------------------------------------------------
echo "[+] Configuring VLAN tagging..."

# Node B: Trunk (VLANs 100 & 200 tagged, VLAN 1 native)
ovs-vsctl set port brB trunks=100,200 vlan_mode=native-untagged tag=1

# Node D: Access port (native VLAN 1 only)
ovs-vsctl set port brD vlan_mode=native-untagged tag=1

# Node A: VLAN 100 (tagged)
ovs-vsctl set port brA tag=100

# Node C: VLAN 200 (tagged)
ovs-vsctl set port brC tag=200

# Inter-switch trunk: VLANs 100 & 200 tagged, VLAN 1 native
ovs-vsctl set port s1-s2 trunks=100,200 vlan_mode=native-untagged tag=1
ovs-vsctl set port s2-s1 trunks=100,200 vlan_mode=native-untagged tag=1

# ------------------------------------------------------------
# 8. Assign IP addresses and enable interfaces (FIXED SECTION)
# ------------------------------------------------------------
echo "[+] Assigning IP addresses and bringing up interfaces in namespaces..."

# Node A (VLAN 100)
ip netns exec nodeA ip addr add 192.168.100.10/24 dev vethA

# Node B (Trunk: VLAN 1,100,200)
ip netns exec nodeB ip addr add 192.168.1.20/24 dev vethB  # native VLAN 1
# *** FIX: Bring the base interface UP before adding VLAN sub-interfaces ***
ip netns exec nodeB ip link set vethB up

ip netns exec nodeB ip link add link vethB name vethB.100 type vlan id 100
ip netns exec nodeB ip link add link vethB name vethB.200 type vlan id 200
ip netns exec nodeB ip addr add 192.168.100.20/24 dev vethB.100
ip netns exec nodeB ip addr add 192.168.200.20/24 dev vethB.200
ip netns exec nodeB ip link set vethB.100 up
ip netns exec nodeB ip link set vethB.200 up

# Node C (VLAN 200)
ip netns exec nodeC ip addr add 192.168.200.30/24 dev vethC

# Node D (Attacker)
ip netns exec nodeD ip addr add 192.168.1.40/24 dev vethD

# Bring up all remaining links inside namespaces
for ns in nodeA nodeB nodeC nodeD; do
    ip netns exec $ns ip link set lo up
    ip netns exec $ns ip link set veth${ns: -1} up
done

# ------------------------------------------------------------
# 9. Quick verification
# ------------------------------------------------------------
echo
echo "[✓] VLAN Lab setup complete — all links and bridges are UP!"
echo "------------------------------------------------------------"
echo "[*] Configuration Check (OVS Ports and Tags):"
ovs-vsctl show | grep -E "port|tag"
echo "------------------------------------------------------------"
echo "[*] Test connectivity (expected success):"
#ip netns exec nodeA ping -c 3 192.168.100.20    # VLAN 100 (A→B)
#ip netns exec nodeC ping -c 3 192.168.200.20    # VLAN 200 (C→B)
#ip netns exec nodeD ping -c 3 192.168.1.20      # VLAN 1 (D→B)
echo "------------------------------------------------------------"
echo "[*] Isolation check (expected failure):"
ip netns exec nodeA ping -c 3 192.168.200.30 || echo "[✓] A->C ping failed as expected (VLAN Isolation working)"
echo "------------------------------------------------------------"

