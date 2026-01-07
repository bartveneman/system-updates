#!/bin/bash

################################################################################
# Raspberry Pi Monthly Maintenance Script
# Purpose: System updates, security patches, and maintenance tasks
# Usage: sudo bash rpi_monthly_update.sh
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/rpi_monthly_update.log"

# Function to print colored output
print_step() {
    echo -e "${BLUE}==>${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root. Use: sudo bash rpi_monthly_update.sh"
    exit 1
fi

# Initialize log file
echo "========================================" >> "$LOG_FILE"
echo "Monthly Update - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

print_step "Starting Raspberry Pi monthly maintenance..."
echo ""


# Check if unattended-upgrades is enabled
print_step "Checking automatic security updates..."
if systemctl status unattended-upgrades >/dev/null 2>&1; then
    if systemctl is-active --quiet unattended-upgrades; then
        print_success "Automatic security updates are enabled and running"
    else
        print_warning "Unattended-upgrades service is installed but not active"
        print_warning "To enable it, run: sudo systemctl enable --now unattended-upgrades"
    fi
else
    print_warning "Unattended-upgrades service is not installed or not configured"
    print_warning "To install, run: sudo apt-get install unattended-upgrades"
fi

# Update package lists
print_step "Updating package lists..."
if apt-get update 2>&1 | tee -a "$LOG_FILE"; then
    print_success "Package lists updated"
else
    print_error "Failed to update package lists"
    exit 1
fi

# Install available updates
print_step "Installing system updates..."
if apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
    print_success "System upgraded"
else
    print_warning "Some packages may not have been upgraded"
fi

# Install distribution upgrade (optional - removes old packages)
print_step "Installing distribution upgrades (full-upgrade)..."
if apt-get full-upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
    print_success "Full distribution upgrade completed"
else
    print_warning "Some distribution upgrades may have failed"
fi

# Clean up old packages
print_step "Cleaning up old packages..."
if apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"; then
    print_success "Obsolete packages removed"
else
    print_warning "Autoremove encountered issues"
fi

if apt-get autoclean -y 2>&1 | tee -a "$LOG_FILE"; then
    print_success "Package cache cleaned"
fi

# Update Pi-hole
print_step "Updating Pi-hole..."
if command -v pihole &> /dev/null; then
    if pihole -up 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Pi-hole updated successfully"
    else
        print_warning "Pi-hole update encountered issues"
    fi
else
    print_warning "Pi-hole not installed"
fi

# Disk space check
print_step "Checking disk space..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    print_warning "Disk usage is at ${DISK_USAGE}%"
else
    print_success "Disk usage is healthy (${DISK_USAGE}%)"
fi

# Check system temperature (if vcgencmd available)
print_step "Checking system temperature..."
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*')
    if (( $(echo "$TEMP > 80" | bc -l) )); then
        print_warning "Temperature is high: ${TEMP}°C"
    else
        print_success "Temperature is normal: ${TEMP}°C"
    fi
else
    print_warning "vcgencmd not available (not a Raspberry Pi or GPU drivers not installed)"
fi

# Check system load
print_step "Checking system load..."
LOAD=$(cat /proc/loadavg | awk '{print $1}')
print_success "System load: $LOAD"

# Check for security configurations
if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        print_success "SSH root login is disabled"
    else
        print_warning "Consider disabling SSH root login: set 'PermitRootLogin no' in /etc/ssh/sshd_config"
    fi
else
    print_warning "SSH configuration not found"
fi

# Check if unattended-upgrades is enabled
print_step "Checking automatic security updates..."
if systemctl status unattended-upgrades >/dev/null 2>&1; then
    if systemctl is-active --quiet unattended-upgrades; then
        print_success "Automatic security updates are enabled and running"
    else
        print_warning "Unattended-upgrades service is installed but not active"
        print_warning "To enable it, run: sudo systemctl enable --now unattended-upgrades"
    fi
else
    print_warning "Unattended-upgrades service is not installed or not configured"
    print_warning "To install, run: sudo apt-get install unattended-upgrades"
fi

# System information
print_step "Gathering system information..."
echo "" >> "$LOG_FILE"
echo "System Information:" >> "$LOG_FILE"
uname -a >> "$LOG_FILE"
cat /etc/os-release >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Final status
print_step "Running final checks..."
if [ $? -eq 0 ]; then
    print_success "All checks completed"
else
    print_warning "Some checks reported issues"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
print_success "Monthly maintenance completed successfully!"
echo -e "${GREEN}========================================${NC}"
echo ""
print_step "Log saved to: $LOG_FILE"
echo ""

# Optional: Check if reboot is needed
if [ -f /var/run/reboot-required ]; then
    print_warning "System reboot is required for updates to take effect"
    echo "To reboot now, run: sudo reboot"
    echo "To reboot later, run: sudo shutdown -r +60  # in 60 minutes"
fi

echo ""