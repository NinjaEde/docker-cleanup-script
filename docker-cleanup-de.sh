#!/bin/bash

# Docker Cleaner - Interaktives Docker Ressourcen-Bereinigungs-Script
# Erstellt für macOS mit schönen UI und interaktiven Menüs

set -euo pipefail

# ANSI Farbcodes für modernes Terminal
COLOR_RESET='\033[0m'
COLOR_BLUE='\033[38;5;39m'      # Modernes Blau
COLOR_GREEN='\033[38;5;46m'     # Frisches Grün  
COLOR_YELLOW='\033[38;5;226m'   # Warnung Gelb
COLOR_RED='\033[38;5;196m'      # Rot für Danger
COLOR_GRAY='\033[38;5;240m'     # Subtiles Grau
COLOR_CYAN='\033[38;5;51m'      # Info Cyan
COLOR_MAGENTA='\033[38;5;201m'  # Magenta für Akzente
COLOR_ORANGE='\033[38;5;208m'   # Orange für Warnings

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
    echo -e "${COLOR_CYAN}║${COLOR_RESET}              Interaktive Ressourcen-Bereinigung                        ${COLOR_CYAN}║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚════════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo
}

# Check if Docker is running
check_docker_status() {
    if ! command -v docker &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker ist nicht installiert oder nicht im PATH${COLOR_RESET}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${COLOR_RED}❌ Docker Daemon läuft nicht. Bitte starten Sie Docker Desktop.${COLOR_RESET}"
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
    
    echo "${status} | Speicher: ${storage}GB"
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
    echo -e "${COLOR_GRAY}Tippen Sie 'j' oder 'J' für Ja, Enter für Nein${COLOR_RESET}"
    
    read -p "Bestätigen? (j/N): " -r response
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
    echo -e "\n${COLOR_GRAY}Drücken Sie Enter um fortzufahren...${COLOR_RESET}"
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
    echo -e "${COLOR_BLUE}🔍 Analysiere dangling Images...${COLOR_RESET}"
    
    local count=$(count_dangling_images)
    if [[ $count -eq 0 ]]; then
        show_success "Keine dangling Images gefunden."
        press_continue
        return 0
    fi
    
    local size=$(get_dangling_images_size)
    echo -e "${COLOR_YELLOW}Gefunden: ${count} dangling Images (~${size}MB)${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Dangling Images:${COLOR_RESET}"
    docker images --filter "dangling=true" --format "table {{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | head -10
    
    echo
    
    if confirm_dialog "${count} dangling Images (~${size}MB) wirklich löschen?"; then
        echo -e "${COLOR_BLUE}🧹 Lösche dangling Images...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST-MODUS: Würde docker rmi \$(docker images -f \"dangling=true\" -q) ausführen"
        else
            docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
            show_success "${count} dangling Images gelöscht"
        fi
    else
        show_info "Löschung abgebrochen."
    fi
    
    press_continue
}

# Cleanup stopped containers
cleanup_containers() {
    echo -e "${COLOR_BLUE}🔍 Analysiere gestoppte Container...${COLOR_RESET}"
    
    local count=$(count_stopped_containers)
    if [[ $count -eq 0 ]]; then
        show_success "Keine gestoppten Container gefunden."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_YELLOW}Gefunden: ${count} gestoppte Container${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Gestoppte Container:${COLOR_RESET}"
    docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.CreatedAt}}" | head -10
    
    echo
    
    if confirm_dialog "${count} gestoppte Container wirklich löschen?"; then
        echo -e "${COLOR_BLUE}🧹 Lösche gestoppte Container...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST-MODUS: Würde docker rm \$(docker ps -a -q --filter \"status=exited\") ausführen"
        else
            docker rm $(docker ps -a -q --filter "status=exited") 2>/dev/null || true
            show_success "${count} Container gelöscht"
        fi
    else
        show_info "Löschung abgebrochen."
    fi
    
    press_continue
}

