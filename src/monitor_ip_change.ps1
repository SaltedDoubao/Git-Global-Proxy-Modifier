Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ����������
$form = New-Object System.Windows.Forms.Form
$form.Text = "Git ���� IP ������"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
#$form.Icon = [System.Drawing.SystemIcons]::Application
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot/../res/icon.ico")
$form.ShowInTaskbar = $true

# ����ϵͳ����ͼ��
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
#$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot/../res/icon.ico")
$notifyIcon.Text = "Git ���� IP ������"
$notifyIcon.Visible = $true

# ��������ͼ���Ҽ��˵�
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showMenuItem.Text = "��ʾ����"
$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "�˳�"
$contextMenu.Items.Add($showMenuItem)
$contextMenu.Items.Add($exitMenuItem)
$notifyIcon.ContextMenuStrip = $contextMenu

# ����״̬��ʾ��
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 10)
$statusLabel.Size = New-Object System.Drawing.Size(380, 20)
$statusLabel.Text = "�ȴ���� IP ��ַ�仯..."
$form.Controls.Add($statusLabel)

# ������ǰIP��ʾ��
$currentIPLabel = New-Object System.Windows.Forms.Label
$currentIPLabel.Location = New-Object System.Drawing.Point(10, 40)
$currentIPLabel.Size = New-Object System.Drawing.Size(380, 20)
$currentIPLabel.Text = "��ǰ IP: δ֪"
$form.Controls.Add($currentIPLabel)

# ����������������ʾ��
$adapterLabel = New-Object System.Windows.Forms.Label
$adapterLabel.Location = New-Object System.Drawing.Point(10, 60)
$adapterLabel.Size = New-Object System.Drawing.Size(380, 20)
$adapterLabel.Text = "����������: δ֪"
$form.Controls.Add($adapterLabel)

# �����˿������
$portLabel = New-Object System.Windows.Forms.Label
$portLabel.Location = New-Object System.Drawing.Point(10, 90)
$portLabel.Size = New-Object System.Drawing.Size(80, 20)
$portLabel.Text = "����˿�:"
$form.Controls.Add($portLabel)

$portTextBox = New-Object System.Windows.Forms.TextBox
$portTextBox.Location = New-Object System.Drawing.Point(90, 90)
$portTextBox.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($portTextBox)

# ��������˿ڰ�ť
$savePortButton = New-Object System.Windows.Forms.Button
$savePortButton.Location = New-Object System.Drawing.Point(200, 90)
$savePortButton.Size = New-Object System.Drawing.Size(80, 20)
$savePortButton.Text = "����˿�"
$form.Controls.Add($savePortButton)

# ������־�ı���
$logTextBox = New-Object System.Windows.Forms.TextBox
$logTextBox.Location = New-Object System.Drawing.Point(10, 120)
$logTextBox.Size = New-Object System.Drawing.Size(370, 100)
$logTextBox.Multiline = $true
$logTextBox.ReadOnly = $true
$logTextBox.ScrollBars = "Vertical"
$form.Controls.Add($logTextBox)

# ������ʼ/ֹͣ��ť
$startStopButton = New-Object System.Windows.Forms.Button
$startStopButton.Location = New-Object System.Drawing.Point(10, 230)
$startStopButton.Size = New-Object System.Drawing.Size(180, 30)
$startStopButton.Text = "��ʼ���"
$form.Controls.Add($startStopButton)

# �����˳���ť
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(200, 230)
$exitButton.Size = New-Object System.Drawing.Size(180, 30)
$exitButton.Text = "�˳�"
$form.Controls.Add($exitButton)

# ȫ�ֱ���
$global:isMonitoring = $false
$global:lastIP = ""
$global:eventJob = $null
$global:currentPort = "7890"

# �Զ�����־����
function Add-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    $logTextBox.AppendText("$logMessage`r`n")
    # �������ײ�
    $logTextBox.SelectionStart = $logTextBox.Text.Length
    $logTextBox.ScrollToCaret()
}

# ��ȡ�ű�����Ŀ¼
$scriptPath = $PSScriptRoot
if (-not $scriptPath) {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
# ���������ļ�·��
$configPath = Join-Path -Path $scriptPath -ChildPath "..\config"
$portFilePath = Join-Path -Path $configPath -ChildPath "proxy_port.txt"
$ipFilePath = Join-Path -Path $configPath -ChildPath "last_ip.txt"

# ��ʼ���˿�
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
            Add-Log "�޷���ȡ�˿��ļ���ʹ��Ĭ�϶˿�7890"
        }
    }
    else {
        $portTextBox.Text = "7890"
        $global:currentPort = "7890"
        # ����Ĭ������Ŀ¼���ļ�
        if (-not (Test-Path $configPath)) {
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
        }
        $global:currentPort | Out-File $portFilePath -NoNewline
        Add-Log "�Ѵ���Ĭ�������ļ�"
    }
}

