---
title: Wireless sniffing
---

# Wireless sniffing

1. Goal
    * Collect and analyze wireless traffic.

2. Used hardware
    * Alfa AWUS036NHA (Long-range USB Adapter)
    * TL-MR3020 (Porable 3G/4G Wireless N Router)
    * 1 laptop with Kali Linux
    * 1 device with a wireless connection (Smartphone, tablet, ...)

3. Used software
    * Kali Linux (2019.4)

4. Setup

![Success](./assets/setup.png)

5. Getting started
    1. Display the list of available adapters (Kali Linux)
    
    ```
    root@kali:~# airmon-ng

    PHY     Interface       Driver          Chipset

    phy0    wlan0           iwlwifi         Intel Corporation WiFi Link 5100
    phy1    wlan1           ath9k_htc       Qualcomm Atheros Communications AR9271 802.11n

    root@kali:~#
    ```
    
    2. Monitor mode allows a wireless network interface controller to monitor all traffic received on a wireless channel.
        1. Kill the network managers. (To Avoid interference with other tools)
        ```
        root@kali:~# airmon-ng check kill

        Killing these processes:

        PID Name
        626 wpa_supplicant

        root@kali:~#
        ```
        2. Put the adapter in monitor mode
        ```
        root@kali:~# airmon-ng start wlan1

        PHY     Interface       Driver          Chipset

        phy0    wlan0           iwlwifi         Intel Corporation WiFi Link 5100
        phy1    wlan1           ath9k_htc       Qualcomm Atheros Communications AR9271 802.11n

                (mac80211 monitor mode vif enabled for [phy1]wlan1 on [phy1]wlan1mon)
                (mac80211 station mode vif disabled for [phy1]wlan1)

        root@kali:~#
        ```
        3. Scan the environment
        ```
        root@kali:~# airodump-ng wlan1mon

        CH 12 ][ Elapsed: 1 min ][ 2019-12-23 11:32

        BSSID              PWR  Beacons    #Data, #/s  CH  MB   ENC  CIPHER AUTH ESSID

        68:FF:7B:45:A5:88  -33       94        0    0  10  270  WPA2 CCMP   PSK  TP-Link_TEST
        3A:43:3D:4B:CE:5E  -53       97       16    0   6  130  WPA2 CCMP   MGT  TelenetWiFree
        0A:19:70:AA:AB:25  -86       23        0    0   1  54e. WPA2 CCMP   MGT  Proximus Public Wi-Fi
        7C:DB:98:0D:D1:8D  -87        7        0    0   1  130  WPA2 CCMP   PSK  Orange-dd189
        7E:DB:98:0D:D1:8E  -90        5        0    0   1  130  WPA2 CCMP   PSK  Guest-Orange-dd189
        AC:22:05:AC:81:93  -87        2        0    0   1  130  WPA2 CCMP   PSK  MyBike
        00:13:1E:2F:51:37  -85        0        0    0   1   65  WPA2 CCMP   PSK  My BMW Hotspot 0663
 
        BSSID              STATION            PWR   Rate    Lost    Frames  Probe

        (not associated)   2E:7A:91:39:13:18  -69    0 - 1      0        5
        (not associated)   00:0E:58:D1:9D:15  -71    0 - 0      0        4  Sonos_0AXtfXNXSHHin1p0B8k3msUjf6
 
        root@kali:~#
        ```
