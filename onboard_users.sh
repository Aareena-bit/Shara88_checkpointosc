#!/bin/bash

#File Paths
CSV_FILE="users.csv"
LOG_FILE="/var/log/user_onboarding_audit.log"
#__________________________________________________
# Check if script runs as root
# #-------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run this script with sudo or as root."
    exit 1
fi

#--------------------------------------------
# Logging function
# ----------------------------------------------
# This function writes messages with timestamps to the log file. 
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

#----------------------------------------
# Check if CSV file exists
# ---------------------------------------
if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: $CSV_FILE not found."
    log_action "ERROR: CSV file $CSV_FILE not found."
    exit 1
fi

#---------------------------------------------------
# Read and parse users.csv line by line
# --------------------------------------------------
# IFS=',' splits each row into 3 variables
while IFS=',' read -r username groupname shell; do

    # Skip blank lines and comments
    [[ -z "$username" ]] && continue
    [[ "$username" =~ ^# ]] && continue
#---------------------------------------------------------
#Validate input
#----------------------------------------------------------
#
#Check if any file is missing
    if [[ -z "$username" || -z "$groupname" || -z "$shell" ]]; then
        log_action "ERROR: Missing field in record: $username,$groupname,$shell"
        continue
    fi

#Check if username is valid     

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_action "ERROR: Invalid username: $username"
        continue
    fi

    echo "Processing user: $username"
    log_action "Processing user: $username"

#-------------------------------------------------------
#Check and manage user accounts
#--------------------------------------------------------
#
#Check if user already exists
    if id "$username" &>/dev/null; then
	    #update the shell if user exists
        usermod -s "$shell" "$username"
        if [[ $? -eq 0 ]]; then
            log_action "Updated shell for existing user $username to $shell"
        else
	
            log_action "ERROR: Failed to update shell for $username"
            continue
        fi
    else
	    #Create new user with home directory 
        useradd -m -s "$shell" "$username"
        if [[ $? -eq 0 ]]; then
            log_action "Created new user $username with shell $shell"
        else
            log_action "ERROR: Failed to create user $username"
            continue
        fi
    fi
#----------------------------------------------------------------
#Group Management
#------------------------------------------------------
#
#Check fd group exists, create if not 
#
    if ! getent group "$groupname" &>/dev/null; then
        groupadd "$groupname"
        if [[ $? -eq 0 ]]; then
            log_action "Created group $groupname"
        else
            log_action "ERROR: Failed to create group $groupname"
            continue
        fi
    fi

    usermod -aG "$groupname" "$username"
    if [[ $? -eq 0 ]]; then
        log_action "Added user $username to group $groupname"
    else
        log_action "ERROR: Failed to add $username to group $groupname"
        continue
    fi

    # Requirement 4 - set up the home directory
    HOME_DIR="/home/$username"
   #Craete hoome directory if missing 
    if [[ ! -d "$HOME_DIR" ]]; then
        mkdir -p "$HOME_DIR"
        log_action "Created home directory $HOME_DIR"
    fi
    #Set ownership and permission 

    chown "$username":"$username" "$HOME_DIR"
    chmod 700 "$HOME_DIR"
    log_action "Set ownership and permissions for $HOME_DIR"

    # Requirement 5 - create a project directory
    PROJECT_DIR="/opt/projects/$username"

    if [[ ! -d "$PROJECT_DIR" ]]; then
        mkdir -p "$PROJECT_DIR"
        log_action "Created project directory $PROJECT_DIR"
    fi

    chown "$username":"$groupname" "$PROJECT_DIR"
    chmod 750 "$PROJECT_DIR"
    log_action "Set ownership to $username:$groupname and permissions 750 for $PROJECT_DIR"

done < "$CSV_FILE"

echo "All users processed."
log_action "Finished processing all users."
