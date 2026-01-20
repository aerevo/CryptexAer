#!/bin/bash 
# 🔍 Z-KINETIC DEPENDENCY AUDIT SCRIPT 
# Purpose: Check and fix security vulnerabilities in npm packages 
# Usage: ./scripts/audit-dependencies.sh
set -e  # Exit on error
echo "🔍 Z-KINETIC Security Audit"
echo "============================"
echo ""
Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
Navigate to server directory
cd "$(dirname "$0")/.."
echo "📦 Current Directory: $(pwd)"
echo ""
============================================
1. CHECK NPM VERSION
============================================
echo "1️⃣  Checking npm version..."
NPM_VERSION=(npm --version)echo "   npm vNPM_VERSION"
echo ""
============================================
2. RUN SECURITY AUDIT
============================================
echo "2️⃣  Running security audit..."
echo ""
if npm audit --json > audit-report.json 2>&1; then
echo -e "{GREEN}✅ No vulnerabilities found!{NC}"
AUDIT_STATUS=0
else
AUDIT_STATUS=$?
# Parse audit results
CRITICAL=$(cat audit-report.json | grep -o '"critical":[0-9]*' | grep -o '[0-9]*' || echo "0")
HIGH=$(cat audit-report.json | grep -o '"high":[0-9]*' | grep -o '[0-9]*' || echo "0")
MODERATE=$(cat audit-report.json | grep -o '"moderate":[0-9]*' | grep -o '[0-9]*' || echo "0")
LOW=$(cat audit-report.json | grep -o '"low":[0-9]*' | grep -o '[0-9]*' || echo "0")

echo -e "${YELLOW}⚠️  Vulnerabilities Found:${NC}"
echo "   🔴 Critical: $CRITICAL"
echo "   🟠 High: $HIGH"
echo "   🟡 Moderate: $MODERATE"
echo "   🟢 Low: $LOW"
echo ""
fi
============================================
3. CHECK OUTDATED PACKAGES
============================================
echo "3️⃣  Checking for outdated packages..."
echo ""
npm outdated || true
echo ""
============================================
4. AUTO-FIX (IF SAFE)
============================================
echo "4️⃣  Attempting automatic fixes..."
echo ""
if [ $AUDIT_STATUS -ne 0 ]; then
echo "   Running: npm audit fix"
npm audit fix
echo ""
echo "   Running: npm audit fix --force (for breaking changes)"
read -p "   ⚠️  This may update to newer major versions. Continue? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    npm audit fix --force
    echo -e "${GREEN}   ✅ Force fix applied${NC}"
else
    echo -e "${YELLOW}   ⏭️  Skipped force fix${NC}"
fi
fi
echo ""
============================================
5. RE-AUDIT AFTER FIX
============================================
echo "5️⃣  Re-running audit after fixes..."
echo ""
if npm audit --json > audit-report-after.json 2>&1; then
echo -e "{GREEN}✅ All vulnerabilities resolved!{NC}"
else
CRITICAL_AFTER=(cat audit-report-after.json | grep -o '"critical":[0-9]' || echo "0")HIGH_AFTER=(cat audit-report-after.json | grep -o '"high":[0-9]' | grep -o '[0-9]' || echo "0")
echo -e "${YELLOW}⚠️  Remaining vulnerabilities:${NC}"
echo "   🔴 Critical: $CRITICAL_AFTER"
echo "   🟠 High: $HIGH_AFTER"
echo ""

if [ "$CRITICAL_AFTER" -gt 0 ] || [ "$HIGH_AFTER" -gt 0 ]; then
    echo -e "${RED}🚨 CRITICAL: Manual intervention required!${NC}"
    echo ""
    echo "📋 Action Items:"
    echo "   1. Review: npm audit"
    echo "   2. Check: audit-report-after.json"
    echo "   3. Update manually: npm install package@latest"
    echo "   4. Or remove vulnerable package if unused"
    echo ""
fi
fi
============================================
6. CHECK SPECIFIC HIGH-RISK PACKAGES
============================================
echo "6️⃣  Checking high-risk packages..."
echo ""
HIGH_RISK_PACKAGES=(
"express"
"helmet"
"cors"
"jsonwebtoken"
"bcrypt"
"winston"
)
for package in "{HIGH_RISK_PACKAGES[@]}"; doCURRENT_VERSION=(npm list $package --depth=0 2>/dev/null | grep $package | grep -o '@[0-9.]*' | sed 's/@//' || echo "NOT INSTALLED")
if [ "$CURRENT_VERSION" != "NOT INSTALLED" ]; then
    echo "   ✅ $package@$CURRENT_VERSION"
else
    echo -e "   ${YELLOW}⚠️  $package: NOT INSTALLED${NC}"
fi
done
echo ""
============================================
7. GENERATE REPORT
============================================
echo "7️⃣  Generating audit report..."
echo ""
REPORT_FILE="security-audit-$(date +%Y%m%d-%H%M%S).txt"
cat > $REPORT_FILE <<EOF
Z-KINETIC SECURITY AUDIT REPORT
Date: $(date)
NPM Version: $NPM_VERSION
VULNERABILITIES BEFORE FIX:
Critical: $CRITICAL
High: $HIGH
Moderate: $MODERATE
Low: $LOW
VULNERABILITIES AFTER FIX:
Critical: ${CRITICAL_AFTER:-0}
High: ${HIGH_AFTER:-0}
OUTDATED PACKAGES:
$(npm outdated 2>/dev/null || echo "All packages up to date")
RECOMMENDATIONS:
Review audit-report-after.json for details
Update package.json with fixed versions
Run: npm ci (for clean install)
Test application thoroughly after updates
Commit updated package-lock.json
MANUAL CHECKS REQUIRED:
Check for deprecated packages: npm deprecate
Review GitHub security advisories
Test server startup: npm start
Run integration tests
EOF
echo "   📄 Report saved: $REPORT_FILE"
echo ""
============================================
8. CLEANUP
============================================
echo "8️⃣  Cleaning up..."
rm -f audit-report.json audit-report-after.json
echo "   ✅ Temporary files removed"
echo ""
============================================
9. FINAL SUMMARY
============================================
echo "================================"
echo "📊 AUDIT SUMMARY"
echo "================================"
if [ "CRITICAL_AFTER" == "0" ] && [ "{GREEN}✅ PASS: No critical vulnerabilities{NC}"
echo ""
echo "Next steps:"
echo "  1. Commit changes: git add package*.json"
echo "  2. Test server: npm start"
echo "  3. Deploy with confidence! 🚀"
exit 0
else
echo -e "{RED}❌ FAIL: Critical issues remain{NC}"
echo ""
echo "Required actions:"
echo "  1. Review: cat $REPORT_FILE"
echo "  2. Manual fixes needed"
echo "  3. Do NOT deploy until resolved"
exit 1
fi
