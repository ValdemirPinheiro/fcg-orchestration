# Roteiro de Narração — Vídeo Fase 3

> **Fluxo:** o `demo-auto.ps1` grava a tela sozinho (~16 min). Depois você abre o vídeo no editor, aperta gravar no microfone e **narra acompanhando o número do PASSO que aparece no cabeçalho de cada tela**. Cada passo abaixo tem a duração aproximada na tela — é o seu tempo para falar.
>
> Ritmo natural de fala: ~2,5 palavras/segundo. Uma frase de 25 palavras ≈ 10 s.

---

## 🎬 Gravação da tela (sem áudio)

```powershell
# Terminal A
cd C:\Users\USUARIO\Dev\FCG-Fase3\fcg-orchestration
.\scripts\prep-video.ps1 -WithK8s        # ou sem -WithK8s
```

Siga o checklist que ele imprime (Terminal B com título `FCG-FUNC` + `func start`, navegador aberto, OBS em REC), depois:

```powershell
.\scripts\demo-auto.ps1                  # ensaio: -Pace 0.15
```

**Não toque em nada** até aparecer "DEMO CONCLUIDA". Pare o OBS.

## 🎙️ Dublagem

1. Abra o MP4 no **Clipchamp** (já vem no Windows 11) → *Gravar e criar* → *Áudio*
2. Dê play e narre acompanhando os passos. Errou? Pare, volte ao passo, regrave só aquele trecho.
3. Exporte em 1080p → YouTube "Não listado" → me manda o link.

---

## CENA 1 — Abertura

### Passo 1 · cartão de título · 40 s
***"Olá, sou Valdemir Pinheiro, da pós FIAP. Esta é a entrega da Fase 3 do Tech Challenge: a FIAP Cloud Games evoluída para uma arquitetura de microsserviços profissionalizada. Vou demonstrar os quatro pilares que a fase exige: API Gateway com Kong como ponto de entrada único, migração do serviço de notificações para serverless, observabilidade com Prometheus e Grafana, e persistência poliglota com MongoDB e cache em Redis. Vamos lá."***

---

## CENA 2 — Arquitetura e repositórios

### Passo 2 · GitHub, lista de repositórios · 39 s
***"A PDF exige um repositório Git independente por microsserviço. São cinco: fcg-users-api, com cadastro, autenticação e emissão de JWT. fcg-catalog-api, com o CRUD de jogos e o início do fluxo de compra. fcg-payments-api, que processa pagamentos de forma assíncrona. fcg-notifications-function, a função serverless, em repositório próprio como a Fase 3 exige. E fcg-orchestration, com gateway, manifestos e observabilidade."***

### Passo 3 · README central com o diagrama · 49 s
***"O README da orquestração é o guia central. No diagrama: o cliente bate no Kong, que é a única porta de entrada. O Kong valida o JWT e roteia para o UsersAPI ou o CatalogAPI. Esses serviços publicam eventos no RabbitMQ. O PaymentsAPI consome e devolve o resultado. A função serverless consome os eventos para enviar e-mails. E o Prometheus coleta métricas de todos e alimenta o Grafana. Logo abaixo, a PDF pede que a escolha da stack de observabilidade seja documentada aqui: escolhi a Opção A, Prometheus e Grafana, com a justificativa registrada."***

---

## CENA 3 — Ambiente rodando

### Passo 4 · docker compose ps, depois a Function · 42 s
***"O ambiente completo sobe com um único docker compose up. Dois PostgreSQL, um por serviço, seguindo database-per-service. MongoDB, Redis, RabbitMQ, os três microsserviços, o Kong, o Prometheus, o Grafana e o Azurite, que dá suporte ao runtime da função."***

*(quando a tela troca para o terminal da Function)*

***"E aqui, separadamente, a função serverless. Ela não é um container por definição, roda no Azure Functions Core Tools. As duas funções estão registradas com trigger de RabbitMQ."***

---

## CENA 4 — API Gateway

### Passo 5 · kong.yml, services e rotas · 34 s
***"A configuração do Kong é declarativa e versionada no repositório de orquestração. Dois services, users-api e catalog-api. Repare na distinção: a rota de autenticação é pública, porque login e cadastro não podem exigir token. A rota de usuários tem o plugin JWT. No catálogo, o GET é público, é a vitrine, mas POST, PUT e DELETE exigem token."***

