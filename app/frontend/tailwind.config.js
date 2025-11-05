// ═══════════════════════════════════════════════════════════════
// tailwind.config.js - Tailwind CSS 4 Configuration
// ═══════════════════════════════════════════════════════════════

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
    './public/index.html',
  ],
  theme: {
    extend: {
      colors: {
        // Modern color palette with enhanced accessibility
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#667eea',
          600: '#5a67d8',
          700: '#4c51bf',
          800: '#434190',
          900: '#3c366b',
          950: '#172554',
        },
        secondary: {
          50: '#fdf4ff',
          100: '#fae8ff',
          200: '#f5d0fe',
          300: '#f0abfc',
          400: '#e879f9',
          500: '#764ba2',
          600: '#6b4397',
          700: '#5f3b8b',
          800: '#4c2f75',
          900: '#3c2860',
        },
        storage: {
          primary: '#667eea',
          secondary: '#10b981',
          accent: '#f59e0b',
          danger: '#ef4444',
          warning: '#f97316',
          success: '#22c55e',
          info: '#06b6d4',
        },
        dark: {
          primary: '#0f172a',
          secondary: '#1e293b',
          tertiary: '#334155',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        arabic: ['Cairo', 'Tajawal', 'Amiri', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '128': '32rem',
      },
      borderRadius: {
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      boxShadow: {
        'soft': '0 2px 15px -3px rgba(0, 0, 0, 0.07), 0 10px 20px -2px rgba(0, 0, 0, 0.04)',
        'medium': '0 4px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
        'strong': '0 10px 40px -10px rgba(0, 0, 0, 0.15), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
        'glow': '0 0 20px rgba(102, 126, 234, 0.4)',
        'glow-lg': '0 0 30px rgba(102, 126, 234, 0.6)',
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-in': 'slideIn 0.3s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'bounce-subtle': 'bounceSubtle 0.6s ease-in-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { 
            transform: 'translateX(100%)',
            opacity: '0'
          },
          '100%': { 
            transform: 'translateX(0)',
            opacity: '1'
          },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        slideDown: {
          '0%': { transform: 'translateY(-10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        scaleIn: {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        bounceSubtle: {
          '0%, 20%, 50%, 80%, 100%': { transform: 'translateY(0)' },
          '40%': { transform: 'translateY(-3px)' },
          '60%': { transform: 'translateY(-1px)' },
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
    require('@tailwindcss/typography'),
    // Custom plugin for storage-specific utilities
    function({ addUtilities, theme }) {
      const newUtilities = {
        '.storage-card': {
          'background': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          'border-radius': theme('borderRadius.xl'),
          'padding': theme('spacing.6'),
          'box-shadow': theme('boxShadow.medium'),
          'transition': 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
          '&:hover': {
            'transform': 'translateY(-2px)',
            'box-shadow': theme('boxShadow.strong'),
          },
        },
        '.storage-progress': {
          'height': theme('spacing.2'),
          'border-radius': theme('borderRadius.full'),
          'background-color': theme('colors.gray.200'),
          'overflow': 'hidden',
          '&-bar': {
            'height': '100%',
            'border-radius': theme('borderRadius.full'),
            'transition': 'width 0.5s ease-in-out',
            'background': 'linear-gradient(90deg, #667eea 0%, #4c51bf 100%)',
          },
        },
        '.storage-status': {
          '&-online': {
            'color': theme('colors.storage.success'),
            '&::before': {
              'content': '"●"',
              'color': theme('colors.storage.success'),
              'margin-right': theme('spacing.2'),
            },
          },
          '&-offline': {
            'color': theme('colors.storage.danger'),
            '&::before': {
              'content': '"●"',
              'color': theme('colors.storage.danger'),
              'margin-right': theme('spacing.2'),
            },
          },
          '&-warning': {
            'color': theme('colors.storage.warning'),
            '&::before': {
              'content': '"●"',
              'color': theme('colors.storage.warning'),
              'margin-right': theme('spacing.2'),
            },
          },
        },
      };
      addUtilities(newUtilities);
    },
  ],
  darkMode: 'class',
};
