#!/bin/bash

# Docker Cleaner - Interactive Docker Resource Cleanup Script
# Created for macOS with beautiful UI and interactive menus

set -euo pipefail

# ANSI color codes for modern terminal
COLOR_RESET='\033[0m'
COLOR_BLUE='\033[38;5;39m'      # Modern Blue
COLOR_GREEN='\033[38;5;46m'     # Fresh Green  
COLOR_YELLOW='\033[38;5;226m'   # Warning Yellow
COLOR_RED='\033[38;5;196m'      # Red for Danger
COLOR_GRAY='\033[38;5;240m'     # Subtle Gray
COLOR_CYAN='\033[38;5;51m'      # Info Cyan
COLOR_MAGENTA='\033[38;5;201m'  # Magenta for Accents
COLOR_ORANGE='\033[38;5;208m'   # Orange for Warnings

# Global variables
SCRIPT_VERSION="1.0.0"
TEST_MODE=false
VERBOSE=false

# ============================================
# UI/Helper Functions
# ============================================

# Clear screen and show header
show_header() {
    clear
    echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║${COLOR_MAGENTA}                    🐳 DOCKER CLEANER v${SCRIPT_VERSION}                            ${COLOR_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║${COLOR_RESET}                 Interactive Resource Cleanup                           ${COLOR_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo
}

# Check if Docker is running
check_docker_status() {
    if ! command -v docker &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker is not installed or not in PATH${COLOR_RESET}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker daemon is not running. Please start Docker Desktop.${COLOR_RESET}"
        exit 1
    fi
}

# Get Docker status info
get_docker_info() {
    local status="🟢 Running"
    local storage=$(docker system df --format "{{.Size}}" | head -1 | sed 's/ GB\| MB//' | cut -d'.' -f1)
    
    if [[ -z "$storage" ]]; then
        storage="0"
    fi
    
    echo "${status} | Storage: ${storage}GB"
}

# Show success message
show_success() {
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

# Show warning message
show_warning() {
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

# Show error message
show_error() {
    echo -e "${COLOR_RED}❌ $1${COLOR_RESET}"
}

# Show info message
show_info() {
    echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}"
}

# Show spinner during operation
show_spinner() {
    local pid=$1
    local message="$2"
    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    echo -n "${COLOR_CYAN}${message} "
    
    while kill -0 $pid 2>/dev/null; do
        printf "${spinners[$i]}  \r"
        i=$(((i + 1) % 10))
        sleep 0.1
    done
    
    echo -e "${COLOR_GREEN}✓${COLOR_RESET}"
}

# Confirm dialog
confirm_dialog() {
    local message="$1"
    local default="${2:-N}"
    
    echo -e "\n${COLOR_YELLOW}⚠️  $message${COLOR_RESET}"
    echo -e "${COLOR_GRAY}Type 'y' or 'Y' for Yes, Enter for No${COLOR_RESET}"
    
    read -p "Confirm? (y/N): " -r response
    case "$response" in
        [jJ]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Press any key to continue
press_continue() {
    echo -e "\n${COLOR_GRAY}Press Enter to continue...${COLOR_RESET}"
    read -r
}

# ============================================
# Docker Analysis Functions
# ============================================

# Count dangling images
count_dangling_images() {
    docker images --filter "dangling=true" --format "{{.ID}}" | wc -l | tr -d ' '
}

# Get dangling images size
get_dangling_images_size() {
    docker images --filter "dangling=true" --format "{{.Size}}" | {
        local total=0
        while read -r size; do
            if [[ $size =~ ([0-9.]+)([KMGT]?B) ]]; then
                local value=${BASH_REMATCH[1]}
                local unit=${BASH_REMATCH[2]}
                case $unit in
                    KB) value=$((value / 1024)) ;;
                    MB) value=${value/.*} ;;
                    GB) value=$((value * 1024)) ;;
                    TB) value=$((value * 1024 * 1024)) ;;
                esac
                total=$((total + value))
            fi
        done
        echo $total
    }
}

