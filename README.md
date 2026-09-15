# FCG — Repositório de Orquestração (Tech Challenge Fase 3)

Guia central da **FIAP Cloud Games**. Este repositório contém a infraestrutura, o API Gateway, a stack de observabilidade e os arquivos que sobem o ambiente completo.

---

## 📐 Arquitetura

```
                          ┌──────────────────────────┐
     Cliente  ──────────► │   KONG API GATEWAY       │  ← PORTA DE ENTRADA ÚNICA
                          │   • valida JWT           │     (:8000 compose / :30000 k8s)
                          │   • roteia               │
                          │   • rate limit / CORS    │
                          └────────┬─────────┬───────┘
                                   │         │
                        ┌──────────▼──┐  ┌───▼─────────┐
                        │  UsersAPI   │  │ CatalogAPI  │
                        │  PostgreSQL │  │ PostgreSQL  │
                        └──────┬──────┘  │ MongoDB     │
                               │         │ Redis       │
                               │         └──┬───────▲──┘
                  UserCreated  │  OrderPlaced│       │ PaymentProcessed
                               ▼             ▼       │
                        ┌──────────────────────────┐ │
                        │        RabbitMQ          │─┘
                        └────┬──────────────┬──────┘
                             │              │
                   ┌─────────▼────┐   ┌─────▼──────────────────┐
                   │ PaymentsAPI  │   │ NotificationsFunction  │
                   │  MongoDB     │   │  ⚡ SERVERLESS          │
                   └──────────────┘   │  (Azure Function)      │
                                      └────────────────────────┘

        Prometheus ──scrape /metrics──► UsersAPI, CatalogAPI, PaymentsAPI, Kong
             │
             └──────────► Grafana (dashboard em tempo real)
```

---

## 📦 Repositórios do projeto

| Repositório | Conteúdo |
|---|---|
| [`fcg-users-api`](../fcg-users-api) | Microsserviço de Usuários — cadastro, JWT, autorização |
| [`fcg-catalog-api`](../fcg-catalog-api) | Microsserviço de Catálogo — CRUD de jogos, MongoDB, Redis, início da compra |
| [`fcg-payments-api`](../fcg-payments-api) | Microsserviço de Pagamentos — processa e publica resultado |
| [`fcg-notifications-function`](../fcg-notifications-function) | **Função Serverless** de Notificações (Azure Function) |
| `fcg-orchestration` *(este)* | Gateway, docker-compose, manifestos K8s, observabilidade |

---

## 🔭 Stack de Observabilidade escolhida: **Opção A — Prometheus + Grafana**

Conforme exigido pela PDF, a escolha está documentada aqui. Optamos pela stack de código aberto pelos seguintes motivos:

1. **Sem dependência de conta externa ou trial** — o ambiente inteiro roda localmente
2. **Implantação via manifestos Kubernetes**, exatamente como a PDF pede para a Opção A
3. **Descoberta automática de alvos** pelas annotations `prometheus.io/*` nos Pods
4. **Dashboard provisionado como código** (`grafana/dashboards/fcg-overview.json`), versionado no repositório

### Métricas coletadas

| Métrica | Origem | Painel no Grafana |
|---|---|---|
| `http_request_duration_seconds` | prometheus-net | Latência p50/p95/p99 por serviço |
| `http_requests_received_total` | prometheus-net | Throughput total e por status code HTTP |
| Taxa de erros 5xx | derivada | Stat com alerta visual |
| `fcg_cache_hits_total` / `fcg_cache_misses_total` | CatalogAPI | Eficiência do cache Redis |
| `fcg_payments_processed_total{status}` | PaymentsAPI | Aprovados vs Rejeitados |
| `fcg_library_additions_total` | CatalogAPI | Jogos adicionados às bibliotecas |
| `kong_*` | plugin Prometheus do Kong | Métricas do próprio Gateway |

---

## 🚀 Opção 1 — Subir tudo com Docker Compose

### Pré-requisitos
- Docker Desktop rodando
- Azure Functions Core Tools v4 (`npm i -g azure-functions-core-tools@4 --unsafe-perm true`)

### Passos

```powershell
cd fcg-orchestration
docker compose up -d --build
```

Aguarde ~90 segundos na primeira execução (build das imagens + criação dos bancos).

```powershell
docker compose ps        # todos devem estar "healthy" ou "running"
```

### Suba a Função Serverless (em outro terminal)

```powershell
cd ../fcg-notifications-function/src/FCG.Notifications.Function
func start
```

> A função **não é um container** — ela é serverless por definição. Roda com o Core Tools consumindo as filas do RabbitMQ.

### Endereços

