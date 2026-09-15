# Relatório de Entrega — Tech Challenge Fase 3

> Documento de submissão da Fase 3 do Tech Challenge da pós-graduação FIAP.

## 1. Identificação

| Campo | Valor |
|---|---|
| **Nome do grupo** | Valdemir Pinheiro |
| **Modalidade** | Individual |
| **Data de entrega** | `<PREENCHER — DD/MM/AAAA>` |

## 2. Participantes

| Nome | E-mail | Username Discord |
|---|---|---|
| Valdemir Pinheiro | pinheiroone@gmail.com | pinheiro3199 |

## 3. Links dos repositórios

| Repositório | Finalidade | URL |
|---|---|---|
| `fcg-users-api` | Microsserviço de Usuários (cadastro, JWT, autorização) | <https://github.com/ValdemirPinheiro/fcg-users-api> |
| `fcg-catalog-api` | Microsserviço de Catálogo (jogos, MongoDB, Redis, compra) | <https://github.com/ValdemirPinheiro/fcg-catalog-api> |
| `fcg-payments-api` | Microsserviço de Pagamentos (processamento assíncrono) | <https://github.com/ValdemirPinheiro/fcg-payments-api> |
| `fcg-notifications-function` | **Função Serverless** de Notificações (Azure Function) | <https://github.com/ValdemirPinheiro/fcg-notifications-function> |
| `fcg-orchestration` | Gateway, Docker Compose, Kubernetes, Observabilidade | <https://github.com/ValdemirPinheiro/fcg-orchestration> |

## 4. Link da documentação

O **README.md do repositório de orquestração** (`fcg-orchestration`) é o guia central, conforme exigido pela PDF: contém a arquitetura, a stack de observabilidade escolhida e as instruções completas de execução via Docker e Kubernetes.

- Documentação central: <https://github.com/ValdemirPinheiro/fcg-orchestration/blob/main/README.md>

## 5. Link do vídeo

- `<PREENCHER — https://youtu.be/...>`

---

## 6. Escopo entregue

### 6.1 API Gateway ✅

- **Kong API Gateway 3.7** em modo declarativo (DB-less), como ponto de entrada **único**.
- Configuração versionada em `kong/kong.yml` (Docker Compose) e no ConfigMap `kong-declarative-config` (Kubernetes) — no repositório de orquestração, como exige a PDF.
- **Validação de token JWT** via plugin `jwt` com consumer `fcg-platform` e credencial HS256 cuja `key` casa com a claim `iss` emitida pelo UsersAPI.
- **Roteamento** para `UsersAPI` e `CatalogAPI`, com distinção entre rotas públicas (login, cadastro, vitrine do catálogo) e protegidas.
- Plugins adicionais: `prometheus` (métricas do Gateway), `rate-limiting` (120 req/min), `cors` e `correlation-id`.

### 6.2 Migração para Serverless ✅

- `NotificationsAPI` (container 24/7 da Fase 2) refatorado para **Azure Function** (.NET 8 isolated worker, Functions v4).
- Acionada **diretamente por mensagens do RabbitMQ** através da extensão oficial `Microsoft.Azure.Functions.Worker.Extensions.RabbitMQ` — sem container ocioso.
- Duas funções:
  - `SendWelcomeEmail` — trigger na fila `notifications-user-created`
  - `SendPurchaseConfirmationEmail` — trigger na fila `notifications-payment-processed`
- **Infraestrutura como Código** em `infra/main.bicep`: Storage Account, App Service Plan **Y1 (Consumption — escala a zero)**, Application Insights e Function App.
- Repositório próprio, conforme exigido pela PDF.

### 6.3 Observabilidade — **Opção A: Prometheus + Grafana** ✅

- **Escolha documentada no README.md do repositório de orquestração**, como a PDF exige.
- `UsersAPI` e `CatalogAPI` (e também `PaymentsAPI`) instrumentados com `prometheus-net.AspNetCore`, expondo `/metrics` no formato Prometheus.
- **Implantação via manifestos Kubernetes** (`k8s/observability/`), conforme exigido para a Opção A.
- Prometheus com **descoberta automática** de alvos pelas annotations `prometheus.io/*` nos Pods.
- **Dashboard do Grafana provisionado como código** (`grafana/dashboards/fcg-overview.json`) com:
  - **Latência de requisições** — p50, p95 e p99 por serviço
  - **Contagem de requisições** — total e **por status code HTTP**
  - **Taxa de erros** — percentual de 5xx com alerta visual por cor
  - Painéis de negócio: cache hits/misses, pagamentos aprovados vs rejeitados, adições à biblioteca

### 6.4 Persistência Poliglota ✅

**NoSQL — MongoDB** (driver oficial `MongoDB.Driver`):

| Coleção | Conteúdo | Justificativa do uso de NoSQL |
|---|---|---|
| `library_items` | Biblioteca de jogos por usuário | Leitura sempre por `userId`, sem joins, alta volumetria |
| `game_reviews` | Avaliações com tags livres | **Schema flexível** — campos opcionais e array de tags variável |
| `event_logs` | Log append-only de eventos de domínio | Alta volumetria, escrita intensiva |
| `payments` | Histórico de transações | Append-only, consultado por usuário e data |

**Cache — Redis** (`IDistributedCache` + `StackExchange.Redis`):

- Padrão **cache-aside** em `Infrastructure/CacheService.cs`
- Chaves: `games:list:*` (TTL 2 min), `games:item:{id}` (5 min), `library:{userId}` (1 min)
- Invalidação explícita em operações de escrita
- **Degradação graciosa**: falha do Redis não derruba a requisição
- Métricas `fcg_cache_hits_total` e `fcg_cache_misses_total` expostas ao Prometheus

