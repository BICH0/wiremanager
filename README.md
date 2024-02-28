<div align="center">
  <img src="https://mytcpip.com/wp-content/uploads/2022/01/wg-logo.png" alt="Logo" height="320">  

  ### WireManager  
  
  Wireguard peer manager written in bash, it lets you create, delete and list all your peers.
  You can send your peer config with QR, client files or the old copypasterino
  
  [**Explore the docs »**](https://github.com/BiCH0/wiremanager)  
  [Live Demo](https://github.com/BiCH0/wiremanager/#Demo) · [Report Bug](https://github.com/BiCH0/wiremanager/issues) · [Request Feature](https://github.com/BiCH0/wiremanager/issues)
  
</div>

# Index
* ### [Requirements](#-requirements)
* ### [Installation](#-installation)
* ### [Usage](#-usage)
* ### [License](#-license)

# 💻 Requirements
Wiremanager of course needs wireguard and qrencode, to install them use your distro's package manager:.
## Debian/Ubuntu
```
sudo apt install wireguard qrencode
```
## Arch Linux
```
sudo pacman -Sy wireguard-tools qrencode
```
## Fedora
```
sudo dnf install wireguard-tools qrencode
```
# 🚀 Installation
To install wiremanager clone this repo with the following command (i recommend clonning it in /opt/):
```
git clone git@github.com:BICH0/wiremanager.git
```  
Once installed you can add it to your path to use it more easily to do it
```
ln -s /<path_to_git_dir>/wiremanager/wiremanager.sh /usr/bin/wiremanager
```
# ☕ Usage
To use wiremanager is as easy as execute wiremanager [--config <file>] <action [target]>
If no config file is supplied it will use /etc/wireguard/wg0.conf
Here are some examples:
  ### Create user
  ```
  wiremanager --config /etc/wireguard/wg0.conf add user1
  ```
  ### Delete user
  ```
  wiremanager -c /etc/wireguard/wg0.conf del 10.0.0.2
  ```
  ### List users
  ```
  wiremanager list
  ```

# 📜 License
This project is made under the GPLv3 license, refer to the [License]() for more info  
## LICENSE SYNOPSYS
1. Anyone can copy, modify and distribute this software.
2. You have to include the license and copyright notice with each and every distribution.
3. You can use this software privately.
4. You can use this software for commercial purposes.
5. If you dare build your business solely from this code, you risk open-sourcing the whole code base.
6. If you modify it, you have to indicate changes made to the code.
7. Any modifications of this code base MUST be distributed with the same license, GPLv3.
8. This software is provided without warranty.
9. The software author or license can not be held liable for any damages inflicted by the software.


<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/GPLv3_Logo.svg/2560px-GPLv3_Logo.svg.png" width="80" height="15" alt="WTFPL" /></a>
