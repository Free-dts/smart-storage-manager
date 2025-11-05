import React from 'react';
import { Activity, HardDrive, Monitor } from 'lucide-react';

export const Dashboard: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
        <p className="text-muted-foreground">
          Monitor your storage system status and performance
        </p>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Storage Status</p>
              <p className="text-2xl font-bold text-foreground">Online</p>
            </div>
            <HardDrive className="h-8 w-8 text-primary" />
          </div>
        </div>
        
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-muted-foreground">System Load</p>
              <p className="text-2xl font-bold text-foreground">Normal</p>
            </div>
            <Monitor className="h-8 w-8 text-primary" />
          </div>
        </div>
        
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Activity</p>
              <p className="text-2xl font-bold text-foreground">Active</p>
            </div>
            <Activity className="h-8 w-8 text-primary" />
          </div>
        </div>
      </div>
    </div>
  );
};
