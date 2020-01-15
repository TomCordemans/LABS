---
title: Decryption of TLS sessions
---

# Decryption of TLS sessions

1. Goal
    * Using Wireshark to decrypt (HTTPS) web traffic.
     
2. Used hardware
    * 1 laptop with Microsoft Windows

3. Used software
    * Wireshark 3.2.0

4. Setup
    
    ![Success](./assets/setup.png)

5. Getting started
    
    1. Install WinPcap on the remote system.

    [More information about WinPcap](https://www.winpcap.org/)
    
    2. Start the Remote Packet Capture Protocol service on the remote system.

    ![Success](./assets/services.png)

    3. Add a firewall rule to the host-based firewall of the remote system (if necessary).

    ![Success](./assets/firewall.png)

    4. Open Wireshark on your local system and select "Capture" followed by "Options".

      ![Success](./assets/Wireshark1.png)
    
    5. Select "Manage Interfaces" followed by "Remote Interfaces".

    ![Success](./assets/Wireshark2.png)

    6. Select "+" and add the needed information.

    ![Success](./assets/Wireshark3.png)

    7. The following result appears. Confirm this window.

    ![Success](./assets/Wireshark4.png)

    8. Look for the right interface and start the capture.

    ![Success](./assets/Wireshark5.png)

    9. The result is a succesfull remote capture.

    ![Success](./assets/Wireshark6.png)
    
6. Conclusion
    
    Besides the regular capturing methods (SPAN, TAP, HUB,... ) this method also provides some possibilities.   Please add content to this empty page.
