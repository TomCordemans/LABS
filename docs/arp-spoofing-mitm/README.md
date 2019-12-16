---
title: ARP spoofing (MITM)
---

# ARP spoofing (MITM)

1. Goal
    1. Intercept the communication between 2 devices in a switched network.

2. Used hardware
    1. 1 laptop with Kali Linux
    2. 2 devices (Computers, laptops, ...)

3. Used software
    1. Kali Linux (2019.4)

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

    The result show us no ICMP-traffic destined for the server (192.168.1.1)

    5. Set ip forwarding (Kali Linux)
    
    IP forwarding allow an operating system to forward packets as a router does or more generally to route them through other networks.
    
    
