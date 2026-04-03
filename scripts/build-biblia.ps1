param(
    [string]$TranslationPath = ".codex_tmp\data\PorNVA.json",
    [string]$CrossReferenceDir = ".codex_tmp\data",
    [string]$OutputDir = "."
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
    $value = [regex]::Replace($value, '\s+', ' ')
    $value = [regex]::Replace($value, '\s+([,.;:?!])', '$1')
    $value = [regex]::Replace($value, '([(\[“"''`])\s+', '$1')
    $value = [regex]::Replace($value, '\s+([)\]”"''`])', '$1')
    $value = [regex]::Replace($value, '"([?!])', '$1"')
    $value = [regex]::Replace($value, '([?!])"\.', '$1"')
    $value = [regex]::Replace($value, '"\.', '."')
    $value = $value.Replace('"ou"', '" ou "')
    $value = $value.Replace('"(', '" (')

    foreach ($entry in $script:TextFixes.GetEnumerator()) {
        $value = $value.Replace($entry.Key, $entry.Value)
    }

    return $value.Trim()
}

function New-BookMeta {
    param(
        [int]$Index,
        [string]$Slug,
        [string]$Name,
        [string]$Abbreviation,
        [string]$Testament,
        [string[]]$EnglishNames
    )

    [pscustomobject]@{
        index        = $Index
        slug         = $Slug
        name         = $Name
        abbr         = $Abbreviation
        testament    = $Testament
        englishNames = $EnglishNames
    }
}

$script:TextFixes = @{
    'ressureição' = 'ressurreição'
    'espécieis'   = 'espécies'
    'macho e fêmea Deus os criou' = 'macho e fêmea os criou'
}

