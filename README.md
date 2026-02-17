# **Transmission Seedbox Manager (Gold Master Edition)**

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)[![Transmission](https://img.shields.io/badge/Transmission-4.1.0+-orange.svg)](https://transmissionbt.com/)

An industrial-grade, automated management tool for Transmission 4.0+. This script is designed for high-performance seedbox environments, featuring automatic dependency resolution, kernel-level network tuning, and support for multiple init systems.

## **🚀 Quick Start**

Run the manager immediately with this one-liner:

Bash

wget -qO transmission-manager.sh https://github.com/waelisa/Transmission-seedbox/raw/refs/heads/master/transmission-manager.sh && chmod +x transmission-manager.sh && sudo ./transmission-manager.sh

## **✨ Key Features**

*   **Universal Compatibility:** Automatically detects and configures **Systemd**, **OpenRC**, and **SysV init**.
*   **Seedbox Performance Tuning:** Applies kernel optimizations (sysctl) for high-speed peering and handles thousands of concurrent connections.
*   **Intelligent Build System:** Automatically upgrades **CMake** to 3.16+ if the system version is too old for Transmission 4.0+.
*   **Security Hardened:** \* Runs as a dedicated non-privileged user.
    *   Generates high-entropy 16-character RPC passwords.
    *   Secured log permissions (640).
*   **Reliability Engineering:** \* Uses process-wait loops to prevent the "Ghost Config" bug (where Transmission overwrites settings on shutdown).
    *   Idempotent design (safe to run multiple times).
    *   Lock-file protection to prevent concurrent execution.

## **🛠 Usage**

The script features an interactive menu for ease of use, but also supports CLI flags for automation:

Bash

# Interactive Menu sudo ./transmission-manager.sh # Automation Flags sudo ./transmission-manager.sh -i # Install latest version silently sudo ./transmission-manager.sh -u # Check for and apply updates sudo ./transmission-manager.sh -p # Set a custom RPC password

## **📊 Technical Optimizations**

This manager doesn't just install software; it prepares your Linux kernel for heavy torrenting:

*   **Network Buffers:** Increases rmem_max and wmem_max to 16MB.
*   **TCP Scaling:** Optimizes tcp_rmem and tcp_wmem windows.
*   **File Descriptors:** Increases system limits to 100,000 to prevent "Too many open files" errors during high peering.

## **📦 Supported Distributions**

*   **Debian Family:** Debian 10+, Ubuntu 18.04+, Linux Mint.
*   **RHEL Family:** CentOS 7/8/9, AlmaLinux, Rocky Linux.
*   **Arch Linux:** Base and derivatives.
*   **Alpine Linux:** (Uses OpenRC support).

## **☕ Support & Donate**

If this script saved you time or improved your seedbox performance, consider supporting the developer:

*   **PayPal:** [Donate via PayPal](file:///opt/onlyoffice/desktopeditors/editors/web-apps/apps/documenteditor/main/index.html?_dc=0&lang=en-US&type=desktop&frameEditorId=placeholder&isForm=false&parentOrigin=file://&fileType=docx)
