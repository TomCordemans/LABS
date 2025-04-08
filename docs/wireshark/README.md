---
title: Wireshark course
---

# Under construction (My goal for 2025)

This course introduces you to the fundamental skills needed to use Wireshark effectively. It covers the most commonly used protocols and explores a variety of intriguing problems. To enhance your learning experience, the course incorporates practical exercises to share as much expertise as possible.   

## 1 Introduction
    
**1.1. What is Wireshark?**

Wireshark is an application known as a "packet sniffer" and "protocol analyzer," designed to capture and analyze data on a network. It is a the successor of the once widely used Ethereal. The functionality of Wireshark is somewhat similar to the [tcpdump](https://www.tcpdump.org/) tool, but it provides a GUI and additional functionality for sorting, filtering and visualising data.   

The figure below shows the main window of Wireshark with the differtent toolbars and panes.   

![Success](./assets/main.png)

Wireshark enables users to monitor data transmitted over a network by setting the network card to promiscuous mode. This mode allows the network card to process all incoming frames, not just those specifically addressed to it.  

Beyond merely displaying network traffic, Wireshark has the capability to interpret the structure of numerous network protocols. This enables the software to present the various nested protocols and reveal the contents of each field in detail.   

Wireshark is available under an open-source license and is compatible with multiple platforms, including Windows, Unix, Unix-like systems such as Linux, and macOS. It utilizes Npcap/libpcap to capture network traffic.   

![Success](./assets/visual.png)

* **Qt** provides a platform independent graphical user interface for Wireshark.   
* The **Core engine** supports thousands of dissectors and puts everything in a readable format.   
* The **Dumpcap capture engine** determines how the capture process starts and stops.   
* The **libpcap/Npcap** is a specific driver that takes the frames from the network and offers them to the **Dumpcap capture engine**.   
* When you open a saved pcapng file in Wireshark, you use the **Wiretap library** to offer the saved frames to the **Core engine**.   

**1.2. When to use Wireshark?**

Wireshark provides visibility into the traffic's source, destination, and timing, but it doesn't explain the reasons behind the traffic. Therefore, it's essential to review the application and operating system logs and debug information.   

Wireshark, on the other hand, can guide you on where to focus your investigation. For many "black box" network devices with limited or nonexistent user interface, Wireshark often becomes the primary troubleshooting tool.   

Some of the most notable uses of Wireshark include:

* Network traffic analysis (e.g., identifying top talkers)
* Troubleshooting issues (e.g., diagnosing slow network performance)
* Security investigations (e.g., detecting suspicious hosts)
* Application analysis (e.g., bandwidth consumption)

**1.3. First exploration**

In this exercise, we will take a quick tour of the main window, along with the various toolbars and panes.
The following file will be used: [intro.pcapng](https://www.tomcordemans.net/intro.pcapng) 

Questions:
* How many packets does this pcapng file contain?
* What IP addresses made a TCP connection in frames 18, 21, and 22?
* What HTTP command was sent by the client in frame 23?
* What response was sent by the HTTP server in frame 29?
* What is the length of the largest frame in this pcapng file?
* What protocols are visible in the protocol column?
* What web browser was used by the client?

## 2 Getting Wireshark ready

**2.1 Using configuration profiles**

Configuration profiles enable you to customize settings based on your specific needs. For instance, you can set up separate profiles for troubleshooting and cybersecurity analysis.   
By default, Wireshark uses the default profile. It’s recommended to create a new profile promptly to preserve the default profile as a reference point for all future profiles.

![Success](./assets/default.png)

A configuration profile is a folder containing text files that are loaded when the associated profile is activated. These files define preference settings, display filters, coloring rules, and more.
Configuration profiles can be effortlessly shared using the import and export features. Profiles can be managed in various ways, such as through the menu by navigating to Edit > Configuration Profiles.
Recent enhancements such as "Automatic Profile Switching" will be explored later in this course. 

Tip: Create a new profile before continuing with this course.   

![Success](./assets/profile.png)

**2.2 Adding/removing columns**

In this exercise, we will add an extra column.   
The following file will be used: [column.pcapng](https://www.tomcordemans.net/column.pcapng)

While browsing, an HTTP client makes multiple requests for HTTP objects to one or more HTTP servers. Our goal is to obtain an overview of all HTTP servers.

The following steps will be used:
* Step 1: Apply the display filter **http** in the filter toolbar.
* Step 2: Look for a **HTTP GET** in the packet list pane.
* Step 3: Look for the **Host** field in the packet details pane.
* Step 4: Right-click and select **Apply as Column**.

The figure below shows an extra column that can be sorted.

![Success](./assets/column.png)

**2.3 Wireshark dissectors**

Analyzing network traffic is one of Wireshark's most essential and powerful capabilities. The "dissection process" transforms raw data streams (bits) into readable requests, responses, refusals, retransmissions, and more.
Wireshark's core engine recognizes the structure of thousands of protocols and applications.   

For example, a computer on an LAN transmits an HTTP GET request to a website.   
First, the frame dissector processes the data and makes the information accessible.

![Success](./assets/diss_frame.png)

Next, the frame dissector passes the task to the Ethernet dissector, which interprets and presents the fields of the Ethernet header.

![Success](./assets/diss_ethernet.png)

The next dissector is determined by the contents of the Type field. In this case, the Type field is 0x0800, indicating IPv4, so the IPv4 dissector is called next.

![Success](./assets/diss_ipv4.png)

The IPv4 dissector interprets the IPv4 fields and examines the Protocol field to identify the next dissector. In this case, the TCP dissector takes over, processing the data and displaying the relevant information. The Port field then determines the subsequent dissector.

![Success](./assets/diss_tcp.png)

The HTTP dissector interprets and processes the different HTTP fields.

![Success](./assets/diss_http.png)

What happens if the dissectors fail to recognize the network traffic?

**2.4 Network traffic through non-standardized ports**

Network traffic that bypasses standard ports can be frustrating for a network administrator, as it often appears suspicious (e.g., an attempt to bypass firewall rules).   
If you need to manually associate a port with a specific protocol, you can do so through **Edit → Preferences → Protocols**.

![Success](./assets/pref_http.png)

**Statistics → Protocol Hierarchy** lets you identify issues with assigning dissectors to specific network traffic. The "Data" section refers to network traffic for which no appropriate dissector was found.

![Success](./assets/data.png)

**2.5 Hands-on exercise**

To effectively troubleshoot with a network analyzer (such as Wireshark), a deep understanding of the OSI model and its associated protocols is essential. The following exercise will assess the students' knowledge and skills, allowing us to identify any necessary refresher training.

The figure below shows the used topology.

![Success](./assets/topology.png)

**Problem Statement:**  
A user reports being unable to access the internal website (**http://webserver.test.local**), while external websites remain accessible. We have access to network traffic from **PC1** through a port mirror and will analyze the provided capture file [website.pcapng](https://www.tomcordemans.net/website.pcapng).  

**Question:**  
Identify the most likely cause of the issue.  

* A) IP conflict  
* B) MAC spoofing  
* C) Incorrect DNS configuration on Server1  
* D) Server2 is completely unreachable
* E) The web server operates on a non-standard port  
* F) Misconfigured proxy server on PC1

