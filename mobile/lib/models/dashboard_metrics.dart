import 'lead.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.openLeadsCount,
    required this.confirmedCount,
    required this.deliveredCount,
    required this.collectedMargin,
    required this.upcomingDeliveries,
    required this.todayDeliveries,
  });

  final int openLeadsCount;
  final int confirmedCount;
  final int deliveredCount;
  final int collectedMargin;
  final List<Lead> upcomingDeliveries;
  final List<Lead> todayDeliveries;

  factory DashboardMetrics.fromLeads(List<Lead> leads) {
    final open = leads.where((l) => l.isOpen).toList();
    final confirmed = leads.where((l) => l.isConfirmed).toList();
    final delivered = leads.where((l) => l.isDelivered).toList();

    final margin = delivered.where((l) => l.paid).fold<int>(
          0,
          (sum, l) => sum + l.netMargin,
        );

    final scheduled = leads.where((l) => l.hasDeliveryDate && l.isOpen).toList()
      ..sort((a, b) => a.deliveryAt.compareTo(b.deliveryAt));

    final today = scheduled.where((l) => l.isScheduledToday).toList();

    return DashboardMetrics(
      openLeadsCount: open.length,
      confirmedCount: confirmed.length,
      deliveredCount: delivered.length,
      collectedMargin: margin,
      upcomingDeliveries: scheduled,
      todayDeliveries: today,
    );
  }
}
