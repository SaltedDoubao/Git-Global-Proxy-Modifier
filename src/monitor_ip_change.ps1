Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 创建主窗口
$form = New-Object System.Windows.Forms.Form
$form.Text = "Git 代理 IP 监视器"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
#$form.Icon = [System.Drawing.SystemIcons]::Application
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot/../res/icon.ico")
$form.ShowInTaskbar = $true

# 创建系统托盘图标
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
#$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot/../res/icon.ico")
$notifyIcon.Text = "Git 代理 IP 监视器"
$notifyIcon.Visible = $true

# 创建托盘图标右键菜单
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showMenuItem.Text = "显示窗口"
$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "退出"
$contextMenu.Items.Add($showMenuItem)
$contextMenu.Items.Add($exitMenuItem)
$notifyIcon.ContextMenuStrip = $contextMenu

# 创建状态显示器
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 10)
$statusLabel.Size = New-Object System.Drawing.Size(380, 20)
$statusLabel.Text = "等待检测 IP 地址变化..."
$form.Controls.Add($statusLabel)

# 创建当前IP显示器
$currentIPLabel = New-Object System.Windows.Forms.Label
$currentIPLabel.Location = New-Object System.Drawing.Point(10, 40)
$currentIPLabel.Size = New-Object System.Drawing.Size(380, 20)
$currentIPLabel.Text = "当前 IP: 未知"
$form.Controls.Add($currentIPLabel)

# 创建网络适配器显示器
$adapterLabel = New-Object System.Windows.Forms.Label
$adapterLabel.Location = New-Object System.Drawing.Point(10, 60)
$adapterLabel.Size = New-Object System.Drawing.Size(380, 20)
$adapterLabel.Text = "网络适配器: 未知"
$form.Controls.Add($adapterLabel)

# 创建端口输入框
$portLabel = New-Object System.Windows.Forms.Label
$portLabel.Location = New-Object System.Drawing.Point(10, 90)
$portLabel.Size = New-Object System.Drawing.Size(80, 20)
$portLabel.Text = "代理端口:"
$form.Controls.Add($portLabel)

$portTextBox = New-Object System.Windows.Forms.TextBox
$portTextBox.Location = New-Object System.Drawing.Point(90, 90)
$portTextBox.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($portTextBox)

# 创建保存端口按钮
$savePortButton = New-Object System.Windows.Forms.Button
$savePortButton.Location = New-Object System.Drawing.Point(200, 90)
$savePortButton.Size = New-Object System.Drawing.Size(80, 20)
$savePortButton.Text = "保存端口"
$form.Controls.Add($savePortButton)

# 创建日志文本框
$logTextBox = New-Object System.Windows.Forms.TextBox
$logTextBox.Location = New-Object System.Drawing.Point(10, 120)
$logTextBox.Size = New-Object System.Drawing.Size(370, 100)
$logTextBox.Multiline = $true
$logTextBox.ReadOnly = $true
$logTextBox.ScrollBars = "Vertical"
$form.Controls.Add($logTextBox)

# 创建开始/停止按钮
$startStopButton = New-Object System.Windows.Forms.Button
$startStopButton.Location = New-Object System.Drawing.Point(10, 230)
$startStopButton.Size = New-Object System.Drawing.Size(180, 30)
$startStopButton.Text = "开始监控"
$form.Controls.Add($startStopButton)

# 创建退出按钮
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(200, 230)
$exitButton.Size = New-Object System.Drawing.Size(180, 30)
$exitButton.Text = "退出"
$form.Controls.Add($exitButton)

# 全局变量
$global:isMonitoring = $false
$global:lastIP = ""
$global:eventJob = $null
$global:currentPort = "7890"

# 自定义日志函数
function Add-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    $logTextBox.AppendText("$logMessage`r`n")
    # 滚动到底部
    $logTextBox.SelectionStart = $logTextBox.Text.Length
    $logTextBox.ScrollToCaret()
}

# 获取脚本所在目录
$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
# 设置配置文件路径
$configPath = Join-Path -Path $scriptPath -ChildPath "..\config"
$portFilePath = Join-Path -Path $configPath -ChildPath "proxy_port.txt"
$ipFilePath = Join-Path -Path $configPath -ChildPath "last_ip.txt"