| Serviço | URL | Credenciais |
|---|---|---|
| **API Gateway (Kong)** | <http://localhost:8000> | — |
| Kong Admin API | <http://localhost:8001> | — |
| Grafana | <http://localhost:3000> | admin / admin |
| Prometheus | <http://localhost:9090> | — |
| RabbitMQ UI | <http://localhost:15672> | guest / guest |
| UsersAPI (direto, debug) | <http://localhost:8081/swagger> | — |
| CatalogAPI (direto, debug) | <http://localhost:8082/swagger> | — |
| PaymentsAPI (direto, debug) | <http://localhost:8083/swagger> | — |

> Em produção apenas a porta 8000 (Gateway) seria exposta. As portas diretas existem só para facilitar a demonstração.

### Teste end-to-end automatizado

```powershell
.\scripts\smoke-test.ps1
```

O script exercita: cadastro → validação de senha → login → bloqueio sem token → cache hit/miss → compra aprovada → compra rejeitada → avaliação → cadastro admin.

---

## ☸️ Opção 2 — Deploy no Kubernetes

### Pré-requisitos
- Docker Desktop com **Kubernetes habilitado** (Settings → Kubernetes → Enable Kubernetes)
- `kubectl` configurado (`kubectl cluster-info` deve responder)

### Deploy automatizado

```powershell
.\scripts\deploy-k8s.ps1
```

O script constrói as imagens, aplica os manifestos na ordem correta e aguarda cada camada ficar pronta.

### Deploy manual

```powershell
# 1. Imagens
docker build -t fcg/users-api:latest    ../fcg-users-api
docker build -t fcg/catalog-api:latest  ../fcg-catalog-api
docker build -t fcg/payments-api:latest ../fcg-payments-api

# 2. Namespace
kubectl apply -f k8s/00-namespace.yaml

# 3. Infraestrutura
kubectl apply -f k8s/infra/

# 4. Microsserviços (manifestos vivem em cada repositório)
kubectl apply -f ../fcg-users-api/k8s/
kubectl apply -f ../fcg-catalog-api/k8s/
kubectl apply -f ../fcg-payments-api/k8s/

# 5. API Gateway
kubectl apply -f k8s/gateway/

# 6. Observabilidade
kubectl apply -f k8s/observability/04-prometheus.yaml
kubectl create configmap grafana-dashboards --from-file=grafana/dashboards/fcg-overview.json -n fcg
kubectl apply -f k8s/observability/05-grafana.yaml

# 7. Verificar
kubectl get pods -n fcg
kubectl get svc -n fcg
```

### Endereços no Kubernetes

| Serviço | URL |
|---|---|
| **API Gateway (Kong)** | <http://localhost:30000> |
| Prometheus | <http://localhost:30090> |
| Grafana | <http://localhost:30300> |

```powershell
# RabbitMQ UI
kubectl port-forward -n fcg svc/rabbitmq 15672:15672
```

### Teste no Kubernetes

```powershell
.\scripts\smoke-test.ps1 -Gateway "http://localhost:30000"
```

---

## 🔐 ConfigMaps e Secrets

A PDF exige separação explícita. Aplicada em todos os serviços:

| Tipo | Conteúdo | Onde |
|---|---|---|
| **ConfigMap** | Nomes de filas, hosts de serviço, issuer/audience do JWT, ambiente, limites de negócio | `*/k8s/configmap.yaml`, `k8s/infra/*` |
| **Secret** | Connection strings (PostgreSQL, MongoDB, Redis), senha do RabbitMQ, chave HMAC do JWT | `*/k8s/secret.yaml`, `k8s/gateway/03-kong.yaml` |

> Os Secrets usam `stringData` em texto plano **apenas para fins didáticos**. Em produção: Sealed Secrets, External Secrets Operator ou um cofre gerenciado (Azure Key Vault / AWS Secrets Manager).

---

## 🔀 Fluxos orientados a eventos

### Fluxo de Cadastro de Usuário

```
1. POST /api/auth/register  →  Kong  →  UsersAPI
2. UsersAPI grava no PostgreSQL e publica UserCreatedEvent
3. NotificationsFunction (serverless) consome e "envia" e-mail de boas-vindas
```

### Fluxo de Compra de Jogo

```
1. POST /api/games/{id}/purchase  →  Kong (valida JWT)  →  CatalogAPI
2. CatalogAPI publica OrderPlacedEvent                    → HTTP 202 Accepted
3. PaymentsAPI consome, processa e publica PaymentProcessedEvent
4a. CatalogAPI consome: se Approved, grava na biblioteca (MongoDB) e invalida o cache
4b. NotificationsFunction consome: "envia" e-mail de confirmação ou recusa
```

### Filas e exchanges

