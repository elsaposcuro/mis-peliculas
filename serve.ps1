param([int]$Port = 8080)

$root = $PSScriptRoot
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()

$hostname = [System.Net.Dns]::GetHostName()
$ips = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
Write-Host "Servidor corriendo en el puerto $Port."
Write-Host "Abri esto en Safari del iPhone (misma red WiFi que esta PC):"
foreach ($ip in $ips) { Write-Host "  http://$($ip.IPAddressToString):$Port" }
Write-Host "(Ctrl+C para detener)"

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".htm"  = "text/html; charset=utf-8"
  ".js"   = "application/javascript"
  ".css"  = "text/css"
  ".json" = "application/json; charset=utf-8"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 3000
        $client.SendTimeout = 3000
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $requestLine = $reader.ReadLine()
        if (-not $requestLine) { continue }
        while (($line = $reader.ReadLine()) -and $line -ne "") {}

        $path = "/index.html"
        if ($requestLine -match '^\w+\s+(\S+)\s+HTTP') {
            $rawPath = $matches[1].Split('?')[0]
            if ($rawPath -ne "/") { $path = [System.Uri]::UnescapeDataString($rawPath) }
        }

        $filePath = [System.IO.Path]::GetFullPath((Join-Path $root ($path.TrimStart("/"))))

        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.AutoFlush = $true

        if ($filePath.StartsWith($root) -and (Test-Path $filePath -PathType Leaf)) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = $mimeTypes[$ext]
            if (-not $contentType) { $contentType = "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $writer.Write("HTTP/1.1 200 OK`r`n")
            $writer.Write("Content-Type: $contentType`r`n")
            $writer.Write("Content-Length: $($bytes.Length)`r`n")
            $writer.Write("Connection: close`r`n`r`n")
            $writer.Flush()
            $stream.Write($bytes, 0, $bytes.Length)
        } else {
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $writer.Write("HTTP/1.1 404 Not Found`r`n")
            $writer.Write("Content-Type: text/plain`r`n")
            $writer.Write("Content-Length: $($body.Length)`r`n")
            $writer.Write("Connection: close`r`n`r`n")
            $writer.Flush()
            $stream.Write($body, 0, $body.Length)
        }
        $stream.Flush()
    } catch {
    } finally {
        $client.Close()
    }
}
