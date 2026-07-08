$RootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = 8080

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $Port)
$listener.Start()

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'
  '.jpg' = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.png' = 'image/png'
  '.svg' = 'image/svg+xml'
  '.webp' = 'image/webp'
  '.pdf' = 'application/pdf'
  '.docx' = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  '.md' = 'text/markdown; charset=utf-8'
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream)
    $requestLine = $reader.ReadLine()

    while (($line = $reader.ReadLine()) -ne '') { }

    $target = 'index.html'
    if ($requestLine -match 'GET\s+([^\s]+)') {
      $urlPath = [Uri]::UnescapeDataString(($matches[1] -split '\?')[0])
      if ($urlPath -ne '/') {
        $target = $urlPath.TrimStart('/')
      }
    }

    $file = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootPath, $target))
    if (-not $file.StartsWith($RootPath)) {
      throw 'Forbidden'
    }
    if (-not [System.IO.File]::Exists($file)) {
      throw 'Not found'
    }

    $bytes = [System.IO.File]::ReadAllBytes($file)
    $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
    $type = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
    $header = "HTTP/1.1 200 OK`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($headBytes, 0, $headBytes.Length)
    $stream.Write($bytes, 0, $bytes.Length)
  }
  catch {
    $body = [System.Text.Encoding]::UTF8.GetBytes('Not found')
    $header = "HTTP/1.1 404 Not Found`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($headBytes, 0, $headBytes.Length)
    $stream.Write($body, 0, $body.Length)
  }
  finally {
    $client.Close()
  }
}