# Count stopped containers
count_stopped_containers() {
    docker ps -a --filter "status=exited" --format "{{.ID}}" | wc -l | tr -d ' '
}

# Count unused volumes
count_unused_volumes() {
    docker volume ls --filter "dangling=true" --format "{{.Name}}" | wc -l | tr -d ' '
}

# Get build cache size
get_build_cache_size() {
    docker system df --format "table {{.Type}}\t{{.TotalReclaimable}}" | grep "Build Cache" | awk '{print $2}' | sed 's/GB\|MB//' | cut -d'.' -f1
}

# ============================================
# Docker Cleanup Functions
# ============================================

# Cleanup dangling images
cleanup_dangling_images() {
    echo -e "${COLOR_BLUE}🔍 Analyzing dangling images...${COLOR_RESET}"
    
    local count=$(count_dangling_images)
    if [[ $count -eq 0 ]]; then
        show_success "No dangling images found."
        press_continue
        return 0
    fi
    
    local size=$(get_dangling_images_size)
    echo -e "${COLOR_YELLOW}Found: ${count} dangling images (~${size}MB)${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Dangling Images:${COLOR_RESET}"
    docker images --filter "dangling=true" --format "table {{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | head -10
    
    echo
    
    if confirm_dialog "${count} dangling images (~${size}MB) really delete?"; then
        echo -e "${COLOR_BLUE}🧹 Deleting dangling images...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST MODE: Would run docker rmi \$(docker images -f \"dangling=true\" -q)"
        else
            docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
            show_success "${count} dangling images deleted"
        fi
    else
        show_info "Deletion cancelled."
    fi
    
    press_continue
}

# Cleanup stopped containers
cleanup_containers() {
    echo -e "${COLOR_BLUE}🔍 Analyzing stopped containers...${COLOR_RESET}"
    
    local count=$(count_stopped_containers)
    if [[ $count -eq 0 ]]; then
        show_success "No stopped containers found."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_YELLOW}Found: ${count} stopped containers${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Stopped Containers:${COLOR_RESET}"
    docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.CreatedAt}}" | head -10
    
    echo
    
    if confirm_dialog "${count} stopped containers really delete?"; then
        echo -e "${COLOR_BLUE}🧹 Deleting stopped containers...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST MODE: Would run docker rm \$(docker ps -a -q --filter \"status=exited\")"
        else
            docker rm $(docker ps -a -q --filter "status=exited") 2>/dev/null || true
            show_success "${count} containers deleted"
        fi
    else
        show_info "Deletion cancelled."
    fi
    
    press_continue
}

# Cleanup unused volumes
cleanup_volumes() {
    echo -e "${COLOR_BLUE}🔍 Analyzing unused volumes...${COLOR_RESET}"
    
    local count=$(count_unused_volumes)
    if [[ $count -eq 0 ]]; then
        show_success "No unused volumes found."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_RED}⚠️  Found: ${count} unused volumes${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}WARNING: Deleting volumes can cause data loss!${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Unused Volumes:${COLOR_RESET}"
    docker volume ls --filter "dangling=true" --format "table {{.Name}}\t{{.Driver}}" | head -10
    
    echo
    
    if confirm_dialog "${count} unused volumes really delete? (Data loss possible!)"; then
        echo -e "${COLOR_BLUE}🧹 Deleting unused volumes...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST MODE: Would run docker volume prune --force"
        else
            docker volume prune --force
            show_success "${count} volumes deleted"
        fi
    else
        show_info "Deletion cancelled."
    fi
    
    press_continue
}

