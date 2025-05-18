# Git代理IP监视器

这是一个自动检测本地IP地址变化并更新Git代理设置的工具，带有简陋的图形界面。

主要用于应对动态ip地址 (如某些校园网)

## ✨ 功能特点

- 自动检测IP地址变化并更新Git代理
- 智能识别物理网卡和优先连接
- 图形界面显示状态和设置
- 可自定义代理端口
- 开机启动选项（目前还没实现，需手动添加）

## 📁 项目结构

```
Git-Global-Proxy-Modifier/
├── src/                # 源代码
│   └── monitor_ip_change.ps1  # 主程序
├── res/                # 资源文件
│   └── icon.ico        # 程序图标
├── config/             # 配置文件
│   └── proxy_port.txt  # 代理端口设置
├── start_ip_monitor.bat  # 启动脚本
└── README.md           # 项目说明
```

## 🚀 使用方法

### 直接运行
1. 双击 `start_ip_monitor.bat`
2. 程序会以管理员权限启动并自动监听IP变化
3. 可以在系统托盘找到程序图标

## 💻 系统要求

- Windows 7/8/10/11
- PowerShell 5.0或更高版本
- Git命令行工具
- 管理员权限（用于监听网络事件）

## 🏛️ 许可协议

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 开源许可证。

## 📞联系方式

> 📧 **邮箱**：`salteddoubao@gmail.com`

> 🐧 **QQ**：`1531895767`

> 📺 **BiliBili**：[椒盐豆包](https://space.bilibili.com/498891142)