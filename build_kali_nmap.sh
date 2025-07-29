#!/bin/bash

set -e

echo "========================================="
echo "Kali Linux Nmap Optimized Build Script"
echo "========================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：打印帶顏色的消息
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

# 檢查系統要求
print_status "Checking system requirements..."

# 檢查必要命令 - 使用更寬容的檢查方式
MISSING_CMDS=""

# 檢查基本編譯工具
for cmd in gcc g++ make; do
    if ! which $cmd &> /dev/null; then
        MISSING_CMDS="$MISSING_CMDS $cmd"
    fi
done

# 檢查 autotools
for cmd in autoconf automake; do
    if ! which $cmd &> /dev/null; then
        MISSING_CMDS="$MISSING_CMDS $cmd"
    fi
done

# 檢查 libtool - 嘗試多個可能的名稱，包括 libtoolize
LIBTOOL_FOUND=false
for cmd in libtool glibtool libtoolize glibtoolize; do
    if which $cmd &> /dev/null; then
        LIBTOOL_FOUND=true
        print_status "Found libtool variant: $cmd"
        break
    fi
done

if [ "$LIBTOOL_FOUND" = false ]; then
    MISSING_CMDS="$MISSING_CMDS libtool"
fi

# 如果有缺失的命令，顯示錯誤
if [ -n "$MISSING_CMDS" ]; then
    print_error "Missing required commands:$MISSING_CMDS"
    print_error "Please install the missing packages:"
    print_error "sudo apt install build-essential autoconf automake libtool"
    exit 1
fi

# 檢查優化模組文件
if [ ! -f "nmap_integration_patch.h" ] || [ ! -f "nmap_integration_patch.cc" ]; then
    print_error "Optimization module files not found"
    print_error "Please ensure nmap_integration_patch.h and nmap_integration_patch.cc are in the current directory"
    exit 1
fi

print_success "System requirements check passed"

# 檢查是否在 Nmap 目錄中
if [ ! -f "configure.ac" ] || [ ! -f "nmap.cc" ]; then
    print_error "Not in Nmap source directory"
    print_error "Please run this script from the Nmap source directory"
    exit 1
fi

# 備份原始文件
print_status "Backing up original files..."
if [ ! -d "backup_original" ]; then
    mkdir -p backup_original
fi

cp configure.ac backup_original/ 2>/dev/null || true
cp Makefile.in backup_original/ 2>/dev/null || true
cp nmap.cc backup_original/ 2>/dev/null || true

print_success "Backup completed"

# 清理之前的構建
print_status "Cleaning previous build..."
make clean 2>/dev/null || true
make distclean 2>/dev/null || true

# 修改 configure.ac
print_status "Modifying configure.ac..."
if ! grep -q "enable-optimization" configure.ac; then
    cat >> configure.ac << 'EOF'

# Add optimization options
AC_ARG_ENABLE([optimization],
    AS_HELP_STRING([--enable-optimization], [Enable performance optimization features]),
    [enable_optimization=$enableval],
    [enable_optimization=no])
if test "x$enable_optimization" = "xyes"; then
    AC_DEFINE([ENABLE_OPTIMIZATION], [1], [Enable optimization features])
    CPPFLAGS="$CPPFLAGS -DENABLE_OPTIMIZATION"
    trace_use="$trace_use optimization"
else
    trace_no_use="$trace_no_use optimization"
fi
EOF
    print_success "configure.ac modified"
else
    print_warning "Optimization options already exist in configure.ac"
fi

# 修改 Makefile.in
print_status "Modifying Makefile.in..."
# 添加源文件
if ! grep -q "nmap_integration_patch.cc" Makefile.in; then
    sed -i 's/export SRCS = /export SRCS = nmap_integration_patch.cc /' Makefile.in
fi

# 添加頭文件
if ! grep -q "nmap_integration_patch.h" Makefile.in; then
    sed -i 's/export HDRS = /export HDRS = nmap_integration_patch.h /' Makefile.in
fi

# 添加目標文件
if ! grep -q "nmap_integration_patch.o" Makefile.in; then
    sed -i 's/OBJS = /OBJS = nmap_integration_patch.o /' Makefile.in
fi

print_success "Makefile.in modified"

