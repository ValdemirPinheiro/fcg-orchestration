# =============================================================================
# EXECUTOR DA DEMO PARA O VIDEO
#
# Cada passo: mostra o titulo -> voce le a narracao do roteiro -> aperta ENTER
# -> o comando executa -> voce comenta o resultado -> aperta ENTER -> proximo.
#
# Passos de BROWSER abrem a URL automaticamente no navegador padrao.
# Voce so precisa: ler, apertar Enter, e as vezes rolar/clicar no browser.
#
#   .\scripts\demo-video.ps1
# =============================================================================

param(
    [string]$Gateway = "http://localhost:8000",
    [string]$GitHubUser = "ValdemirPinheiro",
    [int]$StartAt = 1          # para retomar de um passo especifico apos um corte
)

$ErrorActionPreference = "Continue"
$script:step = 0
$script:token = $null
$script:adminToken = $null
$script:games = $null
$script:userEmail = "maria.demo@fcg.com"

# ---------------------------------------------------------------- helpers ---
function Wait-Enter($hint = "ENTER para continuar") {
    Write-Host ""
    Write-Host "  [ $hint ]" -ForegroundColor DarkGray
    Read-Host | Out-Null
}

function Banner($cena, $titulo) {
    $script:step++
    if ($script:step -lt $StartAt) { return $false }
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
    Write-Host "   CENA $cena  |  PASSO $($script:step)" -ForegroundColor DarkCyan
    Write-Host "   $titulo" -ForegroundColor Cyan
    Write-Host "  ================================================================" -ForegroundColor DarkCyan
    Write-Host ""
    return $true
}

function Run($label, [scriptblock]$cmd) {
    Write-Host "  > $label" -ForegroundColor Yellow
    Write-Host ""
    try { & $cmd } catch { Write-Host "  (erro: $($_.Exception.Message))" -ForegroundColor Red }
    Write-Host ""
}

function Show($obj) {
    if ($null -eq $obj) { Write-Host "  (vazio)" -ForegroundColor DarkGray; return }
    $obj | ConvertTo-Json -Depth 6 | ForEach-Object { Write-Host "  $_" }
}

function Open-Url($url) {
    Write-Host "  abrindo no navegador: $url" -ForegroundColor DarkGray
    Start-Process $url
}

function Expect401([scriptblock]$cmd) {
    try {
        & $cmd | Out-Null
        Write-Host "  (inesperado: passou sem token)" -ForegroundColor Red
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Host "  HTTP $code - bloqueado pelo Kong" -ForegroundColor Green
    }
}

# =============================================================================
# CENA 1 - ABERTURA
# =============================================================================
if (Banner 1 "Abertura - apenas narracao") {
    Write-Host "  Leia a abertura do roteiro. Nada e executado aqui." -ForegroundColor White
    Wait-Enter "ENTER quando terminar a abertura"
}

# =============================================================================
# CENA 2 - ARQUITETURA E REPOSITORIOS
# =============================================================================
if (Banner 2 "GitHub - os 5 repositorios") {
    Write-Host "  Vai abrir o perfil do GitHub. Aponte os 5 repositorios enquanto narra." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/${GitHubUser}?tab=repositories&q=fcg"
    Wait-Enter
}

if (Banner 2 "README central - diagrama e stack de observabilidade") {
    Write-Host "  Vai abrir o README da orquestracao. Role ate o diagrama e depois ate" -ForegroundColor White
    Write-Host "  a secao 'Stack de Observabilidade escolhida'." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-orchestration#readme"
    Wait-Enter
}

