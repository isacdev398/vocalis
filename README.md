# Vocalis Fonoaudiologia

App em **Flutter + Firebase** para clínicas de fonoaudiologia. A mesma clínica é
vista por quatro perfis, e tudo o que um perfil faz aparece em tempo real para
os outros:

| Perfil | O que faz |
| --- | --- |
| **Cliente / Responsável** | Vê a próxima consulta, pede reagendamento, pratica os exercícios em casa (ouve a palavra, grava, ganha estrelas) e acompanha as mensalidades. |
| **Recepção** | Agenda do dia com check-in, chamada para o consultório, faltas e cancelamentos. Avalia e confirma os pedidos de troca de horário. |
| **Fonoaudiólogo(a)** | Atendimento com evolução **SOAP** (salvamento automático, índice de precisão articulatória e assinatura), histórico do paciente e prescrição de exercícios domiciliares. |
| **Dono** | Painel de indicadores (ocupação, faturamento, absenteísmo, salas e equipe), gestão financeira e controle de permissões da equipe. |

**Integrantes:** _preencher com os nomes do grupo_.

O design segue o protótipo feito no **Google Stitch** (design system *Clinical
Warmth & Human Clarity*: Plus Jakarta Sans + Atkinson Hyperlegible Next).

---

## Como rodar

Pré-requisito: Flutter 3.47 ou mais recente (Dart 3.13).

```bash
flutter pub get
flutter run -d chrome
```

Sem configurar nada, o app abre em **modo demonstração**: os dados ficam na
memória do navegador e somem ao recarregar a página. Para explorar:

- Na tela de login, toque em **Explorar demonstração interativa** e escolha um
  personagem. O botão ⇄ no topo volta para o seletor a qualquer momento.
- Ou entre com uma conta de teste (senha `demo123`): `juliana@vocalis.demo`
  (cliente), `camila@vocalis.demo` (recepção), `ana@vocalis.demo` (fono)
  e `kariny@vocalis.demo` (dona).

**Roteiro sugerido para a apresentação:**

1. Entre como **Camila (Recepção)**, abra o pedido de reagendamento da Maitê e
   confirme o novo horário.
2. Troque para **Dono**: o card "Reagendamento Resolvido" já mostra a mudança.
3. Troque para **Dra. Ana**: inicie o atendimento do Lucas, preencha o SOAP,
   atribua um exercício e assine a evolução.
4. Troque para **Cliente**: o novo exercício aparece. Pratique, toque em
   "Ouvir" (a palavra é falada pelo navegador) e registre a prática para ganhar
   uma estrela.

## Conectando ao Firebase

1. Crie um projeto em <https://console.firebase.google.com>.
2. Em **Authentication → Método de login**, ative **E-mail/senha**.
3. Em **Firestore Database**, crie o banco (modo produção).
4. Em **Firestore → Regras**, cole o conteúdo de [`firestore.rules`](firestore.rules)
   e clique em **Publicar**.
5. No terminal, dentro da pasta do projeto:

   ```bash
   npm install -g firebase-tools
   ```

   ```bash
   firebase login
   ```

   ```bash
   dart pub global activate flutterfire_cli
   ```

   ```bash
   flutterfire configure --platforms=web,android
   ```

   Esse comando substitui o arquivo provisório `lib/firebase_options.dart`.
6. Rode `flutter run -d chrome`, crie uma conta com o perfil **Dono da Clínica**
   e, no menu do avatar, toque em **Popular dados de exemplo**.

Para forçar a demonstração mesmo com o Firebase configurado:
`flutter run -d chrome --dart-define=DEMO=true`.

### Publicar no portfólio (Firebase Hosting)

```bash
flutter build web --release
```

```bash
firebase init hosting
```

Responda: pasta pública `build/web`, *single-page app* **sim**, e não
sobrescreva o `index.html`. Depois publique:

```bash
firebase deploy --only hosting
```

---

## Desempenho

O app foi otimizado e medido para a disciplina **Código de Alta Performance
Mobile**: lista sob demanda (`SliverList.builder`), cálculos em Isolate com
memoização, consultas por intervalo de datas e cache offline do Firestore.
Para comparar o antes e o depois com 5.000 registros:

```bash
flutter run --profile --dart-define=ESTRESSE=5000 --dart-define=OTIMIZADO=false
```

```bash
flutter run --profile --dart-define=ESTRESSE=5000
```

Detalhes, números medidos e roteiro da apresentação em
[`PERFORMANCE.md`](PERFORMANCE.md).

## Requisitos do trabalho

| Requisito | Onde está |
| --- | --- |
| Várias telas e navegação | 13 telas com `go_router` ([`lib/rotas.dart`](lib/rotas.dart)): rotas aninhadas, `ShellRoute` com barra inferior por perfil e redirecionamento por login e permissão. |
| Login / autenticação | Firebase Authentication com e-mail e senha, cadastro, recuperação de senha e mensagens de erro em português ([`lib/servicos/auth_servico.dart`](lib/servicos/auth_servico.dart)). |
| Gerência de estado | **Provider**: `Sessao` (estado global de login e perfil) e `AgendaController` (filtros da agenda) ([`lib/estado`](lib/estado)). Dados ao vivo via streams do Firestore. |
| Testes | 47 testes em [`test/`](test): regras de negócio, modelos, repositório, sessão, testes de widget do login e testes de desempenho ([`test/desempenho_test.dart`](test/desempenho_test.dart)). Rode com `flutter test`. |

## Arquitetura

```
lib/
├── core/         tema (design system do Stitch), formatação pt-BR, validações, chaves de desempenho
├── modelos/      Usuario, Paciente, Agendamento, Solicitacao, Evolucao, Exercicio, Cobranca
├── dados/        BancoDados (Firestore ou memória), ClinicaRepositorio, dados de exemplo
├── logica/       regras puras: conflitos de agenda, indicadores, resumo financeiro
├── estado/       Sessao e AgendaController (Provider / ChangeNotifier)
├── servicos/     autenticação e síntese de voz
├── telas/        auth, demo, cliente, equipe (agenda/recepção), fono, dono
└── widgets/      componentes do design system (cartões, pílulas, avatares…)
```

- **Injeção de dependência:** o `ClinicaRepositorio` recebe um `BancoDados`.
  Em produção é o `FirestoreBanco`; na demonstração e nos testes é o
  `MemoriaBanco`. As telas nunca acessam o Firebase diretamente.
- **Operações atômicas:** confirmar um reagendamento ou assinar uma evolução
  grava vários documentos num lote só (*batch*).
- **Sem índices compostos:** as consultas usam um único filtro de igualdade e a
  ordenação é feita no app.
- **Sigilo clínico:** só quem tem permissão clínica **e** CRFa abre o
  prontuário, tanto nas rotas do app quanto nas regras do Firestore.

## O que é simulado

Para manter o projeto gratuito e sem integrações pagas, estes recursos mostram
a interface, mas não falam com serviços externos (o app avisa quando são usados):
envio por WhatsApp, ligação, PIX/QR Code, emissão de NF-e, exportação de
relatório, conciliação bancária, gravação de áudio e análise acústica.

A leitura em voz alta das palavras dos exercícios é **real** na versão web
(Web Speech API do navegador).

## Limitações conhecidas

- No cadastro, qualquer pessoa pode escolher o perfil "Dono". Num sistema real,
  esse papel seria atribuído por uma Cloud Function ou pelo painel administrativo.
- "Popular dados de exemplo" cria colaboradores e pacientes fictícios que não
  têm login próprio.
