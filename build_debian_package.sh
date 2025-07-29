#!/bin/bash

set -e

echo "========================================="
echo "Debian Package Build Script for Nmap Optimized"
echo "========================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查是否已經構建了 nmap
if [ ! -f "nmap" ]; then
    print_error "Nmap binary not found. Please run build_kali_nmap.sh first."
    exit 1
fi

# 檢查 dpkg-deb 命令
if ! command -v dpkg-deb &> /dev/null; then
    print_error "dpkg-deb not found. Please install dpkg-dev"
    exit 1
fi

print_status "Creating Debian package structure..."

# 創建 debian 目錄結構
rm -rf debian
mkdir -p debian/DEBIAN
mkdir -p debian/usr/local/bin
mkdir -p debian/usr/local/share/man/man1
mkdir -p debian/usr/local/share/nmap

# 創建控制文件
cat > debian/DEBIAN/control << EOF
Package: nmap-optimized
Version: 7.96-optimized
Architecture: amd64
Maintainer: Nmap Optimized Team <nmap-optimized@example.com>
Depends: libc6 (>= 2.17), libpcap0.8 (>= 1.5.1), libssl3 (>= 3.0.0), zlib1g (>= 1:1.2.0)
Recommends: libpcre3
Suggests: nmap-scripts
Description: Nmap with performance optimization features
 This package contains Nmap with integrated performance
 optimization modules for faster network scanning.
 .
 Features:
 - Multi-threaded scanning with configurable worker threads
 - Adaptive timeout mechanisms for better performance
 - Performance monitoring and reporting
 - Backward compatibility with standard Nmap
 - Support for all standard Nmap scan types
 .
 This optimized version provides significant performance
 improvements while maintaining full compatibility with
 the original Nmap functionality.
 .
 Use 'nmap --optimize' to enable optimization features.
EOF

# 創建安裝後腳本
cat > debian/DEBIAN/postinst << 'EOF'
#!/bin/bash
set -e

echo "Nmap optimized version installed successfully!"
echo ""
echo "Features available:"
echo "- Use 'nmap --optimize' to enable optimization"
echo "- Use 'nmap --parallel-workers N' to set worker threads"
echo "- Use 'nmap --performance-monitoring' for detailed metrics"
echo ""
echo "Example usage:"
echo "  nmap --optimize localhost"
echo "  nmap --optimize --parallel-workers 16 192.168.1.0/24"
echo "  nmap --optimize --performance-monitoring -p 1-1000 localhost"
echo ""

# 更新 man 頁面緩存
if command -v mandb &> /dev/null; then
    mandb -q /usr/local/share/man 2>/dev/null || true
fi

exit 0
EOF

chmod +x debian/DEBIAN/postinst

# 創建卸載前腳本
cat > debian/DEBIAN/prerm << 'EOF'
#!/bin/bash
set -e

echo "Removing Nmap optimized version..."

# 檢查是否有其他 nmap 版本
if [ -f "/usr/bin/nmap" ]; then
    echo "Standard Nmap found at /usr/bin/nmap"
    echo "This optimized version will be removed, but standard Nmap remains."
fi

exit 0
EOF

chmod +x debian/DEBIAN/prerm

# 創建卸載後腳本
cat > debian/DEBIAN/postrm << 'EOF'
#!/bin/bash
set -e

echo "Nmap optimized version removed successfully!"

# 更新 man 頁面緩存
if command -v mandb &> /dev/null; then
    mandb -q /usr/local/share/man 2>/dev/null || true
fi

exit 0
EOF

chmod +x debian/DEBIAN/postrm

print_status "Installing Nmap to package directory..."

# 安裝 nmap 到 debian 目錄
sudo make install DESTDIR=./debian

# 檢查安裝結果
if [ -f "debian/usr/local/bin/nmap" ]; then
    print_success "Nmap installed to package directory"
else
    print_error "Failed to install Nmap to package directory"
    exit 1
fi