$bookCatalog = @(
    (New-BookMeta -Index 0 -Slug 'genesis' -Name 'Gênesis' -Abbreviation 'Gn' -Testament 'AT' -EnglishNames @('Genesis')),
    (New-BookMeta -Index 1 -Slug 'exodo' -Name 'Êxodo' -Abbreviation 'Êx' -Testament 'AT' -EnglishNames @('Exodus')),
    (New-BookMeta -Index 2 -Slug 'levitico' -Name 'Levítico' -Abbreviation 'Lv' -Testament 'AT' -EnglishNames @('Leviticus')),
    (New-BookMeta -Index 3 -Slug 'numeros' -Name 'Números' -Abbreviation 'Nm' -Testament 'AT' -EnglishNames @('Numbers')),
    (New-BookMeta -Index 4 -Slug 'deuteronomio' -Name 'Deuteronômio' -Abbreviation 'Dt' -Testament 'AT' -EnglishNames @('Deuteronomy')),
    (New-BookMeta -Index 5 -Slug 'josue' -Name 'Josué' -Abbreviation 'Js' -Testament 'AT' -EnglishNames @('Joshua')),
    (New-BookMeta -Index 6 -Slug 'juizes' -Name 'Juízes' -Abbreviation 'Jz' -Testament 'AT' -EnglishNames @('Judges')),
    (New-BookMeta -Index 7 -Slug 'rute' -Name 'Rute' -Abbreviation 'Rt' -Testament 'AT' -EnglishNames @('Ruth')),
    (New-BookMeta -Index 8 -Slug '1-samuel' -Name '1 Samuel' -Abbreviation '1Sm' -Testament 'AT' -EnglishNames @('1 Samuel', 'I Samuel')),
    (New-BookMeta -Index 9 -Slug '2-samuel' -Name '2 Samuel' -Abbreviation '2Sm' -Testament 'AT' -EnglishNames @('2 Samuel', 'II Samuel')),
    (New-BookMeta -Index 10 -Slug '1-reis' -Name '1 Reis' -Abbreviation '1Rs' -Testament 'AT' -EnglishNames @('1 Kings', 'I Kings')),
    (New-BookMeta -Index 11 -Slug '2-reis' -Name '2 Reis' -Abbreviation '2Rs' -Testament 'AT' -EnglishNames @('2 Kings', 'II Kings')),
    (New-BookMeta -Index 12 -Slug '1-cronicas' -Name '1 Crônicas' -Abbreviation '1Cr' -Testament 'AT' -EnglishNames @('1 Chronicles', 'I Chronicles')),
    (New-BookMeta -Index 13 -Slug '2-cronicas' -Name '2 Crônicas' -Abbreviation '2Cr' -Testament 'AT' -EnglishNames @('2 Chronicles', 'II Chronicles')),
    (New-BookMeta -Index 14 -Slug 'esdras' -Name 'Esdras' -Abbreviation 'Ed' -Testament 'AT' -EnglishNames @('Ezra')),
    (New-BookMeta -Index 15 -Slug 'neemias' -Name 'Neemias' -Abbreviation 'Ne' -Testament 'AT' -EnglishNames @('Nehemiah')),
    (New-BookMeta -Index 16 -Slug 'ester' -Name 'Ester' -Abbreviation 'Et' -Testament 'AT' -EnglishNames @('Esther')),
    (New-BookMeta -Index 17 -Slug 'jo' -Name 'Jó' -Abbreviation 'Jó' -Testament 'AT' -EnglishNames @('Job')),
    (New-BookMeta -Index 18 -Slug 'salmos' -Name 'Salmos' -Abbreviation 'Sl' -Testament 'AT' -EnglishNames @('Psalms', 'Psalm')),
    (New-BookMeta -Index 19 -Slug 'proverbios' -Name 'Provérbios' -Abbreviation 'Pv' -Testament 'AT' -EnglishNames @('Proverbs')),
    (New-BookMeta -Index 20 -Slug 'eclesiastes' -Name 'Eclesiastes' -Abbreviation 'Ec' -Testament 'AT' -EnglishNames @('Ecclesiastes')),
    (New-BookMeta -Index 21 -Slug 'cantares' -Name 'Cânticos' -Abbreviation 'Ct' -Testament 'AT' -EnglishNames @('Song of Solomon', 'Song of Songs', 'Canticles')),
    (New-BookMeta -Index 22 -Slug 'isaias' -Name 'Isaías' -Abbreviation 'Is' -Testament 'AT' -EnglishNames @('Isaiah')),
    (New-BookMeta -Index 23 -Slug 'jeremias' -Name 'Jeremias' -Abbreviation 'Jr' -Testament 'AT' -EnglishNames @('Jeremiah')),
    (New-BookMeta -Index 24 -Slug 'lamentacoes' -Name 'Lamentações' -Abbreviation 'Lm' -Testament 'AT' -EnglishNames @('Lamentations')),
    (New-BookMeta -Index 25 -Slug 'ezequiel' -Name 'Ezequiel' -Abbreviation 'Ez' -Testament 'AT' -EnglishNames @('Ezekiel')),
    (New-BookMeta -Index 26 -Slug 'daniel' -Name 'Daniel' -Abbreviation 'Dn' -Testament 'AT' -EnglishNames @('Daniel')),
    (New-BookMeta -Index 27 -Slug 'oseias' -Name 'Oséias' -Abbreviation 'Os' -Testament 'AT' -EnglishNames @('Hosea')),
    (New-BookMeta -Index 28 -Slug 'joel' -Name 'Joel' -Abbreviation 'Jl' -Testament 'AT' -EnglishNames @('Joel')),
    (New-BookMeta -Index 29 -Slug 'amos' -Name 'Amós' -Abbreviation 'Am' -Testament 'AT' -EnglishNames @('Amos')),
    (New-BookMeta -Index 30 -Slug 'obadias' -Name 'Obadias' -Abbreviation 'Ob' -Testament 'AT' -EnglishNames @('Obadiah')),
    (New-BookMeta -Index 31 -Slug 'jonas' -Name 'Jonas' -Abbreviation 'Jn' -Testament 'AT' -EnglishNames @('Jonah')),
    (New-BookMeta -Index 32 -Slug 'miqueias' -Name 'Miqueias' -Abbreviation 'Mq' -Testament 'AT' -EnglishNames @('Micah')),
    (New-BookMeta -Index 33 -Slug 'naum' -Name 'Naum' -Abbreviation 'Na' -Testament 'AT' -EnglishNames @('Nahum')),
    (New-BookMeta -Index 34 -Slug 'habacuque' -Name 'Habacuque' -Abbreviation 'Hc' -Testament 'AT' -EnglishNames @('Habakkuk')),
    (New-BookMeta -Index 35 -Slug 'sofonias' -Name 'Sofonias' -Abbreviation 'Sf' -Testament 'AT' -EnglishNames @('Zephaniah')),
    (New-BookMeta -Index 36 -Slug 'ageu' -Name 'Ageu' -Abbreviation 'Ag' -Testament 'AT' -EnglishNames @('Haggai')),
    (New-BookMeta -Index 37 -Slug 'zacarias' -Name 'Zacarias' -Abbreviation 'Zc' -Testament 'AT' -EnglishNames @('Zechariah')),
    (New-BookMeta -Index 38 -Slug 'malaquias' -Name 'Malaquias' -Abbreviation 'Ml' -Testament 'AT' -EnglishNames @('Malachi')),
    (New-BookMeta -Index 39 -Slug 'mateus' -Name 'Mateus' -Abbreviation 'Mt' -Testament 'NT' -EnglishNames @('Matthew')),
    (New-BookMeta -Index 40 -Slug 'marcos' -Name 'Marcos' -Abbreviation 'Mc' -Testament 'NT' -EnglishNames @('Mark')),
    (New-BookMeta -Index 41 -Slug 'lucas' -Name 'Lucas' -Abbreviation 'Lc' -Testament 'NT' -EnglishNames @('Luke')),
    (New-BookMeta -Index 42 -Slug 'joao' -Name 'João' -Abbreviation 'Jo' -Testament 'NT' -EnglishNames @('John')),
    (New-BookMeta -Index 43 -Slug 'atos' -Name 'Atos' -Abbreviation 'At' -Testament 'NT' -EnglishNames @('Acts', 'Acts of the Apostles')),
    (New-BookMeta -Index 44 -Slug 'romanos' -Name 'Romanos' -Abbreviation 'Rm' -Testament 'NT' -EnglishNames @('Romans')),
    (New-BookMeta -Index 45 -Slug '1-corintios' -Name '1 Coríntios' -Abbreviation '1Co' -Testament 'NT' -EnglishNames @('1 Corinthians', 'I Corinthians')),
    (New-BookMeta -Index 46 -Slug '2-corintios' -Name '2 Coríntios' -Abbreviation '2Co' -Testament 'NT' -EnglishNames @('2 Corinthians', 'II Corinthians')),
    (New-BookMeta -Index 47 -Slug 'galatas' -Name 'Gálatas' -Abbreviation 'Gl' -Testament 'NT' -EnglishNames @('Galatians')),
    (New-BookMeta -Index 48 -Slug 'efesios' -Name 'Efésios' -Abbreviation 'Ef' -Testament 'NT' -EnglishNames @('Ephesians')),
    (New-BookMeta -Index 49 -Slug 'filipenses' -Name 'Filipenses' -Abbreviation 'Fp' -Testament 'NT' -EnglishNames @('Philippians')),
    (New-BookMeta -Index 50 -Slug 'colossenses' -Name 'Colossenses' -Abbreviation 'Cl' -Testament 'NT' -EnglishNames @('Colossians')),
    (New-BookMeta -Index 51 -Slug '1-tessalonicenses' -Name '1 Tessalonicenses' -Abbreviation '1Ts' -Testament 'NT' -EnglishNames @('1 Thessalonians', 'I Thessalonians')),
    (New-BookMeta -Index 52 -Slug '2-tessalonicenses' -Name '2 Tessalonicenses' -Abbreviation '2Ts' -Testament 'NT' -EnglishNames @('2 Thessalonians', 'II Thessalonians')),
    (New-BookMeta -Index 53 -Slug '1-timoteo' -Name '1 Timóteo' -Abbreviation '1Tm' -Testament 'NT' -EnglishNames @('1 Timothy', 'I Timothy')),
    (New-BookMeta -Index 54 -Slug '2-timoteo' -Name '2 Timóteo' -Abbreviation '2Tm' -Testament 'NT' -EnglishNames @('2 Timothy', 'II Timothy')),
    (New-BookMeta -Index 55 -Slug 'tito' -Name 'Tito' -Abbreviation 'Tt' -Testament 'NT' -EnglishNames @('Titus')),
    (New-BookMeta -Index 56 -Slug 'filemom' -Name 'Filemom' -Abbreviation 'Fm' -Testament 'NT' -EnglishNames @('Philemon')),
    (New-BookMeta -Index 57 -Slug 'hebreus' -Name 'Hebreus' -Abbreviation 'Hb' -Testament 'NT' -EnglishNames @('Hebrews')),
    (New-BookMeta -Index 58 -Slug 'tiago' -Name 'Tiago' -Abbreviation 'Tg' -Testament 'NT' -EnglishNames @('James')),
    (New-BookMeta -Index 59 -Slug '1-pedro' -Name '1 Pedro' -Abbreviation '1Pe' -Testament 'NT' -EnglishNames @('1 Peter', 'I Peter')),
    (New-BookMeta -Index 60 -Slug '2-pedro' -Name '2 Pedro' -Abbreviation '2Pe' -Testament 'NT' -EnglishNames @('2 Peter', 'II Peter')),
    (New-BookMeta -Index 61 -Slug '1-joao' -Name '1 João' -Abbreviation '1Jo' -Testament 'NT' -EnglishNames @('1 John', 'I John')),
    (New-BookMeta -Index 62 -Slug '2-joao' -Name '2 João' -Abbreviation '2Jo' -Testament 'NT' -EnglishNames @('2 John', 'II John')),
    (New-BookMeta -Index 63 -Slug '3-joao' -Name '3 João' -Abbreviation '3Jo' -Testament 'NT' -EnglishNames @('3 John', 'III John')),
    (New-BookMeta -Index 64 -Slug 'judas' -Name 'Judas' -Abbreviation 'Jd' -Testament 'NT' -EnglishNames @('Jude')),
    (New-BookMeta -Index 65 -Slug 'apocalipse' -Name 'Apocalipse' -Abbreviation 'Ap' -Testament 'NT' -EnglishNames @('Revelation', 'Revelation of John'))
)

