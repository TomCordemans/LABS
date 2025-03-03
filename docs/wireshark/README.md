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
When a problem arises, there won’t be time to analyze the network from scratch—users expect swift and precise action.

**3.1 Determine the optimal capture location**  

Aim to capture traffic as close as possible to the affected device. When a user reports an issue (e.g., slow downloads), it is best to analyze the problem from the user's perspective for the most accurate diagnosis.

## Using display filters

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