## 3 How and where to capture

Thorough preparation, including **network documentation and troubleshooting procedures**, is crucial!   
When a problem arises, there won’t be time to analyze the network from scratch. Users expect swift and precise action.

**3.1 Determine the optimal capture location**  

Aim to capture traffic as close as possible to the affected device. When a user reports an issue (e.g., slow downloads), it is best to analyze the problem from the user's perspective for the most accurate diagnosis.

**3.2 Capturing options**

There are three different ways to capture network traffic near the target device.

**First option:**

Install Wireshark directly on the host. Alternatively, you can use other tools like tcpdump.

![Success](./assets/host.png)

**Second option:**

Most managed switches support port mirroring, allowing them to replicate all network traffic (excluding data link-layer errors) from a designated port to another port on the switch. This approach provides significant flexibility, with options like SPAN (Switch Port Analyzer), RSPAN (Remote SPAN), and ERSPAN (Encapsulated RSPAN).

![Success](./assets/mirror.png)

**Third option:**

A network tap is a full-duplex device placed between the target device and the switch, allowing it to forward all network traffic, including data link-layer errors. The main drawback of this option is its cost.

![Success](./assets/tap.png)

Inserting a hub between the target and the switch is not recommended, as it significantly alters the network and can lead to substantial performance degradation.

**3.3 Capturing wireless networks. (WLAN)**

Capturing wireless network traffic is significantly more complex. Therefore, we will dedicate a separate chapter to capturing, analyzing, and decrypting wireless networks.

**3.4 Active interfaces**

If Wireshark does not detect the interface, it cannot be used within the application.   
You can view your available interfaces by navigating to **Capture → Options**.

![Success](./assets/options.png)

**3.5 Capturing invisible**

For accurate results, avoid making changes to the network configuration or keep them to a minimum. To make the computer running Wireshark invisible on the network, you can disable the TCP/IP stack.

