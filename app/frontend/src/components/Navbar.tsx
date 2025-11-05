import React from 'react';
import { HardDrive, Menu } from 'lucide-react';

export const Navbar: React.FC = () => {
  return (
    <nav className="bg-card border-b border-border shadow-sm">
      <div className="container mx-auto max-w-7xl px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-4">
            <HardDrive className="h-8 w-8 text-primary" />
            <h1 className="text-xl font-bold text-foreground">
              Smart Storage Manager
            </h1>
          </div>
          
          <div className="flex items-center space-x-4">
            <button className="btn btn-outline btn-sm">
              <Menu className="h-4 w-4 mr-2" />
              Menu
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};
