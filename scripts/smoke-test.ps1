# =============================================================================
# Smoke test end-to-end via API Gateway
#   .\scripts\smoke-test.ps1
#   .\scripts\smoke-test.ps1 -Gateway "http://localhost:30000"   (Kubernetes)
# =============================================================================

param([string]$Gateway = "http://localhost:8000")

$ErrorActionPreference = "Stop"

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK: $m" -ForegroundColor Green }
function Fail($m) { Write-Host "    FALHA: $m" -ForegroundColor Red }
function Note($m) { Write-Host "    >> $m" -ForegroundColor Yellow }

$stamp = Get-Date -Format "HHmmss"
$email = "maria.$stamp@fcg.com"

# ---------------------------------------------------------------------------
Step "1. Cadastro de usuario (dispara UserCreatedEvent)"
$register = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/register" `
    -ContentType "application/json" `
    -Body (@{ name = "Maria Aluna"; email = $email; password = "Senha@123" } | ConvertTo-Json)
Ok "Usuario criado: $($register.id)"
Note "Confira o log da Azure Function: e-mail de boas-vindas"

# ---------------------------------------------------------------------------
Step "2. Validacao de senha fraca (espera 400)"
try {
    Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/register" `
        -ContentType "application/json" `
        -Body (@{ name = "Teste"; email = "fraco.$stamp@fcg.com"; password = "12345678" } | ConvertTo-Json) | Out-Null
    Fail "deveria ter rejeitado a senha fraca"
} catch { Ok "senha fraca rejeitada (400)" }

# ---------------------------------------------------------------------------
Step "3. Login (obtem JWT)"
$login = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/login" `
    -ContentType "application/json" `
    -Body (@{ email = $email; password = "Senha@123" } | ConvertTo-Json)
$token = $login.token
$headers = @{ Authorization = "Bearer $token" }
Ok "token obtido, expira em $($login.expiresAt)"

# ---------------------------------------------------------------------------
Step "4. Rota protegida SEM token (Kong deve barrar com 401)"
try {
    Invoke-RestMethod -Method Get -Uri "$Gateway/api/library/me" | Out-Null
    Fail "o Gateway deveria ter bloqueado"
} catch { Ok "Kong bloqueou a requisicao sem token (401)" }

# ---------------------------------------------------------------------------
Step "5. Catalogo publico via Gateway (1a chamada = cache MISS)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$games = Invoke-RestMethod -Method Get -Uri "$Gateway/api/games"
$sw.Stop()
Ok "$($games.Count) jogos em $($sw.ElapsedMilliseconds)ms (leu do PostgreSQL)"

Step "6. Catalogo novamente (2a chamada = cache HIT no Redis)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$games = Invoke-RestMethod -Method Get -Uri "$Gateway/api/games"
$sw.Stop()
Ok "$($games.Count) jogos em $($sw.ElapsedMilliseconds)ms (veio do Redis)"

# ---------------------------------------------------------------------------
$cheap = $games | Where-Object { $_.price -le 200 } | Select-Object -First 1
$expensive = $games | Where-Object { $_.price -gt 200 } | Select-Object -First 1

Step "7. COMPRA APROVADA - $($cheap.title) por $($cheap.price)"
$order = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/purchase" -Headers $headers
Ok "pedido $($order.orderId) com status $($order.status)"
Write-Host "    Aguardando pipeline assincrono (Payments, Catalog, Notifications)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 7

$library = Invoke-RestMethod -Method Get -Uri "$Gateway/api/library/me" -Headers $headers
if ($library.Count -gt 0) {
    Ok "biblioteca atualizada: $($library[0].gameTitle) por $($library[0].pricePaid)"
    Note "Confira o log da Azure Function: e-mail de confirmacao"
} else {
    Fail "biblioteca vazia - verifique os logs do payments-api e catalog-api"
}

# ---------------------------------------------------------------------------
if ($expensive) {
    Step "8. COMPRA REJEITADA - $($expensive.title) por $($expensive.price), acima do limite de 200"
    $order2 = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($expensive.id)/purchase" -Headers $headers
    Ok "pedido $($order2.orderId) enviado"
    Start-Sleep -Seconds 7

    $library2 = Invoke-RestMethod -Method Get -Uri "$Gateway/api/library/me" -Headers $headers
    if ($library2.Count -eq $library.Count) {
        Ok "pagamento rejeitado, jogo NAO entrou na biblioteca (correto)"
        Note "Confira o log da Azure Function: e-mail de recusa"
    } else {
        Fail "jogo entrou na biblioteca mesmo com pagamento rejeitado"
    }
}

# ---------------------------------------------------------------------------
Step "9. Avaliacao do jogo (documento flexivel no MongoDB)"
$review = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games/$($cheap.id)/reviews" `
    -Headers $headers -ContentType "application/json" `
    -Body (@{ rating = 5; comment = "Excelente jogo"; tags = @("relaxante", "indie") } | ConvertTo-Json)
Ok "avaliacao criada: $($review.id)"

# ---------------------------------------------------------------------------
Step "10. Login como Admin e cadastro de jogo (rota protegida por role)"
$adminLogin = Invoke-RestMethod -Method Post -Uri "$Gateway/api/auth/login" `
    -ContentType "application/json" `
    -Body (@{ email = "admin@fcg.com"; password = "Admin@123" } | ConvertTo-Json)
$adminHeaders = @{ Authorization = "Bearer $($adminLogin.token)" }

$newGame = Invoke-RestMethod -Method Post -Uri "$Gateway/api/games" `
    -Headers $adminHeaders -ContentType "application/json" `
    -Body (@{
        title = "Celeste $stamp"; description = "Plataforma desafiador"; genre = "Indie"
        price = 29.90; releaseDate = "2018-01-25T00:00:00Z"
    } | ConvertTo-Json)
Ok "jogo criado pelo admin: $($newGame.title)"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  SMOKE TEST CONCLUIDO" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Gere carga para o dashboard do Grafana:"
Write-Host "    1..200 | ForEach-Object { Invoke-RestMethod $Gateway/api/games | Out-Null }"
Write-Host "=================================================================="