Disabling the TCP/IP stack will ensure that Wireshark continues to function while the OS and other applications do not generate additional network traffic.

![Success](./assets/stack.png)

**3.6 Managing large volumes of network traffic**

Wireshark does not handle large capture files (pcap or pcapng) efficiently. To improve performance, you can use a **File Set** to split large files into smaller ones that Wireshark can process more quickly.

Recommended practice: Aim to keep your files under 100 MB whenever possible.

To clarify a few concepts, we will go through an exercise.  
First, we launch Wireshark and navigate to **Capture → Options**.  

Our goal is to capture network traffic while splitting it into multiple files, each limited to 1MB or 10 seconds in duration, with the capture automatically stopping after five files.

![Success](./assets/size.png)

![Success](./assets/amount.png)

Now, click Start and browse the internet for a minute.  
The image below displays the final result.

![Success](./assets/files.png)

Imagine you need to capture network traffic continuously while storing up to five files, each covering a time span of one minute. Which option would you select? In what situations would this option be beneficial?

**3.7 Using capture filters**

If you plan to use Wireshark in a high-speed network environment, it may result in packet loss due to its limited processing speed. To manage this, capture filters can be applied to reduce the number of packets. However, be aware that using capture filters may inadvertently exclude relevant network traffic.

Under normal conditions, it's best to avoid using capture filters. Only use them if Wireshark struggles to process network traffic. You can check the status bar for dropped packets to identify any issues.

![Success](./assets/dropped.png)

Capture filters utilize BPF (Berkeley Packet Filter) syntax. Here are some examples of BPF syntax:

| Syntax | Description |
| ------ | ----------- |
| host 10.4.1.1 | Capture traffic to/from not host 10.4.1.1 |
| not host 10.4.1.1 | Capture all traffic except traffic to/from 10.4.1.1 |
| src host 10.4.1.1 | Capture traffic from 10.4.1.1 |
| dst host 10.4.1.1 | Capture traffic to 10.4.1.1 |
| host www.hln.be | Capture traffic to/from any IP address that resolves to www.hln.be |
| net 10.8.0.0/16 | Capture traffic to/from any host on network 10.8.0.0 |
| not dst net 10.8.0.0/16 | Capture all traffic except traffic to an IP address starting with 10.8 |
| dst net 10.8.0.0/16 | Capture traffic to any IP address starting with 10.8 |
| src net 10.8.0.0/16 | Capture traffic from any IP address starting with 10.8 |
| ip broadcast | Capture traffic to 255.255.255.255 |
| ip multicast | Capture traffic to 224.0.0.0 through 239.255.255.255 (also catches traffic to 255.255.255.255) |
| ether host 00:08:15:00:08:15 | Capture traffic to or from 00:08:15:00:08:15 |
| ether src 02:0A:42:23:41:AC | Capture traffic from 02:0A:42:23:41:AC |
| ether dst 02:0A:42:23:41:AC | Capture traffic to 02:0A:42:23:41:AC |
| not ether host 00:08:15:00:08:15 | Capture traffic to or from any MAC address except for traffic to or from 00:08:15:00:08:15 |
| port 53  | Capture UDP/TCP traffic to or from port 53 (typically DNS traffic) |
| not port 53 | Capture all UDP/TCP traffic except traffic to or from port 53 |
| port 80 | Capture UDP/TCP traffic to or from port 80 (typically HTTP traffic) |
| udp port 67 | Capture UDP traffic to or from port 67 (typically DHCP traffic) |
| tcp port 21 | Capture TCP traffic to or from port 21 (typically the FTP command channel) |
| portrange 1‐80 | Capture UDP/TCP traffic to or from ports from 1 through 80 |
| tcp portrange 1‐80 | Capture TCP traffic to or from ports from 1 through 80 |
| port 20 or port 21 | Capture all UDP/TCP traffic to or from port 20 or port 21(typically FTP data and command ports) |
| host 10.3.1.1 and port 80 | Capture UDP/TCP traffic to or from port 80 that is being sent to or from 10.3.1.1 |
| host 10.3.1.1 and not port 80 | Capture UDP/TCP traffic to or from 10.3.1.1 except traffic to or from port 80 |
| udp src port 68 and udp dst port 67 | Capture all UDP traffic from port 68 to port 67 (typically traffic sent from a DHCP client to DHCP server) |
| udp src port 67 and udp dst port 68 | Capture all UDP traffic from port 67 to port 68 (typically traffic sent from a DHCP server to a DHCP client) |
| icmp | Capture all ICMP packets |
| icmp[0]=8 | Capture all ICMP Type 8 (Echo Request) packets |
| icmp[0]=17 | Capture all ICMP Type 17 (Address Mask Request) packets |
| icmp[0]=8 or icmp[0]=0 | Capture all ICMP Type 8 (Echo Request) packets or ICMP Type 0 (Echo Reply) packets |

