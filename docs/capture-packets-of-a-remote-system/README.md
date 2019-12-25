---
title: Capture packets of a remote system
---

# Capture packets on a remote system

1. Goal
    * Wireshark captures traffic from your system’s local interfaces by default, but this isn’t always the location you want to capture from.
     
2. Used hardware
    * 2 laptops with Microsoft Windows

        Note: This feature is only available on Windows. Wireshark’s official documentation recommends that Linux users use an SSH tunnel.

3. Used software
    * Wireshark 3.2.0
    * WinPcap 4.1.3

4. Setup
    
    ![Success](./assets/setup.png)

5. Getting started
    
    1. Install WinPcap on the remote system.

    [More information about WinPcap](https://www.winpcap.org/)
    
    2. Start the Remote Packet Capture Protocol service on the remote system.

    ![Success](./assets/services.png)

    3. Add a firewall rule to the host-based firewall of the remote system (if necessary)

    ![Success](./assets/firewall.png)
        

    6. Conclusion
    
    It is recommended to disable CDP whenever possible.Please add content to this empty page.
