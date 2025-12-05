#!/bin/bash

################################################################################
# Ghidra Batch Pipeline Setup Script
# 
# This script sets up a minimal environment for running Ghidra batch analysis:
# - Downloads Ghidra from Google Drive
# - Extracts and configures Ghidra
# - Sets up minimal Python environment 
# - Runs the batch pipeline
#
# Supports: Ubuntu/Debian and Fedora/RHEL based systems
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GHIDRA_INSTALL_DIR="/opt/ghidra"
GOOGLE_DRIVE_FOLDER="https://drive.google.com/drive/u/0/folders/1M0fiQeg5Tv8hAWGKDLpZVRB5GzvCJNGT"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root. It will request sudo when needed."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_info "Detected OS: $NAME $VERSION"
    else
        print_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

################################################################################
# Minimal System Package Installation
################################################################################

install_minimal_packages() {
    print_header "Installing Minimal Required Packages"
    
    case $OS in
        fedora|rhel|centos)
            sudo dnf update -y || print_warning "Failed to update package list"
            sudo dnf install -y \
                python3 \
                python3-pip \
                java-17-openjdk \
                java-17-openjdk-devel \
                wget \
                curl \
                unzip \
                git
            ;;
        ubuntu|debian)
            sudo apt update || print_warning "Failed to update package list"
            sudo apt install -y \
                python3 \
                python3-pip \
                python3-venv \
                openjdk-17-jdk \
                openjdk-17-jre \
                wget \
                curl \
                unzip \
                git
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Supported: Fedora, RHEL, CentOS, Ubuntu, Debian"
            exit 1
            ;;
    esac
    
    print_success "Minimal packages installed"
    
    # Verify Java installation
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    print_info "Java version: $JAVA_VERSION"
}

################################################################################
# Google Drive Download Function
################################################################################

download_from_google_drive() {
    print_header "Downloading Ghidra from Google Drive"
    
    print_info "Google Drive folder: $GOOGLE_DRIVE_FOLDER"
    print_warning "This script cannot automatically download from Google Drive folders due to authentication requirements."
    print_info "Please follow these steps:"
    echo ""
    echo "1. Open the Google Drive folder in your browser:"
    echo "   $GOOGLE_DRIVE_FOLDER"
    echo ""
    echo "2. Look for a Ghidra zip file (e.g., ghidra_*.zip)"
    echo ""
    echo "3. Download it to this directory ($(pwd))"
    echo ""
    
    # Wait for user to download the file
    while true; do
        read -p "Have you downloaded the Ghidra zip file to this directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            print_info "Please download the Ghidra zip file first, then run this script again."
            exit 0
        fi
    done
    
    # Find the downloaded zip file
    GHIDRA_ZIP=$(find . -maxdepth 1 -name "*.zip" -name "*ghidra*" | head -n 1)
    if [ -z "$GHIDRA_ZIP" ]; then
        GHIDRA_ZIP=$(find . -maxdepth 1 -name "*.zip" | head -n 1)
    fi
    
    if [ -z "$GHIDRA_ZIP" ]; then
        print_error "No zip file found in current directory. Please download the Ghidra zip file."
        exit 1
    fi
    
    print_success "Found zip file: $GHIDRA_ZIP"
    return 0
}

################################################################################
# Ghidra Installation
################################################################################

