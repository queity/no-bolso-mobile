import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/financial_colors.dart';
import '../../../data/firebase/storage_service.dart';
import '../../../data/firebase/transaction_service.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/receipt_picker.dart';

/// Tela de Adicionar/Editar Transação.
///
/// Quando [transactionId] é nulo a tela está em modo de criação; caso
/// contrário ela carrega a transação pelo id (rota `/transactions/:id/edit`)
/// e preenche o formulário para edição.
///
/// A ordem e as regras dos campos seguem o No Bolso web (valor, data,
/// descrição, categoria, direção, tipo, comprovante) pra não criar duas
/// experiências diferentes do mesmo produto.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  /// Quando nulo, a tela está em modo de criação. Caso contrário, edição.
  final String? transactionId;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  final TransactionService _transactionService = TransactionService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  // Mesmos padrões do formulário web: saída no Pix.
  TransactionDirection _direction = TransactionDirection.saida;
  TransactionType _type = TransactionType.pix;
  TransactionCategory? _category;
  DateTime _date = DateTime.now();

  /// Recibo escolhido agora no aparelho, ainda não enviado ao Storage.
  File? _pickedReceipt;

  /// Recibo que já estava salvo na transação (modo edição).
  String? _receiptUrl;

  /// Guarda a URL do recibo original pra apagar do Storage se o usuário
  /// trocar ou remover o anexo — evita deixar arquivo órfão no bucket.
  String? _originalReceiptUrl;

  bool get _isEditing => widget.transactionId != null;

  bool _isSaving = false;
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadTransaction();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Converte o texto do campo de valor ("1.234,56") em número.
  ///
  /// Como o campo é mascarado por [_CurrencyInputFormatter], só existem
  /// dígitos e separadores — então basta ler os dígitos como centavos.
  double? _parseAmount(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.parse(digits) / 100;
  }

  Future<void> _loadTransaction() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final doc = await _transactionService.getTransactionById(
        widget.transactionId!,
      );

      if (!mounted) return;

      if (doc == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'Essa transação não existe mais.';
        });
        return;
      }

      final transaction = TransactionModel.fromDoc(doc);
      final currentUserId = context.read<AuthProvider>().user?.uid;

      // Não basta o Firestore devolver o documento: a rota é acessível por
      // link, então conferimos que a transação é mesmo de quem está logado.
      if (transaction.userId != currentUserId) {
        setState(() {
          _isLoading = false;
          _loadError = 'Você não tem acesso a essa transação.';
        });
        return;
      }

      setState(() {
        _amountController.text = _CurrencyInputFormatter.format(
          transaction.amount,
        );
        _descriptionController.text = transaction.description ?? '';
        _direction = transaction.direction;
        _type = transaction.type;
        _category = transaction.category;
        _date = transaction.date;
        _receiptUrl = transaction.receiptUrl;
        _originalReceiptUrl = transaction.receiptUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Não foi possível carregar a transação. Tente de novo.';
      });
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        // Recibo é foto de papel: reduzir já economiza banda e Storage sem
        // atrapalhar a leitura do comprovante.
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      setState(() {
        _pickedReceipt = File(picked.path);
        // A imagem nova substitui a que estava salva na visualização.
        _receiptUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        source == ImageSource.camera
            ? 'Não foi possível abrir a câmera.'
            : 'Não foi possível abrir a galeria.',
      );
    }
  }

  void _removeReceipt() {
    setState(() {
      _pickedReceipt = null;
      _receiptUrl = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      // Uma transação já salva pode ter data futura vinda de outro sistema —
      // aí o picker abriria fora do intervalo permitido.
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      // Igual ao `@PastOrPresent` da API: não se lança o que ainda não aconteceu.
      lastDate: now,
    );

    if (selected == null || !mounted) return;
    setState(() => _date = selected);
  }

  /// Quando o usuário escolhe uma categoria, a direção que combina com ela já
  /// vem sugerida — mesmo comportamento do `direction-suggestion` do web.
  void _onCategoryChanged(TransactionCategory? category) {
    setState(() {
      _category = category;
      final suggestion = category?.suggestedDirection;
      if (suggestion != null) {
        _direction = suggestion;
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) {
      _showError('Sua sessão expirou. Entre novamente.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Se o usuário anexou um recibo novo, ele sobe primeiro — se o upload
      // falhar, a transação não é salva pela metade.
      var receiptUrl = _receiptUrl;
      if (_pickedReceipt != null) {
        receiptUrl = await _storageService.uploadReceipt(
          _pickedReceipt!,
          userId,
        );
      }

      // 2. Monta o model e grava.
      final description = _descriptionController.text.trim();
      final transaction = TransactionModel(
        id: widget.transactionId,
        userId: userId,
        amount: _parseAmount(_amountController.text)!,
        direction: _direction,
        type: _type,
        date: _date,
        category: _category,
        description: description.isEmpty ? null : description,
        receiptUrl: receiptUrl,
      );

      if (_isEditing) {
        await _transactionService.updateTransaction(
          widget.transactionId!,
          transaction.toMap(),
        );
      } else {
        await _transactionService.addTransaction(transaction.toMap());
      }

      // 3. Só depois de gravar é seguro apagar o recibo antigo do Storage.
      if (_originalReceiptUrl != null && _originalReceiptUrl != receiptUrl) {
        await _storageService.deleteReceipt(_originalReceiptUrl!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Transação atualizada!' : 'Transação adicionada!',
          ),
        ),
      );
      _closeForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showError('Não foi possível salvar a transação. Tente de novo.');
    }
  }

  /// Volta pra listagem. A tela é empurrada por cima da shell, mas pode ter
  /// sido aberta direto por link — aí não existe rota pra desempilhar.
  void _closeForm() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transação')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Editar' : 'Adicionar',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _LoadErrorState(message: _loadError!, onBack: _closeForm);
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final financial = Theme.of(context).extension<FinancialColors>()!;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          // Sem isso a mensagem de erro só some no próximo "Adicionar": o
          // usuário corrige o valor e continua vendo "Informe o valor".
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              TextFormField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [_CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor *',
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (value) {
                  final amount = _parseAmount(value ?? '');
                  if (amount == null) {
                    return 'Informe o valor';
                  }
                  // Mesmos limites do TransacaoInputDTO da API.
                  if (amount < 0.01) {
                    return 'O valor deve ser maior que zero';
                  }
                  if (amount > 999999999.99) {
                    return 'O valor excede o limite permitido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Data — campo só de leitura que abre o date picker ao tocar.
              InkWell(
                onTap: _isSaving ? null : _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data da transação *',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(_dateFormat.format(_date)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                // Opcional e com o mesmo teto da API (255).
                maxLength: 255,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Almoço no restaurante',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<TransactionCategory?>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                // Sem teto o menu abre as 12 opcoes de uma vez e ocupa quase
                // a tela inteira. A altura e casada com a do item pra nunca
                // cortar uma opcao ao meio: 8 de padding + 6 itens de 48 + 8.
                itemHeight: 48,
                menuMaxHeight: 304,
                items: [
                  const DropdownMenuItem<TransactionCategory?>(
                    value: null,
                    child: Text('Sem categoria'),
                  ),
                  for (final category in TransactionCategory.values)
                    DropdownMenuItem<TransactionCategory?>(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: _isSaving ? null : _onCategoryChanged,
              ),
              const SizedBox(height: 16),

              // Direção — entra ou sai. Sempre tem um valor selecionado, então
              // não precisa de validação.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Direção *',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TransactionDirection>(
                // Mantem o icone de cada segmento ao selecionar, em vez de
                // trocar pelo check padrao do Material.
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: TransactionDirection.saida,
                    label: Text(TransactionDirection.saida.label),
                    icon: const Icon(Icons.receipt, size: 20),
                  ),
                  ButtonSegment(
                    value: TransactionDirection.entrada,
                    label: Text(TransactionDirection.entrada.label),
                    icon: const Icon(Icons.savings, size: 20),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) =>
                          setState(() => _direction = selection.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _direction.isIncome
                      ? financial.incomeContainer
                      : financial.expenseContainer,
                  selectedForegroundColor: _direction.isIncome
                      ? financial.income
                      : financial.expense,
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<TransactionType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo *',
                  prefixIcon: Icon(Icons.swap_horiz_rounded),
                ),
                items: [
                  for (final type in TransactionType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _type = value!),
                validator: (value) => value == null ? 'Escolha o tipo' : null,
              ),
              const SizedBox(height: 24),

              ReceiptPicker(
                localFile: _pickedReceipt,
                remoteUrl: _receiptUrl,
                enabled: !_isSaving,
                onPick: _pickReceipt,
                onRemove: _removeReceipt,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Salvar alterações' : 'Adicionar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSaving ? null : _closeForm,
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostrado quando a transação da rota não pôde ser carregada (não existe,
/// é de outro usuário ou o Firestore falhou).
class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBack, child: const Text('Voltar')),
        ],
      ),
    );
  }
}

/// Máscara de moeda do campo de valor.
///
/// Mesma lógica do `formatCurrencyInput` do No Bolso web: o usuário digita só
/// números e eles vão preenchendo da direita pra esquerda como centavos —
/// "1", "12", "123" viram "0,01", "0,12", "1,23". Isso impede que ele escreva
/// um valor inválido (vírgula sobrando, letras), então a validação só precisa
/// se preocupar com o intervalo.
class _CurrencyInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  /// Usado também pela tela pra preencher o campo no modo edição.
  static String format(double value) => _formatter.format(value).trim();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return const TextEditingValue();

    // Trava colagens gigantes antes de virar um int que estoura.
    if (digits.length > 12) return oldValue;

    final text = format(int.parse(digits) / 100);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
