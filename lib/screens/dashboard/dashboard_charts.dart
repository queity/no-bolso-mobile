part of 'dashboard_screen.dart';

class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({required this.transactions, required this.period});

  final List<TransactionModel> transactions;
  final _DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isWeekly = period == _DashboardPeriod.week;
    final isCurrentMonth = period == _DashboardPeriod.month;
    final bucketCount = isWeekly ? 7 : isCurrentMonth ? 5 : period == _DashboardPeriod.threeMonths ? 3 : 12;
    final start = isWeekly ? DateTime(now.year, now.month, now.day - 6) : isCurrentMonth ? DateTime(now.year, now.month) : DateTime(now.year, now.month - bucketCount + 1);
    final labels = isWeekly
        ? List.generate(bucketCount, (index) => DateFormat('dd/MM').format(start.add(Duration(days: index))))
        : isCurrentMonth
            ? List.generate(bucketCount, (index) => '${index * 7 + 1}-${index == bucketCount - 1 ? DateTime(now.year, now.month + 1, 0).day : (index + 1) * 7}')
            : List.generate(bucketCount, (index) => DateFormat('MMM', 'pt_BR').format(DateTime(start.year, start.month + index)).replaceAll('.', ''));
    final groups = <BarChartGroupData>[];
    var maximum = 0.0;

    for (var index = 0; index < bucketCount; index++) {
      final income = transactions.where((item) => item.isIncome && _belongsToBucket(item.date, index, start, isWeekly, isCurrentMonth, bucketCount)).fold<double>(0, (total, item) => total + item.amount);
      final expenses = transactions.where((item) => !item.isIncome && _belongsToBucket(item.date, index, start, isWeekly, isCurrentMonth, bucketCount)).fold<double>(0, (total, item) => total + item.amount);
      maximum = [maximum, income, expenses].reduce((current, value) => current > value ? current : value);
      groups.add(BarChartGroupData(x: index, barsSpace: 4, barRods: [
        BarChartRodData(toY: income, color: Colors.green, width: 8, borderRadius: BorderRadius.circular(3)),
        BarChartRodData(toY: expenses, color: Colors.redAccent, width: 8, borderRadius: BorderRadius.circular(3)),
      ]));
    }

    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
        child: Column(children: [
          SizedBox(height: 190, child: BarChart(BarChartData(
            maxY: maximum == 0 ? 10 : maximum * 1.2,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (value, meta) {
                return SideTitleWidget(meta: meta, child: Text(labels[value.toInt()]));
              })),
            ),
            barGroups: groups,
          ))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ChartLegend(color: Colors.green, label: 'Entradas'),
            const SizedBox(width: 20),
            _ChartLegend(color: Colors.redAccent, label: 'Despesas'),
          ]),
          Divider(color: colors.outlineVariant),
          Text(isWeekly ? 'Evolução diária' : isCurrentMonth ? 'Evolução semanal do mês' : period == _DashboardPeriod.all ? 'Evolução mensal dos últimos 12 meses' : 'Evolução mensal', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }

  bool _belongsToBucket(DateTime date, int index, DateTime start, bool isWeekly, bool isCurrentMonth, int bucketCount) {
    if (isWeekly) return DateTime(date.year, date.month, date.day).difference(start).inDays == index;
    if (isCurrentMonth) return date.year == start.year && date.month == start.month && ((date.day - 1) ~/ 7).clamp(0, bucketCount - 1) == index;
    final month = DateTime(start.year, start.month + index);
    return date.year == month.year && date.month == month.month;
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ]);
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.transactions});
  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final totals = <TransactionCategory, double>{};
    for (final item in transactions.where((item) => !item.isIncome)) {
      final category = item.category ?? TransactionCategory.outros;
      totals[category] = (totals[category] ?? 0) + item.amount;
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final palette = [Colors.deepOrange, Colors.indigo, Colors.teal, Colors.amber.shade700, Colors.pink, Colors.blueGrey];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: entries.isEmpty
            ? const SizedBox(height: 150, child: _DashboardMessage(message: 'Ainda não há despesas categorizadas.', icon: Icons.pie_chart_outline_rounded))
            : Row(children: [
                SizedBox(width: 150, height: 150, child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [for (var i = 0; i < entries.length; i++) PieChartSectionData(value: entries[i].value, color: palette[i % palette.length], showTitle: false, radius: 28)],
                ))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < entries.length && i < 5; i++) _LegendItem(color: palette[i % palette.length], label: entries[i].key.label, value: entries[i].value),
                ])),
              ]),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          Text(NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$ ').format(value)),
        ]),
      );
}

