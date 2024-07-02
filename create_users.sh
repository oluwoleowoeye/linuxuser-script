#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure /var/secure exists and has the correct permissions
mkdir -p /var/secure
chmod 700 /var/secure
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to generate random passwords
generate_password() {
    local password_length=12
    tr -dc A-Za-z0-9 </dev/urandom | head -c $password_length
}

# Function to add users, groups and set up home directories
setup_user() {
    local username=$1
    local groups=$2

    # Create the user
    # &>/dev/null
    if ! id -u "$username" &>/dev/null; then
        password=$(generate_password)
        useradd -m -s /bin/bash "$username"
        echo "$username:$password" | chpasswd
        log_message "User $username created."

        # Store the username and password
        echo "$username,$password" >> "$PASSWORD_FILE"
        log_message "Password for $username stored."
    else
        log_message "User $username already exists."
    fi

    # Create groups and add user to groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            log_message "Group $group created."
        fi
        usermod -aG "$group" "$username"
        log_message "Added $username to $group."
    done
    # Set up the home directory
    local home_dir="/home/$username"
    chown "$username":"$username" "$home_dir"
    chmod 700 "$home_dir"
    log_message "Home directory for $username set up with appropriate permissions."
}

# Main script
if [ $# -eq 0 ]; then
    log_message "Usage: $0 <input_file>"
    exit 1
fi

input_file=$1
log_message "Starting user management script."

# Read the input file and process each line
while IFS=';' read -r username groups; do
    setup_user "$username" "$groups"
done < "$input_file"

log_message "User management script completed."