# Cleanup unused volumes
cleanup_volumes() {
    echo -e "${COLOR_BLUE}🔍 Analysiere unbenutzte Volumes...${COLOR_RESET}"
    
    local count=$(count_unused_volumes)
    if [[ $count -eq 0 ]]; then
        show_success "Keine unbenutzten Volumes gefunden."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_RED}⚠️  Gefunden: ${count} unbenutzte Volumes${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}ACHTUNG: Das Löschen von Volumes kann Datenverlust verursachen!${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Unbenutzte Volumes:${COLOR_RESET}"
    docker volume ls --filter "dangling=true" --format "table {{.Name}}\t{{.Driver}}" | head -10
    
    echo
    
    if confirm_dialog "${count} unbenutzte Volumes wirklich löschen? (Datenverlust möglich!)"; then
        echo -e "${COLOR_BLUE}🧹 Lösche unbenutzte Volumes...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST-MODUS: Würde docker volume prune --force ausführen"
        else
            docker volume prune --force
            show_success "${count} Volumes gelöscht"
        fi
    else
        show_info "Löschung abgebrochen."
    fi
    
    press_continue
}

# Cleanup build cache
cleanup_build_cache() {
    echo -e "${COLOR_BLUE}🔍 Analysiere Build Cache...${COLOR_RESET}"
    
    local size=$(get_build_cache_size)
    if [[ -z "$size" || "$size" == "0" ]]; then
        show_success "Kein Build Cache gefunden."
        press_continue
        return 0
    fi
    
    echo -e "${COLOR_YELLOW}Gefunden: Build Cache (~${size}GB)${COLOR_RESET}"
    
    echo
    
    if confirm_dialog "Build Cache (~${size}GB) wirklich löschen?"; then
        echo -e "${COLOR_BLUE}🧹 Lösche Build Cache...${COLOR_RESET}"
        
        if [[ "$TEST_MODE" == "true" ]]; then
            show_info "TEST-MODUS: Würde docker builder prune --all --force ausführen"
        else
            docker builder prune --all --force
            show_success "Build Cache gelöscht"
        fi
    else
        show_info "Löschung abgebrochen."
    fi
    
    press_continue
}

# Show detailed analysis
show_detailed_analysis() {
    echo -e "${COLOR_BLUE}📊 Detaillierte Docker System-Analyse${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_CYAN}System-Übersicht:${COLOR_RESET}"
    docker system df
    
    echo
    echo -e "${COLOR_CYAN}Docker Version:${COLOR_RESET}"
    docker --version
    
    echo
    echo -e "${COLOR_CYAN}System Info:${COLOR_RESET}"
    docker info --format "Server Version: {{.ServerVersion}}\nKernel Version: {{.KernelVersion}}\nOperating System: {{.OperatingSystem}}"
    
    echo
    echo -e "${COLOR_CYAN}Image-Statistiken:${COLOR_RESET}"
    echo "Gesamt Images: $(docker images --format "{{.ID}}" | wc -l | tr -d ' ')"
    echo "Dangling Images: $(count_dangling_images)"
    
    echo
    echo -e "${COLOR_CYAN}Container-Statistiken:${COLOR_RESET}"
    echo "Laufende Container: $(docker ps --format "{{.ID}}" | wc -l | tr -d ' ')"
    echo "Gestoppte Container: $(count_stopped_containers)"
    
    echo
    echo -e "${COLOR_CYAN}Volume-Statistiken:${COLOR_RESET}"
    echo "Gesamt Volumes: $(docker volume ls --format "{{.Name}}" | wc -l | tr -d ' ')"
    echo "Unbenutzte Volumes: $(count_unused_volumes)"
    
    press_continue
}

