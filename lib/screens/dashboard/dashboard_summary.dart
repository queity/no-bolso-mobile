part of 'dashboard_screen.dart';

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.transactions});
  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((item) => item.isIncome)
        .fold<double>(0, (total, item) => total + item.amount);
    final expenses = transactions
        .where((item) => !item.isIncome)
        .fold<double>(0, (total, item) => total + item.amount);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
    final colors = Theme.of(context).colorScheme;
    final financial = Theme.of(context).extension<FinancialColors>()!;
    // Fundo neutro (não `colors.primary`): no tema escuro o `primary` do app
    // é fixado na mesma cor de `financial.income` (ver AppTheme.dark), então
    // um card com fundo `primary` deixava o texto de "Entradas" invisível —
    // texto verde sobre fundo verde. `inverseSurface`/`onInverseSurface` já
    // vêm com contraste garantido pelo Material 3 nos dois temas.
    return Card(
      margin: EdgeInsets.zero,
      color: colors.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo acumulado',
              style: TextStyle(color: colors.onInverseSurface),
            ),
            const SizedBox(height: 4),
            Text(
              currency.format(income - expenses),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onInverseSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Entradas',
                    value: currency.format(income),
                    color: financial.income,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Despesas',
                    value: currency.format(expenses),
                    color: financial.expense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withAlpha(210),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ],
  );
}
