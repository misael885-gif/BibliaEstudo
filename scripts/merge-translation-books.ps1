param(
    [Parameter(Mandatory = $true)][string[]]$SourceBooksDirs,
    [Parameter(Mandatory = $true)][string]$TranslationCode,
    [Parameter(Mandatory = $true)][string]$OutputBooksDir,
    [string]$CatalogPath = "data\catalog.js"
)

$ErrorActionPreference = 'Stop'

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force $directory | Out-Null
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Read-CatalogBooks {
    param([Parameter(Mandatory = $true)][string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $json = $raw -replace '^\s*window\.__BIBLIA_CONFIG__\s*=\s*', ''
    $json = $json -replace ';\s*$', ''
    return @((ConvertFrom-Json $json).books)
}

function Read-BookPayload {
    param([Parameter(Mandatory = $true)][string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ($raw -match "^window\.__BIBLIA_REGISTER_BOOK__\('[^']+',\s*'[^']+',\s*") {
        $json = $raw -replace "^window\.__BIBLIA_REGISTER_BOOK__\('[^']+',\s*'[^']+',\s*", ''
    } else {
        $json = $raw -replace "^window\.__BIBLIA_REGISTER_BOOK__\('[^']+',\s*", ''
    }

    $json = $json -replace '\);\s*$', ''
    return @($json | ConvertFrom-Json)
}

function Normalize-BookPayload {
    param(
        [AllowNull()][object[]]$Payload,
        [Parameter(Mandatory = $true)][int]$ExpectedChapterCount
    )

    if ($null -eq $Payload) {
        Write-Output -NoEnumerate @()
        return
    }

    if ($ExpectedChapterCount -eq 1) {
        if ($Payload.Count -eq 1 -and $Payload[0] -is [System.Array]) {
            Write-Output -NoEnumerate (,$Payload[0])
            return
        }

        Write-Output -NoEnumerate (,$Payload)
        return
    }

    if ($Payload.Count -eq 1 -and $Payload[0] -is [System.Array]) {
        Write-Output -NoEnumerate $Payload[0]
        return
    }

    Write-Output -NoEnumerate $Payload
}

function Select-FirstValue {
    param([AllowNull()][object[]]$Values)

    if ($null -eq $Values) {
        return $null
    }

    foreach ($value in $Values) {
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return $null
}

$catalogBooks = Read-CatalogBooks -Path $CatalogPath
New-Item -ItemType Directory -Force $OutputBooksDir | Out-Null

foreach ($book in $catalogBooks) {
    $sourcePayloads = @()
    foreach ($sourceDir in $SourceBooksDirs) {
        $bookPath = Join-Path $sourceDir "$($book.slug).js"
        if (-not (Test-Path -LiteralPath $bookPath)) {
            throw "Livro ausente em uma das fontes: $bookPath"
        }

        $payload = Normalize-BookPayload -Payload (Read-BookPayload -Path $bookPath) -ExpectedChapterCount $book.chapterCount
        $sourcePayloads += ,@($payload)
    }

    $basePayload = $sourcePayloads[0]
    if ($basePayload.Count -ne $book.chapterCount) {
        throw "Estrutura-base inesperada para $($book.slug). Esperado: $($book.chapterCount) capÃ­tulos. Encontrado: $($basePayload.Count)."
    }

    $mergedChapters = New-Object System.Collections.ArrayList
    for ($chapterIndex = 0; $chapterIndex -lt $book.chapterCount; $chapterIndex++) {
        $baseChapter = $basePayload[$chapterIndex]
        if ($null -eq $baseChapter -or $baseChapter -isnot [System.Array]) {
            throw "Estrutura-base inesperada para $($book.slug) capÃ­tulo $($chapterIndex + 1)."
        }

        $verseCount = $baseChapter.Count
        $chapter = New-Object System.Collections.ArrayList

        for ($verseIndex = 0; $verseIndex -lt $verseCount; $verseIndex++) {
            $candidates = @(
                $sourcePayloads | ForEach-Object {
                    if ($chapterIndex -lt $_.Count -and $verseIndex -lt $_[$chapterIndex].Count) {
                        $_[$chapterIndex][$verseIndex]
                    } else {
                        $null
                    }
                }
            )

            [void]$chapter.Add((Select-FirstValue -Values @($candidates)))
        }

        [void]$mergedChapters.Add(@($chapter))
    }

    if ($mergedChapters.Count -eq 1) {
        $chapterPayload = [object[]]@($mergedChapters[0])
        $payload = "[" + (ConvertTo-Json -InputObject $chapterPayload -Depth 10 -Compress) + "]"
    } else {
        $payloadData = @()
        foreach ($chapter in $mergedChapters) {
            $payloadData += ,([object[]]@($chapter))
        }

        $payload = ConvertTo-Json -InputObject ([object[]]$payloadData) -Depth 10 -Compress
    }
    $content = "window.__BIBLIA_REGISTER_BOOK__('{0}', '{1}', {2});" -f $TranslationCode, $book.slug, $payload
    Write-Utf8File -Path (Join-Path $OutputBooksDir "$($book.slug).js") -Content $content
}

Write-Host "Tradução $TranslationCode mesclada em $OutputBooksDir"