# 初始化端口
function Initialize-Port {
    if (Test-Path $portFilePath) {
        try {
            $global:currentPort = Get-Content $portFilePath -Raw
            $global:currentPort = $global:currentPort.Trim()
            $portTextBox.Text = $global:currentPort
        }
        catch {
            $portTextBox.Text = "7890"
            $global:currentPort = "7890"
            Add-Log "无法读取端口文件，使用默认端口7890"
        }
    }
    else {
        $portTextBox.Text = "7890"
        $global:currentPort = "7890"
        # 创建默认配置目录和文件
        if (-not (Test-Path $configPath)) {
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
        }
        $global:currentPort | Out-File $portFilePath -NoNewline
        Add-Log "已创建默认配置文件"
    }
}

# 检测当前IP并显示
function Get-CurrentIP {
    # 获取允许外部连接的IPv4地址
    # 优先获取拥有默认网关的接口，通常是主要网络连接
    $defaultRouteInterface = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | 
                             Select-Object -ExpandProperty InterfaceIndex -First 1
    
    if ($defaultRouteInterface) {
        # 使用默认路由的接口获取IP
        $ip = (Get-NetIPAddress -InterfaceIndex $defaultRouteInterface -AddressFamily IPv4).IPAddress
        $adapterName = (Get-NetAdapter -InterfaceIndex $defaultRouteInterface | Select-Object -ExpandProperty Name)
        $adapterLabel.Text = "网络适配器: $adapterName (默认路由)"
        Add-Log "找到默认路由接口: $adapterName"
    } else {
        # 备选方案: 尝试获取有线连接的适配器
        $connectedAdapter = Get-NetAdapter | Where-Object {
            $_.Status -eq 'Up' -and 
            $_.PhysicalMediaType -ne 'Unspecified' -and
            $_.PhysicalMediaType -notmatch 'Wireless' -and
            $_.InterfaceDescription -notmatch 'Virtual|VPN|TAP|Tunnel'
        } | Select-Object -First 1
        
        if ($connectedAdapter) {
            $ip = (Get-NetIPAddress -InterfaceIndex $connectedAdapter.ifIndex -AddressFamily IPv4).IPAddress
            $adapterName = $connectedAdapter.Name
            $adapterLabel.Text = "网络适配器: $adapterName (有线)"
            Add-Log "找到有线网络适配器: $adapterName"
        } else {
            # 第三个选项：获取无线网卡
            $wirelessAdapter = Get-NetAdapter | Where-Object {
                $_.Status -eq 'Up' -and 
                $_.PhysicalMediaType -match 'Wireless'
            } | Select-Object -First 1
            
            if ($wirelessAdapter) {
                $ip = (Get-NetIPAddress -InterfaceIndex $wirelessAdapter.ifIndex -AddressFamily IPv4).IPAddress
                $adapterName = $wirelessAdapter.Name
                $adapterLabel.Text = "网络适配器: $adapterName (无线)"
                Add-Log "找到无线网络适配器: $adapterName"
            } else {
                # 最后方案：使用之前的过滤方法
                $ip = (Get-NetIPAddress | Where-Object {
                    $_.AddressFamily -eq 'IPv4' -and 
                    $_.InterfaceAlias -notmatch 'Loopback' -and 
                    $_.IPAddress -notmatch '^169\.254\.' -and
                    $_.IPAddress -notmatch '^0\.' -and
                    $_.IPAddress -notmatch '^172\.(1[6-9]|2[0-9]|3[0-1])\.' -and
                    $_.IPAddress -notmatch '^10\.' -and
                    $_.IPAddress -notmatch '^192\.168\.'
                }).IPAddress | Select-Object -First 1
                
                if ($ip) {
                    $adapterLabel.Text = "网络适配器: 未知 (外部IP)"
                    Add-Log "找到外部IP地址"
                } else {
                    # 如果外部IP没找到，就回到尝试寻找合适的内网IP
                    $ip = (Get-NetIPAddress | Where-Object {
                        $_.AddressFamily -eq 'IPv4' -and 
                        $_.InterfaceAlias -notmatch 'Loopback' -and 
                        $_.IPAddress -notmatch '^169\.254\.' -and
                        $_.IPAddress -notmatch '^0\.'
                    }).IPAddress | Select-Object -First 1
                    $adapterLabel.Text = "网络适配器: 未知 (内部IP)"
                    Add-Log "使用备选方案找到IP地址"
                }
            }
        }
    }

    if ($ip) {
        $currentIPLabel.Text = "当前 IP: $ip"
        Add-Log "确定当前的IP地址为: $ip"
        return $ip
    }
    else {
        $currentIPLabel.Text = "当前 IP: 未知"
        $adapterLabel.Text = "网络适配器: 未找到"
        Add-Log "无法确定有效的网络IP地址"
        return $null
    }
}

