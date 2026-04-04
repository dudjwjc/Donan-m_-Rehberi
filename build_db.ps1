$files = Get-ChildItem -Path . -Filter *.html
$cpus = @{}
$gpus = @{}

foreach ($f in $files) {
    if ($f.Name -match "index\.html|karsilastirma\.html|anakartlar\.html|islemciler\.html|ekran-kartlari\.html|iletisim\.html") { continue }
    
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    
    $isGPU = $f.Name -match "gpu-"
    $isCPU = $false
    
    $title = ""
    # "Intel Core i9-14900KS - Detay" veya sadece başlık
    if ($content -match "<title>([\s\S]*?)( - Detay)?</title>") {
        $title = $matches[1].Trim()
    }
    
    if (!$isGPU) {
        # Tablolarda Çekirdek, Frekans, İş Parçacığı vb özellikleri var mı?
        # Ayrıca Yonga Seti / VRM gibi anakart özellikleri varsa CPU değildir.
        if ($content -match "Çekirdek|Frekans|İş Parçacığı|Soket|TDP") {
             if ($content -match "Yonga Seti|Genişleme Yuvaları|VRM") {
                 # Anakart, atla
             } else {
                 $isCPU = $true
             }
        }
    }
    
    if ($isGPU -or $isCPU) {
        $productProps = @{}
        $productProps["img"] = if ($isGPU) { 
            if ($content -match "nvidia|geforce|rtx|gtx") { "nvidia_gpu_gen.png" } elseif ($content -match "radeon|amd|rx") { "amd_gpu_gen.png" } elseif ($content -match "intel|arc") { "intel_placeholder.png" } else { "nvidia_gpu_gen.png" }
        } else {
            if ($content -match "AMD|Ryzen|Athlon|Threadripper|Epyc") { "amd_placeholder.png" } else { "intel_placeholder.png" }
        }
        
        $matchescol = [regex]::Matches($content, "<th[^>]*>([^<]+)</th>\s*<td[^>]*>([^<]+)</td>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($m in $matchescol) {
            $key = $m.Groups[1].Value -replace "<[^>]+>","" -replace "^\s+|\s+$",""
            $val = $m.Groups[2].Value -replace "<[^>]+>","" -replace "^\s+|\s+$",""
            if (![string]::IsNullOrWhiteSpace($key)) {
                $productProps[$key] = $val
            }
        }
        
        if ($productProps.Count -gt 1 -and $title -ne "") {
            $title = $title -replace " \(Masaüstü\)", "" -replace " \(Laptop\)", " (Mobil)"
            
            # Aynı isimde iki ürün çıkarsa birleştir mi? Genelde farklı modeller (Masaüstü vs Mobil) olabilir.
            # Şu anki isimlendirme Desktop kısmını attığı için çakışma olabilir. "Mobil"i attırmadık.
            
            if ($isGPU) { $gpus[$title] = $productProps } else { $cpus[$title] = $productProps }
        }
    }
}

$output = "const db = {`r`n    islemci: {"
$cpuKeys = $cpus.Keys | Sort-Object
foreach ($k in $cpuKeys) {
    $props = $cpus[$k]
    $propsJsonArr = @()
    foreach ($p in $props.Keys) {
        $keyEsc = $p.Replace('"', '\"')
        $valEsc = $props[$p].Replace('"', '\"').Replace("`n", " ").Replace("`r", "")
        $propsJsonArr += "`"$keyEsc`": `"$valEsc`""
    }
    $propsJson = $propsJsonArr -join ", "
    $titleEsc = $k.Replace('"', '\"').Replace("`n", "").Replace("`r", "")
    $output += "`r`n        `"$titleEsc`": { $propsJson },"
}
$output += "`r`n    },`r`n    ekranKarti: {"
$gpuKeys = $gpus.Keys | Sort-Object
foreach ($k in $gpuKeys) {
    $props = $gpus[$k]
    $propsJsonArr = @()
    foreach ($p in $props.Keys) {
        $keyEsc = $p.Replace('"', '\"')
        $valEsc = $props[$p].Replace('"', '\"').Replace("`n", " ").Replace("`r", "")
        $propsJsonArr += "`"$keyEsc`": `"$valEsc`""
    }
    $propsJson = $propsJsonArr -join ", "
    $titleEsc = $k.Replace('"', '\"').Replace("`n", "").Replace("`r", "")
    $output += "`r`n        `"$titleEsc`": { $propsJson },"
}
$output += "`r`n    }`r`n};`r`n"

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("db.js", $output, $utf8NoBom)
Write-Output "db.js olusturuldu. Islemci sayisi: $($cpus.Count). Ekran karti sayisi: $($gpus.Count)"