# Cleanup build cache
cleanup_build_cache() {
    echo -e "${COLOR_BLUE}🔍 Analyzing build cache...${COLOR_RESET}"
    
    local size=$(get_build_cache_size)
    if [[ -z "$size" || "$size" == "0" ]]; then
        show_success "No build cache found."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_YELLOW}Found: Build cache (~${size}GB)${COLOR_RESET}"
    
    echo
    
    if confirm_dialog "Build cache (~${size}GB) really delete?"; then
        echo -e "${COLOR_BLUE}🧹 Deleting build cache...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST MODE: Would run docker builder prune --all --force"
        else
            docker builder prune --all --force
            show_success "Build cache deleted"
        fi
    else
        show_info "Deletion cancelled."
    fi
    
    press_continue
}

# Show detailed analysis
show_detailed_analysis() {
    echo -e "${COLOR_BLUE}📊 Detailed Docker System Analysis${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_CYAN}System Overview:${COLOR_RESET}"
    docker system df
    
    echo
    echo -e "${COLOR_CYAN}Docker Version:${COLOR_RESET}"
    docker --version
    
    echo
    echo -e "${COLOR_CYAN}System Info:${COLOR_RESET}"
    docker info --format "Server Version: {{.ServerVersion}}\nKernel Version: {{.KernelVersion}}\nOperating System: {{.OperatingSystem}}"
    
    echo
    echo -e "${COLOR_CYAN}Image Statistics:${COLOR_RESET}"
    echo "Total Images: $(docker images --format "{{.ID}}" | wc -l | tr -d ' ')"
    echo "Dangling Images: $(count_dangling_images)"
    
    echo
    echo -e "${COLOR_CYAN}Container Statistics:${COLOR_RESET}"
    echo "Running Containers: $(docker ps --format "{{.ID}}" | wc -l | tr -d ' ')"
    echo "Stopped Containers: $(count_stopped_containers)"
    
    echo
    echo -e "${COLOR_CYAN}Volume Statistics:${COLOR_RESET}"
    echo "Total Volumes: $(docker volume ls --format "{{.Name}}" | wc -l | tr -d ' ')"
    echo "Unused Volumes: $(count_unused_volumes)"
    
    press_continue
}

# Show all images sorted by size
show_all_images() {
    echo -e "${COLOR_BLUE}📋 All Docker Images (sorted by size)${COLOR_RESET}"
    echo
    
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | (
        read -r header
        echo "$header"
        docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | tail -n +2 | sort -hr -k2
    ) | head -20
    
    press_continue
}

# Full cleanup
full_cleanup() {
    echo -e "${COLOR_RED}🚀 FULL CLEANUP${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}This function performs all cleanup operations.${COLOR_RESET}"
    echo
    
    local dangling=$(count_dangling_images)
    local containers=$(count_stopped_containers)
    local volumes=$(count_unused_volumes)
    
    echo -e "${COLOR_CYAN}Preview:${COLOR_RESET}"
    echo "- $dangling dangling images"
    echo "- $containers stopped containers"
    echo "- $volumes unused volumes"
    echo "- Build cache"
    
    echo
    
    if confirm_dialog "Really perform full cleanup?"; then
        cleanup_dangling_images
        cleanup_containers
        cleanup_volumes
        cleanup_build_cache
        
        show_success "Full cleanup completed!"
    else
        show_info "Full cleanup cancelled."
    fi
    
    press_continue
}

# ============================================
# Menu Functions
# ============================================

