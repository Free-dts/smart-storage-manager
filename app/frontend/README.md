# Smart Storage Manager Frontend

Modern React 19 frontend for the Smart Storage Manager application, built with Vite 6.0.1.

## Quick Start

### 🚀 Fast Setup

```bash
cd app/frontend
chmod +x install.sh
./install.sh --build
```

### 🔧 Fix Build Issues

If you encounter build problems:

```bash
cd app/frontend
chmod +x fix-build.sh
./fix-build.sh --full
```

### 📦 Manual Installation

```bash
cd app/frontend
npm install
npm run dev
```

Visit http://localhost:3000 to see the application.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint issues |
| `npm run type-check` | Run TypeScript type checking |
| `npm test` | Run tests |
| `npm run clean` | Clean build artifacts |

## Key Features

- **React 19.2.0** - Latest React with modern hooks and patterns
- **Vite 6.0.1** - Fast build tool with hot module replacement
- **TypeScript** - Type-safe development
- **Tailwind CSS 4** - Utility-first CSS framework
- **ESLint + Prettier** - Code linting and formatting
- **Vitest** - Fast unit testing
- **React Router** - Client-side routing
- **React Query** - Data fetching and caching
- **Zustand** - State management

## Prerequisites

- Node.js 20.19.0 or later
- npm 10.0.0 or later

## Troubleshooting

### Build Failures

Run the automated fix script:
```bash
./fix-build.sh --full
```

### Common Issues

1. **Node.js version too old**
   ```bash
   # Install Node.js 20.19.0+ from nodejs.org
   ```

2. **Dependency installation fails**
   ```bash
   rm -rf node_modules package-lock.json
   npm cache clean --force
   npm install --legacy-peer-deps
   ```

3. **TypeScript errors**
   ```bash
   npm install typescript@5.9.3 --save-dev
   npm run type-check
   ```

4. **Vite build errors**
   ```bash
   rm -rf node_modules/.vite
   npm install
   npm run build
   ```

## Documentation

- [Complete Build Fix Guide](./BUILD_FIX_GUIDE.md) - Comprehensive troubleshooting guide
- [Installation Script](./install.sh) - Automated installation
- [Build Script](./build.sh) - Production build script
- [Fix Script](./fix-build.sh) - Automated troubleshooting

## Environment Variables

Create a `.env` file:

```env
VITE_API_BASE_URL=http://localhost:5000
VITE_SOCKET_URL=http://localhost:5000
VITE_APP_NAME=Smart Storage Manager
VITE_APP_VERSION=2.0.0
VITE_ENVIRONMENT=development
```

## Project Structure

```
app/frontend/
├── src/
│   ├── components/     # React components
│   ├── pages/          # Page components
│   ├── hooks/          # Custom hooks
│   ├── utils/          # Utilities
│   ├── types/          # TypeScript types
│   ├── test/           # Test setup
│   ├── App.tsx         # Main app
│   ├── main.tsx        # Entry point
│   └── index.css       # Global styles
├── public/             # Static files
├── package.json        # Dependencies
├── vite.config.ts      # Vite config
├── tsconfig.json       # TypeScript config
└── tailwind.config.js  # Tailwind config
```

## Development

1. **Start development server**:
   ```bash
   npm run dev
   ```

2. **Run type checking**:
   ```bash
   npm run type-check
   ```

3. **Run linting**:
   ```bash
   npm run lint
   ```

4. **Run tests**:
   ```bash
   npm test
   ```

## Production Build

```bash
npm run build
```

The build output will be in the `dist/` directory.

## Support

If you encounter issues:

1. Check the [Build Fix Guide](./BUILD_FIX_GUIDE.md)
2. Run `./fix-build.sh` for automatic fixes
3. Check `npm-debug.log` for detailed errors
4. Ensure Node.js 20.19.0+ is installed

---

**Version**: 2.0.0  
**React**: 19.2.0  
**Vite**: 6.0.1  
**Node.js**: 20.19.0+
