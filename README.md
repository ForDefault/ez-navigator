#under construction works just not fully furnished# 

# ez-navigator
ez.sh is a highly modular and customizable bash script designed for efficient file and directory navigation, management, and interaction within the terminal.
>Your one-click solution for navigating, managing, and customizing your terminal experience.

  
- Replace and add your own commands!
### **Navigation**
- **`Enter:`** Select a file or directory by pressing the corresponding number and hitting Enter.
- **`Backspace:`** Move up one directory level. `Press for Single-Click:`
  
   [X]- **`↑/↓:`** Move up and down the list of files and directories. **I will get this working**
  
![image](https://github.com/user-attachments/assets/cf31351e-c915-4a58-9084-01e4ee3cda36)

  
### **Single-Click Menus (Toggle)** 
*Menus that do not navigate away from your current directory:*

-Instant Context Menus: Access powerful file actions instantly. No more typing out long commands—just hit a key and go!

- **`0:`** Access the context menu for additional actions.
   
  ![image](https://github.com/user-attachments/assets/4dc59010-760a-481a-925e-7adbdaec5324)



- `Toggle CLI Mode`: Seamlessly switch between the script interface and your standard CLI with one button. (Tab to toggle)

  - **`Tab:`** Toggle between the script interface and terminal mode.
    
  ![image](https://github.com/user-attachments/assets/28417584-e9b3-4168-a014-55e9eedb63ac)
  
   *(Tab functionality should not be modified.)*

- **`Shift+1:`** Open clipboard menu.
  
  - Clipboard Mastery: Copy, save, and **manage paths** with bookmarks and a clipboard manager. Your CLI clipboard has never been this powerful.


### **File Actions** #####Many Changes Occur I will try to keep updated#####

![image](https://github.com/user-attachments/assets/e594334b-fe3b-4609-801f-0ea954d78231)

Just select number and hit enter!


### **Search and Clipboard**
-  View and manage clipboard contents.
- Initiate a search within the current directory.
-  Refine search results.
  
![image](https://github.com/user-attachments/assets/02585bc9-6018-4633-9c83-92bdc88057c2)

  - Smart Search: Search your directories in seconds. Refine within your search to zero in on exactly what you need—quickly and efficiently.


# Install as CLI alias - 
1. Move to where you want the repo folder to install.
2. Paste the command
3. Now just enter in your terminal `ez`. Now whatever terminal you run `ez` will be where ez.sh begins.
```
#!/bin/bash

# Variables for easy modification
REPO_URL="https://github.com/ForDefault/ez-navigator.git"
SCRIPT_NAME="ez.sh"
ALIAS_NAME="ez"

# Extract repository name from the URL
REPO_NAME=$(basename $REPO_URL .git)

# Get the current username
username=$(whoami)

# Clone the repository
git clone $REPO_URL && \
cd $REPO_NAME && \

# Get the full path to the cloned directory
full_path=$(pwd) && \

# Install necessary dependencies
sudo apt-get update && sudo apt-get install -y xclip && \

# Make the script executable
chmod +x "$SCRIPT_NAME" && \

# Modify the script to use the current directory as needed
sed -i 's|current_dir_tracker=$(pwd)|current_dir_tracker=$(pwd -P)|g' "$SCRIPT_NAME" && \

# Add the alias to .bashrc if it doesn't already exist
if ! grep -q "alias $ALIAS_NAME=" ~/.bashrc; then \
  echo 'alias '"$ALIAS_NAME"'="'"$full_path"'/'"$SCRIPT_NAME"'"' >> ~/.bashrc; \
fi && \

# Reload .bashrc to apply the new alias
source ~/.bashrc && \

# Final message
echo "Installation complete. You can now use '$ALIAS_NAME' to run the $REPO_NAME script from anywhere."
   
``` 

>##### Love CLI but hate navigating and typing out paths? Trying to remember the last location of that file? Maybe you just wanted to interact with files from the CLI with ease. Maybe you just like to move around with speed. 