### 6.5 Base de microsserviços (Fase 2) ✅

Construída integralmente como fundação desta entrega:

- **Quatro serviços** em **repositórios Git independentes**
- **Mensageria** com RabbitMQ + MassTransit, implementando os dois fluxos orientados a eventos da PDF da Fase 2 (`UserCreatedEvent`, `OrderPlacedEvent`, `PaymentProcessedEvent`)
- **Dockerfiles multi-stage** otimizados, com usuário não-root
- **`docker-compose.yml`** que sobe o ambiente completo
- **Manifestos Kubernetes** em `/k8s` na raiz de cada repositório, com **Deployments** (nunca Pods isolados), **Services**, **ConfigMaps** (não sensíveis) e **Secrets** (sensíveis)
- Comunicação intra-cluster por **nomes de Service** (`http://users-api:80`, `http://catalog-api:80`)

---

## 7. Como executar

Instruções completas no `README.md` do repositório `fcg-orchestration`. Resumo:

### Docker Compose

```powershell
cd fcg-orchestration
docker compose up -d --build

# Em outro terminal — a função serverless
cd ../fcg-notifications-function/src/FCG.Notifications.Function
func start

# Teste end-to-end
cd ../../../fcg-orchestration
.\scripts\smoke-test.ps1
```

### Kubernetes

```powershell
cd fcg-orchestration
.\scripts\deploy-k8s.ps1
kubectl get pods -n fcg
.\scripts\smoke-test.ps1 -Gateway "http://localhost:30000"
```

### Endereços

| Serviço | Docker Compose | Kubernetes |
|---|---|---|
| **API Gateway** | <http://localhost:8000> | <http://localhost:30000> |
| Grafana | <http://localhost:3000> | <http://localhost:30300> |
| Prometheus | <http://localhost:9090> | <http://localhost:30090> |
| RabbitMQ UI | <http://localhost:15672> | `kubectl port-forward` |

### Credenciais

| Perfil | E-mail | Senha |
|---|---|---|
| Administrador | `admin@fcg.com` | `Admin@123` |

---

## 8. Decisões técnicas relevantes

| Decisão | Justificativa |
|---|---|
| **Kong DB-less** | Configuração 100% declarativa e versionada em Git, sem banco de dados auxiliar. Alinhado com GitOps. |
| **Azure Functions em vez de AWS Lambda** | Roda localmente com Azure Functions Core Tools, sem conta cloud nem custo, e tem trigger nativo de RabbitMQ via extensão oficial da Microsoft. |
| **Prometheus + Grafana (Opção A)** | Sem dependência de trial ou conta externa; implantação via manifestos K8s exatamente como a PDF pede para essa opção. |
| **MassTransit sobre RabbitMQ** | Abstrai publish/subscribe, retry e idempotência com pouquíssimo código. Filas para a Function pré-provisionadas por `definitions.json`. |
| **PostgreSQL em vez de SQL Server** | ~200MB por container contra ~1.5GB do SQL Server. Com 8 containers no ambiente, a diferença é decisiva. |
| **Database-per-service** | Cada microsserviço possui seu próprio banco, garantindo autonomia e evitando acoplamento por dados compartilhados. |
| **Snapshot de preço em `library_items`** | O valor pago é gravado na aquisição; promoções futuras não alteram o histórico. |
| **Índice único `(UserId, GameId)`** | Garante idempotência do consumidor de `PaymentProcessedEvent` no nível do banco. |
| **Projeto único por microsserviço** | Microsserviço pequeno com 4 camadas é over-engineering. A separação de responsabilidades aqui é entre serviços, não dentro deles. |

---

## 9. Estrutura dos repositórios

```
fcg-users-api/                  fcg-catalog-api/               fcg-payments-api/
├── src/FCG.Users.API/          ├── src/FCG.Catalog.API/       ├── src/FCG.Payments.API/
│   ├── Contracts/              │   ├── Contracts/             │   ├── Contracts/
│   ├── Domain/                 │   ├── Domain/                │   ├── Consumers/
│   ├── Infrastructure/         │   ├── Infrastructure/        │   └── Infrastructure/
│   └── Controllers/            │   ├── Consumers/             ├── k8s/
├── k8s/                        │   └── Controllers/           ├── Dockerfile
│   ├── deployment.yaml         ├── k8s/                       └── README.md
│   ├── configmap.yaml          ├── Dockerfile
│   └── secret.yaml             └── README.md
├── Dockerfile
└── README.md

fcg-notifications-function/     fcg-orchestration/
├── src/.../                    ├── docker-compose.yml
│   ├── NotificationFunctions   ├── kong/kong.yml
│   ├── Contracts/              ├── rabbitmq/definitions.json
│   └── host.json               ├── prometheus/prometheus.yml
├── infra/                      ├── grafana/{dashboards,provisioning}/
│   ├── main.bicep              ├── k8s/{infra,gateway,observability}/
│   └── deploy.ps1              ├── scripts/{deploy-k8s,smoke-test}.ps1
└── README.md                   ├── docs/
                                └── README.md  ← guia central
```

---

## 10. Referências

- [Kong Gateway — Declarative Configuration](https://docs.konghq.com/gateway/latest/production/deployment-topologies/db-less-and-declarative-config/)
- [Azure Functions — RabbitMQ bindings](https://learn.microsoft.com/azure/azure-functions/functions-bindings-rabbitmq)
- [MassTransit](https://masstransit.io/)
- [prometheus-net](https://github.com/prometheus-net/prometheus-net)
- [Grafana — Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [MongoDB .NET Driver](https://www.mongodb.com/docs/drivers/csharp/)
