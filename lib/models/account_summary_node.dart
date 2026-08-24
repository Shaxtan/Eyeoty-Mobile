/// Ported from HourlyReportPage.jsx's Account Summary tree shape - same
/// POST /usage/reports/account-summary-report endpoint DashboardService
/// already confirmed for the Dashboard's utilization trend, but parsed
/// here as the FULL recursive account tree rather than collapsed into
/// a single percentage.
class AccountSummaryNode {
  final String accountName;
  final String accountId;
  final int deviceCount;
  final num totalDistance;
  final num totalRunTime; // seconds
  final List<AccountSummaryNode> childAccounts;

  AccountSummaryNode({
    required this.accountName,
    required this.accountId,
    this.deviceCount = 0,
    this.totalDistance = 0,
    this.totalRunTime = 0,
    this.childAccounts = const [],
  });

  factory AccountSummaryNode.fromJson(Map<String, dynamic> json) {
    final children = (json['childAccounts'] as List<dynamic>?) ?? [];
    return AccountSummaryNode(
      accountName: json['accountName']?.toString() ?? '',
      accountId: (json['accountId'] ?? '').toString(),
      deviceCount:
          json['deviceCount'] is num ? (json['deviceCount'] as num).toInt() : int.tryParse('${json['deviceCount']}') ?? 0,
      totalDistance:
          json['totalDistance'] is num ? json['totalDistance'] as num : num.tryParse('${json['totalDistance']}') ?? 0,
      totalRunTime:
          json['totalRunTime'] is num ? json['totalRunTime'] as num : num.tryParse('${json['totalRunTime']}') ?? 0,
      childAccounts: children.map((e) => AccountSummaryNode.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Ported 1:1 from flattenAccounts(): recursively collects LEAF accounts
/// (no children) from the tree.
List<AccountSummaryNode> flattenAccountSummary(List<AccountSummaryNode> accounts) {
  final flat = <AccountSummaryNode>[];
  for (final a in accounts) {
    if (a.childAccounts.isEmpty) {
      flat.add(a);
    } else {
      flat.addAll(flattenAccountSummary(a.childAccounts));
    }
  }
  return flat;
}