$englishToMeta = @{}
foreach ($meta in $bookCatalog) {
    foreach ($alias in $meta.englishNames) {
        $englishToMeta[$alias] = $meta
    }
}

$translationFile = Join-Path $OutputDir $TranslationPath
$crossReferencePath = Join-Path $OutputDir $CrossReferenceDir
$dataDir = Join-Path $OutputDir 'data'
$booksDir = Join-Path $dataDir 'books'
$refsDir = Join-Path $dataDir 'refs'

if (-not (Test-Path -LiteralPath $translationFile)) {
    throw "Arquivo da tradução não encontrado: $translationFile"
}

New-Item -ItemType Directory -Force $booksDir, $refsDir | Out-Null

Write-Host "Lendo tradução em português..."
$translationJson = Get-Content -LiteralPath $translationFile -Raw -Encoding UTF8 | ConvertFrom-Json

if ($translationJson.books.Count -ne $bookCatalog.Count) {
    throw "Quantidade inesperada de livros. Esperado: $($bookCatalog.Count). Encontrado: $($translationJson.books.Count)."
}

for ($i = 0; $i -lt $bookCatalog.Count; $i++) {
    $meta = $bookCatalog[$i]
    $book = $translationJson.books[$i]
    $chapters = @()

    foreach ($chapter in $book.chapters) {
        $verseList = @()
        $sortedVerses = $chapter.verses | Sort-Object { [int]$_.verse }

        foreach ($verse in $sortedVerses) {
            $verseNumber = [int]$verse.verse
            while ($verseList.Count -lt ($verseNumber - 1)) {
                $verseList += $null
            }

            $verseList += (Normalize-Text $verse.text)
        }

        $chapters += ,$verseList
    }

    $meta | Add-Member -NotePropertyName chapterCount -NotePropertyValue $chapters.Count -Force

    $bookPayload = ConvertTo-Json -InputObject $chapters -Depth 8 -Compress
    Write-Utf8File -Path (Join-Path $booksDir "$($meta.slug).js") -Content ("window.__BIBLIA_REGISTER_BOOK__('{0}', {1});" -f $meta.slug, $bookPayload)
}