# =============================================================================
# CENA 3 - AMBIENTE RODANDO
# =============================================================================
if (Banner 3 "docker compose ps - todos os containers") {
    Wait-Enter "ENTER para executar"
    Run "docker compose ps" { docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" }
    Write-Host "  Agora mostre o terminal da Function (func start) com as 2 funcoes registradas." -ForegroundColor White
    Wait-Enter
}

# =============================================================================
# CENA 4 - API GATEWAY
# =============================================================================
if (Banner 4 "kong.yml - configuracao declarativa do Gateway") {
    Write-Host "  Vai abrir o kong.yml no GitHub. Aponte: services, rotas publicas vs" -ForegroundColor White
    Write-Host "  protegidas (plugin jwt), e o consumer com key FCG.Gateway." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-orchestration/blob/main/kong/kong.yml"
    Wait-Enter
}

if (Banner 4 "Rota PUBLICA via Gateway - GET /api/games sem token") {
    Wait-Enter "ENTER para executar"
    Run "GET $Gateway/api/games" {
        $script:games = Invoke-RestMethod "$Gateway/api/games"
        $script:games | Select-Object title, genre, price | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    Wait-Enter
}

if (Banner 4 "Rota PROTEGIDA sem token - Kong deve barrar com 401") {
    Wait-Enter "ENTER para executar"
    Run "GET $Gateway/api/library/me  (sem Authorization)" {
        Expect401 { Invoke-RestMethod "$Gateway/api/library/me" }
    }
    Write-Host "  A requisicao nem chegou ao microsservico - o Gateway parou antes." -ForegroundColor White
    Wait-Enter
}

if (Banner 4 "Cadastro de usuario - dispara UserCreatedEvent") {
    Write-Host "  Apos executar, MOSTRE o terminal da Function: o e-mail de boas-vindas aparece." -ForegroundColor White
    Wait-Enter "ENTER para executar"
    Run "POST $Gateway/api/auth/register" {
        $body = @{ name = "Maria Aluna"; email = $script:userEmail; password = "Senha@123" } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/register" -ContentType "application/json" -Body $body
        Show $r
    }
    Wait-Enter "ENTER apos mostrar o e-mail na Function"
}

if (Banner 4 "Login - obtem o JWT (copiado para a area de transferencia)") {
    Wait-Enter "ENTER para executar"
    Run "POST $Gateway/api/auth/login" {
        $body = @{ email = $script:userEmail; password = "Senha@123" } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/login" -ContentType "application/json" -Body $body
        $script:token = $r.token
        Set-Clipboard -Value $r.token
        Write-Host "  usuario : $($r.user.email)  role: $($r.user.role)"
        Write-Host "  expira  : $($r.expiresAt)"
        Write-Host ""
        Write-Host "  token   : $($r.token.Substring(0,40))..." -ForegroundColor Green
        Write-Host ""
        Write-Host "  >> token COPIADO. No jwt.io, cole com Ctrl+V no campo Encoded." -ForegroundColor Yellow
    }
    Wait-Enter "ENTER para abrir o jwt.io"
    Open-Url "https://jwt.io"
    Write-Host "  Cole o token (Ctrl+V). Aponte: sub, email, role, e iss = FCG.Gateway." -ForegroundColor White
    Wait-Enter
}

if (Banner 4 "Mesma rota protegida, agora COM token") {
    Wait-Enter "ENTER para executar"
    Run "GET $Gateway/api/library/me  (Authorization: Bearer ...)" {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers @{ Authorization = "Bearer $($script:token)" }
        if (-not $r -or $r.Count -eq 0) { Write-Host "  [] - biblioteca vazia (Maria ainda nao comprou nada)" -ForegroundColor Green }
        else { Show $r }
    }
    Wait-Enter
}

# =============================================================================
# CENA 5 - FLUXO DE COMPRA
# =============================================================================
if (Banner 5 "Codigo do Purchase - publica OrderPlacedEvent e devolve 202") {
    Write-Host "  Vai abrir o GamesController no GitHub. Role ate o metodo Purchase." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Controllers/GamesController.cs"
    Wait-Enter
}

if (Banner 5 "COMPRA APROVADA - jogo barato") {
    $cheap = $script:games | Where-Object { $_.price -le 200 } | Sort-Object price | Select-Object -First 1
    Write-Host "  Jogo escolhido: $($cheap.title) por $($cheap.price)" -ForegroundColor White
    Wait-Enter "ENTER para executar"
    Run "POST $Gateway/api/games/$($cheap.id)/purchase" {
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/purchase" -Headers @{ Authorization = "Bearer $($script:token)" }
        Show $r
    }
    Write-Host "  202 Accepted. O processamento e assincrono - vamos seguir o rastro." -ForegroundColor White
    Wait-Enter
}

if (Banner 5 "Rastro 1/3 - PaymentsAPI consumiu e processou") {
    Wait-Enter "ENTER para executar"
    Run "docker compose logs payments-api --tail=12" {
        docker compose logs payments-api --tail=12 --no-log-prefix 2>&1 | Select-String -Pattern "OrderPlaced|PaymentProcessed|Processando" | ForEach-Object { Write-Host "  $_" }
    }
    Wait-Enter
}

if (Banner 5 "Rastro 2/3 - CatalogAPI adicionou a biblioteca") {
    Wait-Enter "ENTER para executar"
    Run "docker compose logs catalog-api --tail=12" {
        docker compose logs catalog-api --tail=12 --no-log-prefix 2>&1 | Select-String -Pattern "adicionado|biblioteca|PaymentProcessed" | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host "  Rastro 3/3: MOSTRE o terminal da Function - e-mail de confirmacao." -ForegroundColor White
    Wait-Enter "ENTER apos mostrar a Function"
}

if (Banner 5 "Biblioteca da Maria - agora com o jogo") {
    Wait-Enter "ENTER para executar"
    Run "GET $Gateway/api/library/me" {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers @{ Authorization = "Bearer $($script:token)" }
        Show $r
    }
    Wait-Enter
}

if (Banner 5 "COMPRA REJEITADA - jogo acima do limite de 200") {
    $exp = $script:games | Where-Object { $_.price -gt 200 } | Select-Object -First 1
    Write-Host "  Jogo escolhido: $($exp.title) por $($exp.price)" -ForegroundColor White
    Wait-Enter "ENTER para executar"
    Run "POST $Gateway/api/games/$($exp.id)/purchase" {
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($exp.id)/purchase" -Headers @{ Authorization = "Bearer $($script:token)" }
        Show $r
    }
    Write-Host "  Aguardando o pagamento ser processado (~3s)..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 4
    Write-Host "  MOSTRE o terminal da Function - e-mail de RECUSA com o motivo." -ForegroundColor White
    Wait-Enter "ENTER apos mostrar a Function"
}

if (Banner 5 "Biblioteca continua com 1 jogo - consistencia mantida") {
    Wait-Enter "ENTER para executar"
    Run "GET $Gateway/api/library/me" {
        $r = Invoke-RestMethod "$Gateway/api/library/me" -Headers @{ Authorization = "Bearer $($script:token)" }
        Write-Host "  itens na biblioteca: $(@($r).Count)" -ForegroundColor Green
        @($r) | Select-Object gameTitle, pricePaid | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    Wait-Enter
}

if (Banner 5 "RabbitMQ - as filas do sistema") {
    Write-Host "  Vai abrir a UI do RabbitMQ (guest / guest). Clique na aba Queues." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "http://localhost:15672/#/queues"
    Wait-Enter
}

# =============================================================================
# CENA 6 - SERVERLESS
# =============================================================================
if (Banner 6 "Codigo da Function - RabbitMQTrigger") {
    Write-Host "  Vai abrir NotificationFunctions.cs. Aponte o atributo [RabbitMQTrigger(...)]." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-notifications-function/blob/main/src/FCG.Notifications.Function/NotificationFunctions.cs"
    Wait-Enter
}

if (Banner 6 "Infraestrutura como Codigo - Bicep") {
    Write-Host "  Vai abrir main.bicep. Aponte o sku Y1 / Dynamic (Consumption, escala a zero)." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-notifications-function/blob/main/infra/main.bicep"
    Wait-Enter
}

# =============================================================================
# CENA 7 - OBSERVABILIDADE
# =============================================================================
if (Banner 7 "Prometheus - alvos coletados") {
    Wait-Enter "ENTER para abrir"
    Open-Url "http://localhost:9090/targets"
    Write-Host "  Todos os alvos devem estar UP: users-api, catalog-api, payments-api, kong." -ForegroundColor White
    Wait-Enter
}

if (Banner 7 "Prometheus - query de latencia p95") {
    $q = [uri]::EscapeDataString('histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job))')
    Wait-Enter "ENTER para abrir"
    Open-Url "http://localhost:9090/graph?g0.expr=$q&g0.tab=0&g0.range_input=15m"
    Wait-Enter
}

if (Banner 7 "Codigo - instrumentacao com prometheus-net") {
    Write-Host "  Vai abrir o Program.cs do CatalogAPI. Aponte UseHttpMetrics() e MapMetrics()." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Program.cs"
    Wait-Enter
}

if (Banner 7 "Grafana - dashboard FCG") {
    Write-Host "  Vai abrir o dashboard. Percorra os paineis de cima para baixo." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "http://localhost:3000/d/fcg-overview?refresh=5s&from=now-15m&to=now"
    Wait-Enter "ENTER para gerar carga ao vivo"
    Run "gerando 100 requisicoes para ver os graficos subirem" {
        1..100 | ForEach-Object { try { Invoke-RestMethod "$Gateway/api/games" -TimeoutSec 5 | Out-Null } catch { } }
        Write-Host "  pronto - volte ao Grafana e veja os paineis atualizando" -ForegroundColor Green
    }
    Wait-Enter
}

# =============================================================================
# CENA 8 - NOSQL E CACHE
# =============================================================================
if (Banner 8 "Codigo - MongoStore (4 cenarios de NoSQL)") {
    Write-Host "  Vai abrir MongoStore.cs. Aponte LibraryItem, GameReview (tags livres), EventLog." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Infrastructure/MongoStore.cs"
    Wait-Enter
}

if (Banner 8 "Avaliacao com tags livres - documento flexivel") {
    $cheap = $script:games | Where-Object { $_.price -le 200 } | Sort-Object price | Select-Object -First 1
    Wait-Enter "ENTER para executar"
    Run "POST $Gateway/api/games/$($cheap.id)/reviews" {
        $body = @{ rating = 5; comment = "Excelente jogo!"; tags = @("relaxante", "indie", "pixel-art") } | ConvertTo-Json
        $r = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/reviews" -Headers @{ Authorization = "Bearer $($script:token)" } -ContentType "application/json" -Body $body
        Show $r
    }
    Write-Host "  Agora abra o MongoDB Compass: fcg_catalog > library_items e game_reviews." -ForegroundColor White
    Write-Host "  Na library_items, mostre a aba Indexes (ux_user_game)." -ForegroundColor White
    Wait-Enter "ENTER apos mostrar o Compass"
}

if (Banner 8 "Codigo - CacheService (cache-aside com degradacao graciosa)") {
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-catalog-api/blob/main/src/FCG.Catalog.API/Infrastructure/CacheService.cs"
    Wait-Enter
}

if (Banner 8 "Cache na pratica - miss vs hit") {
    Wait-Enter "ENTER para executar"
    Run "invalidando cache e medindo 2 chamadas" {
        docker exec fcg-redis redis-cli FLUSHALL 2>&1 | Out-Null
        $t1 = (Measure-Command { Invoke-RestMethod "$Gateway/api/games" | Out-Null }).TotalMilliseconds
        $t2 = (Measure-Command { Invoke-RestMethod "$Gateway/api/games" | Out-Null }).TotalMilliseconds
        Write-Host ("  1a chamada (cache MISS, PostgreSQL): {0,8:N0} ms" -f $t1) -ForegroundColor Yellow
        Write-Host ("  2a chamada (cache HIT,  Redis)     : {0,8:N0} ms" -f $t2) -ForegroundColor Green
        if ($t2 -gt 0) { Write-Host ("  ganho: {0:N0}x mais rapido" -f ($t1 / $t2)) -ForegroundColor Cyan }
    }
    Wait-Enter
}

if (Banner 8 "Chaves no Redis") {
    Wait-Enter "ENTER para executar"
    Run "redis-cli KEYS *" {
        docker exec fcg-redis redis-cli KEYS "*" 2>&1 | ForEach-Object { Write-Host "  $_" }
    }
    Wait-Enter
}

# =============================================================================
# CENA 9 - KUBERNETES
# =============================================================================
if (Banner 9 "Manifestos - Deployment, ConfigMap e Secret") {
    Write-Host "  Vai abrir a pasta k8s do UsersAPI. Abra deployment.yaml, configmap.yaml, secret.yaml." -ForegroundColor White
    Wait-Enter "ENTER para abrir"
    Open-Url "https://github.com/$GitHubUser/fcg-users-api/tree/main/k8s"
    Wait-Enter
}

if (Banner 9 "kubectl get pods / svc") {
    Wait-Enter "ENTER para executar"
    Run "kubectl get pods -n fcg" {
        kubectl get pods -n fcg 2>&1 | ForEach-Object { Write-Host "  $_" }
    }
    Run "kubectl get svc -n fcg" {
        kubectl get svc -n fcg 2>&1 | ForEach-Object { Write-Host "  $_" }
    }
    Wait-Enter
}

# =============================================================================
# CENA 10 - ENCERRAMENTO
# =============================================================================
if (Banner 10 "Encerramento - apenas narracao") {
    Open-Url "https://github.com/${GitHubUser}?tab=repositories&q=fcg"
    Write-Host "  Leia o encerramento do roteiro. Depois pare a gravacao no OBS." -ForegroundColor White
    Wait-Enter "ENTER para finalizar"
}

Clear-Host
Write-Host ""
Write-Host "  DEMO CONCLUIDA. Pare a gravacao no OBS." -ForegroundColor Green
Write-Host ""
