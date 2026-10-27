/// Períodos que o usuário pode escolher no Dashboard.
enum DashboardPeriod {
  week('Semanal'),
  month('1 mês'),
  threeMonths('3 meses'),
  sixMonths('6 meses'),
  all('Todos');

  const DashboardPeriod(this.label);

  final String label;

  /// Primeiro dia do período (inclusivo), relativo a [now]. `null` em
  /// [DashboardPeriod.all], que não tem limite.
  DateTime? startFrom(DateTime now) {
    return switch (this) {
      DashboardPeriod.week => DateTime(now.year, now.month, now.day - 6),
      DashboardPeriod.month => DateTime(now.year, now.month),
      DashboardPeriod.threeMonths => DateTime(now.year, now.month - 2),
      DashboardPeriod.sixMonths => DateTime(now.year, now.month - 5),
      DashboardPeriod.all => null,
    };
  }
}
