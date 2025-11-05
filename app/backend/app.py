# ═══════════════════════════════════════════════════════════════
# 6. app/backend/app.py - Backend الرئيسي
# ═══════════════════════════════════════════════════════════════

"""
Smart Storage Manager Backend
واجهة API لإدارة التخزين
"""

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import os
import logging
from disk_manager import DiskManager
from snapraid_manager import SnapRAIDManager
from apscheduler.schedulers.background import BackgroundScheduler

# إعداد التطبيق
app = Flask(__name__, static_folder='../frontend/build')
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# إعداد Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# المديرون
disk_manager = DiskManager()
snapraid_manager = SnapRAIDManager()

# الجدولة للصيانة التلقائية
scheduler = BackgroundScheduler()

# ═══════════════════════════════════════════════════════════════
# Routes - نقاط النهاية
# ═══════════════════════════════════════════════════════════════

# الصفحة الرئيسية
@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def static_proxy(path):
    return send_from_directory(app.static_folder, path)

# ═══════════════════════════════════════════════════════════════
# API - اكتشاف الأقراص
# ═══════════════════════════════════════════════════════════════

@app.route('/api/disks/detect', methods=['GET'])
def detect_disks():
    """اكتشاف جميع الأقراص المتاحة"""
    try:
        result = disk_manager.detect_all_disks()
        return jsonify(result), 200
    except Exception as e:
        logger.error(f"Error detecting disks: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/disks/info/<disk_name>', methods=['GET'])
def get_disk_info(disk_name):
    """الحصول على معلومات قرص معين"""
    try:
        info = disk_manager.get_disk_info(disk_name)
        return jsonify(info), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ═══════════════════════════════════════════════════════════════
# API - إعداد النظام
# ═══════════════════════════════════════════════════════════════

@app.route('/api/setup/auto', methods=['POST'])
def setup_auto():
    """إعداد تلقائي للنظام"""
    try:
        data = request.json
        disks = data.get('disks', [])
        
        # بدء الإعداد
        socketio.emit('setup_progress', {'step': 'start', 'message': 'بدء الإعداد...'})
        
        result = disk_manager.setup_automatic(disks, progress_callback=emit_progress)
        
        socketio.emit('setup_progress', {'step': 'complete', 'message': 'اكتمل الإعداد!'})
        
        return jsonify(result), 200
    except Exception as e:
        logger.error(f"Setup error: {e}")
        socketio.emit('setup_progress', {'step': 'error', 'message': str(e)})
        return jsonify({"error": str(e)}), 500

@app.route('/api/setup/manual', methods=['POST'])
def setup_manual():
    """إعداد يدوي"""
    try:
        data = request.json
        parity_disk = data.get('parity_disk')
        data_disks = data.get('data_disks', [])
        
        result = disk_manager.setup_manual(parity_disk, data_disks, progress_callback=emit_progress)
        
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ═══════════════════════════════════════════════════════════════
# API - حالة النظام
# ═══════════════════════════════════════════════════════════════

@app.route('/api/status', methods=['GET'])
def get_status():
    """الحصول على حالة النظام الكاملة"""
    try:
        status = {
            'disks': disk_manager.get_all_disks_status(),
            'mergerfs': disk_manager.get_mergerfs_status(),
            'snapraid': snapraid_manager.get_status(),
            'health': disk_manager.check_health()
        }
        return jsonify(status), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/storage/usage', methods=['GET'])
def get_storage_usage():
    """الحصول على استخدام المساحة"""
    try:
        usage = disk_manager.get_storage_usage()
        return jsonify(usage), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ═══════════════════════════════════════════════════════════════
# API - SnapRAID
# ═══════════════════════════════════════════════════════════════

@app.route('/api/snapraid/sync', methods=['POST'])
def snapraid_sync():
    """تشغيل SnapRAID Sync"""
    try:
        socketio.start_background_task(run_snapraid_sync)
        return jsonify({"message": "بدأ Sync"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/snapraid/scrub', methods=['POST'])
def snapraid_scrub():
    """تشغيل SnapRAID Scrub"""
    try:
        socketio.start_background_task(run_snapraid_scrub)
        return jsonify({"message": "بدأ Scrub"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/snapraid/status', methods=['GET'])
def snapraid_status():
    """حالة SnapRAID"""
    try:
        status = snapraid_manager.get_detailed_status()
        return jsonify(status), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ═══════════════════════════════════════════════════════════════
# API - الإعدادات
# ═══════════════════════════════════════════════════════════════

@app.route('/api/settings', methods=['GET'])
def get_settings():
    """الحصول على الإعدادات"""
    try:
        settings = disk_manager.get_settings()
        return jsonify(settings), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/settings', methods=['POST'])
def update_settings():
    """تحديث الإعدادات"""
    try:
        data = request.json
        result = disk_manager.update_settings(data)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ═══════════════════════════════════════════════════════════════
# WebSocket Events
# ═══════════════════════════════════════════════════════════════

@socketio.on('connect')
def handle_connect():
    """عند اتصال العميل"""
    logger.info("Client connected")
    emit('connected', {'message': 'متصل بالخادم'})

@socketio.on('disconnect')
def handle_disconnect():
    """عند قطع الاتصال"""
    logger.info("Client disconnected")

def emit_progress(step, message, percentage=None):
    """إرسال تقدم العملية"""
    data = {'step': step, 'message': message}
    if percentage:
        data['percentage'] = percentage
    socketio.emit('operation_progress', data)

# ═══════════════════════════════════════════════════════════════
# Background Tasks
# ═══════════════════════════════════════════════════════════════

def run_snapraid_sync():
    """تشغيل Sync في الخلفية"""
    try:
        for progress in snapraid_manager.sync_with_progress():
            socketio.emit('snapraid_progress', progress)
    except Exception as e:
        logger.error(f"Sync error: {e}")
        socketio.emit('snapraid_error', {'error': str(e)})

def run_snapraid_scrub():
    """تشغيل Scrub في الخلفية"""
    try:
        for progress in snapraid_manager.scrub_with_progress():
            socketio.emit('snapraid_progress', progress)
    except Exception as e:
        logger.error(f"Scrub error: {e}")
        socketio.emit('snapraid_error', {'error': str(e)})

def scheduled_maintenance():
    """الصيانة المجدولة"""
    logger.info("Running scheduled maintenance")
    socketio.emit('maintenance_start', {'message': 'بدأت الصيانة التلقائية'})
    
    try:
        # فحص الصحة
        health = disk_manager.check_health()
        
        # SnapRAID Sync إذا كانت هناك تغييرات
        status = snapraid_manager.get_status()
        if status.get('changes', 0) > 0:
            run_snapraid_sync()
        
        socketio.emit('maintenance_complete', {'message': 'اكتملت الصيانة'})
    except Exception as e:
        logger.error(f"Maintenance error: {e}")
        socketio.emit('maintenance_error', {'error': str(e)})

# جدولة الصيانة اليومية الساعة 2 صباحاً
scheduler.add_job(scheduled_maintenance, 'cron', hour=2, minute=0)
scheduler.start()

# ═══════════════════════════════════════════════════════════════
# تشغيل التطبيق
# ═══════════════════════════════════════════════════════════════

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
