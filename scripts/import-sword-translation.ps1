param(
    [Parameter(Mandatory = $true)][string]$SwordModuleDir,
    [Parameter(Mandatory = $true)][string]$TranslationCode,
    [Parameter(Mandatory = $true)][string]$OutputBooksDir,
    [string]$CatalogPath = "data\catalog.js",
    [string]$ReferenceBooksDir = "data\translations\bl\books"
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
    return (ConvertFrom-Json $json).books
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
    $payload = @($json | ConvertFrom-Json)
    Write-Output -NoEnumerate $payload
}

function Read-ReferenceVerseCounts {
    param([Parameter(Mandatory = $true)][string]$Path)

    $payload = Read-BookPayload -Path $Path
    $chapters = if ($payload.Count -eq 1 -and $payload[0] -is [System.Array]) {
        @($payload[0])
    } else {
        @($payload)
    }

    if ($chapters.Count -eq 0) {
        return @()
    }

    if (($chapters[0] -is [string]) -or $null -eq $chapters[0]) {
        return @($chapters.Count)
    }

    return @($chapters | ForEach-Object { $_.Count })
}

function Read-SwordIndexRecords {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
    if (($bytes.Length % 6) -ne 0) {
        throw "Indice Sword invalido em $Path"
    }

    $records = New-Object System.Collections.ArrayList
    for ($offset = 0; $offset -lt $bytes.Length; $offset += 6) {
        $start = [int]$offset
        [void]$records.Add([pscustomobject]@{
            offset = [BitConverter]::ToUInt32($bytes, $start)
            length = [BitConverter]::ToUInt16($bytes, $start + 4)
        })
    }

    return @($records)
}

function Read-SwordRecordText {
    param(
        [System.IO.FileStream]$Stream,
        [Parameter(Mandatory = $true)][uint32]$Offset,
        [Parameter(Mandatory = $true)][uint16]$Length
    )

    if ($Length -eq 0) {
        return $null
    }

    $buffer = New-Object byte[] $Length
    $Stream.Position = $Offset
    $totalRead = 0

    while ($totalRead -lt $Length) {
        $read = $Stream.Read($buffer, $totalRead, $Length - $totalRead)
        if ($read -le 0) {
            throw "Falha ao ler o texto Sword no deslocamento $Offset"
        }

        $totalRead += $read
    }

    return [System.Text.Encoding]::UTF8.GetString($buffer)
}

function Normalize-Text {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $value = $Text.Replace([char]0x00A0, ' ')
    $value = $value.Replace([char]0x2018, "'")
    $value = $value.Replace([char]0x2019, "'")
    $value = $value.Replace([char]0x201C, '"')
    $value = $value.Replace([char]0x201D, '"')
    $value = $value.Replace([char]0x2013, '-')
    $value = $value.Replace([char]0x2014, '-')
    $value = [regex]::Replace($value, '\s+', ' ')
    $value = [regex]::Replace($value, '\s+([,.;:?!])', '$1')
    $value = [regex]::Replace($value, '([(\["''`])\s+', '$1')
    $value = [regex]::Replace($value, '\s+([)\]"''`])', '$1')
    $value = [regex]::Replace($value, '(?<=[\p{L}\p{N}])\s*-\s*(?=[\p{L}\p{N}])', '-')
    $value = [regex]::Replace($value, '([,.;:?!])(?=[^\s)\]"''`])', '$1 ')
    $value = [regex]::Replace($value, '([,.;:?!])"(?=\p{L})', '$1 "')
    $value = [regex]::Replace($value, '(?<=[\p{L}\p{N}.!?])"(?=\p{L})', '" ')
    $value = [regex]::Replace($value, '\s+', ' ')
    $value = $value.Replace('"ou"', '" ou "')
    $value = $value.Replace('"(', '" (')

    $value = $value.Trim()
    if (-not $value) {
        return $null
    }

    return $value
}

