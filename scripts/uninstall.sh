# ═══════════════════════════════════════════════════════════════
# uninstall.sh - سكريبت إلغاء التثبيت
# ═══════════════════════════════════════════════════════════════

#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  إلغاء تثبيت Smart Storage Manager${NC}"
echo ""
echo "سيتم:"
echo "  • إيقاف وحذف Docker containers"
echo "  • حذف systemd service"
echo "  • حذف cron jobs"
echo ""
echo -e "${RED}ملاحظة: بياناتك المخزنة في /mnt/storage لن تُحذف${NC}"
echo ""
read -p "هل أنت متأكد؟ (اكتب 'YES' بالأحرف الكبيرة): " confirm

if [ "$confirm" != "YES" ]; then
    echo "تم الإلغاء"
    exit 0
fi

echo -e "${YELLOW}[1/6]${NC} إيقاف الخدمة..."
cd /opt/smart-storage-manager
docker-compose down || true

echo -e "${YELLOW}[2/6]${NC} حذف systemd service..."
systemctl stop smart-storage-manager || true
systemctl disable smart-storage-manager || true
rm -f /etc/systemd/system/smart-storage-manager.service
systemctl daemon-reload

echo -e "${YELLOW}[3/6]${NC} حذف cron jobs..."
crontab -l | grep -v "smart-storage-maintenance" | crontab - || true

echo -e "${YELLOW}[4/6]${NC} حذف السكريبتات..."
rm -f /usr/local/bin/smart-storage-maintenance

echo -e "${YELLOW}[5/6]${NC} حذف ملفات التطبيق..."
read -p "حذف ملفات التطبيق في /opt/smart-storage-manager؟ (y/n): " del_app
if [[ $del_app =~ ^[Yy]$ ]]; then
    rm -rf /opt/smart-storage-manager
fi

echo -e "${YELLOW}[6/6]${NC} حذف السجلات..."
read -p "حذف السجلات في /var/log/smart-storage؟ (y/n): " del_logs
if [[ $del_logs =~ ^[Yy]$ ]]; then
    rm -rf /var/log/smart-storage
fi

echo ""
echo -e "${GREEN}✅ تم إلغاء التثبيت${NC}"
echo ""
echo -e "${YELLOW}ملاحظات:${NC}"
echo "  • بياناتك في /mnt/storage لا تزال موجودة"
echo "  • إعدادات fstab و SnapRAID لا تزال موجودة"
echo "  • MergerFS و SnapRAID لا يزالان مثبتين"
echo ""
echo "لإلغاء تثبيت كامل، نفذ:"
echo "  sudo apt remove mergerfs"
echo "  sudo rm /usr/local/bin/snapraid"
echo "  sudo nano /etc/fstab  # وأزل السطور المتعلقة بالتخزين"
echo ""