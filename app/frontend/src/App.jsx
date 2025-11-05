import React from 'react';

function App() {
  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>Smart Storage Manager</h1>
      <p>Frontend is working!</p>
      <p>Node.js version: {process.env.NODE_VERSION || 'Unknown'}</p>
      <div style={{ marginTop: '20px', padding: '10px', border: '1px solid #ccc' }}>
        <h3>System Information:</h3>
        <p>React Version: {React.version}</p>
        <p>Build Status: Success</p>
        <p>Environment: Production Ready</p>
      </div>
    </div>
  );
}

export default App;