# Main menu
show_main_menu() {
    while true; do
        show_header
        local docker_info=$(get_docker_info)
        
        echo -e "${COLOR_GRAY}Status: $docker_info${COLOR_RESET}"
        echo
        
        echo -e "${COLOR_CYAN}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  🧹 Docker Resource Cleaner - Main Menu                     ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[1]${COLOR_RESET} 🗑️   Delete dangling images (<none> images)             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[2]${COLOR_RESET} 🐳  Cleanup unused containers                          ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[3]${COLOR_RESET} 💾  Cleanup unused volumes                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[4]${COLOR_RESET} 🔨  Clear build cache                                  ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[5]${COLOR_RESET} 📊  Show detailed analysis                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[6]${COLOR_RESET} 🚀  Full cleanup (all above)                           ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[7]${COLOR_RESET} ⚙️   Advanced options                                   ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_RED}[0]${COLOR_RESET} 🚪  Exit                                               ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo
        
        # Show test mode status
        if [[ "$TEST_MODE" == "true" ]]; then
            echo -e "${COLOR_YELLOW}⚠️  TEST MODE ACTIVE (No actual deletions)${COLOR_RESET}"
            echo
        fi
        
        read -p "Your choice: " -n 1 -r choice
        echo
        
        case $choice in
            1)
                cleanup_dangling_images
                ;;
            2)
                cleanup_containers
                ;;
            3)
                cleanup_volumes
                ;;
            4)
                cleanup_build_cache
                ;;
            5)
                show_detailed_analysis
                ;;
            6)
                full_cleanup
                ;;
            7)
                show_advanced_menu
                ;;
            0)
                echo -e "${COLOR_GREEN}👋 Goodbye!${COLOR_RESET}"
                exit 0
                ;;
            *)
                show_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Advanced menu
show_advanced_menu() {
    while true; do
        show_header
        echo -e "${COLOR_CYAN}┌─────────────────────────────────────────────────────────────┐${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ⚙️  Advanced Options                                        ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[1]${COLOR_RESET} 📋  Show all images sorted by size                     ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[2]${COLOR_RESET} 📈  System statistics (docker system df)               ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[3]${COLOR_RESET} 🏷️    Show all images (including active)                ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[4]${COLOR_RESET} 🐋  Docker version & system info                       ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[5]${COLOR_RESET} 🧪  Toggle test mode                                   ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_RED}[9]${COLOR_RESET} 🔙  Back to main menu                                  ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo
        
        if [[ "$TEST_MODE" == "true" ]]; then
            echo -e "${COLOR_YELLOW}🧪 Test Mode: ACTIVE${COLOR_RESET}"
        else
            echo -e "${COLOR_GRAY}🧪 Test Mode: INACTIVE${COLOR_RESET}"
        fi
        echo
        
        read -p "Your choice: " -n 1 -r choice
        echo
        
        case $choice in
            1)
                show_all_images
                ;;
            2)
                echo -e "${COLOR_BLUE}📈 Docker System Statistics:${COLOR_RESET}"
                docker system df
                press_continue
                ;;
            3)
                echo -e "${COLOR_BLUE}🏷️  All Docker Images:${COLOR_RESET}"
                docker images
                press_continue
                ;;
            4)
                echo -e "${COLOR_BLUE}🐋 Docker Information:${COLOR_RESET}"
                docker version
                echo
                docker system info --format "Server: {{.ServerVersion}}\nKernel: {{.KernelVersion}}\nOS: {{.OperatingSystem}}\nArchitecture: {{.Architecture}}"
                press_continue
                ;;
            5)
                if [[ "$TEST_MODE" == "true" ]]; then
                    TEST_MODE=false
                    show_success "Test mode deactivated"
                else
                    TEST_MODE=true
                    show_warning "Test mode activated - No actual deletions will be performed!"
                fi
                sleep 2
                ;;
            9)
                return 0
                ;;
            *)
                show_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# ============================================
# Main Execution
# ============================================

main() {
    # Check Docker status
    check_docker_status
    
    # Show welcome message
    show_header
    echo -e "${COLOR_GREEN}Welcome to Docker Cleaner!${COLOR_RESET}"
    echo -e "${COLOR_BLUE}This script helps you safely clean up Docker resources.${COLOR_RESET}"
    echo
    sleep 2
    
    # Start main menu
    show_main_menu
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Docker Cleaner v${SCRIPT_VERSION}"
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h       Show this help"
        echo "  --test           Activate test mode"
        echo "  --version        Show version"
        exit 0
        ;;
    --test)
        TEST_MODE=true
        ;;
    --version)
        echo "Docker Cleaner v${SCRIPT_VERSION}"
        exit 0
        ;;
    "")
        # No arguments - run normal
        ;;
    *)
        show_error "Unknown option: $1"
        echo "Use --help for assistance."
        exit 1
        ;;
esac

# Run main function
main "$@"
