# PathValidator.ps1
param(
    [switch]$Fix
)

# Constantes para as chaves do Registro
$UserPathKey = "HKCU:\Environment"
$SystemPathKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$Separator = ";"

# --- Funções de Ajuda ---

# Função para normalizar caminhos (ignora caixa e remove barra final)
function Get-NormalizedPath {
    param(
        [string]$Path
    )
    if (-not $Path) { return "" }
    
    # Converte para minúsculas e remove a barra final (Windows é case-insensitive)
    $Normalized = $Path.ToLower()
    if ($Normalized.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $Normalized = $Normalized.Substring(0, $Normalized.Length - 1)
    }
    return $Normalized
}

# Função principal de validação e limpeza
function Optimize-PathString {
    param(
        [string]$RawPath,
        [string]$ScopeName,
        [hashtable]$SystemPaths = @{}  # Caminhos do Sistema para detectar duplicatas
    )
    
    $Paths = $RawPath.Split($Separator) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    $UniquePaths = @{} # Usado como um Set para rastrear caminhos normalizados
    $CleanedPaths = @()
    $ReportList = @()

    Write-Host "`n### -> PATH de $ScopeName (Entradas totais: $($Paths.Count))" -ForegroundColor Cyan

    foreach ($PathEntry in $Paths) {
        $NormalizedPath = Get-NormalizedPath $PathEntry
        $Status = "OK"
        
        # 1. Verificação de Variável Composta (contém %VARIAVEL% ou $VARIAVEL)
        if ($PathEntry -match '%[^%]+%|\$[A-Z_][A-Z0-9_]*') {
            $Status = "Ignorado"
            # Não adiciona ao CleanedPaths, mas adiciona ao relatório
        }
        # 2. Verificação de Duplicidade com PATH do Sistema (apenas para PATH do Usuário)
        elseif ($SystemPaths.Count -gt 0 -and $SystemPaths.ContainsKey($NormalizedPath)) {
            $Status = "Duplicada em Sistema"
            # Não adiciona ao CleanedPaths quando em modo Fix
        }
        # 3. Verificação de Duplicidade no mesmo escopo
        elseif ($UniquePaths.ContainsKey($NormalizedPath)) {
            $Status = "Duplicado"
        }
        else {
            # Marca como único para rastreamento
            $UniquePaths.Add($NormalizedPath, $true)

            # 4. Verificação de Existência (Apenas diretórios são considerados válidos)
            if (Test-Path -Path $PathEntry -PathType Container) {
                $CleanedPaths += $PathEntry
                $Status = "OK"
            }
            else {
                $Status = "Invalido/Nao Encontrado"
            }
        }

        $ReportList += [PSCustomObject]@{
            Status  = $Status
            Caminho = $PathEntry
        }
    }
    
    # Exibe a tabela com todos os caminhos e seus status
    $ReportList | Format-Table -AutoSize | Out-Host
    
    # Retorna o PATH limpo (válidos e únicos)
    return $CleanedPaths -join $Separator
}

# --- Bloco Principal de Execução ---

Write-Host "===================================================" -ForegroundColor White
if ($Fix) {
    Write-Host "| MODO: AJUSTE (--Fix) |" -ForegroundColor Yellow
    Write-Host "| Necessita de permissões de ADMIN para o PATH de Sistema (HKLM) |" -ForegroundColor Red
}
else {
    Write-Host "| MODO: RELATORIO |" -ForegroundColor Cyan
}
Write-Host "===================================================" -ForegroundColor White


# 1. Recuperação dos PATHs (Leitura Direta do Registro)
# -Force para garantir que não haja erro se a chave/propriedade estiver vazia
$UserPath = (Get-ItemProperty -Path $UserPathKey -ErrorAction SilentlyContinue).Path
$SystemPath = (Get-ItemProperty -Path $SystemPathKey -ErrorAction SilentlyContinue).Path

# 2. Primeiro, processa o PATH do Sistema para criar um índice de caminhos
Write-Host "`n[INFO] Processando PATH do Sistema primeiro para detectar duplicatas..." -ForegroundColor Cyan
$SystemPathsNormalized = @{}
if ($SystemPath) {
    $SystemPath.Split($Separator) | ForEach-Object { 
        $trimmed = $_.Trim()
        if ($trimmed) {
            $normalized = Get-NormalizedPath $trimmed
            if (-not $SystemPathsNormalized.ContainsKey($normalized)) {
                $SystemPathsNormalized.Add($normalized, $true)
            }
        }
    }
}

# 3. Validação e Geração dos Novos PATHs (Limpos)
$NewSystemPath = Optimize-PathString -RawPath $SystemPath -ScopeName "Sistema (HKLM)"
$NewUserPath = Optimize-PathString -RawPath $UserPath -ScopeName "Usuario (HKCU)" -SystemPaths $SystemPathsNormalized

# 4. Aplicação das Mudanças (Modo --Fix)
if ($Fix) {
    Write-Host "`n===================================================" -ForegroundColor White
    Write-Host "| EXECUTANDO AJUSTES (REMOCAO) |" -ForegroundColor Yellow
    Write-Host "===================================================" -ForegroundColor White

    # Atualiza PATH do Usuário (sempre funciona)
    try {
        Set-ItemProperty -Path $UserPathKey -Name Path -Value $NewUserPath -Type String
        Write-Host "`n[OK] PATH de Usuario atualizado com sucesso." -ForegroundColor Green
    }
    catch {
        Write-Host "`n[X] ERRO ao atualizar PATH de Usuario: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Atualiza PATH de Sistema (Requer Admin)
    try {
        Set-ItemProperty -Path $SystemPathKey -Name Path -Value $NewSystemPath -Type String
        Write-Host "`n[OK] PATH de Sistema atualizado com sucesso." -ForegroundColor Green
    }
    catch {
        Write-Host "`n[X] ERRO ao atualizar PATH de Sistema: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Isso geralmente ocorre se o PowerShell não foi executado como **Administrador**." -ForegroundColor Red
    }
    
    Write-Host "`n[DONE] Ajuste concluido! Voce precisa **reiniciar seu terminal/sessao** para que as novas variaveis PATH entrem em vigor." -ForegroundColor Magenta
}
else {
    Write-Host "`n Para remover os caminhos inexistentes e duplicados, execute com o parametro -Fix." -ForegroundColor Yellow
}