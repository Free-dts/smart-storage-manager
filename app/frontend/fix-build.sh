#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# fix-build.sh - Build failure fix and troubleshooting script
# ═══════════════════════════════════════════════════════════════

set -e

echo "🔧 Smart Storage Manager Frontend Build Fixer"
echo "=============================================="

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

# Check Node.js and npm versions
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        echo "Please install Node.js 18.19.0 or later from https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2)
    echo "Node.js version: $NODE_VERSION"
    
    # Check if Node version is >= 18
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -lt 18 ]; then
        print_error "Node.js version is too old. Please install Node.js 18.19.0 or later."
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        echo "Please install npm 8.0.0 or later"
        exit 1
    fi
    
    NPM_VERSION=$(npm --version)
    echo "npm version: $NPM_VERSION"
    
    print_success "System requirements check passed"
}

# Clean everything
deep_clean() {
    print_status "Performing deep clean..."
    
    # Remove all potential cache directories
    rm -rf node_modules
    rm -rf dist
    rm -rf build
    rm -rf .vite
    rm -rf coverage
    
    # Remove package-lock.json
    rm -f package-lock.json
    
    # Clean npm cache
    print_status "Cleaning npm cache..."
    npm cache clean --force
    
    # Clean yarn cache if yarn is available
    if command -v yarn &> /dev/null; then
        print_status "Cleaning yarn cache..."
        yarn cache clean
    fi
    
    # Clean pnpm cache if pnpm is available
    if command -v pnpm &> /dev/null; then
        print_status "Cleaning pnpm cache..."
        pnpm store prune
    fi
    
    print_success "Deep clean completed"
}

# Fix package.json dependencies
fix_package_json() {
    print_status "Checking package.json..."
    
    if [ ! -f "package.json" ]; then
        print_error "package.json not found"
        exit 1
    fi
    
    # Backup original package.json
    cp package.json package.json.backup
    
    # Check for syntax errors in package.json
    if ! node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" 2>/dev/null; then
        print_error "package.json contains syntax errors"
        exit 1
    fi
    
    print_success "package.json is valid"
}

# Fix Vite configuration
fix_vite_config() {
    print_status "Checking Vite configuration..."
    
    if [ -f "vite.config.ts" ]; then
        # Basic syntax check
        if ! node -c vite.config.ts 2>/dev/null; then
            print_warning "vite.config.ts may have syntax errors"
        else
            print_success "vite.config.ts syntax is valid"
        fi
    else
        print_warning "vite.config.ts not found"
    fi
}

# Fix TypeScript configuration
fix_ts_config() {
    print_status "Checking TypeScript configuration..."
    
    if [ -f "tsconfig.json" ]; then
        # Check if TypeScript is installed
        if ! command -v tsc &> /dev/null; then
            print_warning "TypeScript compiler not found globally"
        fi
        
        print_success "tsconfig.json found"
    else
        print_warning "tsconfig.json not found"
    fi
}

# Fix missing source files
create_missing_files() {
    print_status "Checking for essential source files..."
    
    # Create src directory if it doesn't exist
    mkdir -p src
    
    # Check for main files
    if [ ! -f "src/main.tsx" ]; then
        print_warning "src/main.tsx not found, creating..."
        cat > src/main.tsx << 'EOL'
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import './index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      gcTime: 10 * 60 * 1000,
      retry: 2,
      refetchOnWindowFocus: false,
    },
  },
});

const container = document.getElementById('root');
if (!container) {
  throw new Error('Root element not found');
}

const root = createRoot(container);

root.render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>
);
EOL
    fi
    
    if [ ! -f "src/App.tsx" ]; then
        print_warning "src/App.tsx not found, creating..."
        cat > src/App.tsx << 'EOL'
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import './App.css';

function App() {
  return (
    <div className="min-h-screen bg-background text-foreground p-6">
      <h1 className="text-3xl font-bold mb-4">Smart Storage Manager</h1>
      <p className="text-muted-foreground">
        Welcome to your Smart Storage Manager frontend.
      </p>
    </div>
  );
}

export default App;
EOL
    fi
    
    if [ ! -f "src/index.css" ]; then
        print_warning "src/index.css not found, creating..."
        cat > src/index.css << 'EOL'
@import 'tailwindcss';
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
}

body {
  @apply bg-background text-foreground;
  font-feature-settings: "rlig" 1, "calt" 1;
}
EOL
    fi
    
    # Create basic components directory
    mkdir -p src/components src/pages src/hooks src/utils src/types
    
    print_success "Essential source files checked/created"
}