# 更新Git代理设置
function Update-GitProxy {
    param ([string]$ip)
    
    if (-not $ip) {
        Add-Log "IP地址为空，无法更新Git代理"
        return
    }
    
    try {
        git config --global http.proxy "http://${ip}:${global:currentPort}"
        git config --global https.proxy "http://${ip}:${global:currentPort}"
        Add-Log "Git代理已更新为: http://${ip}:${global:currentPort}"
        
        # 保存上次IP
        $ip | Out-File "last_ip.txt" -NoNewline
        $global:lastIP = $ip
    }
    catch {
        Add-Log "更新Git代理失败: $_"
    }
}

# 开始监控功能
function Start-Monitoring {
    if ($global:isMonitoring) {
        Add-Log "已经在监控中..."
        return
    }
    
    $global:isMonitoring = $true
    $startStopButton.Text = "停止监控"
    $statusLabel.Text = "正在监控 IP 地址变化..."
    Add-Log "开始监控 IP 地址变化"
    
    # 获取上次保存的IP
    if (Test-Path "last_ip.txt") {
        $global:lastIP = Get-Content "last_ip.txt" -Raw
        $global:lastIP = $global:lastIP.Trim()
        Add-Log "加载上次IP: $global:lastIP"
    }
    
    # 获取当前IP并比较
    $currentIP = Get-CurrentIP
    if ($currentIP -ne $global:lastIP) {
        Add-Log "IP已变化: 从 $global:lastIP 变为 $currentIP"
        Update-GitProxy $currentIP
    }
    
    # 注册网络变化事件
    $NetworkChangeEvent = {
        # 等待1秒确保网络状态已稳定
        Start-Sleep -Seconds 1
        
        # 复用Get-CurrentIP函数的逻辑，但使用UI更新操作
        # 通过默认路由寻找正确的接口
        $defaultRouteInterface = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | 
                                Select-Object -ExpandProperty InterfaceIndex -First 1
        
        if ($defaultRouteInterface) {
            $ip = (Get-NetIPAddress -InterfaceIndex $defaultRouteInterface -AddressFamily IPv4).IPAddress
            $adapterName = (Get-NetAdapter -InterfaceIndex $defaultRouteInterface).Name
        } else {
            # 查找有线适配器
            $connectedAdapter = Get-NetAdapter | Where-Object {
                $_.Status -eq 'Up' -and 
                $_.PhysicalMediaType -ne 'Unspecified' -and
                $_.PhysicalMediaType -notmatch 'Wireless' -and
                $_.InterfaceDescription -notmatch 'Virtual|VPN|TAP|Tunnel'
            } | Select-Object -First 1
            
            if ($connectedAdapter) {
                $ip = (Get-NetIPAddress -InterfaceIndex $connectedAdapter.ifIndex -AddressFamily IPv4).IPAddress
                $adapterName = $connectedAdapter.Name
            } else {
                # 查找无线适配器
                $wirelessAdapter = Get-NetAdapter | Where-Object {
                    $_.Status -eq 'Up' -and 
                    $_.PhysicalMediaType -match 'Wireless'
                } | Select-Object -First 1
                
                if ($wirelessAdapter) {
                    $ip = (Get-NetIPAddress -InterfaceIndex $wirelessAdapter.ifIndex -AddressFamily IPv4).IPAddress
                    $adapterName = $wirelessAdapter.Name
                } else {
                    # 最后备选方案
                    $ip = (Get-NetIPAddress | Where-Object {
                        $_.AddressFamily -eq 'IPv4' -and 
                        $_.InterfaceAlias -notmatch 'Loopback' -and 
                        $_.IPAddress -notmatch '^169\.254\.' -and
                        $_.IPAddress -notmatch '^0\.'
                    }).IPAddress | Select-Object -First 1
                    $adapterName = "未知适配器"
                }
            }
        }
        
        if ($ip -and $ip -ne $global:lastIP) {
            $form.Invoke([Action]{
                $currentIPLabel.Text = "当前 IP: $ip"
                
                # 更新适配器标签
                $adapterDescription = ""
                if ($defaultRouteInterface) {
                    $adapterDescription = "(默认路由)"
                } elseif ($connectedAdapter) {
                    $adapterDescription = "(有线)"
                } elseif ($wirelessAdapter) {
                    $adapterDescription = "(无线)"
                }
                
                $adapterLabel.Text = "网络适配器: $adapterName $adapterDescription"
                Add-Log "IP已变化: 从 $global:lastIP 变为 $ip (适配器: $adapterName $adapterDescription)"
                Update-GitProxy $ip
            })
        }
    }
    
    # 注册事件
    $global:eventJob = Register-CimIndicationEvent -ClassName Win32_NetworkAdapter -EventName __InstanceModificationEvent -Action $NetworkChangeEvent -SourceIdentifier "NetworkChangeEvent"
}

