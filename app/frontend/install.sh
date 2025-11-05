#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# install-frontend.sh - Complete frontend installation script
# ═══════════════════════════════════════════════════════════════

set -e

echo "🚀 Starting Smart Storage Manager Frontend Installation..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check Node.js version
check_node_version() {
    print_status "Checking Node.js version..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 20.19.0 or later."
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    REQUIRED_VERSION=20
    
    if [ "$NODE_VERSION" -lt "$REQUIRED_VERSION" ]; then
        print_error "Node.js version $NODE_VERSION is too old. Please install Node.js 20.19.0 or later."
        exit 1
    fi
    
    print_success "Node.js $(node --version) detected"
}

# Check npm version
check_npm_version() {
    print_status "Checking npm version..."
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm 10.0.0 or later."
        exit 1
    fi
    
    NPM_VERSION=$(npm --version | cut -d'.' -f1)
    REQUIRED_NPM_VERSION=10
    
    if [ "$NPM_VERSION" -lt "$REQUIRED_NPM_VERSION" ]; then
        print_error "npm version $(npm --version) is too old. Please install npm 10.0.0 or later."
        exit 1
    fi
    
    print_success "npm $(npm --version) detected"
}

# Clean previous installation
clean_previous() {
    print_status "Cleaning previous installation..."
    
    cd "$(dirname "$0")"
    cd ..
    
    # Remove node_modules if exists
    if [ -d "node_modules" ]; then
        print_warning "Removing existing node_modules..."
        rm -rf node_modules
    fi
    
    # Remove package-lock.json if exists
    if [ -f "package-lock.json" ]; then
        print_warning "Removing existing package-lock.json..."
        rm -f package-lock.json
    fi
    
    # Remove dist directory
    if [ -d "dist" ]; then
        print_warning "Removing existing dist directory..."
        rm -rf dist
    fi
    
    # Clean npm cache
    print_status "Cleaning npm cache..."
    npm cache clean --force
    
    print_success "Cleanup completed"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Try npm install first, fallback to npm ci
    if [ -f "package-lock.json" ]; then
        print_status "Found package-lock.json, using npm ci..."
        npm ci --prefer-offline --no-audit
    else
        print_status "Using npm install..."
        npm install --prefer-offline --no-audit
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Run type checking
check_types() {
    print_status "Running TypeScript type checking..."
    
    npm run type-check
    
    if [ $? -eq 0 ]; then
        print_success "Type checking passed"
    else
        print_warning "Type checking failed, but continuing..."
    fi
}

# Run linting
run_linting() {
    print_status "Running ESLint..."
    
    npm run lint
    
    if [ $? -eq 0 ]; then
        print_success "Linting passed"
    else
        print_warning "Linting failed, but continuing..."
    fi
}

# Build the project
build_project() {
    print_status "Building the project..."
    
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Project built successfully"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Create .env file if it doesn't exist
setup_environment() {
    if [ ! -f ".env" ]; then
        print_status "Creating environment file..."
        cat > .env << EOL
# Development Environment Variables
VITE_API_BASE_URL=http://localhost:5000
VITE_SOCKET_URL=http://localhost:5000
VITE_APP_NAME=Smart Storage Manager
VITE_APP_VERSION=2.0.0
VITE_ENVIRONMENT=development
EOL
        print_success "Environment file created"
    fi
}

# Create vite.svg icon
create_icon() {
    print_status "Creating Vite icon..."
    cat > public/vite.svg << 'EOL'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
EOL
    print_success "Icon created"
}

# Create manifest.json
create_manifest() {
    print_status "Creating PWA manifest..."
    cat > public/manifest.json << 'EOL'
{
  "name": "Smart Storage Manager",
  "short_name": "Storage Manager",
  "description": "Smart Storage Manager - Modern React 19 Frontend for Umbrel",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#667eea",
  "icons": [
    {
      "src": "vite.svg",
      "sizes": "any",
      "type": "image/svg+xml"
    }
  ]
}
EOL
    print_success "Manifest created"
}

# Create Apple touch icon placeholder
create_apple_touch_icon() {
    print_status "Creating Apple touch icon placeholder..."
    # This is a simple 180x180 SVG converted to PNG placeholder
    echo "Creating placeholder - you may want to add a proper icon later"
}

# Main installation function
main() {
    echo "Smart Storage Manager Frontend Installer"
    echo "========================================="
    echo
    
    check_node_version
    check_npm_version
    clean_previous
    setup_environment
    create_icon
    create_manifest
    create_apple_touch_icon
    install_dependencies
    check_types
    run_linting
    
    # Only build if we want to ensure everything works
    if [ "${1}" = "--build" ]; then
        build_project
    fi
    
    echo
    print_success "Installation completed successfully!"
    echo
    echo "Next steps:"
    echo "  1. Run 'npm run dev' to start the development server"
    echo "  2. Run 'npm run build' to build for production"
    echo "  3. Run 'npm run preview' to preview the production build"
    echo
    echo "Available scripts:"
    echo "  npm run dev       - Start development server"
    echo "  npm run build     - Build for production"
    echo "  npm run preview   - Preview production build"
    echo "  npm run lint      - Run ESLint"
    echo "  npm run type-check - Run TypeScript checks"
    echo
}

# Run main function with all arguments
main "$@"