# ��⵱ǰIP����ʾ
function Get-CurrentIP {
    # ��ȡ�����ⲿ���ӵ�IPv4��ַ
    # ���Ȼ�ȡӵ��Ĭ�����صĽӿڣ�ͨ������Ҫ��������
    $defaultRouteInterface = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | 
                             Select-Object -ExpandProperty InterfaceIndex -First 1
    
    if ($defaultRouteInterface) {
        # ʹ��Ĭ��·�ɵĽӿڻ�ȡIP
        $ip = (Get-NetIPAddress -InterfaceIndex $defaultRouteInterface -AddressFamily IPv4).IPAddress
        $adapterName = (Get-NetAdapter -InterfaceIndex $defaultRouteInterface | Select-Object -ExpandProperty Name)
        $adapterLabel.Text = "����������: $adapterName (Ĭ��·��)"
        Add-Log "�ҵ�Ĭ��·�ɽӿ�: $adapterName"
    } else {
        # ��ѡ����: ���Ի�ȡ�������ӵ�������
        $connectedAdapter = Get-NetAdapter | Where-Object {
            $_.Status -eq 'Up' -and 
            $_.PhysicalMediaType -ne 'Unspecified' -and
            $_.PhysicalMediaType -notmatch 'Wireless' -and
            $_.InterfaceDescription -notmatch 'Virtual|VPN|TAP|Tunnel'
        } | Select-Object -First 1
        
        if ($connectedAdapter) {
            $ip = (Get-NetIPAddress -InterfaceIndex $connectedAdapter.ifIndex -AddressFamily IPv4).IPAddress
            $adapterName = $connectedAdapter.Name
            $adapterLabel.Text = "����������: $adapterName (����)"
            Add-Log "�ҵ���������������: $adapterName"
        } else {
            # ������ѡ���ȡ��������
            $wirelessAdapter = Get-NetAdapter | Where-Object {
                $_.Status -eq 'Up' -and 
                $_.PhysicalMediaType -match 'Wireless'
            } | Select-Object -First 1
            
            if ($wirelessAdapter) {
                $ip = (Get-NetIPAddress -InterfaceIndex $wirelessAdapter.ifIndex -AddressFamily IPv4).IPAddress
                $adapterName = $wirelessAdapter.Name
                $adapterLabel.Text = "����������: $adapterName (����)"
                Add-Log "�ҵ���������������: $adapterName"
            } else {
                # ��󷽰���ʹ��֮ǰ�Ĺ��˷���
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
                    $adapterLabel.Text = "����������: δ֪ (�ⲿIP)"
                    Add-Log "�ҵ��ⲿIP��ַ"
                } else {
                    # ����ⲿIPû�ҵ����ͻص�����Ѱ�Һ��ʵ�����IP
                    $ip = (Get-NetIPAddress | Where-Object {
                        $_.AddressFamily -eq 'IPv4' -and 
                        $_.InterfaceAlias -notmatch 'Loopback' -and 
                        $_.IPAddress -notmatch '^169\.254\.' -and
                        $_.IPAddress -notmatch '^0\.'
                    }).IPAddress | Select-Object -First 1
                    $adapterLabel.Text = "����������: δ֪ (�ڲ�IP)"
                    Add-Log "ʹ�ñ�ѡ�����ҵ�IP��ַ"
                }
            }
        }
    }

    if ($ip) {
        $currentIPLabel.Text = "��ǰ IP: $ip"
        Add-Log "ȷ����ǰ��IP��ַΪ: $ip"
        return $ip
    }
    else {
        $currentIPLabel.Text = "��ǰ IP: δ֪"
        $adapterLabel.Text = "����������: δ�ҵ�"
        Add-Log "�޷�ȷ����Ч������IP��ַ"
        return $null
    }
}

# ����Git��������
function Update-GitProxy {
    param ([string]$ip)
    
    if (-not $ip) {
        Add-Log "IP��ַΪ�գ��޷�����Git����"
        return
    }
    
    try {
        git config --global http.proxy "http://${ip}:${global:currentPort}"
        git config --global https.proxy "http://${ip}:${global:currentPort}"
        Add-Log "Git�����Ѹ���Ϊ: http://${ip}:${global:currentPort}"
        
        # �����ϴ�IP
        $ip | Out-File "last_ip.txt" -NoNewline
        $global:lastIP = $ip
    }
    catch {
        Add-Log "����Git����ʧ��: $_"
    }
}

