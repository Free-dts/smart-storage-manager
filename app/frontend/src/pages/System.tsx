import React from 'react';
import { Monitor } from 'lucide-react';

export const System: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">System Information</h1>
        <p className="text-muted-foreground">
          View system status and monitoring information
        </p>
      </div>
      
      <div className="card p-6">
        <div className="flex items-center space-x-4">
          <Monitor className="h-12 w-12 text-primary" />
          <div>
            <h2 className="text-xl font-semibold text-foreground">System Status</h2>
            <p className="text-muted-foreground">
              Monitor system performance and health
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