# 創建符號連結到 /usr/bin
mkdir -p debian/usr/bin
ln -sf /usr/local/bin/nmap debian/usr/bin/nmap-optimized

# 創建 man 頁面
print_status "Creating man page..."
mkdir -p debian/usr/local/share/man/man1

cat > debian/usr/local/share/man/man1/nmap-optimized.1 << 'EOF'
.TH NMAP-OPTIMIZED 1 "2024" "Nmap Optimized" "User Commands"
.SH NAME
nmap-optimized \- Network exploration tool with performance optimizations
.SH SYNOPSIS
.B nmap-optimized
[\fIOPTIONS\fR] \fITARGET\fR
.SH DESCRIPTION
Nmap-optimized is an enhanced version of Nmap with integrated performance
optimization modules for faster network scanning.
.SH OPTIMIZATION OPTIONS
.TP
.B \-\-optimize
Enable performance optimization features
.TP
.B \-\-parallel-workers \fIN\fR
Set number of parallel worker threads (default: 8)
.TP
.B \-\-performance-monitoring
Enable detailed performance monitoring and reporting
.TP
.B \-\-adaptive-timeout-factor \fIFACTOR\fR
Set adaptive timeout factor (default: 0.8)
.SH EXAMPLES
.TP
Basic optimized scan:
.B nmap-optimized \-\-optimize localhost
.TP
High-performance scan with custom workers:
.B nmap-optimized \-\-optimize \-\-parallel-workers 16 192.168.1.0/24
.TP
Performance monitoring scan:
.B nmap-optimized \-\-optimize \-\-performance-monitoring \-p 1-1000 localhost
.SH SEE ALSO
nmap(1), nmap-scripts(1)
.SH AUTHOR
Nmap Optimized Team
.SH VERSION
7.96-optimized
EOF

# 複製標準 man 頁面
if [ -f "nmap.1" ]; then
    cp nmap.1 debian/usr/local/share/man/man1/
fi

print_status "Building Debian package..."

# 構建 deb 套件
PACKAGE_NAME="nmap-optimized_7.96-optimized_amd64.deb"
dpkg-deb --build debian "$PACKAGE_NAME"

# 檢查構建結果
if [ -f "$PACKAGE_NAME" ]; then
    print_success "Debian package created: $PACKAGE_NAME"
    echo "Package size: $(ls -lh "$PACKAGE_NAME" | awk '{print $5}')"
    
    # 顯示包信息
    print_status "Package information:"
    dpkg-deb -I "$PACKAGE_NAME"
    
    # 創建安裝腳本
    cat > install_package.sh << EOF
#!/bin/bash
set -e

echo "Installing Nmap optimized package..."
sudo dpkg -i "$PACKAGE_NAME"

# 修復依賴問題
sudo apt-get install -f

echo "Installation completed!"
echo "Test with: nmap-optimized --optimize localhost"
EOF

    chmod +x install_package.sh
    
    # 創建測試腳本
    cat > test_package.sh << 'EOF'
#!/bin/bash
set -e

echo "Testing Nmap optimized package..."

echo "1. Testing version..."
nmap-optimized --version

echo "2. Testing help..."
nmap-optimized --help | grep -i optimize

echo "3. Testing basic scan..."
nmap-optimized localhost -p 80

echo "4. Testing optimized scan..."
nmap-optimized --optimize localhost -p 80

echo "Test completed successfully!"
EOF

    chmod +x test_package.sh
    
    print_success "========================================="
    print_success "Debian package build completed!"
    print_success "========================================="
    echo ""
    echo "Files created:"
    echo "- $PACKAGE_NAME (Debian package)"
    echo "- install_package.sh (installation script)"
    echo "- test_package.sh (test script)"
    echo ""
    echo "To install: ./install_package.sh"
    echo "To test: ./test_package.sh"
    echo ""
    echo "Package can be distributed and installed on any Debian-based system"
    echo "including Kali Linux, Ubuntu, Debian, etc."
    echo ""
    
else
    print_error "Failed to create Debian package"
    exit 1
fi 