---
title: ARP spoofing (MITM)
---

# ARP spoofing (MITM)

1. Goal
    * Intercept the communication between 2 devices in a switched network.

2. Used hardware
    * 1 laptop with Kali Linux
    * 2 devices (Computers, laptops, ...)

3. Used software
    * Kali Linux (2019.4)

4. Setup


5. Getting started
    1. Get an overview of your network (Kali Linux)
    
    ![Success](./assets/netdiscover_command.png)

    ![Success](./assets/netdiscover_result.png)

    The result shows us the server (192.168.1.1) and the client (192.168.1.101).

    2. Start the communication between the client and the server

     ![Success](./assets/ping.png)
    
    3. Look at the MAC address table of the client

    ![Success](./assets/first_arp.png)

    4. Start Wireshark (Kali Linux)

    ![Success](./assets/first_Wireshark.png)

    The result shows us no ICMP-traffic destined for the server (192.168.1.1)

    5. Set IP forwarding (Kali Linux)
    
    IP forwarding allows an operating system to forward packets as a router does or more generally to route them through other networks.
    
     ![Success](./assets/ip_forward.png)

    6. Launch the MITM attack

        1. Start Ettercap

        ![Success](./assets/ettercap.png)

        2. Select Sniff - Unified sniffing - eth0

        3. Select Hosts - Scan for hosts

        


