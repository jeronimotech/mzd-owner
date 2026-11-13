import 'package:flutter/material.dart';

import '../models/maintenance.dart';
import '../state/app_state.dart';
import 'format.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = state.maintenanceByUrgency;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Mantenimiento', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Odómetro: ${fmtKm(state.profile.odometerKm)} · intervalos sugeridos, revisa tu manual',
            style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 16),
        for (final item in items) ...[
          _MaintenanceCard(item: item, status: state.statusOf(item), onTap: () => _edit(context, item)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _edit(BuildContext context, MaintenanceItem item) async {
    final km = TextEditingController(text: state.profile.odometerKm.round().toString());
    final everyKm = TextEditingController(text: item.everyKm?.toString() ?? '');
    final everyMonths = TextEditingController(text: item.everyMonths?.toString() ?? '');
    DateTime date = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(item.title, style: Theme.of(ctx).textTheme.titleLarge),
            if (item.lastDate != null)
              Text('Último: ${fmtDate(item.lastDate!)}${item.lastKm != null ? ' · ${fmtKm(item.lastKm!)}' : ''}',
                  style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilometraje del servicio'))),
              const SizedBox(width: 12),
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text(fmtDate(date)),
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2010), lastDate: DateTime.now());
                  if (d != null) setSheet(() => date = d);
                },
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                await state.markDone(item.id, km: double.tryParse(km.text), date: date);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Marcar como hecho'),
            ),
            const Divider(height: 32),
            Text('Intervalo', style: Theme.of(ctx).textTheme.titleSmall),
            Row(children: [
              Expanded(child: TextField(controller: everyKm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cada (km)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: everyMonths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cada (meses)'))),
            ]),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await state.updateItem(MaintenanceItem(
                  id: item.id,
                  title: item.title,
                  everyKm: int.tryParse(everyKm.text),
                  everyMonths: int.tryParse(everyMonths.text),
                  lastKm: item.lastKm,
                  lastDate: item.lastDate,
                  note: item.note,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar intervalo'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.item, required this.status, required this.onTap});
  final MaintenanceItem item;
  final DueStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status.level) {
      DueLevel.due => (Colors.redAccent, Icons.error),
      DueLevel.soon => (Colors.orangeAccent, Icons.schedule),
      DueLevel.ok => (const Color(0xFF33D17A), Icons.check_circle),
      DueLevel.unknown => (Colors.white38, Icons.help_outline),
    };
    final every = [
      if (item.everyKm != null) 'cada ${fmtKm(item.everyKm!.toDouble())}',
      if (item.everyMonths != null) 'cada ${item.everyMonths} meses',
    ].join(' o ');
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: color),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${status.label}\n$every', style: const TextStyle(height: 1.4)),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
