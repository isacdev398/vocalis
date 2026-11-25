# Desempenho — Vocalis

Material para a apresentação final de **Código de Alta Performance Mobile**.
Resume o que foi otimizado, como medir o "antes vs. depois" e um roteiro
de 10 minutos seguindo a ordem pedida pelo professor.

---

## Como medir (antes vs. depois)

O app tem duas chaves de compilação ([`lib/core/perf.dart`](lib/core/perf.dart)):

| Chave | O que faz |
| --- | --- |
| `ESTRESSE=5000` | A demonstração gera 5.000 cobranças no mês atual e 5.000 agendamentos antigos (2 a 14 meses atrás). |
| `OTIMIZADO=false` | Liga a versão **antes**: lista montada inteira numa `Column`, cálculos dentro do `build()` na thread de UI e consultas que baixam a coleção inteira. |

> ⚠️ Meça **sempre em modo profile e num celular Android** (ou no Windows
> desktop). O modo debug é lento de propósito, e na Web não existem Isolates.

Com o celular ligado no USB (depuração USB ativada):

```bash
flutter run --profile --dart-define=ESTRESSE=5000 --dart-define=OTIMIZADO=false
```

```bash
flutter run --profile --dart-define=ESTRESSE=5000
```

Em cada execução:

1. Abra o **Flutter DevTools** (o link aparece no terminal).
2. Explorar demonstração → **Dono** → aba **Financeiro**.
3. Na aba **Performance** do DevTools, grave enquanto rola a lista até o fim
   e digita na busca. Tire print do gráfico de quadros (barras vermelhas são
   *jank*) e anote o tempo médio de UI e de raster por quadro.
4. Na aba **Memory**, anote o pico de RAM com a tela do Financeiro aberta.
5. Cold start: feche o app de verdade e reabra. O tempo até o primeiro quadro
   aparece no terminal (`flutter run --trace-startup --profile` grava em
   `build/start_up_info.json`).

### Números medidos no Chrome, em modo profile (24/11/2026)

Builds `flutter build web --profile --dart-define=ESTRESSE=5000`, com e sem
`OTIMIZADO=false`, abertos no Chrome com tela de celular emulada (375×812).
Roteiro igual nas duas versões: entrar como Dono, abrir o Financeiro e rolar a
lista. Medido com as APIs do navegador: Long Tasks (tarefas acima de 50 ms na
thread principal), `performance.memory` (memória JS) e o evento
`flutter-first-frame` (primeiro quadro).

| Métrica (Financeiro, 5.000 cobranças) | Antes | Depois |
| --- | --- | --- |
| Travamento ao abrir a tela | 10,7 s (1 tarefa) | 0,19 s (2 tarefas) |
| Tempo travado rolando (tarefas > 50 ms) | 8,1 s (15 tarefas) | 0 s |
| Maior pausa rolando | 650 ms | 51 ms |
| Memória JS no pico | 1.098 MB | 58 MB |
| Primeiro quadro do app (média de 3) | 562 ms | 601 ms |

No celular, repita com `flutter run --profile` e o DevTools (passos acima). O
navegador não tem Isolates, então o ganho do `compute()` só aparece no aparelho.

### Números já medidos (teste automático, `flutter test`)

Rode `flutter test test/desempenho_test.dart` para reproduzir. São medidas
feitas em ambiente de teste, no Windows, e servem como prova complementar:

| Medida | Antes | Depois | Ganho |
| --- | --- | --- | --- |
| `ResumoFinanceiro.calcular` com 5.000 cobranças | **1.227 ms** | **47 ms** | 26× mais rápido |
| Cartões construídos na tela do Financeiro (2.000 de estresse) | **2.127** | **11** | 193× menos widgets |
| Primeiro quadro do Financeiro no teste (modo debug) | 15,3 s | 0,3 s | ~50× |
| Criar 200 mil `DateTime` locais × ler 200 mil getters | 4.086 ms | 4 ms | causa raiz do item 1 |

---

## As otimizações

### 1. Otimização de interface — lista sob demanda (`SliverList.builder`)

- **Antes:** todas as telas usavam o widget `Conteudo`, que é um `ListView`
  com uma única `Column` dentro. Com 5.000 lançamentos, os 5.000 cartões
  eram criados, medidos e pintados de uma vez, mesmo fora da tela.
- **Depois:** o novo widget `ConteudoLista`
  ([`lib/widgets/comuns.dart`](lib/widgets/comuns.dart)) usa
  `CustomScrollView` + `SliverList.builder`: só os cartões visíveis (mais
  uma pequena folga) existem, e os que saem da tela são reciclados.
  Usado em [`financeiro_tela.dart`](lib/telas/dono/financeiro_tela.dart).
- **Prova:** o teste conta 2.127 cartões antes e 11 depois.

### 2. Memória e CPU — cálculo fora do `build()`, em Isolate, com memoização

- **Antes:** `ResumoFinanceiro.calcular` (Financeiro) e
  `IndicadoresClinica.calcular` (Visão Geral) rodavam dentro do `build()`.
  Cada tecla na busca, cada troca de filtro e cada rolagem que reconstruía a
  tela refazia o cálculo inteiro na thread de UI.
- **Depois:** o widget `Calculado` ([`lib/widgets/comuns.dart`](lib/widgets/comuns.dart)):
  - **memoização:** só recalcula quando os dados de entrada mudam;
  - **Isolate:** o cálculo roda com `compute()` em outra thread
    ([`lib/core/perf.dart`](lib/core/perf.dart)), e a animação não trava;
  - descarta resultados atrasados se os dados mudarem no meio do cálculo.
