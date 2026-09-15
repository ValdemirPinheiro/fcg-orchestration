# Roteiro de Gravação — Vídeo Tech Challenge Fase 3 (20 min)

> Deixe este arquivo aberto em uma segunda tela. As falas em ***itálico negrito*** são para LER em voz alta. 📺 = mostrar/clicar. ⌨️ = comando/payload para colar.

---

## 🚦 Checklist pré-gravação

### Ambiente (faça 20 min antes de gravar)

```powershell
# 1. Suba tudo
cd C:\Users\USUARIO\Dev\FCG-Fase3\fcg-orchestration
docker compose down -v          # ambiente limpo
docker compose up -d --build    # aguarde ~2 min na 1a vez
docker compose ps               # todos healthy

# 2. Em OUTRO terminal — a função serverless
cd C:\Users\USUARIO\Dev\FCG-Fase3\fcg-notifications-function\src\FCG.Notifications.Function
func start                      # deve listar as 2 funções

# 3. Gere carga para o Grafana ter dados
1..300 | ForEach-Object { Invoke-RestMethod http://localhost:8000/api/games | Out-Null }
```

### Janelas abertas (uma por Alt+Tab)

- [ ] **VS Code** com a pasta `FCG-Fase3` aberta
- [ ] **Terminal 1**: `docker compose` (mostra logs)
- [ ] **Terminal 2**: `func start` rodando — **deixe visível, é a estrela do serverless**
- [ ] **Terminal 3**: PowerShell livre para comandos
- [ ] **Browser tab 1**: <http://localhost:3000> (Grafana → dashboard FCG)
- [ ] **Browser tab 2**: <http://localhost:9090/targets> (Prometheus)
- [ ] **Browser tab 3**: <http://localhost:15672> (RabbitMQ, guest/guest)
- [ ] **Browser tab 4**: GitHub com os 5 repositórios
- [ ] **MongoDB Compass** conectado em `mongodb://localhost:27017`

### Gravação
- [ ] OBS Studio: 1920×1080, 30fps
- [ ] Notificações do Windows silenciadas
- [ ] Microfone testado

---

## 🎬 CENA 1 — Abertura (0:00 → 0:40)

📺 Slide/câmera.

***"Olá, sou Valdemir Pinheiro, da pós FIAP. Esta é a entrega da Fase 3 do Tech Challenge: a FIAP Cloud Games evoluída para uma arquitetura de microsserviços profissionalizada. Nos próximos 20 minutos vou demonstrar os quatro pilares que a fase exige: um API Gateway com Kong como ponto de entrada único, a migração do serviço de notificações para serverless, uma stack completa de observabilidade com Prometheus e Grafana, e persistência poliglota com MongoDB e cache em Redis. Vamos lá."***

---

## 🎬 CENA 2 — Arquitetura e repositórios (0:40 → 3:00)

📺 GitHub, mostrando os 5 repositórios.

***"A PDF exige um repositório Git independente por microsserviço. São cinco no total."***

📺 Aponte cada um:

***"fcg-users-api, responsável por cadastro, autenticação e emissão de JWT. fcg-catalog-api, com o CRUD de jogos e o início do fluxo de compra. fcg-payments-api, que processa pagamentos de forma assíncrona. fcg-notifications-function, que é a função serverless — repositório próprio, como a Fase 3 exige. E fcg-orchestration, com o gateway, os manifestos e a observabilidade."***

📺 Abra `fcg-orchestration` → `README.md`.

***"O README da orquestração é o guia central. Aqui está o diagrama da arquitetura."***

📺 Mostre o diagrama ASCII no README, acompanhando com o cursor:

***"O cliente bate no Kong, que é a única porta de entrada. O Kong valida o JWT e roteia para o UsersAPI ou o CatalogAPI. Esses serviços publicam eventos no RabbitMQ. O PaymentsAPI consome e devolve o resultado. E a função serverless consome os eventos para enviar e-mails. Por baixo, o Prometheus coleta métricas de todos e alimenta o Grafana."***

📺 Faça scroll até a seção "Stack de Observabilidade escolhida".