We'll solidify our understanding through an exercise.
In this exercise, we'll create and apply a DNS capture filter.

![Success](./assets/port53.png)

![Success](./assets/dns.png)

## 4 Using display filters

Display filters are a crucial part of working with Wireshark, making it much easier to pinpoint specific data quickly. Like finding a needle in a haystack.
It's important to note that display filters are entirely different from capture filters in both purpose and syntax.

**4.1 Display filter syntax**

The simplest display filters are typically based on specific protocols or applications.  
Here are a few examples:

Protocol filters:

| Syntax | Description |
| ------ | ----------- |
| arp | Displays all ARP traffic including gratuitous ARPs, ARP requests, and ARP replies |
| ip | Displays all IPv4 traffic including packets that have IPv4 headers embedded in them (such as ICMP destination unreachable packets that return the incoming IPv4 header after the ICMPheader) |
| ipv6 | Displays all IPv6 traffic including IPv4 packets that have IPv6 headers embedded in them, such as 6to4, Teredo, and ISATAP traffic |
| tcp | Displays all TCP‐based communications |
| icmp | Displays all ICMP traffic |

Application filters:

| Syntax | Description |
| ------ | ----------- |
| dhcp | Displays all DHCP traffic |
| dns | Displays all DNS traffic including TCP‐based zone transfers and the standard UDP‐based DNS requests and responses |
| tftp | Displays all TFTP (Trivial File Transfer Protocol) traffic |
| http | Displays all HTTP commands, responses and data transfer packets, but does not display the TCP handshake packets, TCP ACK packets or TCP connection teardown packets |

Field existence filters:

| Syntax | Description |
| ------ | ----------- |
| dhcp.option.hostname | Displays all DHCP traffic that contains a host name |
| http.host | Displays all HTTP packets that have the HTTP host name field. This packet is sent by the clients when they send a request to a web server |
| ftp.request.command | Displays all FTP traffic that contains a command, such as the USER, PASS, or RETR commands |

Characteristic filters:

| Syntax | Description |
| ------ | ----------- |
| tcp.analysis.flags | Displays all packets that have any of the TCP analysis flags associated with them. This includes indications of packet loss, retransmissions, or zerowindow conditions |
| Tcp.analysis.zero_window | Displays packets that are flagged to indicate the sender has run out of receive buffer space |

It's important to note that display filters are case-sensitive and color coding is applied.
Red: Syntax check failed
Green: Syntax check passed
Yellow: Syntax check passed with a warning

![Success](./assets/color.png)

Comparison operators can also be used.
Here are a few examples:

| Syntax | Description |
| ------ | ----------- |
| ip.src == 10.2.2.2 | Display all IPv4 traffic from 10.2.2.2 |
| tcp.srcport != 80 | Display all TCP traffic from any port except port 80 |
| frame.time_relative > 1 | Display packets that arrived more than 1 second after the previous packet in the trace file |
| tcp.window_size < 1460 | Display when the TCP receive window size is less than 1460 bytes |
| dns.count.answers >= 10 | Display DNS response packets that contain at least 10 answers |
| ip.ttl < 10 | Display any packets that have less than 10 in the IP Time to Live field |
| http contains "GET" | Display all the HTTP client GET requests sent to HTTP servers |

In the next exercise, you'll observe network traffic from a user visiting a website and submitting a web form.
The following file will be used: [display1.pcapng](https://www.tomcordemans.net/display1.pcapng)

![Success](./assets/display1_1.png)

Without applying a display filter, we can see a total of 703 packets.





## Tables and graphs

## Extract data out of network traffic

## Straight from practice

## Wireless LAN

## Nice to know

## Other sources

## Answers

**1.3. First exploration**
* How many packets does this pcapng file contain? 3200
* What IP addresses made a TCP connection in frames 18, 21, and 22? 192.168.1.129 and 195.238.0.64
* What HTTP command was sent by the client in frame 23? GET
* What response was sent by the HTTP server in frame 29? Status Code 302
* What is the length of the largest frame in this pcapng file? 1514 bytes
* What protocols are visible in the protocol column? DNS, HTTP, IGMPv2, TCP and TLSv1
* What web browser was used by the client? Internet Explorer 11 (User-Agent: Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; rv:11.0) like Gecko)

**2.5 Hands-on exercise**
* E) The web server operates on a non-standard port