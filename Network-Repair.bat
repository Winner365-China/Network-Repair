@echo off
title Network Repair
setlocal enabledelayedexpansion

REM 请求管理员权限
>nul 2>&1 "%SYSTEMROOT%\System32\cacls.exe" "%SYSTEMROOT%\System32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 正在请求管理员权限...
    goto UACPrompt
) else ( goto start )


:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:start
cls
echo.
echo =====================================================
echo                                             Network Repair
echo                                                                           @Winner365
echo =====================================================
echo.
echo 步骤 1/3: 开始检测网络问题...
echo.

REM 定义问题列表和修复结果
set "problems="
set "fix_results="

REM 检测网络连接
call :Check_Connection
REM 检测DHCP服务
call :Check_DHCP
REM 检查DNS设置和可用性
call :Check_DNS
REM 检查防火墙
call :Check_Firewall
REM 检查IP冲突
call :Check_IPConflict

REM 显示问题列表
if defined problems (
    echo.
    echo =====================================================
    echo                检测到的网络问题
    echo =====================================================
    echo %problems%
    echo.
    echo 是否要修复所有问题？ (Y/N)
    choice /C YN /M "输入 Y 或 N"
    if %errorlevel% equ 1 (
        echo.
        echo 步骤 2/3: 正在尝试修复问题...
        echo.
        call :Fix_Problems
    ) else (
        echo 未选择修复，程序即将退出。
        pause
        exit /B
    )
) else (
    echo 没有检测到网络问题！
    pause
    exit /B
)

REM 显示修复结果
echo.
echo =====================================================
echo                     修复完成
echo =====================================================
echo %fix_results%
echo.
echo 按任意键退出...
pause
exit /B

REM 检测网络连接
:Check_Connection
    for /f %%i in ('powershell -Command "Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet"') do set "result=%%i"
    if "!result!" NEQ "True" (
        set "problems=!problems!1. 网络连接异常：无法访问外部网络（如 Google DNS）"
        echo [警告] 网络连接异常：无法访问外部网络（如 Google DNS）
    ) else (
        echo [正常] 网络连接正常
    )
exit /B

REM 检测DHCP服务
:Check_DHCP
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "Get-Service -Name Dhcp -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status"') do (
        set "status=%%i"
    )
    if not "!status!" == "Running" (
        set "problems=!problems!2. DHCP服务异常：DHCP客户端服务未运行"
        echo [警告] DHCP服务未运行（可能影响自动获取IP）
    ) else (
        echo [正常] DHCP服务已运行
    )
exit /B

REM 检查DNS设置和可用性
:Check_DNS
    REM 检查DNS是否配置
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "(Get-DnsClientServerAddress -InterfaceAlias '以太网' -AddressFamily IPv4).ServerAddresses"') do (
        set "dns=%%i"
    )
    if not defined dns (
        set "problems=!problems!3. DNS设置异常：未配置DNS服务器"
        echo [警告] DNS服务器未配置（可能导致无法解析网址）
    ) else (
        echo [正常] DNS服务器已配置为 %dns%
    )

    REM 检测关键域名的解析
    set "failed_domains="
    for %%d in (microsoft.com github.com baidu.com bing.com ubuntu.com) do (
        powershell -Command "$domain='%%d'; $ips=Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue; if ($ips -eq $null) { exit 1 } else { foreach ($ip in $ips.IPAddress) { if ($ip -match '^(127\.|10\.|172\.(1[6-9]|[2-9]\d|30|31)\.|192\.168\.)') { exit 2 } }; exit 0 }" >nul
        if !errorlevel! equ 1 (
            set "failed_domains=!failed_domains! %%d（无法解析）"
        ) else if !errorlevel! equ 2 (
            set "failed_domains=!failed_domains! %%d（解析到非法IP）"
        )
    )

    if defined failed_domains (
        set "problems=!problems!4. DNS解析异常：以下域名解析失败或结果异常"
        echo [警告] DNS解析异常：以下域名解析失败或结果异常
        echo   %failed_domains%
    ) else (
        echo [正常] 域名解析正常
    )
exit /B

REM 检查防火墙
:Check_Firewall
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "Get-NetFirewallProfile -Name Domain,Public,Private | Where-Object { $_.Enabled -eq 'True' } | Measure-Object | Select-Object -ExpandProperty Count"') do (
        set "count=%%i"
    )
    if !count! GEQ 1 (
        set "problems=!problems!5. 防火墙设置异常：防火墙可能阻止了连接"
        echo [警告] 防火墙处于启用状态（可能阻止部分网络访问）
    ) else (
        echo [正常] 防火墙未启用
    )
exit /B

REM 检查IP冲突
:Check_IPConflict
    for /f %%i in ('arp -a | find /i "duplicate"') do (
        if not "%%i" == "" (
            set "problems=!problems!6. IP地址冲突：检测到IP地址冲突"
            echo [警告] 检测到IP地址冲突（可能导致网络中断）
        )
    )
    if not defined problems echo [正常] 未检测到IP地址冲突
exit /B

REM 执行修复操作
:Fix_Problems
    REM 修复网络连接：启用适配器
    echo 正在启用网络适配器...
    powershell -Command "Get-NetAdapter | Where-Object { $_.Status -ne 'Up' } | Enable-NetAdapter" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? 网络适配器已成功启用"
        echo [成功] 网络适配器已启用
    ) else (
        set "fix_results=!fix_results!× 启用网络适配器失败"
        echo [失败] 启用网络适配器失败
    )

    REM 修复DHCP服务
    echo 正在启动DHCP客户端服务...
    powershell -Command "Start-Service -Name Dhcp" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? DHCP服务已启动"
        echo [成功] DHCP服务已启动
    ) else (
        set "fix_results=!fix_results!× 启动DHCP服务失败"
        echo [失败] 启动DHCP服务失败
    )

    REM 修复DNS设置：设置备用DNS（Google）
    echo 正在设置Google DNS服务器（8.8.8.8）...
    powershell -Command "Set-DnsClientServerAddress -InterfaceAlias '以太网' -ServerAddresses 8.8.8.8,8.8.4.4" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? DNS服务器已设置为Google DNS"
        echo [成功] DNS已设置为Google公共DNS
    ) else (
        set "fix_results=!fix_results!× 设置DNS失败"
        echo [失败] 设置DNS失败
    )

    REM 修复防火墙：临时禁用防火墙（需用户确认）
    echo.
    echo 正在检查防火墙设置...
    echo.
    echo 需要临时禁用防火墙以测试连接？（禁用后可能影响安全）
    echo 输入 Y 确认，或 N 跳过此步骤
    choice /C YN /M "输入 Y 或 N"
    if !errorlevel! equ 1 (
        powershell -Command "Set-NetFirewallProfile -Profile * -Enabled False" >nul
        if !errorlevel! equ 0 (
            set "fix_results=!fix_results!? 防火墙已临时禁用"
            echo [成功] 防火墙已临时禁用
        ) else (
            set "fix_results=!fix_results!× 禁用防火墙失败"
            echo [失败] 禁用防火墙失败
        )
    ) else (
        echo [跳过] 用户选择不修改防火墙设置
    )

    REM 修复IP冲突：重启网络适配器
    echo 正在重启网络适配器以解决IP冲突...
    powershell -Command "Restart-NetAdapter -Name '以太网'" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? 网络适配器已重启"
        echo [成功] 网络适配器已重启
    ) else (
        set "fix_results=!fix_results!× 重启适配器失败"
        echo [失败] 重启适配器失败
    )
exit /B