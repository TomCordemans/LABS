---
title: Additional Labs for Netacad CyberOps Associate
---

## ARP spoofing (MITM)

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
    1. Get an overview of your network. (Kali Linux)
    
    ![Success](./assets/netdiscover_command.png)

    ![Success](./assets/netdiscover_result.png)

    The result shows us the client (192.168.1.1) and the server (192.168.1.2).

    2. Start the communication between the client and the server.

    ![Success](./assets/ping.png)
    
    3. Look at the MAC address table of the client.

    ![Success](./assets/first_arp.png)

    4. Start Wireshark (Kali Linux)

    ![Success](./assets/first_Wireshark.png)

    The result shows us no ICMP traffic destined for the server (192.168.1.2).

    5. Set IP forwarding. (Kali Linux)
    
    IP forwarding allows an operating system to forward packets as a router does or more generally to route them through other networks.
    
    ![Success](./assets/ip_forward.png)

    6. Launch the MITM attack. (Kali Linux)

        1. Start Ettercap.

        ![Success](./assets/Ettercap.png)

        2. Select the correct sniffing method and interface.

        ![Success](./assets/sniffing.png)

        ![Success](./assets/sniffing2.png)

        3. Select  the hosts (via a scan or manually).

        ![Success](./assets/scan.png)

        ![Success](./assets/scan2.png)

        4. Start the attack.

        ![Success](./assets/attack.png)

        ![Success](./assets/attack2.png)

    7. Verify if the attack was succesfull.

    We are now capturing the traffic between the client and the server.

    ![Success](./assets/after_wireshark.png)

    The MAC address table of the client is poisonend. (192.168.1.10 is our Kali)

    ![Success](./assets/last_arp.png)

6. Conclusion
    * A man-in-the-middle attack (MITM) is easy to establish and hard to detect.

## Attack the SAM database

1. Goal
    * Recover the password of a user that uses Microsoft Windows as operating system.
    
2. Used hardware
    * 1 laptop with Kali Linux
    * 1 laptop with Microsoft Windows (user)  

3. Used software
    * Kali Linux (2020.1)
    * Microsoft Windows 10

4. Setup
    
    ![Success](./assets/setup.png)

5. Getting started

    1. Introduction

        The Security Account Manager (SAM) is a database file that stores users' passwords.

        [More information about Security Account Manager](https://en.wikipedia.org/wiki/Security_Account_Manager)

        There are 2 possible strategies:

            * The online attack
            The user didn't log off. So Microsoft Windows is still running.

            * The offline attack
            The hard disk of the user is in your possion.
             

    2. The online attack

        1. Download the tool PwDump8.
        
            [On your own responsibility!](http://blackmath.it/#Download)


        2. Run the tool (requires administrative privileges) on the laptop of the user.

            ![Success](./assets/pwdump.png)

        3. Retrieve the password.

            There are multiple websites available.

            ![Success](./assets/hash.png)
    
    3. The offline attack

        1. Attach the hard disk to Kali laptop.

            ![Success](./assets/disk.png)

        2. Start ophcrack.

            ![Success](./assets/ophcrack.png)
        
        3. Select Load - Encrypted SAM.

            ![Success](./assets/sam.png)
        
        4. Check the result.

            ![Success](./assets/ophcrack2.png)

        5. Retrieve the password.

            There are multiple websites available.

            ![Success](./assets/hash.png)

6. Conclusion
    * Never leave your computer unattended!
        


