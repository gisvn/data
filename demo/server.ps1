# WebGIS Local Server - PowerShell
$port = 8080
$root = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
try { $listener.Start() } catch {
    Write-Host "[LOI] Khong the mo port $port. Co the port dang duoc dung boi chuong trinh khac."
    Write-Host "Thu doi port hoac dong chuong trinh dang dung port $port."
    Read-Host 'Nhan Enter de thoat'
    exit 1
}

Write-Host '=========================================='
Write-Host '   WebGIS Local Server (PowerShell)'
Write-Host '=========================================='
Write-Host ''
Write-Host "[OK] Server dang chay tai: http://localhost:$port"
Write-Host 'Nhan Ctrl+C de dung server.'
Write-Host ''

# Mo trinh duyet sau khi server da Start() thanh cong
Start-Process "http://localhost:$port"

$mimeTypes = @{
    '.html'    = 'text/html; charset=utf-8'
    '.js'      = 'application/javascript; charset=utf-8'
    '.css'     = 'text/css; charset=utf-8'
    '.json'    = 'application/json; charset=utf-8'
    '.geojson' = 'application/json; charset=utf-8'
    '.png'     = 'image/png'
    '.jpg'     = 'image/jpeg'
    '.jpeg'    = 'image/jpeg'
    '.ico'     = 'image/x-icon'
    '.svg'     = 'image/svg+xml'
    '.woff2'   = 'font/woff2'
    '.woff'    = 'font/woff'
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $urlPath = $req.Url.LocalPath

        # ── CORS headers cho mọi response ──
        $res.Headers.Add('Access-Control-Allow-Origin', '*')
        $res.Headers.Add('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        $res.Headers.Add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
        if ($req.HttpMethod -eq 'OPTIONS') {
            $res.StatusCode = 204; $res.OutputStream.Close(); continue
        }

        # ════════════════════════════════════════════
        # PROXY /api/s2token  – lấy OAuth2 token
        # POST body: client_id=...&client_secret=...
        # ════════════════════════════════════════════
        if ($urlPath -eq '/api/s2token' -and $req.HttpMethod -eq 'POST') {
            try {
                $bodyStream = New-Object System.IO.StreamReader($req.InputStream)
                $bodyText   = $bodyStream.ReadToEnd()
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('Content-Type', 'application/x-www-form-urlencoded')
                $tokenUrl  = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
                $respBytes = $wc.UploadData($tokenUrl, 'POST', [System.Text.Encoding]::UTF8.GetBytes($bodyText))
                $res.ContentType = 'application/json; charset=utf-8'
                $res.StatusCode  = 200
                $res.ContentLength64 = $respBytes.Length
                $res.OutputStream.Write($respBytes, 0, $respBytes.Length)
            } catch [System.Net.WebException] {
                $errResp  = $_.Exception.Response
                $errCode  = if ($errResp) { [int]$errResp.StatusCode } else { 502 }
                $errBody  = ''
                if ($errResp) {
                    $sr = New-Object System.IO.StreamReader($errResp.GetResponseStream())
                    $errBody = $sr.ReadToEnd()
                }
                $msg = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                $res.StatusCode = $errCode
                $res.ContentType = 'application/json; charset=utf-8'
                $res.ContentLength64 = $msg.Length
                $res.OutputStream.Write($msg, 0, $msg.Length)
            } catch {
                $msg = [System.Text.Encoding]::UTF8.GetBytes('{"error":"proxy_error","error_description":"' + $_.Exception.Message + '"}')
                $res.StatusCode = 502
                $res.ContentLength64 = $msg.Length
                $res.OutputStream.Write($msg, 0, $msg.Length)
            }
            $res.OutputStream.Close(); continue
        }

        # ════════════════════════════════════════════
        # PROXY /api/s2process – Sentinel Hub Process API
        # POST body: JSON payload, Header: Authorization: Bearer ...
        # ════════════════════════════════════════════
        if ($urlPath -eq '/api/s2process' -and $req.HttpMethod -eq 'POST') {
            try {
                $bodyStream = New-Object System.IO.StreamReader($req.InputStream)
                $bodyText   = $bodyStream.ReadToEnd()
                $authHdr    = $req.Headers['Authorization']
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add('Content-Type', 'application/json')
                if ($authHdr) { $wc.Headers.Add('Authorization', $authHdr) }
                $processUrl = 'https://sh.dataspace.copernicus.eu/api/v1/process'
                $respBytes  = $wc.UploadData($processUrl, 'POST', [System.Text.Encoding]::UTF8.GetBytes($bodyText))
                $res.ContentType = 'image/tiff'
                $res.StatusCode  = 200
                $res.ContentLength64 = $respBytes.Length
                $res.OutputStream.Write($respBytes, 0, $respBytes.Length)
            } catch [System.Net.WebException] {
                $errResp  = $_.Exception.Response
                $errCode  = if ($errResp) { [int]$errResp.StatusCode } else { 502 }
                $errBody  = ''
                if ($errResp) {
                    $sr = New-Object System.IO.StreamReader($errResp.GetResponseStream())
                    $errBody = $sr.ReadToEnd()
                }
                $msg = [System.Text.Encoding]::UTF8.GetBytes($errBody)
                $res.StatusCode = $errCode
                $res.ContentType = 'application/json; charset=utf-8'
                $res.ContentLength64 = $msg.Length
                $res.OutputStream.Write($msg, 0, $msg.Length)
            } catch {
                $msg = [System.Text.Encoding]::UTF8.GetBytes('{"error":"proxy_error","error_description":"' + $_.Exception.Message + '"}')
                $res.StatusCode = 502
                $res.ContentLength64 = $msg.Length
                $res.OutputStream.Write($msg, 0, $msg.Length)
            }
            $res.OutputStream.Close(); continue
        }

        # ════ Static file serving (giữ nguyên) ════
        if ($urlPath -eq '/') { $urlPath = '/index.html' }
        $filePath = Join-Path $root $urlPath.TrimStart('/')
        $filePath = [System.IO.Path]::GetFullPath($filePath)
        # Bao ve thu muc: chi cho phep doc file trong $root
        if (-not $filePath.StartsWith($root)) {
            $res.StatusCode = 403
            $res.OutputStream.Close()
            continue
        }
        if ([System.IO.File]::Exists($filePath)) {
            $ext  = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $res.ContentType     = $mime
            $res.ContentLength64 = $bytes.Length
            $res.StatusCode      = 200
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
            $res.OutputStream.Write($msg, 0, $msg.Length)
        }
        $res.OutputStream.Close()
    } catch { }
}