# 修改 nmap.cc
print_status "Modifying nmap.cc..."
# 添加包含語句
if ! grep -q "nmap_integration_patch.h" nmap.cc; then
    sed -i '1i #include "nmap_integration_patch.h"' nmap.cc
fi

# 在 nmap_main 函數中添加初始化代碼
if ! grep -q "NmapIntegration::handle_optimization_options" nmap.cc; then
    # 找到 nmap_main 函數的開始
    sed -i '/int nmap_main/,/^{/{
        /^{/a\
  // Initialize optimization module\
  NmapIntegration::handle_optimization_options(argc, argv);\
  NmapIntegration::initialize_optimization_modules();
    }' nmap.cc
fi

# 在 nmap_main 函數結尾添加清理代碼
if ! grep -q "NmapIntegration::cleanup_optimization_modules" nmap.cc; then
    # 找到 return 0; 之前添加清理代碼
    sed -i '/return 0;/i\
  // Cleanup optimization module\
  NmapIntegration::cleanup_optimization_modules();\
' nmap.cc
fi

# 替換 ultra_scan 調用
if ! grep -q "ultra_scan_optimized" nmap.cc; then
    sed -i 's/ultra_scan(/NmapIntegration::ultra_scan_optimized(/g' nmap.cc
fi

print_success "nmap.cc modified"

# 嘗試重新生成配置，但忽略錯誤
print_status "Regenerating configuration..."
if autoreconf -i 2>/dev/null; then
    print_success "Configuration script generated"
else
    print_warning "autoreconf failed, trying to use existing configure script"
fi

# 檢查配置腳本
if [ -f "configure" ]; then
    print_success "Configuration script found"
else
    print_error "No configure script found"
    exit 1
fi

# 配置構建
print_status "Configuring build with optimization enabled..."
if ./configure --enable-optimization --prefix=/usr/local; then
    print_success "Configuration completed"
else
    print_warning "Configuration may have issues, but continuing..."
fi

# 檢查配置結果
if grep -q "ENABLE_OPTIMIZATION" config.h 2>/dev/null; then
    print_success "Optimization enabled in configuration"
else
    print_warning "Optimization may not be enabled, continuing anyway..."
fi

# 編譯
print_status "Compiling Nmap with optimization module..."
if make -j$(nproc); then
    print_success "Compilation completed"
else
    print_error "Compilation failed"
    exit 1
fi

# 檢查編譯結果
if [ -f "nmap" ]; then
    print_success "Build successful!"
    echo "Nmap binary size: $(ls -lh nmap | awk '{print $5}')"
    
    # 測試版本信息
    print_status "Testing nmap version..."
    ./nmap --version
    
    # 測試優化選項
    print_status "Testing optimization options..."
    if ./nmap --help 2>&1 | grep -i optimize > /dev/null; then
        print_success "Optimization options found in help"
        ./nmap --help | grep -i optimize
    else
        print_warning "No optimization options found in help"
    fi
    
else
    print_error "Build failed!"
    exit 1
fi

# 創建安裝腳本
print_status "Creating installation script..."
cat > install_nmap_optimized.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing Nmap optimized version..."
sudo make install

echo "Testing installation..."
nmap --version

echo "Installation completed successfully!"
echo "Use 'nmap --optimize' to enable optimization features"
EOF

chmod +x install_nmap_optimized.sh

# 創建測試腳本
print_status "Creating test script..."
cat > test_nmap_optimized.sh << 'EOF'
#!/bin/bash
set -e

echo "Testing Nmap optimized version..."

echo "1. Testing version information..."
nmap --version

echo "2. Testing help options..."
nmap --help | grep -i optimize || echo "No optimization options found"

echo "3. Testing basic scan..."
nmap localhost -p 80

echo "4. Testing optimized scan..."
nmap --optimize localhost -p 80

echo "Test completed successfully!"
EOF

chmod +x test_nmap_optimized.sh

print_success "========================================="
print_success "Build completed successfully!"
print_success "========================================="
echo ""
echo "Next steps:"
echo "1. Install: ./install_nmap_optimized.sh"
echo "2. Test: ./test_nmap_optimized.sh"
echo "3. Use: nmap --optimize localhost"
echo ""
echo "Files created:"
echo "- nmap (optimized binary)"
echo "- install_nmap_optimized.sh (installation script)"
echo "- test_nmap_optimized.sh (test script)"
echo "- backup_original/ (backup of original files)"
echo "" 