- **Busca com debounce:** o filtro só é aplicado 250 ms depois que o usuário
  para de digitar.
- **Sem vazamento de memória:** controllers, `Timer`s e `StreamSubscription`s
  são liberados no `dispose()` (ex.: a folha de novo agendamento cancela a
  escuta ao fechar; o SOAP cancela o salvamento automático).

### 3. O gargalo escondido — `DateTime` dentro do `sort`

Ao medir o cálculo do resumo, ele levava **1,2 s** com 5.000 cobranças.
A medição isolada de cada parte mostrou a causa: `Cobranca.situacao()` criava dois `DateTime`
locais a cada chamada, e ela era chamada **dentro do comparador do `sort`**
(n·log n ≈ 60 mil comparações → ~250 mil `DateTime`). Criar um `DateTime`
local consulta o fuso horário do sistema operacional (~20 µs cada no Windows).

Correção ([`cobranca.dart`](lib/modelos/cobranca.dart),
[`resumo_financeiro.dart`](lib/logica/resumo_financeiro.dart)):
- comparar datas como número (`20261124`) usando só os getters;
- calcular o "peso" de cada cobrança **uma vez** antes de ordenar.

Resultado: **1.227 ms → 47 ms**.

### 4. Rede e dados offline — consultas por intervalo + cache do Firestore

- **Antes:** Agenda e Visão Geral escutavam a coleção `agendamentos`
  **inteira** (todo o histórico da clínica), e cada mudança reenviava e
  reconvertia tudo.
- **Depois** ([`banco_dados.dart`](lib/dados/banco_dados.dart),
  [`clinica_repositorio.dart`](lib/dados/clinica_repositorio.dart)):
  - a Agenda baixa só a **semana visível** (`inicio >= segunda && < segunda+7`);
  - a Visão Geral baixa só o mês atual e o anterior;
  - a folha de novo agendamento consulta só o **dia escolhido**, e conta as
    sessões do paciente com uma consulta filtrada por paciente;
  - são consultas de intervalo num único campo: o Firestore usa o índice
    automático e não precisa de índice composto.
- **Cache offline** ([`main.dart`](lib/main.dart)): persistência local do
  Firestore ligada, com limite de 50 MB. O app abre sem internet e envia as
  gravações quando a conexão volta.

---

## Roteiro da apresentação (10 min)

**1. Introdução (1 min)**
- Vocalis — integrantes: _preencher_.
- Problema: clínicas de fono controlam agenda, prontuário e cobrança em papel
  e WhatsApp. O app junta 4 perfis (cliente, recepção, fono, dono) em tempo real.
- Desafio de performance esperado: **listas que só crescem** (cobranças,
  agendamentos, histórico) e **painéis que agregam todo o histórico**.
  Uma clínica pequena gera milhares de registros por ano.

**2. Stack e arquitetura (1,5 min)**
- Flutter + Dart: compilado AOT para código nativo, motor de renderização
  próprio (Impeller) a 60/120 FPS, uma base de código para Android, iOS e Web.
  Firebase (Auth + Firestore) com cache offline nativo.
- Camadas: `modelos/` → `dados/` (BancoDados + Repositório, injeção de
  dependência) → `logica/` (regras puras, sem Flutter) → `estado/`
  (Provider) → `telas/`. As regras puras são o que dá para mandar para um
  Isolate, porque não dependem de widgets.

**3. Demo (2 min)** — no Chrome, em modo profile, com 5.000 registros extras:
`flutter run -d chrome --profile --dart-define=ESTRESSE=5000`.
- Antes de começar: F12 → Ctrl+Shift+M (tela de celular) e, no DevTools do
  Chrome, ⋮ → More tools → Rendering → "Frame rendering stats" (medidor de FPS).
- Recarregar a página (cold start de ~0,6 s).
- Recepção: agenda da semana, troca de semana.
- Dono: Visão Geral → Financeiro, rolar os 5.000 lançamentos e digitar na busca.
- Extra, se sobrar tempo: a versão `OTIMIZADO=false` congelando ~10 s ao abrir
  o Financeiro.
- No celular (com Android SDK), o mesmo roteiro vale com `flutter run --profile`
  e o *Performance Overlay* do Flutter DevTools.

**4. Mergulho técnico (3,5 min)** — escolher 3:
1. Lista sob demanda (`SliverList.builder`).
2. Isolate + memoização (+ o caso do `DateTime` no `sort`).
3. Consultas por intervalo + cache offline do Firestore.

**5. Métricas (1,5 min)** — prints do DevTools (antes × depois) e a tabela acima.

**6. Lições (30 s)**
- Principal desafio: o gargalo não estava onde a gente achava. Parecia ser a
  lista, mas medindo cada parte apareceu o `DateTime` dentro do `sort`.
- Próximos passos:
  - paginação com cursor (`limit` + `startAfter`) no histórico clínico;
  - totais do financeiro com consultas de agregação (`sum`/`count`) no servidor;
  - empacotar as fontes no app em vez de baixá-las do Google Fonts na
    primeira abertura;
  - aplicar `ConteudoLista` também na agenda e no histórico do paciente.

### Observação honesta sobre o modo "antes"

O código original do Financeiro mostrava 20 lançamentos por vez com um botão
"Ver mais". O modo `OTIMIZADO=false` reproduz a abordagem ingênua (todos os
itens na `Column`), que é o que acontece depois de apertar "Ver mais" até o
fim. Já o cálculo dentro do `build()`, as consultas da coleção inteira e o
`DateTime` no `sort` eram exatamente o código original.
