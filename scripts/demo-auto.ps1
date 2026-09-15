# =============================================================================
# DEMO 100% AUTOMATICA PARA GRAVACAO
#
# Roda sozinha do inicio ao fim, com pausas cronometradas. Ninguem toca em nada.
# Voce aperta REC no OBS, roda este script, e depois narra por cima do video.
#
#   .\scripts\demo-auto.ps1               (ritmo normal, ~15 min)
#   .\scripts\demo-auto.ps1 -Pace 1.3     (30% mais lento, ~19 min)
#   .\scripts\demo-auto.ps1 -Pace 0.15    (ensaio rapido, ~2 min)
#   .\scripts\demo-auto.ps1 -StartAt 12   (retoma de um passo)
#
# PRE-REQUISITOS (prep-video.ps1 imprime tudo isso):
#   - Terminal B com titulo FCG-FUNC rodando:
#       $host.UI.RawUI.WindowTitle = "FCG-FUNC"
#       func start 2>&1 | Tee-Object -FilePath "$env:TEMP\fcg-func.log"
#   - Navegador padrao ja aberto (evita demora no primeiro Start-Process)
# =============================================================================

param(
    [double]$Pace = 1.0,
    [int]$StartAt = 1,
    [string]$Gateway = "http://localhost:8000",
    [string]$GitHubUser = "ValdemirPinheiro"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# ------------------------------------------------------------ Win32 focus ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Focus {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@

$host.UI.RawUI.WindowTitle = "FCG-DEMO"
$script:demoHwnd = [Win32Focus]::GetForegroundWindow()
$script:funcHwnd = [IntPtr]::Zero
$funcProc = Get-Process | Where-Object { $_.MainWindowTitle -like "*FCG-FUNC*" } | Select-Object -First 1
if ($funcProc) { $script:funcHwnd = $funcProc.MainWindowHandle }
$script:funcLog = Join-Path $env:TEMP "fcg-func.log"

function Focus-Window($hwnd) {
    if ($hwnd -eq [IntPtr]::Zero) { return }
    [Win32Focus]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)   # Alt down
    [Win32Focus]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)   # Alt up  (libera o SetForegroundWindow)
    [Win32Focus]::ShowWindow($hwnd, 9) | Out-Null            # SW_RESTORE
    [Win32Focus]::SetForegroundWindow($hwnd) | Out-Null
}

# ---------------------------------------------------------------- estado ---
$script:step = 0
$script:token = $null
$script:games = $null
$script:userEmail = "maria.demo.$(Get-Date -Format 'HHmm')@fcg.com"
$script:t0 = Get-Date

# --------------------------------------------------------------- helpers ---
function Pause($s) { Start-Sleep -Milliseconds ([int]($s * 1000 * $Pace)) }

function Banner($cena, $titulo) {
    $script:step++
    if ($script:step -lt $StartAt) { return $false }
    Clear-Host
    $elapsed = ((Get-Date) - $script:t0).ToString("mm\:ss")
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
    Write-Host "   CENA $cena  |  PASSO $($script:step)  |  $elapsed" -ForegroundColor DarkCyan
    Write-Host "   $titulo" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Pause 3
    return $true
}

function Cmd($label) {
    Write-Host "  > $label" -ForegroundColor Yellow
    Write-Host ""
}

function Show($obj) {
    if ($null -eq $obj) { Write-Host "  (vazio)" -ForegroundColor DarkGray; return }
    $obj | ConvertTo-Json -Depth 6 | ForEach-Object { Write-Host "  $_" }
}

function Open-Browser($url, $seconds) {
    Write-Host "  abrindo: $url" -ForegroundColor DarkGray
    Start-Process $url
    Pause $seconds
    Focus-Window $script:demoHwnd
    Pause 1
}

