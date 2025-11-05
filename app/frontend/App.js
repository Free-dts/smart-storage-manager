import React, { useState, useEffect } from 'react';
import { HardDrive, Shield, Activity, Settings, AlertTriangle, CheckCircle, Loader, Play, RefreshCw } from 'lucide-react';
import io from 'socket.io-client';

const API_URL = window.location.origin;
const socket = io(API_URL);

export default function SmartStorageManager() {
  const [currentView, setCurrentView] = useState('dashboard');
  const [disks, setDisks] = useState({ available: [], excluded: [] });
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [setupMode, setSetupMode] = useState(null);
  const [selectedDisks, setSelectedDisks] = useState([]);
  const [progress, setProgress] = useState(null);
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    loadData();
    
    // WebSocket listeners
    socket.on('connected', (data) => {
      addNotification('success', 'متصل بالخادم');
    });
    
    socket.on('setup_progress', (data) => {
      setProgress(data);
    });
    
    socket.on('snapraid_progress', (data) => {
      setProgress(data);
    });
    
    socket.on('maintenance_start', (data) => {
      addNotification('info', data.message);
    });
    
    socket.on('maintenance_complete', (data) => {
      addNotification('success', data.message);
      loadData();
    });
    
    return () => socket.disconnect();
  }, []);

  const loadData = async () => {
    try {
      const [disksRes, statusRes] = await Promise.all([
        fetch(`${API_URL}/api/disks/detect`),
        fetch(`${API_URL}/api/status`).catch(() => ({ ok: false }))
      ]);
      
      if (disksRes.ok) {
        const disksData = await disksRes.json();
        setDisks(disksData);
      }
      
      if (statusRes.ok) {
        const statusData = await statusRes.json();
        setStatus(statusData);
      }
      
      setLoading(false);
    } catch (error) {
      console.error('Error loading data:', error);
      setLoading(false);
    }
  };

  const addNotification = (type, message) => {
    const id = Date.now();
    setNotifications(prev => [...prev, { id, type, message }]);
    setTimeout(() => {
      setNotifications(prev => prev.filter(n => n.id !== id));
    }, 5000);
  };

  const handleSetupAuto = async () => {
    try {
      const response = await fetch(`${API_URL}/api/setup/auto`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ disks: disks.available.map(d => d.name) })
      });
      
      if (response.ok) {
        addNotification('success', 'بدأ الإعداد التلقائي');
        setCurrentView('setup-progress');
      }
    } catch (error) {
      addNotification('error', 'فشل الإعداد');
    }
  };

  const handleSync = async () => {
    try {
      await fetch(`${API_URL}/api/snapraid/sync`, { method: 'POST' });
      addNotification('info', 'بدأ SnapRAID Sync');
    } catch (error) {
      addNotification('error', 'فشل Sync');
    }
  };

  const handleScrub = async () => {
    try {
      await fetch(`${API_URL}/api/snapraid/scrub`, { method: 'POST' });
      addNotification('info', 'بدأ SnapRAID Scrub');
    } catch (error) {
      addNotification('error', 'فشل Scrub');
    }
  };

  // Dashboard View
  const DashboardView = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-500 text-sm">إجمالي المساحة</p>
              <p className="text-2xl font-bold text-gray-800">
                {status?.mergerfs?.total || '0 GB'}
              </p>
            </div>
            <HardDrive className="w-12 h-12 text-blue-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-500 text-sm">المستخدم</p>
              <p className="text-2xl font-bold text-gray-800">
                {status?.mergerfs?.used || '0 GB'}
              </p>
            </div>
            <Activity className="w-12 h-12 text-green-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-500 text-sm">حالة الحماية</p>
              <p className="text-2xl font-bold text-gray-800">
                {status?.snapraid?.protected ? 'محمي' : 'غير محمي'}
              </p>
            </div>
            <Shield className="w-12 h-12 text-purple-500" />
          </div>
        </div>
      </div>

      {status?.disks && (
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
            <HardDrive className="w-5 h-5" />
            الأقراص
          </h3>
          <div className="space-y-4">
            {Object.entries(status.disks).map(([name, disk]) => (
              <div key={name} className="border rounded-lg p-4">
                <div className="flex justify-between items-center mb-2">
                  <span className="font-semibold">{name}</span>
                  <span className="text-sm text-gray-500">{disk.size}</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-4">
                  <div
                    className={`h-4 rounded-full transition-all ${
                      disk.usage > 90 ? 'bg-red-500' :
                      disk.usage > 80 ? 'bg-yellow-500' : 'bg-green-500'
                    }`}
                    style={{ width: `${disk.usage}%` }}
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  {disk.usage}% مستخدم
                </p>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
          <Shield className="w-5 h-5" />
          SnapRAID
        </h3>
        <div className="space-y-3">
          <div className="flex justify-between">
            <span>آخر مزامنة:</span>
            <span className="font-semibold">
              {status?.snapraid?.last_sync || 'لم يتم بعد'}
            </span>
          </div>
          <div className="flex justify-between">
            <span>الملفات المحمية:</span>
            <span className="font-semibold">
              {status?.snapraid?.files_count || 0}
            </span>
          </div>
          <div className="flex gap-2 mt-4">
            <button
              onClick={handleSync}
              className="flex-1 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 flex items-center justify-center gap-2"
            >
              <RefreshCw className="w-4 h-4" />
              Sync
            </button>
            <button
              onClick={handleScrub}
              className="flex-1 bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 flex items-center justify-center gap-2"
            >
              <Play className="w-4 h-4" />
              Scrub
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  // Setup View
  const SetupView = () => (
    <div className="max-w-4xl mx-auto space-y-6">
      <div className="bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg shadow-lg p-8 text-white">
        <h2 className="text-3xl font-bold mb-2">🚀 مرحباً بك!</h2>
        <p className="text-lg">لنبدأ بإعداد نظام التخزين الذكي</p>
      </div>

      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-xl font-bold mb-4">الأقراص المكتشفة</h3>
        
        {disks.available.length > 0 ? (
          <div className="space-y-3 mb-6">
            {disks.available.map((disk, idx) => (
              <div key={idx} className="border rounded-lg p-4 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <HardDrive className={`w-8 h-8 ${disk.type === 'SSD' ? 'text-blue-500' : 'text-gray-500'}`} />
                  <div>
                    <p className="font-semibold">{disk.name}</p>
                    <p className="text-sm text-gray-500">{disk.size} - {disk.type}</p>
                    {disk.model && <p className="text-xs text-gray-400">{disk.model}</p>}
                  </div>
                </div>
                <CheckCircle className="w-6 h-6 text-green-500" />
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8">
            <AlertTriangle className="w-16 h-16 text-yellow-500 mx-auto mb-4" />
            <p className="text-gray-600">لا توجد أقراص متاحة للإضافة</p>
          </div>
        )}

        {disks.excluded.length > 0 && (
          <details className="mt-4">
            <summary className="cursor-pointer text-sm text-gray-500 hover:text-gray-700">
              أقراص مستبعدة ({disks.excluded.length})
            </summary>
            <div className="mt-2 space-y-2">
              {disks.excluded.map((disk, idx) => (
                <div key={idx} className="text-sm p-2 bg-gray-50 rounded">
                  <span className="font-mono">{disk.name}</span>
                  <span className="text-gray-500 mr-2">- {disk.reason}</span>
                </div>
              ))}
            </div>
          </details>
        )}
      </div>

      {disks.available.length >= 2 && (
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-xl font-bold mb-4">اختر طريقة الإعداد</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <button
              onClick={handleSetupAuto}
              className="p-6 border-2 border-blue-500 rounded-lg hover:bg-blue-50 transition-colors text-right"
            >
              <div className="flex items-center gap-3 mb-2">
                <div className="bg-blue-500 text-white rounded-full w-10 h-10 flex items-center justify-center text-xl">
                  🤖
                </div>
                <h4 className="font-bold text-lg">تلقائي ذكي</h4>
              </div>
              <p className="text-sm text-gray-600">
                يختار النظام التكوين الأمثل تلقائياً (موصى به)
              </p>
            </button>

            <button
              onClick={() => setSetupMode('manual')}
              className="p-6 border-2 border-gray-300 rounded-lg hover:bg-gray-50 transition-colors text-right"
            >
              <div className="flex items-center gap-3 mb-2">
                <div className="bg-gray-500 text-white rounded-full w-10 h-10 flex items-center justify-center text-xl">
                  ⚙️
                </div>
                <h4 className="font-bold text-lg">يدوي</h4>
              </div>
              <p className="text-sm text-gray-600">
                أنت تختار كل قرص ودوره (للمتقدمين)
              </p>
            </button>
          </div>
        </div>
      )}
    </div>
  );

  // Progress View
  const ProgressView = () => (
    <div className="max-w-2xl mx-auto">
      <div className="bg-white rounded-lg shadow p-8">
        <div className="text-center mb-8">
          <Loader className="w-16 h-16 text-blue-500 mx-auto mb-4 animate-spin" />
          <h3 className="text-2xl font-bold mb-2">جاري العمل...</h3>
          {progress && (
            <p className="text-gray-600">{progress.message}</p>
          )}
        </div>

        {progress?.percentage !== undefined && (
          <div className="w-full bg-gray-200 rounded-full h-4 mb-4">
            <div
              className="bg-blue-500 h-4 rounded-full transition-all"
              style={{ width: `${progress.percentage}%` }}
            />
          </div>
        )}

        <div className="bg-gray-50 rounded p-4 max-h-96 overflow-y-auto font-mono text-sm">
          {progress?.log?.map((line, idx) => (
            <div key={idx} className="mb-1">{line}</div>
          )) || <p className="text-gray-500">انتظر...</p>}
        </div>
      </div>
    </div>
  );

  // Main Render
  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-purple-50 flex items-center justify-center">
        <div className="text-center">
          <Loader className="w-16 h-16 text-blue-500 mx-auto mb-4 animate-spin" />
          <p className="text-gray-600">جاري التحميل...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-purple-50" dir="rtl">
      {/* Header */}
      <div className="bg-white shadow">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-2 rounded-lg">
                <HardDrive className="w-8 h-8 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-800">مدير التخزين الذكي</h1>
                <p className="text-sm text-gray-500">Smart Storage Manager</p>
              </div>
            </div>
            
            <div className="flex gap-2">
              <button
                onClick={() => setCurrentView('dashboard')}
                className={`px-4 py-2 rounded transition-colors ${
                  currentView === 'dashboard'
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                لوحة التحكم
              </button>
              <button
                onClick={() => { setCurrentView('setup'); loadData(); }}
                className={`px-4 py-2 rounded transition-colors ${
                  currentView === 'setup'
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                إعداد
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Notifications */}
      <div className="fixed top-20 left-4 z-50 space-y-2">
        {notifications.map(notif => (
          <div
            key={notif.id}
            className={`px-4 py-3 rounded shadow-lg animate-slide-in ${
              notif.type === 'success' ? 'bg-green-500' :
              notif.type === 'error' ? 'bg-red-500' :
              'bg-blue-500'
            } text-white`}
          >
            {notif.message}
          </div>
        ))}
      </div>

      {/* Content */}
      <div className="container mx-auto px-4 py-8">
        {currentView === 'dashboard' && status ? (
          <DashboardView />
        ) : currentView === 'setup' ? (
          <SetupView />
        ) : currentView === 'setup-progress' ? (
          <ProgressView />
        ) : (
          <SetupView />
        )}
      </div>

      {/* Footer */}
      <div className="bg-white border-t mt-12">
        <div className="container mx-auto px-4 py-4 text-center text-sm text-gray-500">
          <p>Smart Storage Manager v1.0.0 | بدعم من Umbrel Community</p>
        </div>
      </div>
    </div>
  );
}