***"A PDF pede que a escolha da stack de observabilidade seja documentada no README da orquestração. Escolhi a Opção A — Prometheus e Grafana — e a justificativa está aqui documentada."***

---

## 🎬 CENA 3 — Ambiente rodando (3:00 → 4:30)

📺 **Terminal 1**.

⌨️ `docker compose ps`

***"O ambiente completo sobe com um único comando: docker compose up. Temos aqui os dois PostgreSQL, um por serviço seguindo database-per-service, o MongoDB, o Redis, o RabbitMQ, os três microsserviços, o Kong, o Prometheus e o Grafana."***

📺 **Terminal 2** — o `func start`.

***"E aqui, separadamente, a função serverless. Ela não é um container por definição — roda no Azure Functions Core Tools. Repare que as duas funções estão registradas com trigger de RabbitMQ: SendWelcomeEmail e SendPurchaseConfirmationEmail."***

📺 Deixe o terminal da função visível na tela — vai ser usado nas próximas cenas.

---

## 🎬 CENA 4 — API Gateway: roteamento e segurança (4:30 → 8:00)

📺 VS Code → `fcg-orchestration/kong/kong.yml`.

***"A configuração do Kong é declarativa e está versionada no repositório de orquestração, como a PDF exige. Temos dois services — users-api e catalog-api — e as rotas."***

📺 Aponte as rotas:

***"Repare na distinção: a rota de autenticação é pública, porque login e cadastro não podem exigir token. Já a rota de usuários tem o plugin JWT. No catálogo, o GET é público — é a vitrine — mas POST, PUT e DELETE exigem token."***

📺 Role até `consumers`:

***"Aqui está o consumer com a credencial JWT. A key é FCG.Gateway, que bate com a claim iss emitida pelo UsersAPI, e o secret é a mesma chave HMAC. É assim que o Kong valida a assinatura do token sem precisar chamar o serviço de usuários."***

### Demonstração prática

📺 **Terminal 3**.

⌨️ **Teste 1 — rota pública passa sem token:**
```powershell
Invoke-RestMethod http://localhost:8000/api/games | Select-Object title, price
```

***"Catálogo público através do Gateway, sem token. Funciona."***

⌨️ **Teste 2 — rota protegida sem token é barrada pelo Kong:**
```powershell
Invoke-RestMethod http://localhost:8000/api/library/me
```

***"Agora a biblioteca, que é protegida, sem token. O Kong barrou com 401 — e repare: a requisição nem chegou ao microsserviço. O Gateway parou antes."***

⌨️ **Teste 3 — cadastro (já dispara o fluxo de eventos):**
```powershell
$body = @{ name="Maria Aluna"; email="maria.demo@fcg.com"; password="Senha@123" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://localhost:8000/api/auth/register -ContentType "application/json" -Body $body
```

📺 **IMEDIATAMENTE mostre o Terminal 2 (func start)** — o e-mail de boas-vindas apareceu.

***"Olha o que aconteceu: o cadastro publicou o UserCreatedEvent no RabbitMQ, e a função serverless foi acionada e 'enviou' o e-mail de boas-vindas. Esse é o primeiro fluxo orientado a eventos."***

⌨️ **Teste 4 — login e token:**
```powershell
$login = Invoke-RestMethod -Method Post -Uri http://localhost:8000/api/auth/login -ContentType "application/json" -Body (@{email="maria.demo@fcg.com"; password="Senha@123"} | ConvertTo-Json)
$headers = @{ Authorization = "Bearer $($login.token)" }
$login.token
```

📺 Copie o token, abra <https://jwt.io>, cole.

***"Decodificando o token: temos o sub com o ID do usuário, o email, a role, e o iss como FCG.Gateway — que é exatamente a key que o Kong usa para validar."***

⌨️ **Teste 5 — agora com token funciona:**
```powershell
Invoke-RestMethod http://localhost:8000/api/library/me -Headers $headers
```

***"Com o token válido, o Kong deixa passar. Biblioteca vazia, porque a Maria ainda não comprou nada."***

---

## 🎬 CENA 5 — Fluxo de compra completo (8:00 → 11:30)