| Exchange (MassTransit) | Fila | Consumidor |
|---|---|---|
| `FCG.Contracts:OrderPlacedEvent` | `payments-order-placed` | PaymentsAPI |
| `FCG.Contracts:PaymentProcessedEvent` | `catalog-payment-processed` | CatalogAPI |
| `FCG.Contracts:PaymentProcessedEvent` | `notifications-payment-processed` | **Function** |
| `FCG.Contracts:UserCreatedEvent` | `notifications-user-created` | **Function** |

As filas e bindings da Function são pré-provisionados por `rabbitmq/definitions.json` (compose) e pelo ConfigMap `rabbitmq-definitions` (K8s).

---

## 🗄️ Persistência Poliglota

| Tecnologia | Uso | Justificativa |
|---|---|---|
| **PostgreSQL** | Usuários; catálogo de jogos | Dados estruturados, relacionais, transacionais |
| **MongoDB** | Biblioteca do usuário, avaliações, logs de eventos, histórico de pagamentos | Schema flexível (tags livres nas avaliações), alta volumetria, leitura sempre por chave (`userId`), sem joins |
| **Redis** | Cache de catálogo, item e biblioteca | Reduz round-trip ao PostgreSQL em consultas repetidas de leitura |

### Estratégia de cache (cache-aside)

| Chave | TTL | Invalidada em |
|---|---|---|
| `games:list:all` / `games:list:{genre}` | 2 min | Create / Update / Delete de jogo |
| `games:item:{id}` | 5 min | Update / Delete daquele jogo |
| `library:{userId}` | 1 min | Novo jogo entra na biblioteca |

Falha no Redis **não derruba a requisição** — o serviço degrada para a origem.

---

## 🛡️ API Gateway — rotas e políticas

Configuração versionada em `kong/kong.yml` (compose) e no ConfigMap `kong-declarative-config` (K8s).

| Rota | Método | Destino | JWT? |
|---|---|---|---|
| `/api/auth/*` | POST | users-api | ❌ público |
| `/api/users/*` | todos | users-api | ✅ obrigatório |
| `/api/games` | GET | catalog-api | ❌ público (vitrine) |
| `/api/games` | POST/PUT/DELETE | catalog-api | ✅ obrigatório |
| `/api/library/*` | todos | catalog-api | ✅ obrigatório |

### Plugins globais

| Plugin | Função |
|---|---|
| `jwt` | Valida assinatura HS256 e expiração. `key_claim_name: iss` casa com o consumer `FCG.Gateway` |
| `prometheus` | Expõe métricas do Gateway em `:8001/metrics` |
| `rate-limiting` | 120 req/min por cliente |
| `cors` | Libera consumo por front-ends |
| `correlation-id` | Injeta `X-Correlation-ID` para rastreabilidade |

---

## 🧪 Comandos úteis

```powershell
# Logs
docker compose logs -f catalog-api
kubectl logs -n fcg -l app=payments-api -f

# Ver as filas e mensagens
# → RabbitMQ UI em http://localhost:15672

# Inspecionar o MongoDB
docker exec -it fcg-mongo mongosh
#   use fcg_catalog
#   db.library_items.find().pretty()
#   db.game_reviews.find().pretty()

# Inspecionar o Redis
docker exec -it fcg-redis redis-cli
#   KEYS *
#   TTL "fcg-catalog:games:list:all"

# Gerar carga para o dashboard do Grafana
1..200 | ForEach-Object { Invoke-RestMethod http://localhost:8000/api/games | Out-Null }

# Derrubar tudo
docker compose down -v
kubectl delete namespace fcg
```

---

## 🔧 Resolução de problemas

| Sintoma | Causa provável | Solução |
|---|---|---|
| `401 Unauthorized` em rota pública | Kong aplicou JWT onde não devia | Verifique `methods` nas rotas do `kong.yml` |
| Function não recebe mensagens | Filas não existem | Confirme que o RabbitMQ carregou `definitions.json`: veja as filas em <http://localhost:15672> |
| Biblioteca vazia após compra | PaymentsAPI ou CatalogAPI fora do ar | `docker compose logs payments-api catalog-api` |
| Grafana sem dados | Prometheus não está coletando | Veja <http://localhost:9090/targets> — todos devem estar `UP` |
| `ImagePullBackOff` no K8s | Imagem não construída localmente | Rode os `docker build` antes do `kubectl apply` |
| Pods `Pending` | Recursos insuficientes | Aumente CPU/memória do Docker Desktop (Settings → Resources) |

---

## 👤 Credenciais de demonstração

| Perfil | E-mail | Senha |
|---|---|---|
| Administrador | `admin@fcg.com` | `Admin@123` |

O catálogo é semeado com 4 jogos: The Witcher 3 (R$ 99,90), Stardew Valley (R$ 39,90), Hades (R$ 49,90) e Elden Ring (R$ 249,90).

> O Elden Ring custa acima do limite de aprovação (R$ 200) — use-o para demonstrar o **caminho de pagamento rejeitado**.
