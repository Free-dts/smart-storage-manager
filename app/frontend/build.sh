#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# build.sh - Frontend build script with error handling
# ═══════════════════════════════════════════════════════════════

set -e

echo "🏗️  Building Smart Storage Manager Frontend..."

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

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check if we're in the frontend directory
if [ ! -f "package.json" ]; then
    print_error "package.json not found. Please run this script from the frontend directory."
    exit 1
fi

# Clean previous build
clean_build() {
    print_status "Cleaning previous build..."
    
    # Remove dist directory
    if [ -d "dist" ]; then
        rm -rf dist
        print_success "Removed existing dist directory"
    fi
    
    # Clean Vite cache
    if [ -d "node_modules/.vite" ]; then
        rm -rf node_modules/.vite
        print_success "Cleaned Vite cache"
    fi
    
    # Remove build artifacts
    rm -rf build
    rm -rf .vite
}

# Install dependencies
install_deps() {
    print_status "Checking dependencies..."
    
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules not found, installing dependencies..."
        
        if [ -f "package-lock.json" ]; then
            npm ci --prefer-offline --no-audit
        else
            npm install --prefer-offline --no-audit
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Failed to install dependencies"
            exit 1
        fi
        print_success "Dependencies installed"
    else
        print_success "Dependencies already installed"
    fi
}

# Run type checking
type_check() {
    print_status "Running TypeScript type checking..."
    
    npm run type-check
    
    if [ $? -ne 0 ]; then
        print_warning "Type checking failed, but continuing with build..."
    else
        print_success "Type checking passed"
    fi
}

# Run linting
run_lint() {
    print_status "Running ESLint..."
    
    npm run lint 2>/dev/null || {
        print_warning "Linting failed, but continuing with build..."
    }
    
    print_success "Linting completed"
}

# Build the project
build_project() {
    print_status "Building project for production..."
    
    # Set production environment
    export NODE_ENV=production
    
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Verify build output
verify_build() {
    print_status "Verifying build output..."
    
    if [ ! -d "dist" ]; then
        print_error "Build output directory 'dist' not found"
        exit 1
    fi
    
    if [ ! -f "dist/index.html" ]; then
        print_error "Build output index.html not found"
        exit 1
    fi
    
    # Check if there are any assets
    ASSET_COUNT=$(find dist -type f | wc -l)
    if [ "$ASSET_COUNT" -eq 0 ]; then
        print_error "No assets found in build output"
        exit 1
    fi
    
    print_success "Build output verified ($ASSET_COUNT files created)"
}

# Show build summary
show_summary() {
    echo
    echo "📦 Build Summary"
    echo "==============="
    
    if [ -d "dist" ]; then
        DIST_SIZE=$(du -sh dist | cut -f1)
        echo "📁 Output directory: dist"
        echo "📊 Total size: $DIST_SIZE"
        echo "📋 Files created: $ASSET_COUNT"
        
        # Show main files
        echo
        echo "🎯 Main build artifacts:"
        ls -la dist/ | head -10
        
        # Show chunk sizes
        if [ -d "dist/assets" ]; then
            echo
            echo "📦 Asset sizes:"
            du -h dist/assets/* | sort -hr
        fi
    fi
    
    echo
    echo "✅ Build completed successfully!"
    echo
    echo "🚀 Next steps:"
    echo "  • Deploy the 'dist' directory to your web server"
    echo "  • Configure your web server to serve index.html for all routes"
    echo "  • Test the application by running 'npm run preview'"
    echo
    echo "🛠️  Available commands:"
    echo "  npm run preview  - Preview the production build locally"
    echo "  npm run dev      - Start development server"
    echo "  npm run lint     - Run linting"
    echo "  npm run test     - Run tests"
}

# Handle cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Build failed. Check the error messages above."
        echo
        echo "🔧 Troubleshooting tips:"
        echo "  1. Run 'npm run clean' to clear all caches"
        echo "  2. Delete node_modules and package-lock.json, then reinstall"
        echo "  3. Check that all imports and dependencies are correct"
        echo "  4. Run 'npm audit' to check for security issues"
        echo
        echo "For more help, see the README or documentation."
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main build function
main() {
    echo "Smart Storage Manager Frontend Build Script"
    echo "==========================================="
    echo
    
    # Check for help flag
    if [ "${1}" = "--help" ] || [ "${1}" = "-h" ]; then
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --clean    Clean build artifacts before building"
        echo "  --dev      Build for development (with source maps)"
        echo "  --help     Show this help message"
        echo
        exit 0
    fi
    
    # Handle clean option
    if [ "${1}" = "--clean" ]; then
        clean_build
    fi
    
    clean_build
    install_deps
    type_check
    run_lint
    build_project
    verify_build
    show_summary
}

# Run main function
main "$@"
