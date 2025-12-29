LAB.2 VLAN and VLAN hopping

1. Overview
The goal of this lab is to demonstrate how an attacker in VLAN 1 (Node D) can bypass VLAN
isolation to reach victims in VLAN 100 (Node A) and VLAN 200 (Node C).
Topology
• S1 (OVS Bridge): Connects Node B (Trunk) and Node D (Attacker).
• S2 (OVS Bridge): Connects Node A (VLAN 100) and Node C (VLAN 200).
• Trunk Link: Connects S1 and S2, carrying VLANs 1, 100, and 200.
Node Role VLAN IP Address
Node A Victim 1 100 192.168.100.10
Node B Gateway/Server Trunk (1, 100, 200) 192.168.1.20, 100.20, 200.20
Node C Victim 2 200 192.168.200.30

Node D Attacker 1 (Native) 192.168.1.40
2. Lab Setup and Execution
Follow these steps to initialize the environment and perform the attack.
Step 1: Environment Setup
This script creates network namespaces, OVS bridges, and virtual interfaces.
Bash
# Make the setup script executable
chmod +x Network_Setup.sh.sh
# Run the setup (requires sudo for OVS and namespaces)
sudo ./Network_Setup.sh.sh

Step 2: Verification (Optional)
Check that the nodes are isolated. Node D should not be able to ping Node A or C
normally.
Bash
# This should fail (Expected isolation)
sudo ip netns exec nodeD ping -c 2 192.168.100.10
Step 3: Launch the Double Tagging Attack
The attacker (Node D) uses Scapy to craft a packet with two tags: Dot1Q(vlan=1) and
Dot1Q(vlan=100).
Bash
# Run the attack script from the attacker's namespace
sudo ip netns exec nodeD python3 Attacker_Double_Tagging.py.py
Step 4: Observation
To see the attack in action, open a second terminal and sniff traffic on the trunk link or the
victim's interface:
Bash
# Monitor traffic entering S2 (the second switch)
sudo ovs-tcpdump -i s2-s1

3. How the Attack Works
1. The Crafting: Node D sends a frame with an outer tag of 1 and an inner tag of 100.
2. Switch 1 (S1): Receives the frame. Since the outer tag matches S1's Native VLAN
(1), S1 strips the outer tag and forwards the frame out of the trunk port toward S2.
3. The Trunk: The frame now travels across the link with only one tag: VLAN 100.
4. Switch 2 (S2): Receives the frame, sees the tag for VLAN 100, and delivers it to
Node A.
5. Result: Node D has successfully "hopped" from VLAN 1 into VLAN 100.