### Passo 6 · kong.yml, consumer · 24 s
***"E o consumer com a credencial JWT. A key é FCG.Gateway, que bate com a claim iss emitida pelo UsersAPI, e o secret é a mesma chave HMAC. Assim o Kong valida a assinatura sem precisar chamar o serviço de usuários."***

### Passo 7 · GET /api/games sem token · 15 s
***"Uma rota pública através do Gateway, sem token. O catálogo é retornado, o Kong deixou passar."***

### Passo 8 · GET /api/library/me sem token → 401 · 15 s
***"Agora a biblioteca, que é protegida, sem token. 401: o Kong barrou, e a requisição nem chegou ao microsserviço. O Gateway parou antes."***

### Passo 9 · cadastro, depois a Function · 38 s
***"Cadastrando uma usuária. Isso dispara o primeiro fluxo de eventos: o UsersAPI grava no banco e publica o UserCreatedEvent."***

*(quando troca para a Function)*

***"E a função serverless foi acionada pela fila e enviou o e-mail de boas-vindas. Esse é o fluxo de cadastro da PDF, ponta a ponta."***

### Passo 10 · login e JWT decodificado · 28 s
***"Login da Maria. Recebemos o JWT e aqui está o payload decodificado: sub com o ID da usuária, email, role, e o iss como FCG.Gateway, exatamente a key que o Kong usa para validar a assinatura."***

### Passo 11 · GET /api/library/me com token · 13 s
***"A mesma rota protegida, agora com o token. O Kong deixou passar. Biblioteca vazia, porque a Maria ainda não comprou nada."***

---

## CENA 5 — Fluxo de compra

### Passo 12 · código do Purchase · 29 s
***"Agora o fluxo mais importante: a compra, que atravessa três microsserviços e a função de forma totalmente assíncrona. Quando o usuário compra, o CatalogAPI não processa nada. Ele publica um OrderPlacedEvent e devolve 202 Accepted. O processamento acontece em background."***

### Passo 13 · compra aprovada · 15 s
***"Comprando um jogo abaixo do limite de aprovação. 202 Accepted, com o ID do pedido e status PendingPayment. Vamos seguir o rastro."***

### Passo 14 · logs do payments-api · 21 s
***"O PaymentsAPI consumiu o OrderPlacedEvent, processou o pagamento simulado e publicou o PaymentProcessedEvent com status Approved."***

### Passo 15 · logs do catalog-api, depois a Function · 39 s
***"O CatalogAPI consumiu esse evento e adicionou o jogo à biblioteca no MongoDB."***

*(quando troca para a Function)*

***"E a função serverless consumiu o mesmo evento e enviou o e-mail de confirmação da compra. Um evento, dois consumidores independentes."***

### Passo 16 · biblioteca com o jogo · 13 s
***"Biblioteca atualizada, com o preço pago registrado como snapshot no momento da compra."***

### Passo 17 · compra rejeitada, depois a Function · 32 s
***"Agora o caminho de rejeição. Este jogo custa acima do limite de 200 configurado no simulador de pagamento."***

*(quando troca para a Function)*

***"A função recebeu o evento com status Rejected e enviou o e-mail de recusa, com o motivo."***

### Passo 18 · biblioteca continua com 1 · 13 s
***"E o jogo não entrou na biblioteca. A consistência foi mantida através dos eventos."***

### Passo 19 · filas do RabbitMQ · 18 s
***"As filas do sistema: payments-order-placed, catalog-payment-processed, e as duas que a função serverless consome, cada uma com seu consumidor conectado."***

---

## CENA 6 — Serverless

### Passo 20 · código da Function · 39 s
***"A função por dentro. Na Fase 2, o NotificationsAPI era um container 24 horas por dia só esperando eventos, exatamente o desperdício que a PDF aponta. Agora é uma função com o atributo RabbitMQTrigger, usando a extensão oficial da Microsoft. Só executa quando há mensagem na fila. Sem evento, sem consumo de recurso."***

