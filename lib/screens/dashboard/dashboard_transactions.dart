part of 'dashboard_screen.dart';

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});
  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
    final recent = transactions.take(5).toList();
    if (recent.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Adicione sua primeira transação para acompanhar sua vida financeira.')));
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [for (final item in recent) ListTile(
        leading: CircleAvatar(
          backgroundColor: (item.isIncome ? Colors.green : Colors.red).withAlpha(24),
          child: Icon(item.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, color: item.isIncome ? Colors.green : Colors.red),
        ),
        title: Text(item.description?.isNotEmpty == true ? item.description! : item.type.label),
        subtitle: Text(DateFormat('dd/MM/yyyy').format(item.date)),
        trailing: Text('${item.isIncome ? '+' : '-'} ${currency.format(item.amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: item.isIncome ? Colors.green : Colors.red)),
      )]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 30, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)]));
}
