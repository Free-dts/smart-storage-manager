# ═══════════════════════════════════════════════════════════════
# snapraid_manager.py - مدير SnapRAID
# ═══════════════════════════════════════════════════════════════

import subprocess
import re
from datetime import datetime

class SnapRAIDManager:
    """مدير SnapRAID"""
    
    def __init__(self):
        self.snapraid_bin = '/usr/local/bin/snapraid'
        self.config_file = '/etc/snapraid.conf'
    
    def run_command(self, cmd):
        """تنفيذ أمر"""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True,
                text=True, timeout=None
            )
            return result.stdout
        except Exception as e:
            return f"Error: {str(e)}"
    
    def get_status(self):
        """الحصول على حالة SnapRAID"""
        output = self.run_command(f'{self.snapraid_bin} status')
        
        status = {
            'configured': os.path.exists(self.config_file),
            'protected': False,
            'files_count': 0,
            'changes': 0,
            'last_sync': None
        }
        
        # تحليل النتيجة
        if 'No differences' in output:
            status['protected'] = True
            status['changes'] = 0
        else:
            # حساب التغييرات
            changes = re.findall(r'(\d+)\s+(?:added|removed|updated)', output)
            status['changes'] = sum(int(c) for c in changes)
        
        # عدد الملفات
        files_match = re.search(r'(\d+)\s+files', output)
        if files_match:
            status['files_count'] = int(files_match.group(1))
        
        return status
    
    def get_detailed_status(self):
        """حالة مفصلة"""
        output = self.run_command(f'{self.snapraid_bin} status')
        return {
            'raw_output': output,
            'summary': self.get_status()
        }
    
    def sync_with_progress(self):
        """Sync مع تتبع التقدم"""
        process = subprocess.Popen(
            f'{self.snapraid_bin} sync',
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        for line in iter(process.stdout.readline, ''):
            if line:
                # إرسال كل سطر كتقدم
                yield {
                    'type': 'sync',
                    'message': line.strip(),
                    'timestamp': datetime.now().isoformat()
                }
        
        process.wait()
        
        if process.returncode == 0:
            yield {
                'type': 'complete',
                'message': 'اكتمل Sync بنجاح',
                'success': True
            }
        else:
            yield {
                'type': 'error',
                'message': 'فشل Sync',
                'success': False
            }
    
    def scrub_with_progress(self):
        """Scrub مع تتبع التقدم"""
        process = subprocess.Popen(
            f'{self.snapraid_bin} scrub -p 10',
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        for line in iter(process.stdout.readline, ''):
            if line:
                yield {
                    'type': 'scrub',
                    'message': line.strip(),
                    'timestamp': datetime.now().isoformat()
                }
        
        process.wait()
        
        yield {
            'type': 'complete',
            'message': 'اكتمل Scrub',
            'success': process.returncode == 0
        }

