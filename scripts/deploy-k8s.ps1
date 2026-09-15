# =============================================================================
# Deploy completo no Kubernetes local (Docker Desktop)
#   .\scripts\deploy-k8s.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$parent = Split-Path -Parent $root

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }

# ---------------------------------------------------------------------------
Step "Verificando cluster Kubernetes"
kubectl cluster-info | Out-Null
Ok "Cluster acessível."

# ---------------------------------------------------------------------------
Step "Construindo as imagens Docker dos microsserviços"
docker build -t fcg/users-api:latest    "$parent/fcg-users-api"
docker build -t fcg/catalog-api:latest  "$parent/fcg-catalog-api"
docker build -t fcg/payments-api:latest "$parent/fcg-payments-api"
Ok "Imagens construídas."

# ---------------------------------------------------------------------------
Step "Criando namespace"
kubectl apply -f "$root/k8s/00-namespace.yaml"

# ---------------------------------------------------------------------------
Step "Aplicando infraestrutura (PostgreSQL, MongoDB, Redis, RabbitMQ)"
kubectl apply -f "$root/k8s/infra/"

Write-Host "    Aguardando bancos ficarem prontos..." -ForegroundColor DarkGray
kubectl wait --for=condition=available --timeout=180s deployment/postgres-users   -n fcg
kubectl wait --for=condition=available --timeout=180s deployment/postgres-catalog -n fcg
kubectl wait --for=condition=available --timeout=180s deployment/mongo            -n fcg
kubectl wait --for=condition=available --timeout=180s deployment/redis            -n fcg
kubectl wait --for=condition=available --timeout=240s deployment/rabbitmq         -n fcg
Ok "Infraestrutura pronta."

# ---------------------------------------------------------------------------
Step "Aplicando os microsserviços"
kubectl apply -f "$parent/fcg-users-api/k8s/"
kubectl apply -f "$parent/fcg-catalog-api/k8s/"
kubectl apply -f "$parent/fcg-payments-api/k8s/"

Write-Host "    Aguardando microsserviços..." -ForegroundColor DarkGray
kubectl wait --for=condition=available --timeout=240s deployment/users-api    -n fcg
kubectl wait --for=condition=available --timeout=240s deployment/catalog-api  -n fcg
kubectl wait --for=condition=available --timeout=240s deployment/payments-api -n fcg
Ok "Microsserviços no ar."

# ---------------------------------------------------------------------------
Step "Aplicando o API Gateway (Kong)"
kubectl apply -f "$root/k8s/gateway/"
kubectl wait --for=condition=available --timeout=180s deployment/kong -n fcg
Ok "Kong no ar."

# ---------------------------------------------------------------------------
Step "Aplicando a stack de observabilidade (Prometheus + Grafana)"
kubectl apply -f "$root/k8s/observability/04-prometheus.yaml"

# O dashboard do Grafana é grande demais para um YAML inline — cria via --from-file
kubectl create configmap grafana-dashboards `
    --from-file="$root/grafana/dashboards/fcg-overview.json" `
    -n fcg --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$root/k8s/observability/05-grafana.yaml"
kubectl wait --for=condition=available --timeout=180s deployment/prometheus -n fcg
kubectl wait --for=condition=available --timeout=180s deployment/grafana    -n fcg
Ok "Observabilidade no ar."

# ---------------------------------------------------------------------------
Step "Status final"
kubectl get pods -n fcg
Write-Host ""
kubectl get svc -n fcg

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  DEPLOY CONCLUÍDO" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  API Gateway (Kong):  http://localhost:30000"
Write-Host "  Prometheus:          http://localhost:30090"
Write-Host "  Grafana:             http://localhost:30300   (admin / admin)"
Write-Host ""
Write-Host "  RabbitMQ UI: kubectl port-forward -n fcg svc/rabbitmq 15672:15672"
Write-Host "  Depois acesse http://localhost:15672 (guest / guest)"
Write-Host ""
Write-Host "  Admin semeado: admin@fcg.com / Admin@123"
Write-Host "=================================================================="
