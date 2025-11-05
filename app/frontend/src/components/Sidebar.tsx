import React from 'react';
import { NavLink } from 'react-router-dom';
import { 
  Home, 
  HardDrive, 
  Settings, 
  Monitor,
  Activity 
} from 'lucide-react';

const navItems = [
  { to: '/dashboard', icon: Home, label: 'Dashboard' },
  { to: '/storage', icon: HardDrive, label: 'Storage' },
  { to: '/system', icon: Monitor, label: 'System' },
  { to: '/settings', icon: Settings, label: 'Settings' },
];

export const Sidebar: React.FC = () => {
  return (
    <aside className="fixed left-0 top-16 h-[calc(100vh-4rem)] w-64 bg-card border-r border-border">
      <nav className="p-4">
        <div className="space-y-2">
          {navItems.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors ${
                  isActive
                    ? 'bg-primary text-primary-foreground'
                    : 'text-foreground hover:bg-accent hover:text-accent-foreground'
                }`
              }
            >
              <Icon className="h-4 w-4 mr-3" />
              {label}
            </NavLink>
          ))}
        </div>
      </nav>
    </aside>
  );
};
