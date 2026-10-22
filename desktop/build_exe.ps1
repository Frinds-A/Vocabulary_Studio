[CmdletBinding()]
param(
    [string]$PythonExe = "python",
    [string]$BuildName = "词序"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$desktopRoot = $PSScriptRoot
$entryPoint = Join-Path $desktopRoot "app.py"
$qmlSource = Join-Path $desktopRoot "qml"
$assetsSource = Join-Path $desktopRoot "assets"
$vocabularySource = Join-Path $desktopRoot "data/vocabulary.json"
$versionFile = Join-Path $desktopRoot "version_info.txt"
$hooksRoot = Join-Path $desktopRoot "pyinstaller_hooks"
$distRoot = $repoRoot
$workRoot = Join-Path $repoRoot "build/pyinstaller/$BuildName"
$specRoot = Join-Path $repoRoot "build/pyinstaller/spec/$BuildName"

foreach ($requiredPath in @($entryPoint, (Join-Path $qmlSource "Main.qml"), $vocabularySource, $versionFile, (Join-Path $assetsSource "icon.ico"))) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required desktop build input was not found: $requiredPath"
    }
}

$pythonCommand = Get-Command $PythonExe -ErrorAction Stop
$pythonPath = $pythonCommand.Source
$runtimeInfo = & $pythonPath -c 'import sys, PySide6, PyInstaller; print(sys.version.split()[0], PySide6.__version__, PyInstaller.__version__)'
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect the selected Python environment."
}
Write-Host "Python / PySide6 / PyInstaller: $runtimeInfo"

$pysideSource = & $pythonPath -c 'import pathlib, PySide6; print(pathlib.Path(PySide6.__file__).parent)'
if ($LASTEXITCODE -ne 0 -or -not $pysideSource) {
    throw "Could not locate the PySide6 runtime DLL directory."
}

New-Item -ItemType Directory -Force -Path $distRoot, $workRoot, $specRoot | Out-Null
Push-Location $repoRoot
try {
    $arguments = @(
        "-m", "PyInstaller",
        "--noconfirm",
        "--clean",
        "--windowed",
        "--onefile",
        "--name", $BuildName,
        "--icon", (Join-Path $assetsSource "icon.ico"),
        "--version-file", $versionFile,
        "--distpath", $distRoot,
        "--workpath", $workRoot,
        "--specpath", $specRoot,
        "--additional-hooks-dir", $hooksRoot,
        "--add-data", "$qmlSource;qml",
        "--add-data", "$assetsSource;assets",
        "--add-data", "$vocabularySource;data",
        "--add-data", "$repoRoot\desktop\data\LICENSE-pypdf.txt;data",
        "--add-data", "$pysideSource\qml\QtQuick\Dialogs;PySide6\qml\QtQuick\Dialogs",
        "--exclude-module", "PySide6.QtWebEngineCore",
        "--exclude-module", "PySide6.QtWebEngineQuick",
        "--exclude-module", "PySide6.QtWebEngineWidgets",
        "--exclude-module", "PySide6.QtWebEngine",
        "--exclude-module", "PySide6.QtWebView",
        "--exclude-module", "PySide6.QtPdf",
        "--exclude-module", "PySide6.QtPdfWidgets",
        "--exclude-module", "PySide6.QtSql",
        "--exclude-module", "PySide6.QtWidgets",
        "--exclude-module", "PySide6.QtMultimediaWidgets",
        "--exclude-module", "PySide6.Qt3DCore",
        "--exclude-module", "PySide6.Qt3DRender",
        "--exclude-module", "PySide6.Qt3DInput",
        "--exclude-module", "PySide6.Qt3DLogic",
        "--exclude-module", "PySide6.Qt3DAnimation",
        "--exclude-module", "PySide6.QtQuick3D",
        "--exclude-module", "PySide6.QtQuickTest",
        "--exclude-module", "PySide6.QtTest",
        "--exclude-module", "PySide6.QtSensors",
        "--exclude-module", "PySide6.QtPositioning",
        "--exclude-module", "PySide6.QtBluetooth",
        "--exclude-module", "PySide6.QtNfc",
        "--exclude-module", "PySide6.QtSerialPort",
        "--exclude-module", "PySide6.QtWebSockets",
        "--exclude-module", "PySide6.QtConcurrent",
        "--exclude-module", "PySide6.QtPrintSupport",
        "--exclude-module", "PySide6.QtSvgWidgets",
        "--exclude-module", "PySide6.QtOpenGLWidgets",
        "--exclude-module", "PySide6.QtUiTools",
        "--exclude-module", "PySide6.QtDesigner",
        "--hidden-import", "PySide6.QtTextToSpeech",
        "--hidden-import", "pypdf",
        "--collect-submodules", "pypdf",
        "--exclude-module", "PIL",
        "--exclude-module", "numpy",
        "--exclude-module", "lxml",
        "--exclude-module", "cryptography",
        "--exclude-module", "psutil",
        "--exclude-module", "charset_normalizer",
        "--exclude-module", "webbrowser",
        "--exclude-module", "multiprocessing",
        $entryPoint
    )

    # The Qt wheel ships the exact MSVC runtime its binaries were built
    # against. Put those files at the archive root so QtCore resolves them
    # before any older system copy.
    foreach ($runtimeDll in @("VCRUNTIME140.dll", "VCRUNTIME140_1.dll", "MSVCP140.dll", "MSVCP140_1.dll", "MSVCP140_2.dll", "CONCRT140.dll")) {
        $sourceDll = Join-Path $pysideSource $runtimeDll
        if (Test-Path -LiteralPath $sourceDll) {
            $arguments += @("--add-binary", "$sourceDll;.")
        }
    }

    & $pythonPath @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$exePath = Join-Path $distRoot "$BuildName.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "PyInstaller completed, but the expected executable is missing: $exePath"
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $exePath).Length / 1MB, 1)
Write-Host "Build complete: $exePath ($sizeMb MB)"
Write-Host "Single-file build: only this .exe is required."
Write-Host "Learning data is saved separately under the user's local application data directory."
