#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# Smart Storage Manager - Modern React 19 Setup Script
# ═══════════════════════════════════════════════════════════════

set -e

echo "🚀 Setting up Smart Storage Manager with React 19..."

# Check Node.js version
NODE_VERSION=$(node --version)
REQUIRED_VERSION="v20.19.0"

if ! node --version | grep -q "v20"; then
    echo "❌ Node.js 20.19.0 or higher is required. Current version: $NODE_VERSION"
    echo "Please update Node.js from: https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js version check passed: $NODE_VERSION"

# Clean install
echo "🧹 Cleaning previous installation..."
rm -rf node_modules package-lock.json
rm -rf dist build .vite

# Install dependencies
echo "📦 Installing modern React 19 dependencies..."
npm install

# Setup git hooks (if git is available)
if [ -d ".git" ]; then
    echo "🔗 Setting up git hooks..."
    npx husky install
    npx husky add .husky/pre-commit "npm run lint:fix"
fi

# Create necessary directories
echo "📁 Creating project structure..."
mkdir -p src/{components,hooks,services,stores,utils,types,styles}
mkdir -p src/components/{ui,layout,features}
mkdir -p public

# Copy TypeScript types
if [ ! -f "src/types/global.d.ts" ]; then
    cat > src/types/global.d.ts << 'EOF'
/// <reference types="vite/client" />

declare module '*.svg' {
  import * as React from 'react';
  
  export const ReactComponent: React.FunctionComponent<
    React.SVGProps<SVGSVGElement> & { title?: string }
  >;
  
  const src: string;
  export default src;
}

declare global {
  interface Window {
    ENV: {
      API_URL: string;
      NODE_ENV: string;
    };
  }
}

export {};
EOF
fi

# Setup testing utilities
if [ ! -f "src/test/setup.ts" ]; then
    cat > src/test/setup.ts << 'EOF'
import '@testing-library/jest-dom';

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  observe() {
    return null;
  }
  disconnect() {
    return null;
  }
  unobserve() {
    return null;
  }
};

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  observe() {
    return null;
  }
  disconnect() {
    return null;
  }
  unobserve() {
    return null;
  }
};
EOF
fi

# Create basic app structure if it doesn't exist
if [ ! -f "src/App.tsx" ]; then
    echo "📝 Creating basic app structure..."
    
    cat > src/App.tsx << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import Layout from '@/components/layout/Layout';
import Home from '@/pages/Home';
import './App.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <Layout>
          <Routes>
            <Route path="/" element={<Home />} />
          </Routes>
        </Layout>
      </Router>
    </QueryClientProvider>
  );
}

export default App;
EOF

    cat > src/main.tsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

    cat > src/index.css << 'EOF'
@import 'tailwindcss/base';
@import 'tailwindcss/components';
@import 'tailwindcss/utilities';

:root {
  font-family: 'Inter', system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
  
  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;
  
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-text-size-adjust: 100%;
}

body {
  margin: 0;
  display: flex;
  place-items: center;
  min-width: 320px;
  min-height: 100vh;
}

#root {
  width: 100%;
  margin: 0 auto;
  text-align: center;
}

@media (prefers-color-scheme: light) {
  :root {
    color: #213547;
    background-color: #ffffff;
  }
}
EOF

    mkdir -p src/pages
    mkdir -p src/components/layout
    
    cat > src/pages/Home.tsx << 'EOF'
import React from 'react';

const Home: React.FC = () => {
  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 to-secondary-50 dark:from-dark-primary dark:to-dark-secondary">
      <div className="container mx-auto px-4 py-16">
        <h1 className="text-4xl font-bold text-center text-gray-900 dark:text-white mb-8">
          Smart Storage Manager
        </h1>
        <p className="text-lg text-gray-600 dark:text-gray-300 text-center max-w-2xl mx-auto">
          Modern React 19 Frontend with TypeScript, Tailwind CSS 4, and Vite 6
        </p>
        <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-8">
          <div className="storage-card">
            <h3 className="text-xl font-semibold mb-4">React 19</h3>
            <p>Latest features including useTransition, useOptimistic, and Activity API</p>
          </div>
          <div className="storage-card">
            <h3 className="text-xl font-semibold mb-4">Tailwind CSS 4</h3>
            <p>Modern utility-first CSS framework with enhanced performance</p>
          </div>
          <div className="storage-card">
            <h3 className="text-xl font-semibold mb-4">Vite 6</h3>
            <p>Lightning-fast development server and build tool</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
EOF

    cat > src/components/layout/Layout.tsx << 'EOF'
import React from 'react';

interface LayoutProps {
  children: React.ReactNode;
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <header className="bg-white dark:bg-gray-800 shadow-sm">
        <div className="container mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">
            Smart Storage Manager
          </h1>
        </div>
      </header>
      <main className="container mx-auto px-4 py-8">
        {children}
      </main>
    </div>
  );
};

export default Layout;
EOF

    cat > src/App.css << 'EOF'
/* Modern App styles */
.storage-card {
  @apply bg-gradient-to-br from-primary-500 to-secondary-600 text-white p-6 rounded-xl shadow-lg hover:shadow-xl transition-all duration-300;
}

.storage-progress {
  @apply w-full bg-gray-200 rounded-full h-2 overflow-hidden;
}

.storage-progress-bar {
  @apply h-full bg-gradient-to-r from-primary-500 to-secondary-500 rounded-full transition-all duration-500;
}

.storage-status-online::before {
  content: '●';
  @apply text-green-500 mr-2;
}

.storage-status-offline::before {
  content: '●';
  @apply text-red-500 mr-2;
}

.storage-status-warning::before {
  content: '●';
  @apply text-yellow-500 mr-2;
}
EOF
fi

# Update index.html with modern meta tags
if [ -f "index.html" ]; then
    echo "🌐 Updating index.html with modern meta tags..."
    
    # Backup existing index.html
    cp index.html index.html.backup
    
    cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Smart Storage Manager - Modern React 19 Frontend" />
    <meta name="theme-color" content="#667eea" />
    <title>Smart Storage Manager</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF
fi

# Run type check
echo "🔍 Running TypeScript type check..."
npm run type-check

# Run linting
echo "🧹 Running linting checks..."
npm run lint

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Start development server: npm run dev"
echo "2. Build for production: npm run build"
echo "3. Run tests: npm test"
echo "4. Check for security issues: npm run security-audit"
echo ""
echo "🔧 Development scripts available:"
echo "  npm run dev         - Start development server"
echo "  npm run build       - Build for production"
echo "  npm run preview     - Preview production build"
echo "  npm run lint        - Run ESLint"
echo "  npm run lint:fix    - Fix linting issues"
echo "  npm run type-check  - Run TypeScript type check"
echo "  npm test           - Run test suite"
echo ""
echo "📚 Documentation:"
echo "  See MODERNIZATION_SUMMARY.md for detailed information"
echo "  See /workspace/docs/react-frontend-updates.md for complete analysis"
