@echo off
title Network Repair
setlocal enabledelayedexpansion

REM �������ԱȨ��
>nul 2>&1 "%SYSTEMROOT%\System32\cacls.exe" "%SYSTEMROOT%\System32\config\system"
if '%errorlevel%' NEQ '0' (
    echo �����������ԱȨ��...
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
echo ���� 1/3: ��ʼ�����������...
echo.

REM ���������б���޸����
set "problems="
set "fix_results="

REM �����������
call :Check_Connection
REM ���DHCP����
call :Check_DHCP
REM ���DNS���úͿ�����
call :Check_DNS
REM ������ǽ
call :Check_Firewall
REM ���IP��ͻ
call :Check_IPConflict

REM ��ʾ�����б�
if defined problems (
    echo.
    echo =====================================================
    echo                ��⵽����������
    echo =====================================================
    echo %problems%
    echo.
    echo �Ƿ�Ҫ�޸��������⣿ (Y/N)
    choice /C YN /M "���� Y �� N"
    if %errorlevel% equ 1 (
        echo.
        echo ���� 2/3: ���ڳ����޸�����...
        echo.
        call :Fix_Problems
    ) else (
        echo δѡ���޸������򼴽��˳���
        pause
        exit /B
    )
) else (
    echo û�м�⵽�������⣡
    pause
    exit /B
)

REM ��ʾ�޸����
echo.
echo =====================================================
echo                     �޸����
echo =====================================================
echo %fix_results%
echo.
echo ��������˳�...
pause
exit /B

REM �����������
:Check_Connection
    for /f %%i in ('powershell -Command "Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet"') do set "result=%%i"
    if "!result!" NEQ "True" (
        set "problems=!problems!1. ���������쳣���޷������ⲿ���磨�� Google DNS��"
        echo [����] ���������쳣���޷������ⲿ���磨�� Google DNS��
    ) else (
        echo [����] ������������
    )
exit /B

REM ���DHCP����
:Check_DHCP
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "Get-Service -Name Dhcp -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status"') do (
        set "status=%%i"
    )
    if not "!status!" == "Running" (
        set "problems=!problems!2. DHCP�����쳣��DHCP�ͻ��˷���δ����"
        echo [����] DHCP����δ���У�����Ӱ���Զ���ȡIP��
    ) else (
        echo [����] DHCP����������
    )
exit /B

REM ���DNS���úͿ�����
:Check_DNS
    REM ���DNS�Ƿ�����
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "(Get-DnsClientServerAddress -InterfaceAlias '��̫��' -AddressFamily IPv4).ServerAddresses"') do (
        set "dns=%%i"
    )
    if not defined dns (
        set "problems=!problems!3. DNS�����쳣��δ����DNS������"
        echo [����] DNS������δ���ã����ܵ����޷�������ַ��
    ) else (
        echo [����] DNS������������Ϊ %dns%
    )

    REM ���ؼ������Ľ���
    set "failed_domains="
    for %%d in (microsoft.com github.com baidu.com bing.com ubuntu.com) do (
        powershell -Command "$domain='%%d'; $ips=Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue; if ($ips -eq $null) { exit 1 } else { foreach ($ip in $ips.IPAddress) { if ($ip -match '^(127\.|10\.|172\.(1[6-9]|[2-9]\d|30|31)\.|192\.168\.)') { exit 2 } }; exit 0 }" >nul
        if !errorlevel! equ 1 (
            set "failed_domains=!failed_domains! %%d���޷�������"
        ) else if !errorlevel! equ 2 (
            set "failed_domains=!failed_domains! %%d���������Ƿ�IP��"
        )
    )

    if defined failed_domains (
        set "problems=!problems!4. DNS�����쳣��������������ʧ�ܻ����쳣"
        echo [����] DNS�����쳣��������������ʧ�ܻ����쳣
        echo   %failed_domains%
    ) else (
        echo [����] ������������
    )