$catalogPayload = @{
    translation = @{
        code        = 'PorNVA'
        name        = 'Bíblia Nova Versão de Acesso Livre'
        license     = 'Creative Commons BY-SA 4.0'
        attribution = 'Texto-base em português com licença aberta. Referências cruzadas adaptadas do projeto OpenBible.info.'
    }
    books = @(
        $bookCatalog | ForEach-Object {
            @{
                index        = $_.index
                slug         = $_.slug
                name         = $_.name
                abbr         = $_.abbr
                testament    = $_.testament
                chapterCount = $_.chapterCount
            }
        }
    )
}

Write-Utf8File -Path (Join-Path $dataDir 'catalog.js') -Content ("window.__BIBLIA_CONFIG__ = " + ((ConvertTo-Json -InputObject $catalogPayload -Depth 8 -Compress)) + ";")

$refsByBook = @{}
foreach ($meta in $bookCatalog) {
    $refsByBook[$meta.slug] = @{}
}

Write-Host "Lendo referências cruzadas..."
foreach ($crossRefFile in (Get-ChildItem -LiteralPath $crossReferencePath -Filter 'cross_references_*.json' | Sort-Object Name)) {
    Write-Host ("Processando {0}..." -f $crossRefFile.Name)
    $crossData = Get-Content -LiteralPath $crossRefFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($entry in $crossData.cross_references) {
        $fromMeta = $englishToMeta[$entry.from_verse.book]
        if (-not $fromMeta) {
            continue
        }

        $key = "{0}:{1}" -f [int]$entry.from_verse.chapter, [int]$entry.from_verse.verse
        if (-not $refsByBook[$fromMeta.slug].ContainsKey($key)) {
            $refsByBook[$fromMeta.slug][$key] = New-Object System.Collections.ArrayList
        }

        foreach ($target in $entry.to_verse) {
            $toMeta = $englishToMeta[$target.book]
            if (-not $toMeta) {
                continue
            }

            [void]$refsByBook[$fromMeta.slug][$key].Add([object[]]@(
                [int]$toMeta.index,
                [int]$target.chapter,
                [int]$target.verse_start,
                [int]$target.verse_end,
                [int]$entry.votes
            ))
        }
    }
}