install_ghidra() {
    print_header "Installing Ghidra"
    
    download_from_google_drive
    
    # Check if Ghidra is already installed
    if [ -d "$GHIDRA_INSTALL_DIR" ]; then
        print_warning "Ghidra appears to be already installed at $GHIDRA_INSTALL_DIR"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing Ghidra installation"
            return
        fi
        sudo rm -rf $GHIDRA_INSTALL_DIR
    fi
    
    print_info "Extracting Ghidra..."
    TEMP_DIR=$(mktemp -d)
    cd $TEMP_DIR
    
    unzip -q "$OLDPWD/$GHIDRA_ZIP"
    
    # Find the extracted Ghidra directory
    GHIDRA_DIR=$(find . -maxdepth 1 -type d -name "*ghidra*" | head -n 1)
    if [ -z "$GHIDRA_DIR" ]; then
        print_error "Could not find Ghidra directory in extracted zip"
        exit 1
    fi
    
    sudo mkdir -p /opt
    sudo mv "$GHIDRA_DIR" $GHIDRA_INSTALL_DIR
    
    cd "$OLDPWD"
    rm -rf $TEMP_DIR
    
    if [ -f "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]; then
        print_success "Ghidra installed successfully at $GHIDRA_INSTALL_DIR"
    else
        print_error "Ghidra installation failed - analyzeHeadless not found at $GHIDRA_INSTALL_DIR"
        exit 1
    fi
    
    # Set environment variable
    echo "export GHIDRA_HOME=$GHIDRA_INSTALL_DIR" >> ~/.bashrc
    echo "export GHIDRA_HOME=$GHIDRA_INSTALL_DIR" >> ~/.zshrc 2>/dev/null || true
    export GHIDRA_HOME=$GHIDRA_INSTALL_DIR
    
    print_success "GHIDRA_HOME environment variable set to $GHIDRA_INSTALL_DIR"
}

################################################################################
# Python Environment Setup
################################################################################

setup_python_environment() {
    print_header "Setting Up Python Environment"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_info "Creating Python virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install minimal required packages for the batch pipeline
    print_info "Installing minimal Python packages..."
    pip install python-dotenv
    
    print_success "Python environment configured"
}

################################################################################
# Create Environment File
################################################################################

create_env_file() {
    print_header "Creating Environment Configuration"
    
    cat > .env <<EOF
# Ghidra Configuration
GHIDRA_HOME=$GHIDRA_INSTALL_DIR

# Pipeline Configuration
BATCH_SIZE=10
TIMEOUT_PER_BINARY=180
EOF
    
    print_success "Environment file created: .env"
}

################################################################################
# Directory Setup
################################################################################

setup_directories() {
    print_header "Setting Up Working Directories"
    
    # Create required directories if they don't exist
    mkdir -p builds_new
    mkdir -p ghidra_json_new
    mkdir -p ghidra_scripts
    mkdir -p logs
    
    print_success "Working directories created"
    
    # Check for required files
    if [ ! -f "run_batch_pipeline.py" ]; then
        print_error "run_batch_pipeline.py not found!"
        print_info "This script should be run from the directory containing run_batch_pipeline.py"
        exit 1
    fi
    
    if [ ! -f "ghidra_scripts/extract_features.py" ]; then
        print_error "ghidra_scripts/extract_features.py not found!"
        print_info "Please ensure the Ghidra extraction script is in place"
        exit 1
    fi
    
    print_success "Required files verified"
}

################################################################################
# Run Batch Pipeline
################################################################################

run_batch_pipeline() {
    print_header "Running Batch Pipeline"
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Set environment variables
    export GHIDRA_HOME=$GHIDRA_INSTALL_DIR
    
    print_info "Starting Ghidra batch extraction pipeline..."
    print_info "This may take some time depending on the number of binaries to process..."
    
    python3 run_batch_pipeline.py
    
    if [ $? -eq 0 ]; then
        print_success "Batch pipeline completed successfully!"
    else
        print_error "Batch pipeline failed. Check the output above for details."
        exit 1
    fi
}

################################################################################
# Final Instructions
################################################################################

print_final_instructions() {
    print_header "Setup Complete!"
    
    cat <<EOF
${GREEN}Ghidra batch pipeline setup is complete!${NC}

${BLUE}What was installed:${NC}
  - Ghidra: ${YELLOW}$GHIDRA_INSTALL_DIR${NC}
  - Python virtual environment: ${YELLOW}./venv${NC}
  - Environment configuration: ${YELLOW}./.env${NC}

${BLUE}Pipeline Results:${NC}
  - Input binaries: ${YELLOW}builds_new/${NC}
  - Output JSON files: ${YELLOW}ghidra_json_new/${NC}

${BLUE}To run the pipeline again:${NC}
  1. Activate environment: ${YELLOW}source venv/bin/activate${NC}
  2. Export Ghidra path: ${YELLOW}export GHIDRA_HOME=$GHIDRA_INSTALL_DIR${NC}
  3. Run pipeline: ${YELLOW}python3 run_batch_pipeline.py${NC}

${BLUE}To add more binaries:${NC}
  - Place binary files (.o, .a, .elf) in ${YELLOW}builds_new/${NC}
  - Run the pipeline again

${GREEN}Done!${NC}

EOF
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Ghidra Batch Pipeline Setup"
    print_info "This script will set up Ghidra and run the batch analysis pipeline"
    print_info "Estimated time: 5-15 minutes (plus pipeline execution time)"
    echo ""
    
    check_root
    detect_os
    
    # Setup steps
    install_minimal_packages
    install_ghidra
    setup_python_environment
    create_env_file
    setup_directories
    
    # Run the pipeline
    run_batch_pipeline
    
    # Final instructions
    print_final_instructions
}

# Run main function
main