# Script kiểm tra Share Extension trên Windows
# Chạy: powershell -File check_share_extension.ps1

Write-Host "=== KIỂM TRA SHARE EXTENSION ===" -ForegroundColor Cyan
Write-Host ""

# 1. Kiểm tra thư mục Share Extension
Write-Host "1. Kiểm tra thư mục Share Extension:" -ForegroundColor Yellow
if (Test-Path "ios\Share Extension") {
    Write-Host "   ✅ Thư mục 'Share Extension' tồn tại" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Danh sách files:" -ForegroundColor White
    Get-ChildItem "ios\Share Extension" | ForEach-Object {
        Write-Host "   - $($_.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "   ❌ Thư mục 'Share Extension' KHÔNG tồn tại!" -ForegroundColor Red
}
Write-Host ""

# 2. Kiểm tra các file quan trọng
Write-Host "2. Kiểm tra các file cần thiết:" -ForegroundColor Yellow

$files = @(
    "ios\Share Extension\ShareViewController.swift",
    "ios\Share Extension\Info.plist",
    "ios\Share Extension\Share Extension.entitlements"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $size = (Get-Item $file).Length
        Write-Host "   ✅ $file ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $file - THIẾU!" -ForegroundColor Red
    }
}
Write-Host ""

# 3. Kiểm tra references trong project.pbxproj
Write-Host "3. Kiểm tra references trong project.pbxproj:" -ForegroundColor Yellow

$pbxproj = "ios\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbxproj) {
    $content = Get-Content $pbxproj -Raw
    
    # Check ShareViewController
    if ($content -match "ShareViewController.swift") {
        Write-Host "   ✅ ShareViewController.swift được reference" -ForegroundColor Green
    } else {
        Write-Host "   ❌ ShareViewController.swift KHÔNG được reference" -ForegroundColor Red
    }
    
    # Check Info.plist
    if ($content -match "Share Extension.*Info.plist") {
        Write-Host "   ✅ Info.plist được reference" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Info.plist KHÔNG được reference" -ForegroundColor Red
    }
    
    # Check entitlements
    if ($content -match "Share Extension.entitlements") {
        Write-Host "   ✅ Share Extension.entitlements được reference" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Share Extension.entitlements KHÔNG được reference" -ForegroundColor Red
    }
    
    # Check Share Extension target
    if ($content -match "8072EBC72B6191600035633A.*Share Extension") {
        Write-Host "   ✅ Share Extension target tồn tại" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Share Extension target KHÔNG tồn tại" -ForegroundColor Red
    }
    
} else {
    Write-Host "   ❌ project.pbxproj KHÔNG tồn tại!" -ForegroundColor Red
}
Write-Host ""

# 4. Kiểm tra Podfile
Write-Host "4. Kiểm tra Podfile:" -ForegroundColor Yellow
if (Test-Path "ios\Podfile") {
    $podfile = Get-Content "ios\Podfile" -Raw
    if ($podfile -match "Share Extension") {
        Write-Host "   ✅ Podfile có khai báo Share Extension" -ForegroundColor Green
        
        # Check cấu trúc
        if ($podfile -match "target 'Runner'.*target 'Share Extension'") {
            Write-Host "   ✅ Share Extension NESTED trong Runner (đúng)" -ForegroundColor Green
        } elseif ($podfile -match "target 'Share Extension'") {
            Write-Host "   ⚠️  Share Extension có thể ở NGOÀI Runner" -ForegroundColor Yellow
        }
        
        # Check inherit
        if ($podfile -match "inherit!.*:complete") {
            Write-Host "   ✅ Dùng inherit! :complete (đúng)" -ForegroundColor Green
        } elseif ($podfile -match "inherit!.*:search_paths") {
            Write-Host "   ⚠️  Dùng inherit! :search_paths (có thể sai)" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "   ⚠️  Podfile KHÔNG có khai báo Share Extension" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Podfile KHÔNG tồn tại!" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== KẾT THÚC KIỂM TRA ===" -ForegroundColor Cyan