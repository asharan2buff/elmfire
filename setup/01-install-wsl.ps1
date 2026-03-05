# PowerShell script to install WSL2 with Ubuntu 24.04
# Run this from an Administrator PowerShell window

# Check if running as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator (right-click PowerShell -> Run as Administrator)"
    exit 1
}

Write-Host "=== Installing WSL2 with Ubuntu 24.04 ===" -ForegroundColor Cyan

# Enable WSL and Virtual Machine features
Write-Host "Enabling Windows Subsystem for Linux..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

Write-Host "Enabling Virtual Machine Platform..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Set WSL2 as default
Write-Host "Setting WSL2 as default version..." -ForegroundColor Yellow
wsl --set-default-version 2

# Install Ubuntu 24.04
Write-Host "Installing Ubuntu 24.04..." -ForegroundColor Yellow
wsl --install -d Ubuntu-24.04

Write-Host ""
Write-Host "=== Installation initiated ===" -ForegroundColor Green
Write-Host "A restart may be required. After restart:" -ForegroundColor White
Write-Host "  1. Ubuntu 24.04 will launch automatically and ask you to create a username/password." -ForegroundColor White
Write-Host "  2. After setting up Ubuntu, come back to the README for the next steps." -ForegroundColor White
Write-Host ""
Write-Host "To verify WSL2 is set up correctly after restart, run:" -ForegroundColor White
Write-Host "  wsl --list --verbose" -ForegroundColor Gray