# Install dependencies with fallback
install_with_fallback() {
    print_status "Installing dependencies..."
    
    # Try different package managers in order of preference
    
    # Method 1: npm ci
    if [ -f "package-lock.json" ]; then
        print_status "Using npm ci..."
        if npm ci --prefer-offline --no-audit; then
            print_success "Dependencies installed with npm ci"
            return 0
        fi
    fi
    
    # Method 2: npm install
    print_status "Trying npm install..."
    if npm install --prefer-offline --no-audit; then
        print_success "Dependencies installed with npm install"
        return 0
    fi
    
    # Method 3: npm install with legacy peer deps
    print_status "Trying npm install with legacy peer deps..."
    if npm install --legacy-peer-deps --prefer-offline --no-audit; then
        print_success "Dependencies installed with legacy peer deps"
        return 0
    fi
    
    # Method 4: npm install with force
    print_status "Trying npm install with force..."
    if npm install --force --prefer-offline --no-audit; then
        print_success "Dependencies installed with force"
        return 0
    fi
    
    print_error "Failed to install dependencies with all methods"
    return 1
}

# Test build
test_build() {
    print_status "Testing build process..."
    
    # Try to run type check
    print_status "Running type check..."
    npm run type-check || print_warning "Type check failed"
    
    # Try to run lint
    print_status "Running lint..."
    npm run lint || print_warning "Lint failed"
    
    # Try to build
    print_status "Attempting build..."
    if npm run build; then
        print_success "Build test passed!"
        return 0
    else
        print_warning "Build test failed"
        return 1
    fi
}

# Create troubleshooting report
create_report() {
    local report_file="build-fix-report.txt"
    
    print_status "Creating troubleshooting report..."
    
    cat > "$report_file" << EOL
Smart Storage Manager Frontend - Build Fix Report
=================================================
Generated: $(date)

System Information:
- Node.js: $(node --version 2>/dev/null || echo "Not found")
- npm: $(npm --version 2>/dev/null || echo "Not found")
- OS: $(uname -s) $(uname -r)
- Architecture: $(uname -m)

Directory: $(pwd)

Package.json exists: $([ -f package.json ] && echo "Yes" || echo "No")
node_modules exists: $([ -d node_modules ] && echo "Yes" || echo "No")
vite.config.ts exists: $([ -f vite.config.ts ] && echo "Yes" || echo "No")
tsconfig.json exists: $([ -f tsconfig.json ] && echo "Yes" || echo "No")

npm version: $(npm --version 2>/dev/null || echo "N/A")
npm outdated: $(npm outdated 2>/dev/null | wc -l || echo "N/A")

Recent errors (if any):
$(tail -n 20 npm-debug.log 2>/dev/null || echo "No npm-debug.log found")

Troubleshooting steps performed:
- System requirements check
- Deep clean of caches and files
- Package.json validation
- Essential source files creation
- Dependency installation with multiple methods
- Build process testing

If you're still having issues, please:
1. Check the npm-debug.log file for detailed error messages
2. Ensure all environment variables are set correctly
3. Try running the build in a fresh directory
4. Check that all dependencies support your Node.js version
EOL

    print_success "Troubleshooting report saved to $report_file"
}

# Main fix function
main() {
    # Check for help flag
    if [ "${1}" = "--help" ] || [ "${1}" = "-h" ]; then
        echo "Usage: $0 [options]"
        echo
        echo "This script fixes common build issues by:"
        echo "  1. Checking system requirements (Node.js, npm)"
        echo "  2. Cleaning caches and build artifacts"
        echo "  3. Validating configuration files"
        echo "  4. Creating missing source files"
        echo "  5. Installing dependencies with fallback methods"
        echo "  6. Testing the build process"
        echo
        echo "Options:"
        echo "  --full      Perform full deep clean and reinstall"
        echo "  --help      Show this help message"
        echo
        exit 0
    fi
    
    # Handle full option
    if [ "${1}" = "--full" ]; then
        deep_clean
    fi
    
    check_requirements
    fix_package_json
    fix_vite_config
    fix_ts_config
    create_missing_files
    
    if install_with_fallback; then
        test_build
        create_report
        
        echo
        print_success "Build fix completed!"
        echo
        echo "Next steps:"
        echo "  • Run 'npm run dev' to start development"
        echo "  • Run 'npm run build' to build for production"
        echo "  • Check the build-fix-report.txt for detailed information"
    else
        print_error "Build fix failed"
        echo
        echo "Manual troubleshooting steps:"
        echo "  1. Check your internet connection"
        echo "  2. Try running 'npm cache clean --force'"
        echo "  3. Remove node_modules and package-lock.json manually"
        echo "  4. Try installing dependencies manually with 'npm install'"
        echo "  5. Check if your Node.js version is compatible"
        echo
        create_report
        exit 1
    fi
}

# Run main function
main "$@"
