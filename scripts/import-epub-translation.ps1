param(
    [Parameter(Mandatory = $true)][string]$EpubTextDir,
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

function Clean-HtmlVerseText {
    param([AllowNull()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $null
    }

    $value = $Html
    $value = [regex]::Replace($value, '<br\s*/?>', ' ', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $value = [regex]::Replace($value, '<[^>]+>', '')
    $value = [System.Net.WebUtility]::HtmlDecode($value)
    return Normalize-Text -Text $value
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

    [void]$Chapter.Add($VerseText)
}

function Parse-EpubBookFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $html = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path)
    $paragraphs = [regex]::Matches(
        $html,
        '<p\b[^>]*>.*?</p>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $chapters = New-Object System.Collections.ArrayList
    $currentChapter = $null

    foreach ($paragraphMatch in $paragraphs) {
        $paragraph = $paragraphMatch.Value

        if ($paragraph -match 'class="cap"') {
            if ($null -ne $currentChapter) {
                [void]$chapters.Add(@($currentChapter))
            }

            $currentChapter = New-Object System.Collections.ArrayList
            continue
        }

        if ($null -eq $currentChapter) {
            continue
        }

        if ($paragraph -match '<sup>(\d+)</sup>(.*)</p>$') {
            $verseNumber = [int]$Matches[1]
            $verseHtml = $Matches[2]
            Add-VerseToChapter -Chapter $currentChapter -VerseNumber $verseNumber -VerseText (Clean-HtmlVerseText -Html $verseHtml)
        }
    }

    if ($null -ne $currentChapter) {
        [void]$chapters.Add(@($currentChapter))
    }

    Write-Output -NoEnumerate @($chapters)
}

$catalogBooks = Read-CatalogBooks -Path $CatalogPath
$htmlFiles = @(
    Get-ChildItem -LiteralPath $EpubTextDir -Filter '*.html' |
        Where-Object { $_.BaseName -match '^\d{2}_.+' } |
        Sort-Object Name
)

if ($htmlFiles.Count -eq 0) {
    throw "Nenhum arquivo HTML de livro encontrado em $EpubTextDir"
}

New-Item -ItemType Directory -Force $OutputBooksDir | Out-Null

$fileIndex = 0
foreach ($book in $catalogBooks) {
    $chapters = New-Object System.Collections.ArrayList

    while ($chapters.Count -lt $book.chapterCount) {
        if ($fileIndex -ge $htmlFiles.Count) {
            throw "Fim inesperado dos arquivos EPUB ao processar $($book.slug)"
        }

        $parsedChapters = Parse-EpubBookFile -Path $htmlFiles[$fileIndex].FullName
        foreach ($chapter in $parsedChapters) {
            if ($chapters.Count -lt $book.chapterCount) {
                [void]$chapters.Add($chapter)
            } else {
                break
            }
        }

        $fileIndex++
    }

    if ($chapters.Count -ne $book.chapterCount) {
        throw "Contagem de capítulos inesperada para $($book.slug). Esperado: $($book.chapterCount). Encontrado: $($chapters.Count)."
    }

    if ($chapters.Count -eq 1) {
        $chapterPayload = [object[]]@($chapters[0])
        $payload = "[" + (ConvertTo-Json -InputObject $chapterPayload -Depth 10 -Compress) + "]"
    } else {
        $payloadData = @()
        foreach ($chapter in $chapters) {
            $payloadData += ,([object[]]@($chapter))
        }

        $payload = ConvertTo-Json -InputObject ([object[]]$payloadData) -Depth 10 -Compress
    }
    $content = "window.__BIBLIA_REGISTER_BOOK__('{0}', '{1}', {2});" -f $TranslationCode, $book.slug, $payload
    Write-Utf8File -Path (Join-Path $OutputBooksDir "$($book.slug).js") -Content $content
}

if ($fileIndex -ne $htmlFiles.Count) {
    throw "Sobrou conteúdo EPUB não utilizado. Arquivos restantes: $($htmlFiles.Count - $fileIndex)"
}

Write-Host "Arquivos da tradução $TranslationCode gerados em $OutputBooksDir"
