# Smart Storage Manager Frontend - Build Fix Guide

## Overview

This guide provides comprehensive solutions for fixing build failures in the Smart Storage Manager React 19 frontend application.

## Table of Contents

1. [Quick Fix](#quick-fix)
2. [Common Issues and Solutions](#common-issues-and-solutions)
3. [Installation Guide](#installation-guide)
4. [Build Process](#build-process)
5. [Development Setup](#development-setup)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

---

## Quick Fix

For most build issues, run the automatic fix script:

```bash
cd app/frontend
chmod +x fix-build.sh
./fix-build.sh --full
```

This will:
- Check system requirements
- Clean all caches and build artifacts
- Validate configuration files
- Install dependencies with multiple fallback methods
- Test the build process

---

## Common Issues and Solutions

### 1. Node.js Version Issues

**Problem**: "Node.js version is too old"

**Solution**:
```bash
# Install Node.js 20.19.0 or later
# Check current version
node --version

# Should output v20.x.x or higher
```

### 2. Dependency Installation Failures

**Problem**: `npm install` fails with peer dependency errors

**Solution**:
```bash
# Method 1: Clean install
rm -rf node_modules package-lock.json
npm cache clean --force
npm install

# Method 2: Legacy peer deps
npm install --legacy-peer-deps

# Method 3: Force install
npm install --force
```

### 3. TypeScript Compilation Errors

**Problem**: TypeScript compilation fails

**Solution**:
```bash
# Check TypeScript version
npm list typescript

# Reinstall TypeScript
npm install typescript@5.9.3 --save-dev

# Run type check
npm run type-check
```

### 4. Vite Build Errors

**Problem**: Vite build process fails

**Solution**:
```bash
# Clean Vite cache
rm -rf node_modules/.vite

# Rebuild dependencies
npm install

# Test development server
npm run dev
```

### 5. Missing Source Files

**Problem**: Build fails with "Module not found" errors

**Solution**:
```bash
# Run the fix script to create missing files
./fix-build.sh

# Or manually check source files
ls -la src/
```

---

## Installation Guide

### Automated Installation

Use the provided installation script:

```bash
cd app/frontend
chmod +x install.sh
./install.sh --build
```

This will:
1. Check Node.js and npm versions
2. Clean previous installations
3. Install dependencies
4. Run type checking and linting
5. Build the project

### Manual Installation

1. **Check prerequisites**:
   ```bash
   node --version    # Should be 20.19.0+
   npm --version     # Should be 10.0.0+
   ```

2. **Install dependencies**:
   ```bash
   cd app/frontend
   npm install
   ```

3. **Set up environment** (optional):
   ```bash
   # Create .env file
   echo "VITE_API_BASE_URL=http://localhost:5000" > .env
   echo "VITE_SOCKET_URL=http://localhost:5000" >> .env
   ```

4. **Verify installation**:
   ```bash
   npm run type-check
   npm run lint
   npm run build
   ```

---

## Build Process

### Development Build

```bash
# Start development server
npm run dev

# Development server runs on http://localhost:3000
```

### Production Build

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

### Build Scripts

The following scripts are available:

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint issues |
| `npm run type-check` | Run TypeScript type checking |
| `npm test` | Run tests |
| `npm run test:ui` | Run tests with UI |
| `npm run test:coverage` | Run tests with coverage |
| `npm run clean` | Clean build artifacts |

---

## Development Setup

### 1. Prerequisites

- Node.js 20.19.0 or later
- npm 10.0.0 or later
- Git

### 2. Project Structure

```
app/frontend/
├── src/
│   ├── components/     # React components
│   ├── pages/          # Page components
│   ├── hooks/          # Custom React hooks
│   ├── utils/          # Utility functions
│   ├── types/          # TypeScript type definitions
│   ├── assets/         # Static assets
│   ├── test/           # Test setup and utilities
│   ├── App.tsx         # Main app component
│   ├── App.css         # App styles
│   ├── main.tsx        # Entry point
│   └── index.css       # Global styles
├── public/             # Public static files
├── package.json        # Dependencies and scripts
├── vite.config.ts      # Vite configuration
├── tsconfig.json       # TypeScript configuration
├── tailwind.config.js  # Tailwind CSS configuration
├── postcss.config.js   # PostCSS configuration
├── eslint.config.js    # ESLint configuration
├── install.sh          # Installation script
├── build.sh            # Build script
└── fix-build.sh        # Build fix script
```

### 3. Environment Variables

Create a `.env` file in the frontend directory:

```env
# API Configuration
VITE_API_BASE_URL=http://localhost:5000
VITE_SOCKET_URL=http://localhost:5000

# App Configuration
VITE_APP_NAME=Smart Storage Manager
VITE_APP_VERSION=2.0.0
VITE_ENVIRONMENT=development

# Development
VITE_DEBUG=true
```

---

## Troubleshooting

### Build Failure Checklist

1. **System Requirements**:
   - [ ] Node.js version is 20.19.0 or later
   - [ ] npm version is 10.0.0 or later
   - [ ] Sufficient disk space (at least 1GB free)

2. **Dependencies**:
   - [ ] `node_modules` directory exists
   - [ ] `package-lock.json` file exists (for npm ci)
   - [ ] No package.json syntax errors
   - [ ] All peer dependency conflicts resolved

3. **Configuration Files**:
   - [ ] `vite.config.ts` exists and is valid
   - [ ] `tsconfig.json` exists and is valid
   - [ ] `tailwind.config.js` exists and is valid
   - [ ] `postcss.config.js` exists and is valid

4. **Source Files**:
   - [ ] `src/main.tsx` exists
   - [ ] `src/App.tsx` exists
   - [ ] `src/index.css` exists
   - [ ] All imports are correct

5. **Build Artifacts**:
   - [ ] No conflicting `.tsbuildinfo` files
   - [ ] No corrupted Vite cache
   - [ ] No conflicting TypeScript project references

### Common Error Messages and Solutions

#### "Module not found: Error: Can't resolve 'react'"

**Solution**:
```bash
npm install react@19.2.0 react-dom@19.2.0 --save
```

#### "Type error: Cannot find module 'react'"

**Solution**:
```bash
npm install @types/react@19.2.0 @types/react-dom@19.2.0 --save-dev
```

#### "Vite: Failed to resolve import"

**Solution**:
```bash
# Check import paths
# Ensure file extensions are correct
# Clear Vite cache
rm -rf node_modules/.vite
```

#### "Tailwind CSS: Cannot find tailwindcss"

**Solution**:
```bash
npm install tailwindcss@4.1.16 --save-dev
```

#### "ESLint: Unexpected token" or parsing errors

**Solution**:
```bash
# Check ESLint configuration
npm install eslint@9.17.0 --save-dev
npm run lint:fix
```

### Advanced Troubleshooting

#### Enable Debug Mode

```bash
# Set debug environment variable
export VITE_DEBUG=true
npm run dev
```

#### Verbose Build Output

```bash
# Run build with verbose output
npm run build -- --debug
```

#### Check Dependency Tree

```bash
# View dependency tree
npm ls

# Check for outdated dependencies
npm outdated

# Check for security vulnerabilities
npm audit
```

#### Manual Cache Clearing

```bash
# Clear all npm caches
npm cache clean --force

# Clear node_modules
rm -rf node_modules

# Clear package-lock.json
rm -f package-lock.json

# Reinstall dependencies
npm install
```

---

## Advanced Configuration

### Custom Vite Configuration

Edit `vite.config.ts` to customize build settings:

```typescript
export default defineConfig({
  // Build optimization
  build: {
    target: 'es2020',
    minify: 'esbuild',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          utils: ['lodash-es', 'date-fns'],
        },
      },
    },
  },
  
  // Server configuration
  server: {
    port: 3000,
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
      },
    },
  },
  
  // Optimization
  optimizeDeps: {
    include: ['react', 'react-dom', 'lodash-es'],
  },
});
```

### Custom TypeScript Configuration

Edit `tsconfig.json` for strict type checking:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Custom Tailwind Configuration

Edit `tailwind.config.js` for custom styling:

```javascript
export default {
  content: ['./src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
};
```

---

## Production Deployment

### Build for Production

```bash
npm run build
```

### Deploy to Web Server

1. **Copy dist directory to web server**:
   ```bash
   scp -r dist/* user@server:/var/www/html/
   ```

2. **Configure web server** (Nginx example):
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           root /var/www/html;
           try_files $uri $uri/ /index.html;
       }
   }
   ```

### Docker Deployment

Use the provided Dockerfile:

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## Support and Contributing

### Getting Help

1. Check the troubleshooting section above
2. Run `./fix-build.sh` for automatic fixes
3. Check the build-fix-report.txt file for detailed information
4. Review npm-debug.log for specific error messages

### Contributing

When contributing to the frontend:

1. Follow the existing code style
2. Run linting and type checking before committing
3. Write tests for new features
4. Update documentation as needed

---

## Changelog

### Version 2.0.0

- Updated to React 19.2.0
- Updated to Vite 6.0.1
- Added comprehensive build fix scripts
- Improved TypeScript configuration
- Enhanced Tailwind CSS 4 support
- Added automated installation and troubleshooting

---

**Last Updated**: November 2025
**Version**: 2.0.0