***"Agora o fluxo mais importante: a compra de um jogo, que atravessa três microsserviços e a função serverless de forma totalmente assíncrona."***

📺 VS Code → mostre rapidamente `fcg-catalog-api/.../GamesController.cs`, método `Purchase`.

***"Quando o usuário compra, o CatalogAPI não processa nada — ele apenas publica um OrderPlacedEvent e devolve 202 Accepted. O processamento acontece em background."***

⌨️ **Compra aprovada:**
```powershell
$games = Invoke-RestMethod http://localhost:8000/api/games
$stardew = $games | Where-Object { $_.title -like "*Stardew*" }
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/games/$($stardew.id)/purchase" -Headers $headers
```

***"202 Accepted, com o ID do pedido e status PendingPayment. Agora vamos ver a cadeia de eventos acontecendo."***

📺 **Terminal 1** — logs do docker compose.

⌨️ `docker compose logs --tail=30 payments-api`

***"O PaymentsAPI consumiu o OrderPlacedEvent, processou o pagamento simulado e publicou o PaymentProcessedEvent com status Approved."***

⌨️ `docker compose logs --tail=20 catalog-api`

***"O CatalogAPI consumiu esse evento e adicionou o jogo à biblioteca no MongoDB."***

📺 **Terminal 2 (func start)**.

***"E a função serverless também consumiu o mesmo evento e enviou o e-mail de confirmação da compra. Um evento, dois consumidores independentes."***

⌨️ **Confirme a biblioteca:**
```powershell
Invoke-RestMethod http://localhost:8000/api/library/me -Headers $headers
```

***"Biblioteca atualizada, com o preço pago registrado."***

### Caminho de rejeição

⌨️ **Compra rejeitada:**
```powershell
$elden = $games | Where-Object { $_.title -like "*Elden*" }
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/games/$($elden.id)/purchase" -Headers $headers
```

***"O Elden Ring custa 249 reais, acima do limite de aprovação de 200 configurado no simulador de pagamento."***

📺 Aguarde ~5 segundos, mostre o **Terminal 2 (func start)**.

***"A função recebeu o evento com status Rejected e enviou o e-mail de recusa."***

⌨️ ```powershell
Invoke-RestMethod http://localhost:8000/api/library/me -Headers $headers
```

***"E o jogo não entrou na biblioteca. A consistência foi mantida através dos eventos."***

