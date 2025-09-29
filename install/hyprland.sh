#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # get the directory of the current script and move to it
SOURCE_DIR="$(dirname "$SCRIPT_DIR")/hypr/config"  # source directory containing the configuration files
CONFIG_DIR="$HOME/.config/hypr" # destination directory for Hyprland configurations

# Colors so that the output is more readable
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to copy files and directories
backup_config() {
    if [ -d "$CONFIG_DIR" ]; then
        echo -e "${YELLOW}Backing up existing Hyprland configuration...${NC}"
        mv "$CONFIG_DIR" "${CONFIG_DIR}_backup_$(date +%Y%m%d%H%M%S)"
        echo -e "${GREEN}Backup completed.${NC}"
    else
        echo -e "${YELLOW}No existing Hyprland configuration found. Skipping backup.${NC}"
    fi
}

# Function to copy files over
copy_config() {
    if [ -d "$SOURCE_DIR" ]; then
        echo -e "${YELLOW}Copying new Hyprland configuration...${NC}"
        mkdir -p "$CONFIG_DIR"
        cp -r "$SOURCE_DIR/"* "$CONFIG_DIR/"
        echo -e "${GREEN}Copy completed.${NC}"
    else
        echo -e "${RED}✗ Source directory $SOURCE_DIR not found.${NC}"
        exit 1
    fi
}

# Main script execution
echo -e "${YELLOW}Starting Hyprland configuration installation...${NC}"
backup_config
copy_config
echo -e "${GREEN}Hyprland configuration installation completed.${NC}"
echo -e "${GREEN}Please run 'hyprctl reload' to apply the changes.${NC}"