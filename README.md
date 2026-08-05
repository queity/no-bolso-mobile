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

## Estrutura do projeto

```
lib/
├── main.dart                    # entrypoint, inicializa o Firebase e o app
├── firebase_options.dart        # gerado pelo `flutterfire configure`
├── core/
│   ├── router/                  # configuração de rotas (go_router)
│   └── theme/                   # tema do app
├── data/
│   └── firebase/                # serviços de acesso ao Firebase (Auth, Firestore, Storage)
├── models/                      # modelos de dados (ex.: Transaction, User)
├── providers/                   # ChangeNotifiers / gerenciamento de estado global
├── screens/
│   ├── splash/                  # tela inicial / verificação de autenticação
│   ├── auth/                    # login
│   ├── dashboard/                # gráficos e análises financeiras
│   ├── transactions/
│   │   ├── list/                 # listagem de transações (filtros, paginação)
│   │   └── form/                 # adicionar/editar transação
└── widgets/                     # componentes reutilizáveis
```

## Rotas

| Rota | Tela |
|---|---|
| `/` | Splash |
| `/login` | Login |
| `/dashboard` | Dashboard |
| `/transactions` | Listagem de transações |
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
