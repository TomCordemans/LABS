---
title: Wireshark course
---

# Under construction (My goal for 2025)

This course introduces you to the fundamental skills needed to use Wireshark effectively. It covers the most commonly used protocols and explores a variety of intriguing problems. To enhance your learning experience, the course incorporates practical exercises to share as much expertise as possible.   

## Introduction
    
**1.1. What is Wireshark**

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

## Getting Wireshark ready

**2.1 Using configuration profiles**

Configuration profiles enable you to customize settings based on your specific needs. For instance, you can set up separate profiles for troubleshooting and cybersecurity analysis.   
By default, Wireshark uses the default profile. It’s recommended to create a new profile promptly to preserve the default profile as a reference point for all future profiles.

![Success](./assets/default.png)

A configuration profile is a folder containing text files that are loaded when the associated profile is activated. These files define preference settings, display filters, coloring rules, and more.

## How and where to capture

## Using display filters

## Tables and graphs

## Extract data out of network traffic

## Straight from practice

## Wireless LAN

## Nice to know

## Other sources

## Solutions

**1.3. First exploration**
* How many packets does this pcapng file contain? 3200
* What IP addresses made a TCP connection in frames 18, 21, and 22? 192.168.1.129 and 195.238.0.64
* What HTTP command was sent by the client in frame 23? GET
* What response was sent by the HTTP server in frame 29? Status Code 302
* What is the length of the largest frame in this pcapng file? 1514 bytes
* What protocols are visible in the protocol column? DNS, HTTP, IGMPv2, TCP and TLSv1
* What web browser was used by the client? Internet Explorer 11 (User-Agent: Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; rv:11.0) like Gecko)