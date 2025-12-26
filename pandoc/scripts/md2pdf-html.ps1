param(
    [Parameter(Mandatory = $true)]
    [string] $InputPath,
    [string] $OutputPath,
    [string] $PandocPath,
    [string] $BrowserPath
)

function Get-AsciiString
{
    param(
        [string] $Text
    )

    if (-not $Text)
    {
        return ""
    }

    $chars = $Text.ToCharArray() | Where-Object { [int][char] $_ -le 127 }
    return -join $chars
}

if (-not (Test-Path -LiteralPath $InputPath))
{
    $inputDir = Split-Path -Parent $InputPath

    if (Test-Path -LiteralPath $inputDir)
    {
        $candidates = Get-ChildItem -LiteralPath $inputDir -Filter "*.md" -File

        if ($candidates.Count -eq 1)
        {
            $InputPath = $candidates[0].FullName
        }
    }
}

if (-not (Test-Path -LiteralPath $InputPath))
{
    throw "Input file not found. Please check the path or run this script directly in PowerShell to avoid encoding issues with file names."
}

if (-not $OutputPath)
{
    $OutputPath = [System.IO.Path]::ChangeExtension($InputPath, ".pdf")
}

$outputDir = Split-Path -Parent $OutputPath
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$htmlDir = Join-Path $outputDir "tmp\\html"
$imageTempDir = Join-Path $outputDir "tmp"
$filterPath = Join-Path $rootDir "filters\\mermaid-html.lua"
$cssPath = Join-Path $rootDir "html\\style.css"

if (-not (Test-Path -LiteralPath $imageTempDir))
{
    New-Item -ItemType Directory -Path $imageTempDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $htmlDir))
{
    New-Item -ItemType Directory -Path $htmlDir -Force | Out-Null
}

$env:MERMAID_OUTPUT_DIR = $imageTempDir

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
$htmlPath = Join-Path $htmlDir ($baseName + ".html")

if (-not $PandocPath -or $PandocPath -eq "")
{
    $PandocPath = "pandoc"
}

if (-not (Get-Command $PandocPath -ErrorAction SilentlyContinue))
{
    $possiblePaths = @(
        "C:\Program Files\Pandoc\pandoc.exe",
        "C:\Program Files (x86)\Pandoc\pandoc.exe"
    )

    foreach ($path in $possiblePaths)
    {
        if (Test-Path $path)
        {
            $PandocPath = $path
            break
        }
    }
}

$pandocArgs = @(
    $InputPath,
    "--from=markdown",
    "--to=html",
    "--standalone",
    "--embed-resources",
    ("--lua-filter=" + $filterPath),
    ("--css=" + $cssPath),
    "-V", "lang=zh-TW",
    "-o", $htmlPath
)

& $PandocPath @pandocArgs

if (-not (Test-Path -LiteralPath $htmlPath))
{
    throw "HTML output was not created. Please check pandoc output."
}

if ($BrowserPath -and $BrowserPath -ne "")
{
    if (-not (Test-Path -LiteralPath $BrowserPath))
    {
        $BrowserPath = ""
    }
}

if (-not $BrowserPath -or $BrowserPath -eq "")
{
    $cmdEdge = Get-Command "msedge" -ErrorAction SilentlyContinue
    $cmdChrome = Get-Command "chrome" -ErrorAction SilentlyContinue

    if ($cmdEdge)
    {
        $BrowserPath = $cmdEdge.Path
    }
    elseif ($cmdChrome)
    {
        $BrowserPath = $cmdChrome.Path
    }
    else
    {
        $browserCandidates = @(
            "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Edge\Application\msedge.exe",
            "C:\Program Files\Google\Chrome\Application\chrome.exe",
            "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome\Application\chrome.exe"
        )

        foreach ($path in $browserCandidates)
        {
            if (Test-Path $path)
            {
                $BrowserPath = $path
                break
            }
        }
    }
}

if (-not $BrowserPath -or $BrowserPath -eq "")
{
    throw "Browser not found. Please install Edge or Chrome, or pass -BrowserPath."
}

$printScript = Join-Path $scriptDir "print-pdf.js"
$nodeCommand = Get-Command "node" -ErrorAction SilentlyContinue

if ($nodeCommand -and (Test-Path -LiteralPath $printScript))
{
    $npmCommand = Get-Command "npm" -ErrorAction SilentlyContinue

    if ($npmCommand)
    {
        $npmRoot = & $npmCommand.Path "root" "-g"

        if ($LASTEXITCODE -eq 0 -and $npmRoot)
        {
            $env:NODE_PATH = $npmRoot
        }
    }

    $nodeArgs = @(
        $printScript,
        $htmlPath,
        $OutputPath
    )

    if ($BrowserPath -and $BrowserPath -ne "")
    {
        $nodeArgs += $BrowserPath
    }

    & $nodeCommand.Path @nodeArgs
    exit $LASTEXITCODE
}

$fileUri = "file:///" + ($htmlPath -replace "\\", "/")
$printArgs = @(
    "--headless=old",
    "--disable-gpu",
    "--disable-features=PrintBrowser",
    ("--print-to-pdf=" + $OutputPath),
    $fileUri
)

& $BrowserPath @printArgs
