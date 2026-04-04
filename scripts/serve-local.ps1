param(
    [int]$Port = 4173,
    [string]$RootPath = (Split-Path -Parent $PSScriptRoot),
    [bool]$OpenBrowser = $true
)

$ErrorActionPreference = "Stop"

function Get-ContentType {
    param([Parameter(Mandatory = $true)][string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".webmanifest" { return "application/manifest+json; charset=utf-8" }
        ".svg" { return "image/svg+xml" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".ico" { return "image/x-icon" }
        ".txt" { return "text/plain; charset=utf-8" }
        default { return "application/octet-stream" }
    }
}

function Write-Response {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][int]$StatusCode,
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$ContentType = "text/plain; charset=utf-8"
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

$root = [System.IO.Path]::GetFullPath($RootPath)
$prefix = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host ""
Write-Host "Biblia local disponivel em $prefix"
Write-Host "Deixe esta janela aberta enquanto usa o app."
Write-Host "Para parar o servidor, pressione Ctrl+C."
Write-Host ""

if ($OpenBrowser) {
    try {
        Start-Process $prefix | Out-Null
    } catch {
        Write-Host "Nao foi possivel abrir o navegador automaticamente."
    }
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()

        try {
            $relativePath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = "index.html"
            }

            $candidatePath = Join-Path $root ($relativePath -replace '/', '\')
            $fullPath = [System.IO.Path]::GetFullPath($candidatePath)

            if (-not $fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Response -Context $context -StatusCode 403 -Text "Acesso negado."
                continue
            }

            if ((Test-Path -LiteralPath $fullPath) -and (Get-Item -LiteralPath $fullPath).PSIsContainer) {
                $fullPath = Join-Path $fullPath "index.html"
            }

            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                Write-Response -Context $context -StatusCode 404 -Text "Arquivo nao encontrado."
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $context.Response.StatusCode = 200
            $context.Response.ContentType = Get-ContentType -Path $fullPath
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } catch {
            Write-Response -Context $context -StatusCode 500 -Text "Erro interno ao servir o app."
        } finally {
            $context.Response.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