exit /B

REM ������ǽ
:Check_Firewall
    for /f "tokens=2 delims=:" %%i in ('powershell -Command "Get-NetFirewallProfile -Name Domain,Public,Private | Where-Object { $_.Enabled -eq 'True' } | Measure-Object | Select-Object -ExpandProperty Count"') do (
        set "count=%%i"
    )
    if !count! GEQ 1 (
        set "problems=!problems!5. ����ǽ�����쳣������ǽ������ֹ������"
        echo [����] ����ǽ��������״̬��������ֹ����������ʣ�
    ) else (
        echo [����] ����ǽδ����
    )
exit /B

REM ���IP��ͻ
:Check_IPConflict
    for /f %%i in ('arp -a | find /i "duplicate"') do (
        if not "%%i" == "" (
            set "problems=!problems!6. IP��ַ��ͻ����⵽IP��ַ��ͻ"
            echo [����] ��⵽IP��ַ��ͻ�����ܵ��������жϣ�
        )
    )
    if not defined problems echo [����] δ��⵽IP��ַ��ͻ
exit /B

REM ִ���޸�����
:Fix_Problems
    REM �޸��������ӣ�����������
    echo ������������������...
    powershell -Command "Get-NetAdapter | Where-Object { $_.Status -ne 'Up' } | Enable-NetAdapter" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? �����������ѳɹ�����"
        echo [�ɹ�] ����������������
    ) else (
        set "fix_results=!fix_results!�� ��������������ʧ��"
        echo [ʧ��] ��������������ʧ��
    )

    REM �޸�DHCP����
    echo ��������DHCP�ͻ��˷���...
    powershell -Command "Start-Service -Name Dhcp" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? DHCP����������"
        echo [�ɹ�] DHCP����������
    ) else (
        set "fix_results=!fix_results!�� ����DHCP����ʧ��"
        echo [ʧ��] ����DHCP����ʧ��
    )

    REM �޸�DNS���ã����ñ���DNS��Google��
    echo ��������Google DNS��������8.8.8.8��...
    powershell -Command "Set-DnsClientServerAddress -InterfaceAlias '��̫��' -ServerAddresses 8.8.8.8,8.8.4.4" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? DNS������������ΪGoogle DNS"
        echo [�ɹ�] DNS������ΪGoogle����DNS
    ) else (
        set "fix_results=!fix_results!�� ����DNSʧ��"
        echo [ʧ��] ����DNSʧ��
    )

    REM �޸�����ǽ����ʱ���÷���ǽ�����û�ȷ�ϣ�
    echo.
    echo ���ڼ�����ǽ����...
    echo.
    echo ��Ҫ��ʱ���÷���ǽ�Բ������ӣ������ú����Ӱ�찲ȫ��
    echo ���� Y ȷ�ϣ��� N �����˲���
    choice /C YN /M "���� Y �� N"
    if !errorlevel! equ 1 (
        powershell -Command "Set-NetFirewallProfile -Profile * -Enabled False" >nul
        if !errorlevel! equ 0 (
            set "fix_results=!fix_results!? ����ǽ����ʱ����"
            echo [�ɹ�] ����ǽ����ʱ����
        ) else (
            set "fix_results=!fix_results!�� ���÷���ǽʧ��"
            echo [ʧ��] ���÷���ǽʧ��
        )
    ) else (
        echo [����] �û�ѡ���޸ķ���ǽ����
    )

    REM �޸�IP��ͻ����������������
    echo �������������������Խ��IP��ͻ...
    powershell -Command "Restart-NetAdapter -Name '��̫��'" >nul
    if !errorlevel! equ 0 (
        set "fix_results=!fix_results!? ����������������"
        echo [�ɹ�] ����������������
    ) else (
        set "fix_results=!fix_results!�� ����������ʧ��"
        echo [ʧ��] ����������ʧ��
    )
exit /B