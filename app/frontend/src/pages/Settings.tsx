import React from 'react';
import { Settings } from 'lucide-react';

export const Settings: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Settings</h1>
        <p className="text-muted-foreground">
          Configure your storage system preferences
        </p>
      </div>
      
      <div className="card p-6">
        <div className="flex items-center space-x-4">
          <Settings className="h-12 w-12 text-primary" />
          <div>
            <h2 className="text-xl font-semibold text-foreground">Configuration</h2>
            <p className="text-muted-foreground">
              Adjust system settings and preferences
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
