# 截取 flutter_rust_demo 窗口画面，保存到 logs/app_screenshot.png
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Capture {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$proc = Get-Process -Name flutter_rust_demo -ErrorAction Stop | Select-Object -First 1
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) { Write-Host "NO WINDOW"; exit 1 }

# 如果最小化则还原
[Win32Capture]::IsIconic($hwnd) | Out-Null
[Win32Capture]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
[Win32Capture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 300

$rect = New-Object Win32Capture+RECT
[Win32Capture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Host "window: $($rect.Left),$($rect.Top) ${w}x${h}"

$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$out = "c:\Users\11456\workspace\flutter_rust_demo\logs\app_screenshot.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "saved: $out"
$g.Dispose(); $bmp.Dispose()
