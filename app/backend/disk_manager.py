# ═══════════════════════════════════════════════════════════════
# disk_manager.py - مدير الأقراص
# ═══════════════════════════════════════════════════════════════

import subprocess
import json
import os
import re
from pathlib import Path

class DiskManager:
    """مدير ذكي لاكتشاف وإدارة الأقراص"""
    
    def __init__(self):
        self.excluded_types = ['loop', 'zram', 'ram']
        self.min_size_gb = 10
    
    def run_command(self, cmd):
        """تنفيذ أمر shell وإرجاع النتيجة"""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, 
                text=True, timeout=30
            )
            return result.stdout.strip()
        except Exception as e:
            return f"Error: {str(e)}"
    
    def get_system_disk(self):
        """اكتشاف قرص النظام"""
        # الطريقة 1: من /
        cmd = "df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's|/dev/||'"
        system_disk = self.run_command(cmd)
        
        if not system_disk:
            # الطريقة 2: من /boot
            cmd = "df /boot | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's|/dev/||'"
            system_disk = self.run_command(cmd)
        
        return system_disk
    
    def is_usb_disk(self, disk_name):
        """التحقق إذا كان القرص USB"""
        cmd = f"udevadm info --query=property --name=/dev/{disk_name} 2>/dev/null | grep 'ID_BUS=usb'"
        result = self.run_command(cmd)
        return 'usb' in result.lower()
    
    def get_disk_size_gb(self, disk_name):
        """الحصول على حجم القرص بالجيجابايت"""
        cmd = f"lsblk -bdn -o SIZE /dev/{disk_name} 2>/dev/null"
        size_bytes = self.run_command(cmd)
        try:
            return int(size_bytes) / (1024**3)
        except:
            return 0
    
    def get_disk_type(self, disk_name):
        """معرفة نوع القرص (HDD/SSD)"""
        try:
            with open(f'/sys/block/{disk_name}/queue/rotational', 'r') as f:
                rotational = f.read().strip()
                return 'HDD' if rotational == '1' else 'SSD'
        except:
            return 'Unknown'
    
    def get_disk_model(self, disk_name):
        """الحصول على موديل القرص"""
        cmd = f"lsblk -dn -o MODEL /dev/{disk_name} 2>/dev/null"
        return self.run_command(cmd).strip()
    
    def get_disk_serial(self, disk_name):
        """الحصول على Serial Number"""
        cmd = f"udevadm info --query=property --name=/dev/{disk_name} 2>/dev/null | grep 'ID_SERIAL_SHORT=' | cut -d= -f2"
        return self.run_command(cmd)
    
    def is_mounted(self, disk_name):
        """التحقق إذا كان القرص مثبت"""
        cmd = f"mount | grep '^/dev/{disk_name}'"
        result = self.run_command(cmd)
        return bool(result)
    
    def is_system_mount(self, disk_name):
        """التحقق إذا كان مثبت على مجلدات النظام"""
        cmd = f"mount | grep '^/dev/{disk_name}' | grep -E ' /boot | /home | /var | /usr '"
        result = self.run_command(cmd)
        return bool(result)
    
    def detect_all_disks(self):
        """اكتشاف جميع الأقراص وتصنيفها"""
        
        # الحصول على قرص النظام
        system_disk = self.get_system_disk()
        
        # الحصول على جميع الأقراص
        cmd = "lsblk -dn -o NAME,TYPE | grep disk | awk '{print $1}'"
        all_disks = self.run_command(cmd).split('\n')
        
        available = []
        excluded = []
        
        for disk in all_disks:
            if not disk:
                continue
            
            # فحص الاستبعادات
            excluded_reason = None
            
            # استبعاد الأجهزة الافتراضية
            if any(disk.startswith(t) for t in self.excluded_types):
                excluded_reason = "جهاز افتراضي"
            
            # استبعاد قرص النظام
            elif disk == system_disk:
                excluded_reason = "قرص النظام"
            
            # استبعاد USB
            elif self.is_usb_disk(disk):
                excluded_reason = "قرص USB خارجي"
            
            # استبعاد الأقراص الصغيرة
            elif self.get_disk_size_gb(disk) < self.min_size_gb:
                excluded_reason = f"صغير جداً (< {self.min_size_gb}GB)"
            
            # استبعاد المثبتة على النظام
            elif self.is_system_mount(disk):
                excluded_reason = "مثبت على مجلدات النظام"
            
            # جمع المعلومات
            disk_info = {
                'name': f'/dev/{disk}',
                'size': self.format_size(self.get_disk_size_gb(disk)),
                'type': self.get_disk_type(disk),
                'model': self.get_disk_model(disk),
                'serial': self.get_disk_serial(disk),
                'mounted': self.is_mounted(disk)
            }
            
            if excluded_reason:
                disk_info['reason'] = excluded_reason
                excluded.append(disk_info)
            else:
                available.append(disk_info)
        
        # ترتيب حسب الحجم (الأكبر أولاً)
        available.sort(key=lambda x: self.parse_size(x['size']), reverse=True)
        
        return {
            'available': available,
            'excluded': excluded,
            'system_disk': f'/dev/{system_disk}',
            'count': {
                'available': len(available),
                'excluded': len(excluded)
            }
        }
    
    def format_size(self, size_gb):
        """تنسيق الحجم للعرض"""
        if size_gb >= 1000:
            return f"{size_gb/1000:.1f} TB"
        return f"{size_gb:.1f} GB"
    
    def parse_size(self, size_str):
        """تحويل النص لحجم رقمي"""
        try:
            num = float(re.findall(r'[\d.]+', size_str)[0])
            if 'TB' in size_str:
                return num * 1000
            return num
        except:
            return 0
    
    def get_disk_info(self, disk_name):
        """الحصول على معلومات تفصيلية لقرص"""
        disk = disk_name.replace('/dev/', '')
        
        info = {
            'name': disk_name,
            'size': self.format_size(self.get_disk_size_gb(disk)),
            'type': self.get_disk_type(disk),
            'model': self.get_disk_model(disk),
            'serial': self.get_disk_serial(disk),
            'mounted': self.is_mounted(disk),
            'partitions': []
        }
        
        # الحصول على Partitions
        cmd = f"lsblk -ln -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/{disk} | tail -n +2"
        partitions = self.run_command(cmd).split('\n')
        
        for part in partitions:
            if part:
                parts = part.split()
                if len(parts) >= 2:
                    info['partitions'].append({
                        'name': parts[0],
                        'size': parts[1],
                        'fstype': parts[2] if len(parts) > 2 else '',
                        'mountpoint': parts[3] if len(parts) > 3 else ''
                    })
        
        # SMART health
        cmd = f"smartctl -H /dev/{disk} 2>/dev/null | grep 'SMART overall-health'"
        health = self.run_command(cmd)
        info['health'] = 'PASSED' if 'PASSED' in health else 'Unknown'
        
        # Temperature
        cmd = f"smartctl -A /dev/{disk} 2>/dev/null | grep Temperature_Celsius | awk '{{print $10}}'"
        temp = self.run_command(cmd)
        info['temperature'] = f"{temp}°C" if temp else 'N/A'
        
        return info
    
    def prepare_disk(self, disk_name, label, progress_callback=None):
        """تحضير قرص (مسح + تقسيم + تهيئة)"""
        disk = disk_name.replace('/dev/', '')
        
        if progress_callback:
            progress_callback('preparing', f'تحضير {disk_name}', 0)
        
        # 1. فك التثبيت
        self.run_command(f"umount /dev/{disk}* 2>/dev/null")
        
        if progress_callback:
            progress_callback('wiping', 'مسح البيانات القديمة', 20)
        
        # 2. مسح البيانات
        self.run_command(f"wipefs -af /dev/{disk}")
        self.run_command(f"dd if=/dev/zero of=/dev/{disk} bs=1M count=100 2>/dev/null")
        
        if progress_callback:
            progress_callback('partitioning', 'إنشاء جدول تقسيم', 40)
        
        # 3. إنشاء جدول تقسيم GPT
        self.run_command(f"parted -s /dev/{disk} mklabel gpt")
        
        if progress_callback:
            progress_callback('creating', 'إنشاء partition', 60)
        
        # 4. إنشاء partition
        self.run_command(f"parted -s /dev/{disk} mkpart primary ext4 0% 100%")
        
        # انتظار النظام
        self.run_command(f"partprobe /dev/{disk}")
        self.run_command("sleep 2")
        
        if progress_callback:
            progress_callback('formatting', 'تهيئة نظام الملفات', 80)
        
        # 5. تهيئة ext4
        self.run_command(f"mkfs.ext4 -F -L {label} /dev/{disk}1")
        
        if progress_callback:
            progress_callback('complete', f'اكتمل تحضير {disk_name}', 100)
        
        return True
    
    def setup_automatic(self, disk_list, progress_callback=None):
        """إعداد تلقائي للنظام"""
        
        if len(disk_list) < 2:
            raise Exception("يجب توفير قرصين على الأقل")
        
        # ترتيب حسب الحجم
        sorted_disks = sorted(disk_list, 
            key=lambda d: self.get_disk_size_gb(d.replace('/dev/', '')), 
            reverse=True)
        
        parity_disk = sorted_disks[0]
        data_disks = sorted_disks[1:]
        
        return self.setup_manual(parity_disk, data_disks, progress_callback)
    
    def setup_manual(self, parity_disk, data_disks, progress_callback=None):
        """إعداد يدوي"""
        
        total_steps = 1 + len(data_disks) + 3  # parity + data + config + mount + snapraid
        current_step = 0
        
        # تحضير Parity
        current_step += 1
        if progress_callback:
            progress_callback('parity', f'تحضير Parity ({current_step}/{total_steps})', 
                             (current_step/total_steps)*100)
        
        self.prepare_disk(parity_disk, 'parity', progress_callback)
        
        # تحضير Data disks
        prepared_data = []
        for idx, disk in enumerate(data_disks, 1):
            current_step += 1
            if progress_callback:
                progress_callback('data', f'تحضير Data Disk {idx} ({current_step}/{total_steps})', 
                                 (current_step/total_steps)*100)
            
            label = f'disk{idx}'
            self.prepare_disk(disk, label, progress_callback)
            prepared_data.append({'disk': disk, 'label': label, 'number': idx})
        
        # إعداد fstab
        current_step += 1
        if progress_callback:
            progress_callback('fstab', f'إعداد fstab ({current_step}/{total_steps})', 
                             (current_step/total_steps)*100)
        
        self.setup_fstab(parity_disk, prepared_data)
        
        # تثبيت MergerFS
        current_step += 1
        if progress_callback:
            progress_callback('mergerfs', f'إعداد MergerFS ({current_step}/{total_steps})', 
                             (current_step/total_steps)*100)
        
        self.setup_mergerfs()
        
        # إعداد SnapRAID
        current_step += 1
        if progress_callback:
            progress_callback('snapraid', f'إعداد SnapRAID ({current_step}/{total_steps})', 
                             (current_step/total_steps)*100)
        
        self.setup_snapraid_config(parity_disk, prepared_data)
        
        return {
            'success': True,
            'parity': parity_disk,
            'data_disks': prepared_data,
            'message': 'تم الإعداد بنجاح'
        }
    
    def setup_fstab(self, parity_disk, data_disks):
        """إعداد fstab للتثبيت التلقائي"""
        
        # إنشاء المجلدات
        os.makedirs('/mnt/parity', exist_ok=True)
        for disk_info in data_disks:
            os.makedirs(f'/mnt/disk{disk_info["number"]}', exist_ok=True)
        os.makedirs('/mnt/storage', exist_ok=True)
        
        # الحصول على UUIDs
        parity_uuid = self.get_uuid(parity_disk)
        
        # قراءة fstab الحالي
        with open('/etc/fstab', 'r') as f:
            fstab_content = f.read()
        
        # إضافة السطور الجديدة
        new_entries = ["\n# Smart Storage Manager"]
        new_entries.append(f"UUID={parity_uuid}  /mnt/parity  ext4  defaults,noatime,nofail  0  2")
        
        for disk_info in data_disks:
            disk_uuid = self.get_uuid(disk_info['disk'])
            new_entries.append(
                f"UUID={disk_uuid}  /mnt/disk{disk_info['number']}  ext4  defaults,noatime,nofail  0  2"
            )
        
        # كتابة fstab
        with open('/etc/fstab', 'a') as f:
            f.write('\n'.join(new_entries))
        
        # تثبيت الأقراص
        self.run_command('mount -a')
    
    def get_uuid(self, disk):
        """الحصول على UUID"""
        disk_part = disk if disk.endswith('1') else f"{disk}1"
        cmd = f"blkid -s UUID -o value {disk_part}"
        return self.run_command(cmd)
    
    def setup_mergerfs(self):
        """إعداد MergerFS"""
        
        # إضافة لـ fstab
        mergerfs_line = "/mnt/disk* /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=mfs,minfreespace=20G,fsname=mergerfs 0 0"
        
        with open('/etc/fstab', 'a') as f:
            f.write(f"\n{mergerfs_line}\n")
        
        # تثبيت
        self.run_command('mount -a')
    
    def setup_snapraid_config(self, parity_disk, data_disks):
        """إنشاء ملف إعدادات SnapRAID"""
        
        config = ["# SnapRAID Configuration - Smart Storage Manager\n"]
        config.append("parity /mnt/parity/snapraid.parity\n")
        config.append("\ncontent /var/snapraid.content")
        
        for disk_info in data_disks:
            config.append(f"content /mnt/disk{disk_info['number']}/.snapraid.content")
        
        config.append("\n")
        for disk_info in data_disks:
            config.append(f"data d{disk_info['number']} /mnt/disk{disk_info['number']}")
        
        config.append("\n# Exclusions")
        exclusions = [
            "exclude *.unrecoverable",
            "exclude /tmp/",
            "exclude /lost+found/",
            "exclude *.!sync",
            "exclude .AppleDouble",
            "exclude ._AppleDouble",
            "exclude .DS_Store",
            "exclude .Thumbs.db",
            "exclude .fseventsd",
            "exclude .Spotlight-V100",
            "exclude .TemporaryItems",
            "exclude .Trashes"
        ]
        config.extend([f"{e}\n" for e in exclusions])
        
        config.append("\nblock_size 256")
        config.append("\nautosave 500\n")
        
        with open('/etc/snapraid.conf', 'w') as f:
            f.writelines(config)
    
    def get_all_disks_status(self):
        """الحصول على حالة جميع الأقراص"""
        disks_status = {}
        
        # البحث عن الأقراص المثبتة
        cmd = "df -h | grep '/mnt/disk'"
        mounted = self.run_command(cmd).split('\n')
        
        for line in mounted:
            if not line:
                continue
            parts = line.split()
            if len(parts) >= 6:
                name = parts[5].split('/')[-1]  # disk1, disk2, etc
                disks_status[name] = {
                    'size': parts[1],
                    'used': parts[2],
                    'available': parts[3],
                    'usage': int(parts[4].rstrip('%'))
                }
        
        return disks_status
    
    def get_mergerfs_status(self):
        """حالة MergerFS"""
        cmd = "df -h /mnt/storage 2>/dev/null | tail -1"
        result = self.run_command(cmd)
        
        if result:
            parts = result.split()
            if len(parts) >= 6:
                return {
                    'mounted': True,
                    'total': parts[1],
                    'used': parts[2],
                    'available': parts[3],
                    'usage': int(parts[4].rstrip('%'))
                }
        
        return {'mounted': False}
    
    def check_health(self):
        """فحص صحة النظام"""
        health = {
            'overall': 'healthy',
            'issues': []
        }
        
        # فحص الأقراص
        cmd = "ls /dev/sd? 2>/dev/null"
        disks = self.run_command(cmd).split()
        
        for disk in disks:
            disk_name = disk.split('/')[-1]
            smart_health = self.run_command(
                f"smartctl -H {disk} 2>/dev/null | grep 'SMART overall-health'"
            )
            
            if 'PASSED' not in smart_health:
                health['issues'].append(f'{disk} - صحة SMART سيئة')
                health['overall'] = 'warning'
        
        # فحص المساحة
        disks_status = self.get_all_disks_status()
        for name, status in disks_status.items():
            if status['usage'] > 90:
                health['issues'].append(f'{name} - ممتلئ بنسبة {status["usage"]}%')
                health['overall'] = 'warning'
        
        return health