📺 **Browser → RabbitMQ UI** (<http://localhost:15672>) → aba **Queues**.

***"No RabbitMQ podemos ver as filas: payments-order-placed, catalog-payment-processed, e as duas filas que a função serverless consome."***

---

## 🎬 CENA 6 — Serverless em detalhe (11:30 → 13:30)

📺 VS Code → `fcg-notifications-function/src/.../NotificationFunctions.cs`.

***"Vamos olhar a função por dentro. Na Fase 2, o NotificationsAPI era um container rodando 24 horas por dia só esperando eventos — exatamente o desperdício que a PDF da Fase 3 aponta."***

📺 Aponte o atributo:

```csharp
[RabbitMQTrigger("notifications-user-created", ConnectionStringSetting = "RabbitMqConnection")]
```

***"Agora é uma função com trigger de RabbitMQ, usando a extensão oficial da Microsoft. Ela só executa quando há mensagem. Sem evento, não há consumo de recurso."***

📺 Mostre `Contracts/Events.cs`, a classe `MassTransitEnvelope`.

***"Um detalhe técnico: o MassTransit envelopa as mensagens. Então criei um desserializador que extrai o payload real do campo message do envelope, com fallback para payload direto."***

📺 Abra `fcg-notifications-function/infra/main.bicep`.

***"A PDF exige infraestrutura como código para a função. Usei Bicep, que é o padrão nativo do Azure. Ele provisiona o Storage Account, o Application Insights, e o ponto mais importante: um App Service Plan Y1, que é o plano Consumption — serverless puro, escala a zero quando ocioso e cobra por execução."***

📺 Aponte a linha do plano:
```bicep
sku: {
  name: 'Y1'
  tier: 'Dynamic'
}
```

---

## 🎬 CENA 7 — Observabilidade (13:30 → 16:30)

📺 **Browser → Prometheus** (<http://localhost:9090/targets>).

***"Começando pelo Prometheus. Aqui estão os alvos coletados: users-api, catalog-api, payments-api e o próprio Kong. Todos UP."***

📺 Vá em **Graph** e execute uma query:

⌨️ `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job))`

***"Essa query calcula a latência no percentil 95 por serviço."***

📺 VS Code → `fcg-catalog-api/.../Program.cs`, aponte:

```csharp
app.UseHttpMetrics();   // instrumentação
app.MapMetrics();       // expõe /metrics
```

***"A instrumentação é o prometheus-net. Duas linhas: UseHttpMetrics coleta latência, contagem e status code de cada requisição, e MapMetrics expõe o endpoint /metrics."***

📺 **Browser → Grafana** (<http://localhost:3000>) → dashboard **FCG — Visão Geral dos Microsserviços**.

***"E aqui está o dashboard, provisionado como código junto com o repositório — não foi criado na mão pela interface."***

📺 Percorra os painéis com o cursor:

***"No topo, os indicadores: requisições por segundo, taxa de erros com alerta visual por cor, latência p95 e serviços no ar."***

***"Abaixo, a latência de requisições em p50, p95 e p99 por serviço — que é exatamente o que a PDF pede."***

***"Aqui, a contagem de requisições por status code HTTP, empilhada. E as requisições por serviço."***

***"E na última linha, métricas de negócio que criei especificamente: cache hits versus misses do Redis, pagamentos aprovados versus rejeitados, e o total de jogos adicionados às bibliotecas."***

📺 **Terminal 3** — gere carga ao vivo:

⌨️ ```powershell
1..100 | ForEach-Object { Invoke-RestMethod http://localhost:8000/api/games | Out-Null }
```

📺 Volte ao Grafana e mostre os gráficos subindo em tempo real.

***"Métricas em tempo real, com refresh de 5 segundos."***

---

## 🎬 CENA 8 — Persistência poliglota e cache (16:30 → 18:30)

📺 VS Code → `fcg-catalog-api/.../Infrastructure/MongoStore.cs`.

***"A PDF exige NoSQL. Usei MongoDB com o driver oficial, em quatro cenários que justificam NoSQL de verdade."***

📺 Aponte as classes:

***"library_items, a biblioteca do usuário — sempre lida por userId, sem joins. game_reviews, as avaliações, com schema flexível: array de tags livres e campos opcionais. event_logs, log append-only de eventos de domínio, alta volumetria. E no PaymentsAPI, o histórico de transações."***

📺 **MongoDB Compass** → database `fcg_catalog`.

***"Aqui no Compass: a coleção library_items com o jogo que a Maria comprou. E repare no índice único composto de UserId mais GameId — é ele que garante idempotência: se o mesmo evento for reprocessado, não duplica."***

📺 Vá em `game_reviews` (se tiver criado alguma) ou crie ao vivo:

⌨️ ```powershell
Invoke-RestMethod -Method Post -Uri "http://localhost:8000/api/games/$($stardew.id)/reviews" -Headers $headers -ContentType "application/json" -Body (@{rating=5; comment="Excelente!"; tags=@("relaxante","indie")} | ConvertTo-Json)
```

📺 Atualize o Compass mostrando o documento com o array de tags.

### Cache Redis

📺 VS Code → `Infrastructure/CacheService.cs`.

***"Para o cache, implementei o padrão cache-aside com IDistributedCache sobre Redis. Tenta o cache; se der miss, vai na origem, grava e devolve."***

📺 Aponte o try/catch:

***"E um detalhe importante de resiliência: se o Redis cair, a aplicação não quebra — ela degrada graciosamente e vai direto ao banco."***

📺 **Terminal 3** — demonstre o ganho:

⌨️ ```powershell
# Primeira chamada — cache miss
Measure-Command { Invoke-RestMethod http://localhost:8000/api/games } | Select-Object TotalMilliseconds
# Segunda — cache hit
Measure-Command { Invoke-RestMethod http://localhost:8000/api/games } | Select-Object TotalMilliseconds
```

***"A diferença de tempo entre a primeira e a segunda chamada é o cache funcionando."***

⌨️ ```powershell
docker exec -it fcg-redis redis-cli KEYS *
```

***"E aqui as chaves no Redis: a lista do catálogo, os itens individuais e a biblioteca do usuário."***

---

## 🎬 CENA 9 — Kubernetes (18:30 → 19:30)

📺 VS Code → `fcg-orchestration/k8s/`.

***"Todo o ambiente também roda em Kubernetes. Os manifestos de infraestrutura, gateway e observabilidade estão no repositório de orquestração, e cada microsserviço tem seus próprios manifestos na pasta k8s da sua raiz."***

📺 Abra `fcg-users-api/k8s/deployment.yaml`.

***"Deployment, nunca Pod isolado, como a PDF exige. Com réplicas, health checks e limites de recursos."***

📺 Abra `configmap.yaml` e `secret.yaml` lado a lado.

***"E a separação obrigatória: ConfigMap para configurações não sensíveis — host do RabbitMQ, issuer do JWT. Secret para dados sensíveis — connection strings e a chave HMAC."***

📺 **Terminal 3** (se já tiver feito o deploy):

⌨️ ```powershell
kubectl get pods -n fcg
kubectl get svc -n fcg
```

***"Todos os pods rodando no cluster local do Docker Desktop. E os services — repare que a comunicação interna usa os nomes de service, como http://users-api:80."***

> **Se não deu tempo de subir no K8s:** mostre apenas os manifestos e diga: ***"O deploy é automatizado pelo script deploy-k8s.ps1, que constrói as imagens e aplica tudo na ordem correta."***

---

## 🎬 CENA 10 — Encerramento (19:30 → 20:00)

📺 GitHub / README.

***"Resumindo a Fase 3: API Gateway com Kong como ponto de entrada único validando JWT e roteando. Notificações migradas para Azure Function serverless, acionada por fila, com infraestrutura como código em Bicep. Observabilidade Opção A com Prometheus e Grafana, dashboard provisionado como código mostrando latência, throughput por status code e taxa de erros. E persistência poliglota com PostgreSQL para dados transacionais, MongoDB para dados flexíveis e de alta volumetria, e Redis para cache distribuído. Tudo containerizado, orquestrado em Kubernetes e documentado. Repositórios no GitHub. Muito obrigado!"***

---

## 🆘 Plano B

| Problema | Ação |
|---|---|
| Função não recebe eventos | Confira as filas em <http://localhost:15672>. Se não existirem, `docker compose restart rabbitmq` |
| Compra não chega à biblioteca | `docker compose logs payments-api catalog-api` — mostre os logs e explique o fluxo |
| Grafana sem dados | Gere carga: `1..200 \| % { Invoke-RestMethod http://localhost:8000/api/games \| Out-Null }` |
| K8s não subiu a tempo | Mostre só os manifestos e o script — a PDF valoriza os artefatos |
| Passando de 20 min | Corte a Cena 9 (Kubernetes) para 30s e encurte a Cena 2 |

---

## ⏱️ Distribuição do tempo

| Cena | Assunto | Duração | Acumulado |
|---|---|---|---|
| 1 | Abertura | 0:40 | 0:40 |
| 2 | Arquitetura e repositórios | 2:20 | 3:00 |
| 3 | Ambiente rodando | 1:30 | 4:30 |
| 4 | **API Gateway** | 3:30 | 8:00 |
| 5 | **Fluxo de compra** | 3:30 | 11:30 |
| 6 | **Serverless** | 2:00 | 13:30 |
| 7 | **Observabilidade** | 3:00 | 16:30 |
| 8 | **NoSQL + Cache** | 2:00 | 18:30 |
| 9 | Kubernetes | 1:00 | 19:30 |
| 10 | Encerramento | 0:30 | 20:00 |

Os quatro requisitos obrigatórios da PDF (cenas 4, 6, 7, 8) recebem 11:30 dos 20 minutos — pouco mais da metade, que é a proporção certa.
