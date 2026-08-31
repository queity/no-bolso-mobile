# No Bolso

Aplicativo mobile de gerenciamento financeiro desenvolvido em Flutter.

O app permite ao usuário autenticado gerenciar suas transações financeiras,
com dashboard de análises, listagem com filtros/paginação, cadastro e edição
de transações (com upload de recibos), integrando Firebase para autenticação,
banco de dados (Cloud Firestore) e armazenamento de arquivos (Firebase Storage).

## Stack

- **Flutter** (mobile)
- **go_router** — navegação
- **provider** — gerenciamento de estado
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`
- **fl_chart** — gráficos do dashboard
- **image_picker** — captura/seleção da foto do recibo
- **intl** — formatação de datas e moeda (pt_BR)

## Dependências

Todas declaradas em `pubspec.yaml`, instaladas com `flutter pub get`:

| Pacote | Uso |
|---|---|
| `go_router` | navegação e rotas (bottom nav, telas empilhadas) |
| `provider` | estado global (sessão do usuário) |
| `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` | conexão com o Firebase |
| `fl_chart` | gráficos de evolução e categorias do dashboard |
| `image_picker` | anexar foto do recibo (câmera/galeria) |
| `intl` | formatação de datas e valores monetários |
| `cupertino_icons` | ícones estilo iOS |
| `flutter_lints` (dev) | regras de lint do projeto |

## Estrutura do projeto

```
lib/
├── main.dart                    # entrypoint, inicializa o Firebase e o app
├── firebase_options.dart        # gerado pelo `flutterfire configure`
├── core/
│   ├── router/                  # configuração de rotas (go_router) + bottom nav (MainShell)
│   └── theme/                   # tema do app
├── data/
│   └── firebase/                # serviços de acesso ao Firebase (Auth, Firestore, Storage)
├── models/                      # modelos de dados (ex.: Transaction)
├── providers/                   # ChangeNotifiers / gerenciamento de estado global
├── screens/
│   ├── splash/                  # tela inicial / verificação de autenticação
│   ├── auth/                    # login e cadastro
│   ├── dashboard/                # tela principal: resumo, gráficos (fl_chart) e recentes
│   │   ├── dashboard_screen.dart      # estado da tela (período, seções visíveis)
│   │   ├── dashboard_header.dart      # saudação + logout
│   │   ├── dashboard_controls.dart    # seletor de período e personalização
│   │   ├── dashboard_summary.dart     # saldo/entradas/despesas do período
│   │   ├── dashboard_charts.dart      # gráfico de evolução e de categorias
│   │   └── dashboard_transactions.dart # lista de movimentações recentes
│   ├── transactions/
│   │   ├── list/                 # listagem paginada (Firestore) com filtro por categoria e período
│   │   └── form/                 # adicionar/editar transação, com upload de recibo
└── widgets/                     # componentes reutilizáveis (ex.: ReceiptPicker)
```

## Rotas

Dashboard e Transações vivem dentro de uma bottom navigation bar
(`StatefulShellRoute`, ver `core/router/main_shell.dart`) — o Dashboard é a
tela principal do app. As telas de Nova/Editar transação abrem por cima, sem a bottom nav.

| Rota | Tela |
|---|---|
| `/` | Splash |
| `/login` | Login |
| `/register` | Cadastro |
| `/dashboard` | Dashboard (aba) |
| `/transactions` | Listagem de transações (aba) |
| `/transactions/new` | Nova transação |
| `/transactions/:id/edit` | Editar transação |

## Como rodar o projeto

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado
- Um dispositivo pra rodar o app: emulador Android (via Android Studio →
  Device Manager) ou um device físico com depuração USB ativada

### Passo a passo

1. Clone o repositório e instale as dependências:
   ```bash
   git clone https://github.com/queity/no-bolso-mobile.git
   cd no-bolso-mobile
   flutter pub get
   ```

2. Confirme que tem um dispositivo disponível:
   ```bash
   flutter devices
   ```
   Se não aparecer nenhum, abra um emulador (`flutter emulators --launch <id>`,
   ou liste os disponíveis com `flutter emulators`) ou conecte um device físico.
   Sem nenhum dos dois, dá pra rodar no navegador como alternativa:
   `flutter run -d chrome`.

3. Rode o app:
   ```bash
   flutter run
   ```

O `lib/firebase_options.dart` já está commitado no repositório, então **não é
necessário rodar `flutterfire configure`** pra rodar o app — os passos acima
já bastam.

### Regenerando a configuração do Firebase (opcional)

Só necessário se for adicionar uma nova plataforma ou o projeto Firebase
mudar. Exige ter sido adicionado como membro do projeto **no-bolso-mobile**
no [console do Firebase](https://console.firebase.google.com) — peça acesso
a quem administra o projeto.

```bash
npm install -g firebase-tools   # requer Node.js instalado
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

No Windows, se o comando `flutterfire` não for reconhecido depois de
ativado, o executável fica em `%LOCALAPPDATA%\Pub\Cache\bin`, que pode não
estar no PATH. Adicione essa pasta ao PATH e abra um terminal novo:
```powershell
setx Path "$($env:Path);$env:LOCALAPPDATA\Pub\Cache\bin"
```

### Testes e análise estática

```bash
flutter analyze
flutter test
```

## Design system

O tema do app fica centralizado em `lib/core/theme/`:

- `app_colors.dart` — paleta de marca e cores semânticas (receita/despesa)
- `financial_colors.dart` — `ThemeExtension` com as cores de receita/despesa,
  acessível via `Theme.of(context)`
- `app_theme.dart` — monta o `ThemeData` final (light e dark)

Evite usar `Colors.xxx` direto nas telas. Prefira:

```dart
final colorScheme = Theme.of(context).colorScheme;
final financial = Theme.of(context).extension<FinancialColors>()!;

Text('+ R\$ 100,00', style: TextStyle(color: financial.income));
Text('- R\$ 50,00', style: TextStyle(color: financial.expense));
```

Isso mantém a consistência visual entre as telas e já funciona com dark mode
(`themeMode: ThemeMode.system`, configurado em `main.dart`).

## Configuração do Firebase

O projeto usa o Firebase **no-bolso-mobile**, com os seguintes recursos habilitados:

- **Authentication** — login do usuário
- **Cloud Firestore** — armazenamento das transações
- **Storage** — upload de recibos/anexos das transações

O arquivo `lib/firebase_options.dart` (gerado pelo FlutterFire CLI) já está
versionado no repositório — as chaves nele não são secretas, apenas
identificam o projeto Firebase; a segurança real é garantida pelas regras do
Firestore/Storage.

### Regras de segurança

Versionadas em `firestore.rules` e `storage.rules`: cada transação/recibo só
pode ser lido, editado ou apagado pelo próprio dono, via `request.auth.uid`.

- **Firestore**: regras deployadas no projeto **no-bolso-mobile**.
- **Storage**: habilitado (plano Blaze) e com as regras de `storage.rules`
  deployadas. Requer um target de deploy configurado (`firebase.json` já
  aponta pro target `default`; se precisar reconfigurar em outra máquina,
  rodar `firebase target:apply storage default no-bolso-mobile.firebasestorage.app`
  antes do primeiro `firebase deploy --only storage`).
