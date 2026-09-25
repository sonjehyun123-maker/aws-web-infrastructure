Add-Type -AssemblyName System.Drawing

$width = 900
$height = 650
$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Brushes and Pens
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(15, 23, 42))
$vpcPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(56, 189, 248), 3)
$vpcBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 35, 60))
$subnetPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(74, 222, 128), 2)
$subnetBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 50, 35))
$cardBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 41, 59))
$ec2Bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 30, 70))
$ec2Pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(168, 85, 247), 2)

$textWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$textCyan = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56, 189, 248))
$textYellow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(251, 191, 36))
$textGreen = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(74, 222, 128))
$textPurple = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(192, 132, 252))

# Fonts
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$fontSub = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$fontBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Background
$g.FillRectangle($bgBrush, 0, 0, $width, $height)

# Title
$g.DrawString("AWS Web Infrastructure Architecture Diagram", $fontTitle, $textCyan, 160, 20)

# Client Box
$g.FillRectangle($cardBg, 280, 70, 340, 40)
$g.DrawRectangle([System.Drawing.Pens]::SlateGray, 280, 70, 340, 40)
$g.DrawString("Internet Users / Clients (External Traffic)", $fontBold, $textWhite, 300, 80)

# Flow Arrow 1
$g.DrawString("v  HTTP (Port 80) / SSH (Port 22)", $fontSub, $textYellow, 340, 118)

# VPC Box
$g.FillRectangle($vpcBg, 40, 140, 820, 480)
$g.DrawRectangle($vpcPen, 40, 140, 820, 480)
$g.DrawString("Mission-VPC (10.0.0.0/16) - ap-northeast-2", $fontHeader, $textCyan, 55, 150)

# IGW Box
$g.FillRectangle($cardBg, 320, 180, 260, 45)
$g.DrawRectangle([System.Drawing.Pens]::Goldenrod, 320, 180, 260, 45)
$g.DrawString("Internet Gateway (IGW)", $fontBold, $textYellow, 360, 188)
$g.DrawString("igw-08725917d1b9eb4b0", $fontSub, $textWhite, 365, 206)

# Flow Arrow 2
$g.DrawString("v  Route Table (0.0.0.0/0 -> IGW)", $fontSub, $textYellow, 340, 232)

# Public Subnet Box
$g.FillRectangle($subnetBg, 70, 255, 760, 345)
$g.DrawRectangle($subnetPen, 70, 255, 760, 345)
$g.DrawString("Public Subnet (10.0.1.0/24) - subnet-0a319c0f06c2b88cc", $fontHeader, $textGreen, 85, 265)

# Security Group Box
$g.FillRectangle($cardBg, 100, 300, 320, 270)
$g.DrawRectangle([System.Drawing.Pens]::Gray, 100, 300, 320, 270)
$g.DrawString("Security Group (Mission-Web-SG)", $fontHeader, $textWhite, 115, 315)
$g.DrawString("sg-046612d8c8902fcae", $fontSub, $textWhite, 115, 335)
$g.DrawLine([System.Drawing.Pens]::DimGray, 115, 355, 405, 355)

$g.DrawString("[Inbound Rules]", $fontBold, $textYellow, 115, 365)
$g.DrawString("1. HTTP (TCP 80):", $fontBold, $textWhite, 115, 395)
$g.DrawString("   Source: 0.0.0.0/0 (Everywhere)", $fontSub, $textGreen, 115, 415)

$g.DrawString("2. SSH (TCP 22):", $fontBold, $textWhite, 115, 445)
$g.DrawString("   Source: 211.209.211.121/32 (My IP)", $fontSub, $textCyan, 115, 465)

$g.DrawString("[Outbound Rules]", $fontBold, $textYellow, 115, 500)
$g.DrawString("   All Traffic (0.0.0.0/0 Allowed)", $fontSub, $textWhite, 115, 520)

# Arrow SG -> EC2
$g.DrawString("=>", $fontHeader, $textYellow, 435, 430)

# EC2 Instance Box
$g.FillRectangle($ec2Bg, 470, 300, 330, 270)
$g.DrawRectangle($ec2Pen, 470, 300, 330, 270)
$g.DrawString("EC2 Instance (Mission-Web-Server)", $fontHeader, $textPurple, 485, 315)
$g.DrawString("i-0760f0f6d6352c5ed", $fontSub, $textWhite, 485, 335)
$g.DrawLine([System.Drawing.Pens]::Purple, 485, 355, 785, 355)

$g.DrawString("Type:", $fontBold, $textWhite, 485, 370)
$g.DrawString("t3.micro (Free Tier)", $fontSub, $textCyan, 570, 370)

$g.DrawString("OS:", $fontBold, $textWhite, 485, 400)
$g.DrawString("Ubuntu 22.04 LTS", $fontSub, $textWhite, 570, 400)

$g.DrawString("Public IP:", $fontBold, $textWhite, 485, 430)
$g.DrawString("3.34.42.120", $fontBold, $textYellow, 570, 430)

$g.DrawString("Private IP:", $fontBold, $textWhite, 485, 460)
$g.DrawString("10.0.1.172", $fontSub, $textWhite, 570, 460)

$g.DrawString("Web Server:", $fontBold, $textWhite, 485, 490)
$g.DrawString("Nginx (Port 80 Running)", $fontSub, $textGreen, 570, 490)

$g.DrawString("Status:", $fontBold, $textWhite, 485, 520)
$g.DrawString("200 OK /health", $fontBold, $textGreen, 570, 520)

$targetPath = Join-Path (Get-Location) "docs\architecture.png"
$bmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$g.Dispose()
Write-Host "Architecture image successfully saved to: $targetPath"
