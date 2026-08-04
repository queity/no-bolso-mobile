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
- [Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli) instalada (`npm install -g firebase-tools`)
- FlutterFire CLI: `dart pub global activate flutterfire_cli`
- Uma conta com acesso ao projeto Firebase **no-bolso-mobile**

> No Windows, builds com plugins exigem suporte a symlink: ative o **Modo de
> Desenvolvedor** (`start ms-settings:developers`) ou rode o terminal como
> Administrador.

### Passo a passo

1. Clone o repositório e instale as dependências:
   ```bash
   git clone https://github.com/queity/no-bolso-mobile.git
   cd no-bolso-mobile
   flutter pub get
   ```

2. Autentique-se no Firebase:
   ```bash
   firebase login
   ```

3. Gere a configuração do Firebase para o projeto (já existe um app registrado;
   isso apenas recria `lib/firebase_options.dart` localmente caso necessário):
   ```bash
   flutterfire configure
   ```
   Selecione o projeto **No Bolso** (`no-bolso-mobile`) e as plataformas
   `android` e `ios`.

4. Rode o app:
   ```bash
   flutter run
   ```

### Testes e análise estática

```bash
flutter analyze
flutter test
```

## Configuração do Firebase

O projeto usa o Firebase **no-bolso-mobile**, com os seguintes recursos habilitados:

- **Authentication** — login do usuário
- **Cloud Firestore** — armazenamento das transações
- **Storage** — upload de recibos/anexos das transações

O arquivo `lib/firebase_options.dart` (gerado pelo FlutterFire CLI) já está
versionado no repositório — as chaves nele não são secretas, apenas
identificam o projeto Firebase; a segurança real é garantida pelas regras do
Firestore/Storage.
