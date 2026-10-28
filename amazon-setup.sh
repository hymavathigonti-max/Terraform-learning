script
#!/bin/bash 
# 1. Update the system and install Nginx and Git 
apt update -y 
apt install nginx git -y 
# 2. Start and enable Nginx to run on boot
 systemctl start nginx
 systemctl enable nginx
 # 3. Clear out the default Nginx welcome files 
rm -rf /var/www/html/* 
# 4. Clone your Amazon clone repository into /tmp
 cd /tmp 
git clone https://github.com/Ironhack-Archive/online-clone-amazon.git 
# 5. Copy the project files to the web server directory 
cp -r online-clone-amazon/* /var/www/html/
