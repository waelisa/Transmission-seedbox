# Transmission Seedbox Manager[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)[![Transmission](https://img.shields.io/badge/Transmission-4.1.0+-orange.svg)](https://transmissionbt.com/)

## **📦 Installation Methods**

**Download the script:**

   bash
    
    wget https://github.com/waelisa/Transmission-seedbox/raw/refs/heads/master/transmission-manager.sh
    
 or
 
bash
    
    curl -O https://github.com/waelisa/Transmission-seedbox/raw/refs/heads/master/transmission-manager.sh
    
bash

### **Method 1: Interactive Menu (Recommended)**

bash

sudo ./transmission-manager.sh

Then select option 1 from the menu.

### **Method 2: Direct Installation**

bash

sudo ./transmission-manager.sh install

### **Method 3: Check Status Only**

bash

sudo ./transmission-manager.sh status

## **🎮 Menu Options**

**Option**

**Description**

**1) Install Transmission**

Detects latest version and installs Transmission

**2) Uninstall Transmission**

Completely removes Transmission with data options

**3) Show Status**

Displays version, service status, config info

**4) Start Service**

Starts the Transmission daemon

**5) Stop Service**

Stops the Transmission daemon

**6) Restart Service**

Restarts the Transmission daemon

**7) View Config Location**

Shows where settings.json is located

**8) Set Custom RPC Password**

Set a pre-hashed password

**9) Generate Random Password**

Creates secure random password

**10) Set Plain Text Password**

Let Transmission hash it automatically

**11) Exit**

Exit the program

## **🔧 Password Management Examples**

### **Set Your Specific Password Hash**

bash

# Select option 8 and enter:{31d17efeeafb43fd0120d54f7f90ef9f6daf9de1M6knt.tv}

### **Generate Random Secure Password**

bash

# Select option 9# The script will generate and save to: /home/transmission/.config/transmission-daemon/rpc_password.txt

### **Set Plain Text Password**

bash

# Select option 10# Enter your password (e.g., "MySecurePassword123")# Transmission will automatically hash it on next start

## **📁 File Locations**

**File**

**Purpose**

/etc/init.d/transmission-daemon

Init script for service management

/home/transmission/.config/transmission-daemon/settings.json

Main configuration file

/home/transmission/.config/transmission-daemon/rpc_password.txt

Saved random passwords (if generated)

/usr/local/bin/transmission-daemon

Transmission binary

## **🔐 Security Features**

*   **Dedicated User** - Runs as transmission user, not root
*   **Password Hashing** - Automatically hashes passwords using SHA1 with salt
*   **Secure File Permissions** - Settings file set to 600 (read/write for owner only)
*   **Config Backup** - Creates backup before modifying settings

## **💻 Supported Operating Systems**

**OS Family**

**Distributions**

**Debian/Ubuntu**

Ubuntu, Debian, Linux Mint, Pop!_OS, Raspbian

**RHEL/Fedora**

Fedora, CentOS, RHEL, Rocky Linux, AlmaLinux

**Arch Linux**

Arch, Manjaro

**SUSE**

openSUSE

**Alpine**

Alpine Linux

**Others**

Any with apt, yum, dnf, pacman, zypper, or apk

## **📝 Requirements**

*   **Root/Sudo Access** - Required for installation and service management
*   **Internet Connection** - To download Transmission source code
*   **2GB+ RAM** - Recommended for compilation (4GB+ preferred)
*   **wget or curl** - For downloading source code

## **🛠️ Technical Details**

### **Build Process**

The script:

1.  Detects your OS and installs build dependencies
2.  Downloads the latest Transmission source code
3.  Configures with appropriate build system (autotools or CMake)
4.  Compiles using all available CPU cores (make -j$(nproc))
5.  Installs using checkinstall (if available) or make install
6.  Sets up init script and user
7.  Initializes default configuration

### **Password Hash Format**

Transmission uses SHA1 hashed passwords with an 8-character salt:

text

{40-char-hash}{8-char-salt}Example: {31d17efeeafb43fd0120d54f7f90ef9f6daf9de1M6knt.tv}

## **🔍 Troubleshooting**

### **Compilation Fails**

bash

# Check if all dependencies are installedsudo ./transmission-manager.sh# Select option 1 to reinstall (will reinstall dependencies)

### **Service Won't Start**

bash

# Check the logssudo tail -f /home/transmission/.config/transmission-daemon/transmission.log# Verify settings.json is valid JSONsudo cat /home/transmission/.config/transmission-daemon/settings.json | python3 -m json.tool

### **Password Not Working**

bash

# Stop Transmissionsudo /etc/init.d/transmission-daemon stop# Check the hash in settings.jsonsudo grep rpc-password /home/transmission/.config/transmission-daemon/settings.json# Restart Transmissionsudo /etc/init.d/transmission-daemon start

## **📄 License**

This project is licensed under the MIT License - see the [LICENSE](https://license/) file for details.

text

MIT LicenseCopyright (c) 2026 Wael IsaPermission is hereby granted, free of charge, to any person obtaining a copyof this software and associated documentation files (the "Software"), to dealin the Software without restriction, including without limitation the rightsto use, copy, modify, merge, publish, distribute, sublicense, and/or sellcopies of the Software, and to permit persons to whom the Software isfurnished to do so, subject to the following conditions:The above copyright notice and this permission notice shall be included in allcopies or substantial portions of the Software.THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS ORIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THEAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHERLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THESOFTWARE.

## **🤝 Contributing**

Contributions are welcome! Please feel free to submit a Pull Request.

1.  Fork the repository
2.  Create your feature branch (git checkout -b feature/AmazingFeature)
3.  Commit your changes (git commit -m 'Add some AmazingFeature')
4.  Push to the branch (git push origin feature/AmazingFeature)
5.  Open a Pull Request

## **📞 Support**

*   **GitHub Issues**: [https://github.com/waelisa/Transmission-seedbox/issues](https://github.com/waelisa/Transmission-seedbox/issues)
*   **Transmission Documentation**: [https://transmissionbt.com/documentation](https://transmissionbt.com/documentation)

## **🙏 Acknowledgements**

*   [Transmission Project](https://transmissionbt.com/) - The amazing BitTorrent client
*   Original init script from [Transmission Trac](https://trac.transmissionbt.com/wiki/Scripts/initd)
*   All contributors and users

## **📊 Version History**

**Version**

**Date**

**Changes**

1.0.0

2026-02-17

Initial release with auto-install and management menu

1.1.0

2026-02-17

Added password management features

1.2.0

2026-02-17

Multi-OS support and improved error handling

**Made with ❤️ by** [**Wael Isa**](https://github.com/waelisa)

text

## Also create a LICENSE fileCreate a file named \`LICENSE\` in the same directory with:

MIT License

Copyright (c) 2026 Wael Isa

Permission is hereby granted, free of charge, to any person obtaining a copy  
of this software and associated documentation files (the "Software"), to deal  
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all  
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  
SOFTWARE.

text

## Quick Setup Commands\`\`\`bash# Create README.mdnano README.md# (paste the content above)# Create LICENSEnano LICENSE# (paste the MIT license content)# Add both to gitgit add README.md LICENSEgit commit -m "Add README and MIT license"git push

The README provides:

*   Complete documentation for your script
*   MIT license information
*   Installation instructions
*   Menu options explanation
*   Password management examples
*   Troubleshooting guide
*   Contributing guidelines
*   Version history


[Donate link – PayPal](https://www.paypal.me/WaelIsa)

