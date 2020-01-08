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

![Success](./assets/mitm.png)

5. Getting started
    1. Get an overview of your network (Kali Linux)
    
    ![Success](./assets/netdiscover_command.png)

    ![Success](./assets/netdiscover_result.png)

    The result shows us the client (192.168.1.1) and the server (192.168.1.2).

    2. Start the communication between the client and the server

    ![Success](./assets/ping.png)
    
    3. Look at the MAC address table of the client

    ![Success](./assets/first_arp.png)

    4. Start Wireshark (Kali Linux)

    ![Success](./assets/first_Wireshark.png)

    The result shows us no ICMP-traffic destined for the server (192.168.1.2)

    5. Set IP forwarding (Kali Linux)
    
    IP forwarding allows an operating system to forward packets as a router does or more generally to route them through other networks.
    
    ![Success](./assets/ip_forward.png)

    6. Launch the MITM attack (Kali Linux)

        1. Start Ettercap

        ![Success](./assets/ettercap.png)

        2. Select Sniff - Unified sniffing - eth0

        ![Success](./assets/sniffing.png)

        ![Success](./assets/sniffing2.png)

        3. Select Hosts - Scan for hosts or you can add your targets manually

        ![Success](./assets/scan.png)

        ![Success](./assets/scan2.png)

        4. Start the attack

        ![Success](./assets/attack.png)

        ![Success](./assets/attack2.png)

    7. Verify if the attack is succesfull

    We are now capturing the traffic between the client and the server.

    ![Success](./assets/after_wireshark.png)

    The MAC-address table of the client is poissend. (192.168.1.10 is our Kali)

    ![Success](./assets/second_arp.png)


        


