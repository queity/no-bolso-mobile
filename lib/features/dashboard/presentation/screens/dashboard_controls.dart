part of 'dashboard_screen.dart';

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selectedPeriod, required this.onChanged});

  final _DashboardPeriod selectedPeriod;
  final ValueChanged<_DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_DashboardPeriod>(
      initialValue: selectedPeriod,
      decoration: const InputDecoration(
        labelText: 'Período do dashboard',
        prefixIcon: Icon(Icons.calendar_month_rounded),
      ),
      items: const [
        DropdownMenuItem(value: _DashboardPeriod.week, child: Text('Semanal')),
        DropdownMenuItem(value: _DashboardPeriod.month, child: Text('1 mês')),
        DropdownMenuItem(value: _DashboardPeriod.threeMonths, child: Text('3 meses')),
        DropdownMenuItem(value: _DashboardPeriod.sixMonths, child: Text('6 meses')),
        DropdownMenuItem(value: _DashboardPeriod.all, child: Text('Todos')),
      ],
      onChanged: (period) {
        if (period != null) onChanged(period);
      },
    );
  }
}

class _SectionCheckbox extends StatelessWidget {
  const _SectionCheckbox({required this.icon, required this.title, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (_) => onChanged(),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon),
      title: Text(title),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