$maxReferencesPerVerse = 10
foreach ($meta in $bookCatalog) {
    Write-Host ("Gravando referências de {0}..." -f $meta.name)
    $verseMap = @{}

    foreach ($verseKey in $refsByBook[$meta.slug].Keys) {
        $dedup = @{}

        foreach ($ref in $refsByBook[$meta.slug][$verseKey]) {
            $refKey = "{0}:{1}:{2}:{3}" -f $ref[0], $ref[1], $ref[2], $ref[3]
            if (-not $dedup.ContainsKey($refKey) -or ($ref[4] -gt $dedup[$refKey][4])) {
                $dedup[$refKey] = $ref
            }
        }

        $topRefs = @(
            $dedup.Values |
                Sort-Object @{ Expression = { $_[4] }; Descending = $true }, @{ Expression = { $_[0] } }, @{ Expression = { $_[1] } }, @{ Expression = { $_[2] } } |
                Select-Object -First $maxReferencesPerVerse
        )

        if ($topRefs.Count -gt 0) {
            $plainRefs = @()
            foreach ($ref in $topRefs) {
                $plainRefs += ,([object[]]$ref)
            }

            $verseMap[$verseKey] = $plainRefs
        }
    }

    $refsPayload = ConvertTo-Json -InputObject $verseMap -Depth 12 -Compress
    Write-Utf8File -Path (Join-Path $refsDir "$($meta.slug).js") -Content ("window.__BIBLIA_REGISTER_REFS__('{0}', {1});" -f $meta.slug, $refsPayload)
}

Write-Host "Dados gerados em $dataDir"