# Show all images sorted by size
show_all_images() {
    echo -e "${COLOR_BLUE}📋 Alle Docker Images (nach Größe sortiert)${COLOR_RESET}"
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
    echo -e "${COLOR_RED}🚀 VOLLTÄNDIGE BEREINIGUNG${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Diese Funktion führt alle Bereinigungsvorgänge durch.${COLOR_RESET}"
    echo
    
    local dangling=$(count_dangling_images)
    local containers=$(count_stopped_containers)
    local volumes=$(count_unused_volumes)
    
    echo -e "${COLOR_CYAN}Vorschau:${COLOR_RESET}"
    echo "- $dangling dangling Images"
    echo "- $containers gestoppte Container"
    echo "- $volumes unbenutzte Volumes"
    echo "- Build Cache"
    
    echo
    
    if confirm_dialog "Vollständige Bereinigung wirklich durchführen?"; then
        cleanup_dangling_images
        cleanup_containers
        cleanup_volumes
        cleanup_build_cache
        
        show_success "Vollständige Bereinigung abgeschlossen!"
    else
        show_info "Vollständige Bereinigung abgebrochen."
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
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  🧹 Docker Resource Cleaner - Hauptmenü                     ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[1]${COLOR_RESET} 🗑️   Dangling Images löschen (<none> Images)            ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[2]${COLOR_RESET} 🐳  Unbenutzte Container bereinigen                    ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[3]${COLOR_RESET} 💾  Unbenutzte Volumes aufräumen                       ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[4]${COLOR_RESET} 🔨  Build Cache leeren                                 ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[5]${COLOR_RESET} 📊  Detaillierte Analyse anzeigen                      ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[6]${COLOR_RESET} 🚀  Vollständige Bereinigung (alle oben)               ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[7]${COLOR_RESET} ⚙️   Erweiterte Optionen                                ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_RED}[0]${COLOR_RESET} 🚪  Beenden                                            ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo
        
        # Show test mode status
        if [[ "$TEST_MODE" == "true" ]]; then
            echo -e "${COLOR_YELLOW}⚠️  TEST-MODUS AKTIV (Keine tatsächlichen Löschungen)${COLOR_RESET}"
            echo
        fi
        
        read -p "Ihre Wahl: " -n 1 -r choice
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
                echo -e "${COLOR_GREEN}👋 Auf Wiedersehen!${COLOR_RESET}"
                exit 0
                ;;
            *)
                show_error "Ungültige Wahl. Bitte erneut versuchen."
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
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ⚙️  Erweiterte Optionen                                     ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────────┤${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[1]${COLOR_RESET} 📋  Alle Images nach Größe sortiert anzeigen           ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[2]${COLOR_RESET} 📈  System-Statistik (docker system df)                ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[3]${COLOR_RESET} 🏷️   Alle Images anzeigen (inkl. aktive)                ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[4]${COLOR_RESET} 🐋  Docker Version & System Info                       ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_GREEN}[5]${COLOR_RESET} 🧪  Test-Modus umschalten                              ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_RED}[9]${COLOR_RESET} 🔙  Zurück zum Hauptmenü                               ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│${COLOR_RESET}                                                             ${COLOR_CYAN}│${COLOR_RESET}"
        echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────────────┘${COLOR_RESET}"
        echo
        
        if [[ "$TEST_MODE" == "true" ]]; then
            echo -e "${COLOR_YELLOW}🧪 Test-Modus: AKTIV${COLOR_RESET}"
        else
            echo -e "${COLOR_GRAY}🧪 Test-Modus: INAKTIV${COLOR_RESET}"
        fi
        echo
        
        read -p "Ihre Wahl: " -n 1 -r choice
        echo
        
        case $choice in
            1)
                show_all_images
                ;;
            2)
                echo -e "${COLOR_BLUE}📈 Docker System-Statistik:${COLOR_RESET}"
                docker system df
                press_continue
                ;;
            3)
                echo -e "${COLOR_BLUE}🏷️  Alle Docker Images:${COLOR_RESET}"
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
                    show_success "Test-Modus deaktiviert"
                else
                    TEST_MODE=true
                    show_warning "Test-Modus aktiviert - Es werden keine tatsächlichen Löschungen durchgeführt!"
                fi
                sleep 2
                ;;
            9)
                return 0
                ;;
            *)
                show_error "Ungültige Wahl. Bitte erneut versuchen."
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
    echo -e "${COLOR_GREEN}Willkommen beim Docker Cleaner!${COLOR_RESET}"
    echo -e "${COLOR_BLUE}Dieses Script hilft Ihnen dabei, Docker-Ressourcen sicher zu bereinigen.${COLOR_RESET}"
    echo
    sleep 2
    
    # Start main menu
    show_main_menu
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Docker Cleaner v${SCRIPT_VERSION}"
        echo "Nutzung: $0 [OPTIONEN]"
        echo
        echo "Optionen:"
        echo "  --help, -h       Diese Hilfe anzeigen"
        echo "  --test           Test-Modus aktivieren"
        echo "  --version        Version anzeigen"
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
        show_error "Unbekannte Option: $1"
        echo "Benutzen Sie --help für Hilfe."
        exit 1
        ;;
esac

# Run main function
main "$@"