# ��ʼ��ع���
function Start-Monitoring {
    if ($global:isMonitoring) {
        Add-Log "�Ѿ��ڼ����..."
        return
    }
    
    $global:isMonitoring = $true
    $startStopButton.Text = "ֹͣ���"
    $statusLabel.Text = "���ڼ�� IP ��ַ�仯..."
    Add-Log "��ʼ��� IP ��ַ�仯"
    
    # ��ȡ�ϴα����IP
    if (Test-Path "last_ip.txt") {
        $global:lastIP = Get-Content "last_ip.txt" -Raw
        $global:lastIP = $global:lastIP.Trim()
        Add-Log "�����ϴ�IP: $global:lastIP"
    }
    
    # ��ȡ��ǰIP���Ƚ�
    $currentIP = Get-CurrentIP
    if ($currentIP -ne $global:lastIP) {
        Add-Log "IP�ѱ仯: �� $global:lastIP ��Ϊ $currentIP"
        Update-GitProxy $currentIP
    }
    
    # ע������仯�¼�
    $NetworkChangeEvent = {
        # �ȴ�1��ȷ������״̬���ȶ�
        Start-Sleep -Seconds 1
        
        # ����Get-CurrentIP�������߼�����ʹ��UI���²���
        # ͨ��Ĭ��·��Ѱ����ȷ�Ľӿ�
        $defaultRouteInterface = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | 
                                Select-Object -ExpandProperty InterfaceIndex -First 1
        
        if ($defaultRouteInterface) {
            $ip = (Get-NetIPAddress -InterfaceIndex $defaultRouteInterface -AddressFamily IPv4).IPAddress
            $adapterName = (Get-NetAdapter -InterfaceIndex $defaultRouteInterface).Name
        } else {
            # ��������������
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
                # ��������������
                $wirelessAdapter = Get-NetAdapter | Where-Object {
                    $_.Status -eq 'Up' -and 
                    $_.PhysicalMediaType -match 'Wireless'
                } | Select-Object -First 1
                
                if ($wirelessAdapter) {
                    $ip = (Get-NetIPAddress -InterfaceIndex $wirelessAdapter.ifIndex -AddressFamily IPv4).IPAddress
                    $adapterName = $wirelessAdapter.Name
                } else {
                    # ���ѡ����
                    $ip = (Get-NetIPAddress | Where-Object {
                        $_.AddressFamily -eq 'IPv4' -and 
                        $_.InterfaceAlias -notmatch 'Loopback' -and 
                        $_.IPAddress -notmatch '^169\.254\.' -and
                        $_.IPAddress -notmatch '^0\.'
                    }).IPAddress | Select-Object -First 1
                    $adapterName = "δ֪������"
                }
            }
        }
        
        if ($ip -and $ip -ne $global:lastIP) {
            $form.Invoke([Action]{
                $currentIPLabel.Text = "��ǰ IP: $ip"
                
                # ������������ǩ
                $adapterDescription = ""
                if ($defaultRouteInterface) {
                    $adapterDescription = "(Ĭ��·��)"
                } elseif ($connectedAdapter) {
                    $adapterDescription = "(����)"
                } elseif ($wirelessAdapter) {
                    $adapterDescription = "(����)"
                }
                
                $adapterLabel.Text = "����������: $adapterName $adapterDescription"
                Add-Log "IP�ѱ仯: �� $global:lastIP ��Ϊ $ip (������: $adapterName $adapterDescription)"
                Update-GitProxy $ip
            })
        }
    }
    
    # ע���¼�
    $global:eventJob = Register-CimIndicationEvent -ClassName Win32_NetworkAdapter -EventName __InstanceModificationEvent -Action $NetworkChangeEvent -SourceIdentifier "NetworkChangeEvent"
}

# ֹͣ��ع���
function Stop-Monitoring {
    if (-not $global:isMonitoring) {
        return
    }
    
    $global:isMonitoring = $false
    $startStopButton.Text = "��ʼ���"
    $statusLabel.Text = "�����ֹͣ"
    Add-Log "ֹͣ��� IP ��ַ�仯"
    
    # ע���¼�
    if ($global:eventJob) {
        Unregister-Event -SourceIdentifier "NetworkChangeEvent" -ErrorAction SilentlyContinue
        $global:eventJob = $null
    }
}

# �¼�������
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
    # ����Ƿ�Ϊϵͳ�ػ��¼�
    # ʹ��CloseReason�������ж��Ƿ�Ϊϵͳ�ػ�
    if ($_.CloseReason -eq [System.Windows.Forms.CloseReason]::WindowsShutDown -or 
        $_.CloseReason -eq [System.Windows.Forms.CloseReason]::TaskManagerClosing) {
        # ϵͳ�ػ�ʱֱ�ӹرգ�����ʾȷ�϶Ի���
        Stop-Monitoring
        $notifyIcon.Visible = $false
    } else {
        # �����رճ���ʱ��ʾȷ�϶Ի���
        $stopConfirm = [System.Windows.Forms.MessageBox]::Show("ȷ���˳�Git����IP��������", "ȷ��", [System.Windows.Forms.MessageBoxButtons]::YesNo)
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
        [System.Windows.Forms.MessageBox]::Show("�˿ڲ���Ϊ�գ�", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        $newPort | Out-File "proxy_port.txt" -NoNewline
        $global:currentPort = $newPort
        Add-Log "����˿��Ѹ���Ϊ: $newPort"
        
        # ������ڼ�أ�ʹ���¶˿ڸ���Git����
        if ($global:isMonitoring) {
            $currentIP = Get-CurrentIP
            if ($currentIP) {
                Update-GitProxy $currentIP
            }
        }
    }
    catch {
        Add-Log "���ö˿�ʧ��: $_"
    }
})

# ��ʼ��
Initialize-Port
Get-CurrentIP

# ��ʼ�Զ����
Start-Monitoring

# ��ʾ����
[System.Windows.Forms.Application]::Run($form)