function Remove-SwordMarkup {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $value = [regex]::Replace($Text, '<!--.*?-->', ' ', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $value = [regex]::Replace($value, '<[^>]+>', '')
    $value = [System.Net.WebUtility]::HtmlDecode($value)
    return Normalize-Text -Text $value
}

function Assert-NoUnexpectedTrailingRecords {
    param(
        [Parameter(Mandatory = $true)][object[]]$Records,
        [Parameter(Mandatory = $true)][int]$RecordIndex,
        [Parameter(Mandatory = $true)][string]$IndexPath
    )

    if ($RecordIndex -ge $Records.Count) {
        return
    }

    $remainingRecords = @($Records[$RecordIndex..($Records.Count - 1)])
    $unexpectedRecords = @(
        $remainingRecords | Where-Object { $_.offset -ne 0 -or $_.length -ne 0 }
    )

    if ($unexpectedRecords.Count -gt 0) {
        throw "Sobrou conteudo nao processado no indice $IndexPath. Posicao final: $RecordIndex de $($Records.Count)."
    }
}

$catalogBooks = @(
    Read-CatalogBooks -Path $CatalogPath
)

$referenceVerseCounts = @{}
foreach ($book in $catalogBooks) {
    $referencePath = Join-Path $ReferenceBooksDir "$($book.slug).js"
    if (-not (Test-Path -LiteralPath $referencePath)) {
        throw "Arquivo de referencia nao encontrado: $referencePath"
    }

    $referenceVerseCounts[$book.slug] = Read-ReferenceVerseCounts -Path $referencePath
}

$testaments = @(
    @{
        name      = 'AT'
        textPath  = Join-Path $SwordModuleDir 'ot'
        indexPath = Join-Path $SwordModuleDir 'ot.vss'
        books     = @($catalogBooks | Where-Object { $_.testament -eq 'AT' })
    },
    @{
        name      = 'NT'
        textPath  = Join-Path $SwordModuleDir 'nt'
        indexPath = Join-Path $SwordModuleDir 'nt.vss'
        books     = @($catalogBooks | Where-Object { $_.testament -eq 'NT' })
    }
)

New-Item -ItemType Directory -Force $OutputBooksDir | Out-Null

foreach ($testament in $testaments) {
    $records = Read-SwordIndexRecords -Path $testament.indexPath
    $recordIndex = 2
    $stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $testament.textPath).Path)

    try {
        foreach ($book in $testament.books) {
            if ($recordIndex -ge $records.Count) {
                throw "Fim inesperado do indice ao iniciar o livro $($book.slug)"
            }

            $recordIndex++ # book marker
            $chapterVerseCounts = $referenceVerseCounts[$book.slug]

            if ($chapterVerseCounts.Count -ne $book.chapterCount) {
                throw "Contagem de capitulos inesperada para $($book.slug). Esperado: $($book.chapterCount). Encontrado: $($chapterVerseCounts.Count)."
            }

            $chapters = New-Object System.Collections.ArrayList
            foreach ($verseCount in $chapterVerseCounts) {
                if ($recordIndex -ge $records.Count) {
                    throw "Fim inesperado do indice ao iniciar um capitulo de $($book.slug)"
                }

                $recordIndex++ # chapter marker
                $chapter = New-Object System.Collections.ArrayList

                for ($verseNumber = 1; $verseNumber -le $verseCount; $verseNumber++) {
                    if ($recordIndex -ge $records.Count) {
                        throw "Fim inesperado do indice ao ler $($book.slug) verso $verseNumber"
                    }

                    $record = $records[$recordIndex]
                    $text = Read-SwordRecordText -Stream $stream -Offset $record.offset -Length $record.length
                    [void]$chapter.Add((Remove-SwordMarkup -Text $text))
                    $recordIndex++
                }

                [void]$chapters.Add(@($chapter))
            }

            $payload = ConvertTo-Json -InputObject $chapters -Depth 10 -Compress
            $content = "window.__BIBLIA_REGISTER_BOOK__('{0}', '{1}', {2});" -f $TranslationCode, $book.slug, $payload
            Write-Utf8File -Path (Join-Path $OutputBooksDir "$($book.slug).js") -Content $content
        }
    } finally {
        $stream.Dispose()
    }

    Assert-NoUnexpectedTrailingRecords -Records $records -RecordIndex $recordIndex -IndexPath $testament.indexPath
}

Write-Host "Arquivos da traducao $TranslationCode gerados em $OutputBooksDir"
