# ═══════════════════════════════════════════════════════════════
# update.sh - سكريبت التحديث
# ═══════════════════════════════════════════════════════════════

#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔄 تحديث Smart Storage Manager${NC}"
echo ""

cd /opt/smart-storage-manager

echo -e "${YELLOW}[1/5]${NC} إيقاف الخدمة..."
docker-compose down

echo -e "${YELLOW}[2/5]${NC} تحديث الكود..."
git pull

echo -e "${YELLOW}[3/5]${NC} بناء Frontend..."
cd app/frontend
npm install
npm run build
cd ../..

echo -e "${YELLOW}[4/5]${NC} إعادة بناء Docker..."
docker-compose build

echo -e "${YELLOW}[5/5]${NC} بدء الخدمة..."
docker-compose up -d

echo ""
echo -e "${GREEN}✅ اكتمل التحديث${NC}"
echo ""
echo "إصدار جديد: $(git describe --tags --always)"
echo ""