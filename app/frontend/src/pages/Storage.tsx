import React from 'react';
import { HardDrive } from 'lucide-react';

export const Storage: React.FC = () => {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Storage Management</h1>
        <p className="text-muted-foreground">
          Manage your storage devices and volumes
        </p>
      </div>
      
      <div className="card p-6">
        <div className="flex items-center space-x-4">
          <HardDrive className="h-12 w-12 text-primary" />
          <div>
            <h2 className="text-xl font-semibold text-foreground">Storage Devices</h2>
            <p className="text-muted-foreground">
              Configure and monitor your storage devices
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