# 停止监控功能
function Stop-Monitoring {
    if (-not $global:isMonitoring) {
        return
    }
    
    $global:isMonitoring = $false
    $startStopButton.Text = "开始监控"
    $statusLabel.Text = "监控已停止"
    Add-Log "停止监控 IP 地址变化"
    
    # 注销事件
    if ($global:eventJob) {
        Unregister-Event -SourceIdentifier "NetworkChangeEvent" -ErrorAction SilentlyContinue
        $global:eventJob = $null
    }
}

# 事件处理函数
$showMenuItem.Add_Click({
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.ShowInTaskbar = $true
    $form.Show()
    $form.Activate()
    $form.TopMost = $true
    $form.Update()
    $form.TopMost = $false
})

$exitMenuItem.Add_Click({
    $form.Close()
})

$notifyIcon.Add_MouseDoubleClick({
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    $form.ShowInTaskbar = $true
    $form.Show()
    $form.Activate()
    $form.TopMost = $true
    $form.Update()
    $form.TopMost = $false
})

$form.Add_Resize({
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
        $form.ShowInTaskbar = $false
        $form.Hide()
        $notifyIcon.Visible = $true
    }
})

$form.Add_Closing({
    # 检查是否为系统关机事件
    # 使用CloseReason属性来判断是否为系统关机
    if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::WindowsShutDown -or 
        $_.CloseReason -eq [System.Windows.Forms.CloseReason]::TaskManagerClosing) {
        # 系统关机时直接关闭，不显示确认对话框
        Stop-Monitoring
        $notifyIcon.Visible = $false
    } else {
        # 正常关闭程序时显示确认对话框
        $stopConfirm = [System.Windows.Forms.MessageBox]::Show("确认退出Git代理IP监视器？", "确认", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($stopConfirm -eq "No") {
            $_.Cancel = $true
        }
        else {
            Stop-Monitoring
            $notifyIcon.Visible = $false
        }
    }
})

$startStopButton.Add_Click({
    if ($global:isMonitoring) {
        Stop-Monitoring
    }
    else {
        Start-Monitoring
    }
})

$exitButton.Add_Click({
    $form.Close()
})

$savePortButton.Add_Click({
    $newPort = $portTextBox.Text.Trim()
    if (-not $newPort) {
        [System.Windows.Forms.MessageBox]::Show("端口不能为空！", "错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        $newPort | Out-File "proxy_port.txt" -NoNewline
        $global:currentPort = $newPort
        Add-Log "代理端口已更新为: $newPort"
        
        # 如果正在监控，使用新端口更新Git代理
        if ($global:isMonitoring) {
            $currentIP = Get-CurrentIP
            if ($currentIP) {
                Update-GitProxy $currentIP
            }
        }
    }
    catch {
        Add-Log "设置端口失败: $_"
    }
})

# 初始化
Initialize-Port
Get-CurrentIP

# 开始自动监控
Start-Monitoring

# 显示窗口
[System.Windows.Forms.Application]::Run($form)