param(
    [Parameter(Mandatory = $true)][string]$UsfmDir,
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
    return (ConvertFrom-Json $json).books
}

function Normalize-Text {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
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
    $value = $value.Replace('mesmoo machado', 'mesmo o machado')
    $value = $value.Replace('Coreiro', 'Cordeiro')
    $value = $value.Replace('celo', 'selo')
    $value = $value.Replace('rigos', 'ricos')
    $value = $value.Replace('dourina', 'doutrina')
    $value = $value.Replace('colocarmeios', 'colocar meios')
    $value = $value.Replace('o o primeiro', 'o primeiro')
    $value = $value.Replace('unidade miltar', 'unidade militar')
    $value = [regex]::Replace($value, '(^|[\s,;(])y(?=[\s,.;:?!)])', '$1e')
    $value = $value.Replace(' e e já ', ' e já ')
    $value = $value.Replace('em Sardo', 'em Sardes')
    $value = $value.Replace(' a o Filho do homem', ' ao Filho do homem')
    $value = $value.Replace(' o principio e o fim', ' o princípio e o fim')
    $value = $value.Replace('significa" o lugar', 'significa "o lugar')
    return $value.Trim()
}

function Remove-UsfmMarkup {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $value = $Text

    foreach ($marker in @('f', 'fe', 'x', 'rq')) {
        $value = [regex]::Replace($value, "\\$marker\s+.*?\\$marker\*", '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }

    foreach ($marker in @('add', 'wj', 'nd', 'qs', 'qt', 'dc', 'it', 'bd', 'bdit', 'bk', 'k', 'tl', 'pn', 'ord', 'sig', 'em')) {
        $value = [regex]::Replace($value, "\\\+$marker\s+([^\\]*?)\\\+$marker\*", '$1')
        $value = [regex]::Replace($value, "\\$marker\s+([^\\]*?)\\$marker\*", '$1')
    }

    $value = [regex]::Replace($value, '\\[a-z0-9+\-*]+\s*', ' ')
    return Normalize-Text $value
}

function Add-VerseToChapter {
    param(
        [System.Collections.ArrayList]$Chapter,
        [Parameter(Mandatory = $true)][int]$VerseNumber,
        [AllowNull()][string]$VerseText
    )

    while ($Chapter.Count -lt ($VerseNumber - 1)) {
        [void]$Chapter.Add($null)
    }

    [void]$Chapter.Add((Remove-UsfmMarkup $VerseText))
}

function Convert-UsfmFileToChapters {
    param([Parameter(Mandatory = $true)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $chapters = New-Object System.Collections.ArrayList
    $currentChapter = New-Object System.Collections.ArrayList
    $currentVerseNumber = $null
    $currentVerseParts = New-Object System.Collections.ArrayList

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if (-not $line) {
            continue
        }

        if ($line -match '^\\c\s+(\d+)') {
            if ($null -ne $currentVerseNumber) {
                Add-VerseToChapter -Chapter $currentChapter -VerseNumber $currentVerseNumber -VerseText (($currentVerseParts -join ' ').Trim())
                $currentVerseNumber = $null
                $currentVerseParts = New-Object System.Collections.ArrayList
            }

            if ($currentChapter.Count -gt 0) {
                [void]$chapters.Add(@($currentChapter))
                $currentChapter = New-Object System.Collections.ArrayList
            }
            continue
        }

        if ($line -match '^\\v\s+(\d+)\s*(.*)$') {
            if ($null -ne $currentVerseNumber) {
                Add-VerseToChapter -Chapter $currentChapter -VerseNumber $currentVerseNumber -VerseText (($currentVerseParts -join ' ').Trim())
                $currentVerseParts = New-Object System.Collections.ArrayList
            }

            $currentVerseNumber = [int]$Matches[1]
            $initialText = $Matches[2].Trim()
            if ($initialText) {
                [void]$currentVerseParts.Add($initialText)
            }
            continue
        }

        if ($null -eq $currentVerseNumber) {
            continue
        }

        if ($line -match '^\\(?:p|m|mi|pi\d*|pm\d*|pmc|pmo|q\d*|qm\d*|qr|qc|qa|qs|li\d*|nb|b|sp|s\d*|sr|r|d|ms\d*|mr|cl|cp|cd)\s*(.*)$') {
            $continuation = $Matches[1].Trim()
            if ($continuation) {
                [void]$currentVerseParts.Add($continuation)
            }
            continue
        }

        if ($line -match '^\\') {
            continue
        }

        [void]$currentVerseParts.Add($line)
    }

    if ($null -ne $currentVerseNumber) {
        Add-VerseToChapter -Chapter $currentChapter -VerseNumber $currentVerseNumber -VerseText (($currentVerseParts -join ' ').Trim())
    }

    if ($currentChapter.Count -gt 0) {
        [void]$chapters.Add(@($currentChapter))
    }

    return @($chapters)
}

$catalogBooks = Read-CatalogBooks -Path $CatalogPath
$usfmFiles = @(Get-ChildItem -LiteralPath $UsfmDir -Filter '*.usfm' | Sort-Object Name)

if ($usfmFiles.Count -ne $catalogBooks.Count) {
    throw "Quantidade de arquivos USFM inesperada. Esperado: $($catalogBooks.Count). Encontrado: $($usfmFiles.Count)."
}

New-Item -ItemType Directory -Force $OutputBooksDir | Out-Null

for ($index = 0; $index -lt $catalogBooks.Count; $index++) {
    $book = $catalogBooks[$index]
    $usfmFile = $usfmFiles[$index]
    $chapters = Convert-UsfmFileToChapters -Path $usfmFile.FullName
    $payload = ConvertTo-Json -InputObject $chapters -Depth 10 -Compress
    $content = "window.__BIBLIA_REGISTER_BOOK__('{0}', '{1}', {2});" -f $TranslationCode, $book.slug, $payload
    Write-Utf8File -Path (Join-Path $OutputBooksDir "$($book.slug).js") -Content $content
}

Write-Host "Arquivos da tradução $TranslationCode gerados em $OutputBooksDir"
