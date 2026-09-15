# =============================================================================
# PREPARACAO DO AMBIENTE PARA GRAVACAO DO VIDEO
#   .\scripts\prep-video.ps1            (compose apenas)
#   .\scripts\prep-video.ps1 -WithK8s   (compose + deploy no Kubernetes)
#
# Deixa tudo limpo, semeado e com carga no Grafana. Rode ~10 min antes de gravar.
# =============================================================================

param([switch]$WithK8s)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK: $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    AVISO: $m" -ForegroundColor Yellow }

Push-Location $root

# ---------------------------------------------------------------------------
Step "1/6 Derrubando ambiente anterior (volumes inclusos)"
docker compose down -v 2>&1 | Out-Null
Ok "ambiente limpo"

# ---------------------------------------------------------------------------
Step "2/6 Subindo tudo (build das imagens)"
docker compose up -d --build 2>&1 | Select-String -Pattern "Started|Healthy|Built|Error|error" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

Write-Host "    aguardando servicos ficarem prontos..." -ForegroundColor DarkGray
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 4
    try {
        $r = Invoke-RestMethod "http://localhost:8000/api/games" -TimeoutSec 5
        if ($r) { $ready = $true; break }
    } catch { }
}
if ($ready) { Ok "Gateway respondendo com $($r.Count) jogos no catalogo" }
else        { Warn "Gateway nao respondeu em 2 min. Rode 'docker compose ps' e 'docker compose logs kong'" }

# ---------------------------------------------------------------------------
Step "3/6 Limpando filas da Function (mensagens antigas)"
docker exec fcg-rabbitmq rabbitmqctl purge_queue notifications-user-created 2>&1 | Out-Null
docker exec fcg-rabbitmq rabbitmqctl purge_queue notifications-payment-processed 2>&1 | Out-Null
Ok "filas limpas"

# ---------------------------------------------------------------------------
Step "4/6 Gerando carga para o Grafana ter historico"
$n = 0
1..250 | ForEach-Object {
    try { Invoke-RestMethod "http://localhost:8000/api/games" -TimeoutSec 5 | Out-Null; $n++ } catch { }
    if ($_ % 50 -eq 0) { Write-Host "    $_ requisicoes..." -ForegroundColor DarkGray }
}
Ok "$n requisicoes enviadas"

# ---------------------------------------------------------------------------
Step "5/6 Verificando alvos do Prometheus"
try {
    $targets = Invoke-RestMethod "http://localhost:9090/api/v1/targets" -TimeoutSec 5
    $up = ($targets.data.activeTargets | Where-Object { $_.health -eq "up" }).Count
    $total = $targets.data.activeTargets.Count
    if ($up -eq $total) { Ok "$up/$total alvos UP" } else { Warn "$up/$total alvos UP - veja http://localhost:9090/targets" }
} catch { Warn "Prometheus nao respondeu" }

# ---------------------------------------------------------------------------
if ($WithK8s) {
    Step "6/6 Deploy no Kubernetes (Docker Desktop)"
    try {
        kubectl cluster-info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "cluster indisponivel" }
        & "$PSScriptRoot\deploy-k8s.ps1"
    } catch {
        Warn "Kubernetes nao disponivel: $_"
        Warn "Habilite em Docker Desktop > Settings > Kubernetes > Enable Kubernetes"
    }
} else {
    Step "6/6 Kubernetes"
    Write-Host "    pulado (use -WithK8s para incluir)" -ForegroundColor DarkGray
}

Pop-Location

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  AMBIENTE PRONTO PARA GRAVAR" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  AGORA, em ordem:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Abra um NOVO PowerShell (janela separada, nao aba) e cole as 3 linhas:" -ForegroundColor White
Write-Host '       $host.UI.RawUI.WindowTitle = "FCG-FUNC"' -ForegroundColor Cyan
Write-Host "       cd C:\Users\USUARIO\Dev\FCG-Fase3\fcg-notifications-function\src\FCG.Notifications.Function" -ForegroundColor Cyan
Write-Host '       func start 2>&1 | Tee-Object -FilePath "$env:TEMP\fcg-func.log"' -ForegroundColor Cyan
Write-Host "     Espere aparecer 'SendWelcomeEmail: rabbitMQTrigger'." -ForegroundColor DarkGray
Write-Host "     (o titulo FCG-FUNC permite que a demo traga essa janela para frente sozinha)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Deixe o navegador padrao ABERTO em uma aba em branco (evita demora no 1o link)." -ForegroundColor White
Write-Host ""
Write-Host "  3. Maximize ESTE terminal. Feche o que nao deve aparecer no video." -ForegroundColor White
Write-Host ""
Write-Host "  4. OBS: gravar tela inteira (sem microfone - o audio entra depois). Aperte REC." -ForegroundColor White
Write-Host ""
Write-Host "  5. Neste terminal, rode e NAO TOQUE em mais nada ate terminar (~15 min):" -ForegroundColor White
Write-Host "       .\scripts\demo-auto.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "     Ensaio rapido antes (2 min):  .\scripts\demo-auto.ps1 -Pace 0.15" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Credenciais: admin@fcg.com / Admin@123   |   Grafana: admin / admin" -ForegroundColor DarkGray
Write-Host "=================================================================="
