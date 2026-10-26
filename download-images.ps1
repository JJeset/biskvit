# Скачивает фото товаров «Бисквита» в папку images рядом со скриптом.
# Список берёт из products.json (поле image_url -> файл из поля image).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$json = Join-Path $root 'products.json'
if (-not (Test-Path $json)) { Write-Host "Не найден products.json рядом со скриптом" -ForegroundColor Red; exit 1 }

$data = Get-Content -Raw -Encoding UTF8 $json | ConvertFrom-Json
$dir = Join-Path $root 'images'
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$total = $data.products.Count
$ok = 0; $skip = 0; $fail = @()
$i = 0
foreach ($p in $data.products) {
    $i++
    $out = Join-Path $root ($p.image -replace '/', '\')
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) { $skip++; continue }
    Write-Progress -Activity 'Скачиваю фото' -Status "$i из $total : $($p.name)" -PercentComplete ($i * 100 / $total)
    try {
        Invoke-WebRequest -Uri $p.image_url -OutFile $out -UseBasicParsing -TimeoutSec 60
        $ok++
        Start-Sleep -Milliseconds 200
    } catch {
        $fail += "$($p.id)  $($p.image_url)"
        if (Test-Path $out) { Remove-Item $out }
    }
}
Write-Progress -Activity 'Скачиваю фото' -Completed

# Логотип и фавиконка
if ($data.brand -and $data.brand.logo) {
    $bdir = Join-Path $root 'images\brand'
    New-Item -ItemType Directory -Force -Path $bdir | Out-Null
    $brandFiles = @(
        @{ url = $data.brand.logo.url; out = Join-Path $root ($data.brand.logo.file -replace '/', '\') },
        @{ url = $data.brand.logo.favicon_url; out = Join-Path $bdir 'favicon.ico' }
    )
    foreach ($b in $brandFiles) {
        if ((Test-Path $b.out) -and ((Get-Item $b.out).Length -gt 0)) { continue }
        try { Invoke-WebRequest -Uri $b.url -OutFile $b.out -UseBasicParsing -TimeoutSec 60 }
        catch { $fail += "brand  $($b.url)" }
    }
}
Write-Host "Готово. Скачано: $ok, уже было: $skip, ошибок: $($fail.Count) из $total" -ForegroundColor Green
if ($fail.Count) {
    $fail | Set-Content -Encoding UTF8 (Join-Path $root 'images-failed.txt')
    Write-Host "Список ошибок: images-failed.txt. Запустите скрипт ещё раз, он докачает только недостающие." -ForegroundColor Yellow
}