### Passo 21 · Bicep · 34 s
***"A PDF exige infraestrutura como código para a função. Usei Bicep, o padrão nativo do Azure. Provisiona Storage, Application Insights e um App Service Plan com sku Y1, o plano Consumption: serverless puro, escala a zero quando ocioso e cobra por execução."***

---

## CENA 7 — Observabilidade

### Passo 22 · Prometheus targets · 24 s
***"Começando pelo Prometheus. Os alvos coletados: users-api, catalog-api, payments-api e o próprio Kong. Todos UP."***

### Passo 23 · Prometheus query · 19 s
***"Uma query de latência no percentil 95, por serviço, calculada a partir dos histogramas expostos."***

### Passo 24 · Program.cs · 24 s
***"A instrumentação é o prometheus-net. Duas linhas: UseHttpMetrics coleta latência, contagem e status code de cada requisição, e MapMetrics expõe o endpoint /metrics."***

### Passo 25 · Grafana · 59 s
***"E o dashboard, provisionado como código junto com o repositório. No topo, requisições por segundo, taxa de erros com alerta por cor, latência p95 e serviços no ar. Abaixo, a latência p50, p95 e p99 por serviço, que é o que a PDF pede. Aqui, a contagem de requisições por status code HTTP, e por serviço. E na última linha, métricas de negócio: cache hits versus misses do Redis, pagamentos aprovados versus rejeitados, e jogos adicionados às bibliotecas. Há carga sendo gerada agora, então os gráficos estão se movendo em tempo real."***

---

## CENA 8 — NoSQL e Cache

### Passo 26 · MongoStore · 39 s
***"A PDF exige NoSQL. Usei MongoDB com o driver oficial, em quatro cenários que justificam NoSQL de verdade. library_items, a biblioteca, sempre lida por userId, sem joins. game_reviews, avaliações com schema flexível: array de tags livres e campos opcionais. event_logs, log append-only de alta volumetria. E no PaymentsAPI, o histórico de transações."***

### Passo 27 · avaliação criada · 13 s
***"Criando uma avaliação com tags livres, um documento de schema flexível."***

### Passo 28 · consultas no Mongo · 35 s
***"Consultando direto no MongoDB: a biblioteca da Maria com o jogo comprado. A avaliação com o array de tags. E os índices da biblioteca: o índice único composto de UserId e GameId garante idempotência. Se o mesmo evento for reprocessado, não duplica."***

### Passo 29 · CacheService · 29 s
***"Para o cache, o padrão cache-aside com IDistributedCache sobre Redis. Tenta o cache; em miss, vai na origem, grava e devolve. E um detalhe de resiliência: se o Redis cair, a aplicação não quebra, degrada graciosamente para o banco."***

### Passo 30 · miss vs hit · 18 s
***"Na prática: a primeira chamada vai ao PostgreSQL. A segunda vem do Redis. A diferença de tempo é o cache funcionando."***

### Passo 31 · chaves no Redis · 13 s
***"E as chaves no Redis: lista do catálogo, itens individuais e a biblioteca do usuário."***

---

## CENA 9 — Kubernetes

### Passo 32 · deployment.yaml e secret.yaml · 38 s
***"Todo o ambiente também roda em Kubernetes. Deployment, nunca Pod isolado, com réplicas, health checks e limites de recursos."***

*(quando abre o secret.yaml)*

***"E a separação obrigatória: ConfigMap para configurações não sensíveis, Secret para connection strings e a chave HMAC do JWT."***

### Passo 33 · kubectl · 24 s
***"Todos os pods rodando no cluster local do Docker Desktop. E os services: a comunicação interna usa os nomes, como users-api na porta 80."***

> Se o Kubernetes não estava disponível na gravação: ***"O deploy é automatizado pelo script deploy-k8s.ps1, que constrói as imagens e aplica os manifestos na ordem correta."***

---

## CENA 10 — Encerramento

### Passo 34 · cartão final · 43 s
***"Resumindo: API Gateway com Kong validando JWT e roteando. Notificações migradas para Azure Function serverless, acionada por fila, com infraestrutura como código. Observabilidade com Prometheus e Grafana, dashboard como código. E persistência poliglota: PostgreSQL para dados transacionais, MongoDB para dados flexíveis, Redis para cache. Tudo containerizado, orquestrado em Kubernetes e documentado. Repositórios no GitHub. Obrigado!"***
