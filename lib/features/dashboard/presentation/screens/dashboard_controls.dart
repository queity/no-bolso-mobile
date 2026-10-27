part of 'dashboard_screen.dart';

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selectedPeriod, required this.onChanged});

  final DashboardPeriod selectedPeriod;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DashboardPeriod>(
      initialValue: selectedPeriod,
      decoration: const InputDecoration(
        labelText: 'Período do dashboard',
        prefixIcon: Icon(Icons.calendar_month_rounded),
      ),
      items: [
        for (final period in DashboardPeriod.values)
          DropdownMenuItem(value: period, child: Text(period.label)),
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
