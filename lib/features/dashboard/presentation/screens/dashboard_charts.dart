part of 'dashboard_screen.dart';

class _EvolutionChart extends StatelessWidget {
  const _EvolutionChart({required this.summary});

  final DashboardSummary summary;

  /// Rótulo de cada barra, conforme o agrupamento escolhido pelo domínio.
  String _label(EvolutionBucket bucket) {
    return switch (summary.granularity) {
      EvolutionGranularity.daily => DateFormat('dd/MM').format(bucket.start),
      EvolutionGranularity.weekOfMonth => '${bucket.start.day}-${bucket.end.day}',
      EvolutionGranularity.monthly => DateFormat('MMM', 'pt_BR').format(bucket.start).replaceAll('.', ''),
    };
  }

  String get _caption {
    return switch (summary.period) {
      DashboardPeriod.week => 'Evolução diária',
      DashboardPeriod.month => 'Evolução semanal do mês',
      DashboardPeriod.all => 'Evolução mensal dos últimos 12 meses',
      _ => 'Evolução mensal',
    };
  }

  @override
  Widget build(BuildContext context) {
    // Os totais de cada barra já vêm prontos do DashboardSummary; aqui só
    // desenhamos.
    final buckets = summary.evolution;
    final labels = [for (final bucket in buckets) _label(bucket)];
    final maximum = summary.evolutionMax;
    final groups = [
      for (var index = 0; index < buckets.length; index++)
        BarChartGroupData(x: index, barsSpace: 4, barRods: [
          BarChartRodData(toY: buckets[index].income, color: Colors.green, width: 8, borderRadius: BorderRadius.circular(3)),
          BarChartRodData(toY: buckets[index].expenses, color: Colors.redAccent, width: 8, borderRadius: BorderRadius.circular(3)),
        ]),
    ];

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
          Text(_caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ),
    );
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
  const _CategoryChart({required this.totals});

  /// Já agrupado e ordenado (maior despesa primeiro) pelo DashboardSummary.
  final List<CategoryTotal> totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals;
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
                  sections: [for (var i = 0; i < entries.length; i++) PieChartSectionData(value: entries[i].total, color: palette[i % palette.length], showTitle: false, radius: 28)],
                ))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < entries.length && i < 5; i++) _LegendItem(color: palette[i % palette.length], label: entries[i].category.label, value: entries[i].total),
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