function Show-Function($seconds) {
    # 1) traz a janela da Function para frente (se encontrada)
    if ($script:funcHwnd -ne [IntPtr]::Zero) {
        Focus-Window $script:funcHwnd
        Pause $seconds
        Focus-Window $script:demoHwnd
        Pause 1
    }
    # 2) garante o conteudo na tela da demo, vindo do log (Tee-Object)
    if (Test-Path $script:funcLog) {
        Write-Host ""
        Write-Host "  --- log da Function (ultimas linhas) ---" -ForegroundColor Magenta
        Get-Content $script:funcLog -Tail 40 -ErrorAction SilentlyContinue |
            Select-String -Pattern "E-MAIL|SERVERLESS|Para:|Assunto:|Pedido:|Jogo:|Valor:|Motivo:|Ola," |
            Select-Object -Last 12 |
            ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Magenta }
        Pause 8
    }
}

function Try-Run([scriptblock]$cmd) {
    try { & $cmd } catch { Write-Host "  (erro: $($_.Exception.Message))" -ForegroundColor Red }
}

function Auth() { @{ Authorization = "Bearer $($script:token)" } }

function Decode-Jwt($jwt) {
    $p = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
    while ($p.Length % 4 -ne 0) { $p += '=' }
    [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}

# =============================================================================
# CENA 1 - ABERTURA (cartao de titulo)
# =============================================================================
if (Banner 1 "Abertura") {
    Clear-Host
    Write-Host ""
    Write-Host ""
    Write-Host "      ==========================================================" -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "                   FIAP  CLOUD  GAMES                           " -ForegroundColor White
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "              Tech Challenge  -  Fase 3                         " -ForegroundColor White
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "        API Gateway  |  Serverless  |  Observabilidade          " -ForegroundColor Gray
    Write-Host "              NoSQL  |  Cache Distribuido                       " -ForegroundColor Gray
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "                   Valdemir Pinheiro                            " -ForegroundColor White
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "      ==========================================================" -ForegroundColor Cyan
    Pause 38
}

# =============================================================================
# CENA 2 - ARQUITETURA E REPOSITORIOS
# =============================================================================
if (Banner 2 "Os 5 repositorios no GitHub") {
    Open-Browser "https://github.com/${GitHubUser}?tab=repositories&q=fcg" 35
}

if (Banner 2 "README central - diagrama e stack de observabilidade") {
    Open-Browser "https://github.com/$GitHubUser/fcg-orchestration#-arquitetura" 45
}

# =============================================================================
# CENA 3 - AMBIENTE RODANDO
# =============================================================================
if (Banner 3 "docker compose ps") {
    Cmd "docker compose ps"
    Try-Run { docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 15
    Write-Host ""
    Write-Host "  Function serverless (terminal separado):" -ForegroundColor White
    Show-Function 15
}

# =============================================================================
# CENA 4 - API GATEWAY
# =============================================================================
if (Banner 4 "kong.yml - services e rotas (publicas vs protegidas)") {
    Open-Browser "https://github.com/$GitHubUser/fcg-orchestration/blob/main/kong/kong.yml#L12-L60" 30
}

if (Banner 4 "kong.yml - consumer JWT (key = FCG.Gateway)") {
    Open-Browser "https://github.com/$GitHubUser/fcg-orchestration/blob/main/kong/kong.yml#L90-L98" 20
}

if (Banner 4 "Rota PUBLICA via Gateway - GET /api/games sem token") {
    Cmd "GET $Gateway/api/games"
    Try-Run {
        $script:games = Invoke-RestMethod "$Gateway/api/games"
        $script:games | Select-Object title, genre, price | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
        Write-Host "  HTTP 200 - o Kong deixou passar (rota publica)" -ForegroundColor Green
    }
    Pause 12
}

if (Banner 4 "Rota PROTEGIDA sem token - Kong barra com 401") {
    Cmd "GET $Gateway/api/library/me   (sem Authorization)"
    try {
        Invoke-RestMethod "$Gateway/api/library/me" | Out-Null
        Write-Host "  (inesperado: passou)" -ForegroundColor Red
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Host "  HTTP $code Unauthorized" -ForegroundColor Green
        Write-Host "  A requisicao NAO chegou ao microsservico - o Gateway parou antes." -ForegroundColor White
    }
    Pause 12
}

if (Banner 4 "Cadastro de usuario - dispara UserCreatedEvent") {
    Cmd "POST $Gateway/api/auth/register"
    Try-Run {
        $body = @{ name = "Maria Aluna"; email = $script:userEmail; password = "Senha@123" } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/register" -ContentType "application/json" -Body $body
        Show $r
        Write-Host "  HTTP 201 - UserCreatedEvent publicado no RabbitMQ" -ForegroundColor Green
    }
    Pause 8
    Write-Host ""
    Write-Host "  A Function serverless consumiu o evento:" -ForegroundColor White
    Pause 3
    Show-Function 15
}

if (Banner 4 "Login - JWT emitido e decodificado") {
    Cmd "POST $Gateway/api/auth/login"
    Try-Run {
        $body = @{ email = $script:userEmail; password = "Senha@123" } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/login" -ContentType "application/json" -Body $body
        $script:token = $r.token
        Write-Host "  token: $($r.token.Substring(0, 60))..." -ForegroundColor Green
        Write-Host ""
        Write-Host "  payload decodificado (base64):" -ForegroundColor White
        $claims = Decode-Jwt $r.token
        Write-Host ("    sub   : {0}" -f $claims.sub)
        Write-Host ("    email : {0}" -f $claims.email)
        Write-Host ("    role  : {0}" -f $claims.role)
        Write-Host ("    iss   : {0}   <- key do consumer no Kong" -f $claims.iss) -ForegroundColor Cyan
        Write-Host ("    aud   : {0}" -f $claims.aud)
        Write-Host ("    exp   : {0} (UTC)" -f ([DateTimeOffset]::FromUnixTimeSeconds($claims.exp).UtcDateTime))
    }
    Pause 25
}

if (Banner 4 "Mesma rota protegida, agora COM token") {
    Cmd "GET $Gateway/api/library/me   (Authorization: Bearer ...)"
    Try-Run {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers (Auth)
        if (-not $r -or @($r).Count -eq 0) { Write-Host "  HTTP 200 - [] biblioteca vazia (Maria ainda nao comprou)" -ForegroundColor Green }
        else { Show $r }
    }
    Pause 10
}

# =============================================================================
# CENA 5 - FLUXO DE COMPRA
# =============================================================================
if (Banner 5 "Codigo do Purchase - publica OrderPlacedEvent e devolve 202") {
    Open-Browser "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Controllers/GamesController.cs#L148-L190" 25
}

if (Banner 5 "COMPRA APROVADA") {
    $cheap = $script:games | Where-Object { $_.price -le 200 } | Sort-Object price | Select-Object -First 1
    Cmd "POST $Gateway/api/games/{id}/purchase   ->  $($cheap.title)  ($($cheap.price))"
    Try-Run {
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/purchase" -Headers (Auth)
        Show $r
        Write-Host "  HTTP 202 Accepted - processamento assincrono iniciado" -ForegroundColor Green
    }
    Pause 12
}

if (Banner 5 "Rastro 1/3 - PaymentsAPI consumiu e processou") {
    Cmd "docker compose logs payments-api"
    Pause 3
    Try-Run {
        docker compose logs payments-api --tail=15 --no-log-prefix 2>&1 |
            Select-String -Pattern "OrderPlaced|PaymentProcessed|Processando" |
            ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    }
    Pause 15
}

if (Banner 5 "Rastro 2/3 - CatalogAPI adicionou a biblioteca") {
    Cmd "docker compose logs catalog-api"
    Try-Run {
        docker compose logs catalog-api --tail=15 --no-log-prefix 2>&1 |
            Select-String -Pattern "adicionado|biblioteca|PaymentProcessed" |
            ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    }
    Pause 12
    Write-Host ""
    Write-Host "  Rastro 3/3 - a Function tambem consumiu (e-mail de confirmacao):" -ForegroundColor White
    Show-Function 15
}

if (Banner 5 "Biblioteca da Maria - agora com o jogo") {
    Cmd "GET $Gateway/api/library/me"
    Try-Run {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers (Auth)
        Show $r
    }
    Pause 10
}

if (Banner 5 "COMPRA REJEITADA - acima do limite de 200") {
    $exp = $script:games | Where-Object { $_.price -gt 200 } | Select-Object -First 1
    Cmd "POST $Gateway/api/games/{id}/purchase   ->  $($exp.title)  ($($exp.price))"
    Try-Run {
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($exp.id)/purchase" -Headers (Auth)
        Show $r
    }
    Write-Host "  aguardando o PaymentsAPI processar..." -ForegroundColor DarkGray
    Pause 5
    Write-Host ""
    Write-Host "  A Function recebeu status Rejected (e-mail de recusa com o motivo):" -ForegroundColor White
    Show-Function 15
}

if (Banner 5 "Biblioteca continua com 1 jogo - consistencia mantida") {
    Cmd "GET $Gateway/api/library/me"
    Try-Run {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers (Auth)
        Write-Host "  itens na biblioteca: $(@($r).Count)" -ForegroundColor Green
        @($r) | Select-Object gameTitle, pricePaid, acquiredAt | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    Pause 10
}

if (Banner 5 "RabbitMQ - filas e consumidores") {
    Cmd "GET http://localhost:15672/api/queues"
    Try-Run {
        $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("guest:guest"))
        $q = Invoke-RestMethod "http://localhost:15672/api/queues" -Headers @{ Authorization = "Basic $basic" }
        $q | Where-Object { $_.name -notlike "*_error" -and $_.name -notlike "*_skipped" } |
            Select-Object @{n="fila";e={$_.name}}, @{n="msgs";e={$_.messages}}, @{n="consumidores";e={$_.consumers}} |
            Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    Pause 15
}

# =============================================================================
# CENA 6 - SERVERLESS
# =============================================================================
if (Banner 6 "Codigo da Function - RabbitMQTrigger") {
    Open-Browser "https://github.com/$GitHubUser/fcg-notifications-function/blob/main/src/FCG.Notifications.Function/NotificationFunctions.cs#L18-L36" 35
}

if (Banner 6 "Infraestrutura como Codigo - Bicep (plano Y1 Consumption)") {
    Open-Browser "https://github.com/$GitHubUser/fcg-notifications-function/blob/main/infra/main.bicep#L50-L64" 30
}

# =============================================================================
# CENA 7 - OBSERVABILIDADE
# =============================================================================
if (Banner 7 "Prometheus - alvos coletados") {
    Open-Browser "http://localhost:9090/targets" 20
}

if (Banner 7 "Prometheus - latencia p95 por servico") {
    $q = [uri]::EscapeDataString('histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job))')
    Open-Browser "http://localhost:9090/graph?g0.expr=$q&g0.tab=0&g0.range_input=15m" 15
}

if (Banner 7 "Instrumentacao - prometheus-net no Program.cs") {
    Open-Browser "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Program.cs#L134-L150" 20
}

if (Banner 7 "Grafana - dashboard FCG em tempo real") {
    Write-Host "  gerando carga em background para os graficos se moverem..." -ForegroundColor DarkGray
    $job = Start-Job -ScriptBlock {
        param($gw)
        1..150 | ForEach-Object { try { Invoke-RestMethod "$gw/api/games" -TimeoutSec 5 | Out-Null } catch { }; Start-Sleep -Milliseconds 250 }
    } -ArgumentList $Gateway
    Open-Browser "http://localhost:3000/d/fcg-overview?refresh=5s&from=now-15m&to=now&kiosk" 55
    Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -ErrorAction SilentlyContinue
}

# =============================================================================
# CENA 8 - NOSQL E CACHE
# =============================================================================
if (Banner 8 "MongoStore - 4 cenarios de NoSQL") {
    Open-Browser "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Infrastructure/MongoStore.cs#L16-L70" 35
}

if (Banner 8 "Avaliacao com tags livres (documento flexivel)") {
    $cheap = $script:games | Where-Object { $_.price -le 200 } | Sort-Object price | Select-Object -First 1
    Cmd "POST $Gateway/api/games/{id}/reviews"
    Try-Run {
        $body = @{ rating = 5; comment = "Excelente jogo!"; tags = @("relaxante", "indie", "pixel-art") } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/reviews" -Headers (Auth) -ContentType "application/json" -Body $body
        Show $r
    }
    Pause 10
}

if (Banner 8 "MongoDB - documentos e indice unico") {
    Cmd "mongosh fcg_catalog: db.library_items.find()"
    Try-Run { docker exec fcg-mongo mongosh fcg_catalog --quiet --eval "printjson(db.library_items.find().toArray())" 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 10
    Write-Host ""
    Cmd "mongosh fcg_catalog: db.game_reviews.find()"
    Try-Run { docker exec fcg-mongo mongosh fcg_catalog --quiet --eval "printjson(db.game_reviews.find().toArray())" 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 10
    Write-Host ""
    Cmd "mongosh fcg_catalog: db.library_items.getIndexes()   -> ux_user_game (unique)"
    Try-Run { docker exec fcg-mongo mongosh fcg_catalog --quiet --eval "printjson(db.library_items.getIndexes())" 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 12
}

if (Banner 8 "CacheService - cache-aside com degradacao graciosa") {
    Open-Browser "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Infrastructure/CacheService.cs#L40-L70" 25
}

if (Banner 8 "Cache na pratica - miss vs hit") {
    Cmd "FLUSHALL no Redis, depois 2 chamadas cronometradas"
    Try-Run {
        docker exec fcg-redis redis-cli FLUSHALL 2>&1 | Out-Null
        $t1 = (Measure-Command { Invoke-RestMethod "$Gateway/api/games" | Out-Null }).TotalMilliseconds
        Start-Sleep -Milliseconds 300
        $t2 = (Measure-Command { Invoke-RestMethod "$Gateway/api/games" | Out-Null }).TotalMilliseconds
        Write-Host ("  1a chamada  (cache MISS -> PostgreSQL) : {0,7:N0} ms" -f $t1) -ForegroundColor Yellow
        Write-Host ("  2a chamada  (cache HIT  -> Redis)      : {0,7:N0} ms" -f $t2) -ForegroundColor Green
        if ($t2 -gt 0) { Write-Host ("  ganho: {0:N0}x mais rapido" -f ($t1 / $t2)) -ForegroundColor Cyan }
    }
    Pause 15
}

if (Banner 8 "Chaves no Redis") {
    Cmd "redis-cli KEYS *"
    Try-Run { docker exec fcg-redis redis-cli KEYS "*" 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 10
}

# =============================================================================
# CENA 9 - KUBERNETES
# =============================================================================
if (Banner 9 "Manifestos - Deployment, ConfigMap e Secret") {
    Open-Browser "https://github.com/$GitHubUser/fcg-users-api/blob/main/k8s/deployment.yaml" 18
    Open-Browser "https://github.com/$GitHubUser/fcg-users-api/blob/main/k8s/secret.yaml" 15
}

if (Banner 9 "kubectl get pods / svc -n fcg") {
    Cmd "kubectl get pods -n fcg"
    Try-Run { kubectl get pods -n fcg 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 3
    Write-Host ""
    Cmd "kubectl get svc -n fcg"
    Try-Run { kubectl get svc -n fcg 2>&1 | ForEach-Object { Write-Host "  $_" } }
    Pause 18
}

# =============================================================================
# CENA 10 - ENCERRAMENTO
# =============================================================================
if (Banner 10 "Encerramento") {
    Clear-Host
    Write-Host ""
    Write-Host ""
    Write-Host "      ==========================================================" -ForegroundColor Cyan
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "               FIAP CLOUD GAMES  -  FASE 3                      " -ForegroundColor White
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "        [x] API Gateway (Kong) - entrada unica + JWT            " -ForegroundColor Gray
    Write-Host "        [x] Serverless (Azure Function) - trigger RabbitMQ      " -ForegroundColor Gray
    Write-Host "        [x] Observabilidade - Prometheus + Grafana              " -ForegroundColor Gray
    Write-Host "        [x] NoSQL (MongoDB) + Cache (Redis)                     " -ForegroundColor Gray
    Write-Host "        [x] Docker Compose + Kubernetes                         " -ForegroundColor Gray
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "           github.com/$GitHubUser                              " -ForegroundColor White
    Write-Host "                                                                " -ForegroundColor Cyan
    Write-Host "      ==========================================================" -ForegroundColor Cyan
    Pause 40
}

$total = ((Get-Date) - $script:t0).ToString("mm\:ss")
Clear-Host
Write-Host ""
Write-Host "  DEMO CONCLUIDA em $total. Pare a gravacao no OBS." -ForegroundColor Green
Write-Host ""
