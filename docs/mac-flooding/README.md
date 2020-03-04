---
title: MAC flooding
---

# MAC flooding

1. Goal
    * Changing the behavior of the switch to the behavior of a hub. (Monitoring all traffic)

2. Used hardware
    * 1 laptop with Kali Linux
    * 2 devices (Client & Server)
    * 1 laptop with Wireshark
    * 1 switch

3. Used software
    * Kali Linux (2020.1)
    * Wireshark 3.2.2

4. Setup

    ![Success](./assets/flooding.png)

5. Getting started
    1. Get an overview of your network. (Kali Linux)
    
    ```
    root@kali:~# sudo netdiscover
    ```

    ```
    Currently scanning: 192.168.20.0/16   |   Screen View: Unique Hosts                                  
                                                                                                      
    2 Captured ARP Req/Rep packets, from 2 hosts.   Total size: 120                                      
    _____________________________________________________________________________
        IP            At MAC Address     Count     Len  MAC Vendor / Hostname      
    -----------------------------------------------------------------------------
    192.168.1.1     ec:f4:bb:1b:76:71      1        60  Dell Inc.                                          
    192.168.1.4     d0:67:e5:56:ca:c8      1        60  Dell Inc.   
    ```

    The result shows us the client (192.168.1.1) and the server (192.168.1.4).

    2. Start the communication between the client and the server.

    ```
    C:\Users\Student>ping 192.168.1.4 -t

    Pinging 192.168.1.4 with 32 bytes of data:
    Reply from 192.168.1.4: bytes=32 time<1ms TTL=64
    Reply from 192.168.1.4: bytes=32 time<1ms TTL=64
    Reply from 192.168.1.4: bytes=32 time<1ms TTL=64
    Reply from 192.168.1.4: bytes=32 time<1ms TTL=64
    ```
    
    3. Look at the MAC address table of the client.

    ![Success](./assets/first_arp.png)

    4. Start Wireshark (Kali Linux)

    ![Success](./assets/first_Wireshark.png)

    The result shows us no ICMP traffic destined for the server (192.168.1.2).

    5. Set IP forwarding. (Kali Linux)