import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/api_endpoints.dart';
import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/screens/parking/parking_widgets.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// The report gallery.
///
/// Mirrors the web `parking-reports`. Two reports rather than the BRD's
/// thirteen, "chosen because they answer the two questions management actually
/// asks: what did we take, and how did the car park behave. The remaining
/// eleven are cuts of the same data and can be added once the client has said
/// which cuts they want to see."
enum _ReportTab { collection, operations, recovery }

class ParkingReportsScreen extends StatefulWidget {
  const ParkingReportsScreen({super.key});

  @override
  State<ParkingReportsScreen> createState() => _ParkingReportsScreenState();
}

class _ParkingReportsScreenState extends State<ParkingReportsScreen> {
  _ReportTab _tab = _ReportTab.collection;

  int? _siteId;
  List<ParkingSite> _sites = [];
  late DateTime _from;
  late DateTime _to;

  bool _loading = false;
  bool _exporting = false;
  String? _error;

  CollectionReport? _collection;
  OperationsReport? _operations;
  List<MerchantRecoveryLine>? _recovery;

  static final DateFormat _iso = DateFormat('yyyy-MM-dd');
  static final DateFormat _pretty = DateFormat('dd MMM');

  @override
  void initState() {
    super.initState();
    // Last seven days — the range someone actually looks at first.
    final today = DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = _to.subtract(const Duration(days: 6));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _siteId = await ParkingContext.dashboardSiteId() ?? ParkingContext.siteId;
    await _loadSites();
    await _load();
  }

  Future<void> _loadSites() async {
    try {
      final response =
          await ApiService.getParkingSites(projectId: ParkingContext.projectId);
      if (!mounted) return;
      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        final list = (decoded is List) ? decoded : (decoded['data'] ?? []);
        final sites = (list as List)
            .map((e) => ParkingSite.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _sites = sites;
          _siteId ??= sites.isNotEmpty ? sites.first.siteId : null;
        });
      } else {
        debugPrint('Report sites failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Report sites error: $e');
    }
  }

  Future<void> _load() async {
    if (_siteId == null) {
      setState(() => _error = 'Choose a site first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _iso.format(_from);
      final to = _iso.format(_to);
      final response = switch (_tab) {
        _ReportTab.collection => await ApiService.getParkingCollectionReport(
            siteId: _siteId!, fromDate: from, toDate: to),
        _ReportTab.operations => await ApiService.getParkingOperationsReport(
            siteId: _siteId!, fromDate: from, toDate: to),
        // The statement is monthly, so the range's start month is what counts.
        _ReportTab.recovery => await ApiService.getParkingRecoveryStatement(
            siteId: _siteId!, month: from),
      };
      if (!mounted) return;

      if (ApiService.isSuccess(response.statusCode)) {
        final decoded = jsonDecode(response.body);
        setState(() {
          switch (_tab) {
            case _ReportTab.collection:
              _collection =
                  CollectionReport.fromJson(decoded as Map<String, dynamic>);
            case _ReportTab.operations:
              _operations =
                  OperationsReport.fromJson(decoded as Map<String, dynamic>);
            case _ReportTab.recovery:
              final list =
                  (decoded is List) ? decoded : (decoded['data'] ?? []);
              _recovery = (list as List)
                  .map((e) =>
                      MerchantRecoveryLine.fromJson(e as Map<String, dynamic>))
                  .toList();
          }
          _loading = false;
        });
      } else {
        debugPrint('Report failed: HTTP ${response.statusCode} '
            '${response.body}');
        setState(() {
          _loading = false;
          _error = 'Could not load the report. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Report error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Please check your connection.';
      });
    }
  }

  /// Download the workbook the server builds.
  ///
  /// Deliberately the server's file, not a client-side re-derivation — the
  /// sheet then cannot disagree with the figures on screen.
  Future<void> _export() async {
    if (_siteId == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final code = _tab == _ReportTab.collection ? 'COLLECTION' : 'OPERATIONS';
      final response = await ApiService.exportParkingReport(
        reportCode: code,
        siteId: _siteId!,
        fromDate: _iso.format(_from),
        toDate: _iso.format(_to),
      );
      if (!mounted) return;

      if (!ApiService.isSuccess(response.statusCode)) {
        debugPrint('Export failed: HTTP ${response.statusCode}');
        setState(() => _exporting = false);
        _toast(
            'Could not build the export. Please try again.', AppColors.danger);
        return;
      }

      // Same directory choice as the attendance report, so parking files land
      // where users already look for them.
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }
      if (dir == null) {
        setState(() => _exporting = false);
        _toast('Could not find a place to save the file.', AppColors.danger);
        return;
      }

      // Mirrors the server's own naming: parking-collection-<from>-to-<to>.
      final name = 'parking-${code.toLowerCase()}-'
          '${_iso.format(_from)}-to-${_iso.format(_to)}-'
          '${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final path = '${dir.path}/$name';
      await File(path).writeAsBytes(response.bodyBytes);
      debugPrint('Report written to $path');

      if (!mounted) return;
      setState(() => _exporting = false);

      final result = await OpenFile.open(path);
      if (!mounted) return;
      _toast(
        result.type == ResultType.done
            ? 'Report saved and opened.'
            : 'Report saved to Downloads.',
        AppColors.success,
      );
    } catch (e) {
      debugPrint('Export error: $e');
      if (!mounted) return;
      setState(() => _exporting = false);
      _toast('Could not save the report. Please try again.', AppColors.danger);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content:
            Text(message, style: const TextStyle(color: AppColors.onPrimary)),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  void _switchTab(_ReportTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    // Each tab is a separate call; only fetch the one being looked at.
    final cached = switch (tab) {
      _ReportTab.collection => _collection != null,
      _ReportTab.operations => _operations != null,
      _ReportTab.recovery => _recovery != null,
    };
    if (!cached) _load();
  }

  Future<void> _selectSite(int siteId) async {
    if (siteId == _siteId) return;
    await ParkingContext.saveDashboardSiteId(siteId);
    if (!mounted) return;
    setState(() {
      _siteId = siteId;
      _collection = null;
      _operations = null;
      _recovery = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: parkingAppBar('Parking Reports', actions: [
        if (_sites.length > 1) _siteMenu(),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
          onPressed: _load,
        ),
      ]),
      body: ContentWidthLimit(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _tabs(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _rangeBar()),
                  const SizedBox(width: 10),
                  _excelButton(),
                ],
              ),
              const SizedBox(height: 14),
              if (_error != null)
                ParkingBanner(
                    text: _error!,
                    color: AppColors.danger,
                    icon: Icons.error_outline)
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else
                ...switch (_tab) {
                  _ReportTab.collection => _collectionView(),
                  _ReportTab.operations => _operationsView(),
                  _ReportTab.recovery => _recoveryView(),
                },
            ],
          ),
        ),
      ),
    );
  }

  Widget _siteMenu() {
    final current = _sites.firstWhere(
      (x) => x.siteId == _siteId,
      orElse: () => ParkingSite(siteName: 'Site'),
    );
    return PopupMenuButton<int>(
      tooltip: 'Change site',
      color: AppColors.surface,
      onSelected: _selectSite,
      itemBuilder: (context) => _sites
          .where((x) => x.siteId != null)
          .map((x) => PopupMenuItem<int>(
                value: x.siteId!,
                child: Row(
                  children: [
                    Icon(
                        x.siteId == _siteId
                            ? Icons.check_circle
                            : Icons.location_city,
                        size: 18,
                        color: x.siteId == _siteId
                            ? AppColors.primary
                            : AppColors.textFaint),
                    const SizedBox(width: 10),
                    Text(x.siteName ?? 'Site ${x.siteId}',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ))
          .toList(),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(current.siteName ?? 'Site',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary)),
              ),
              const Icon(Icons.arrow_drop_down,
                  size: 20, color: AppColors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    return Row(
      children: [
        _tabChip(_ReportTab.collection, 'Collection', Icons.payments,
            'What we took'),
        const SizedBox(width: 8),
        _tabChip(_ReportTab.operations, 'Operations', Icons.insights,
            'How it behaved'),
        const SizedBox(width: 8),
        _tabChip(_ReportTab.recovery, 'Recovery', Icons.storefront,
            'Shop bill-back'),
      ],
    );
  }

  Widget _tabChip(_ReportTab tab, String label, IconData icon, String caption) {
    final bool on = _tab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => _switchTab(tab),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: on ? AppColors.primary : AppColors.divider,
                width: on ? 1.6 : 1),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.26),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: on ? AppColors.onPrimary : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: on ? AppColors.onPrimary : AppColors.textPrimary)),
              Text(caption,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: on
                          ? AppColors.onPrimary.withOpacity(0.85)
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _excelButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: (_exporting || _loading) ? null : _export,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.success,
          side: BorderSide(
              color: _exporting ? AppColors.divider : AppColors.success),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _exporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.success))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.grid_on, size: 18),
                  SizedBox(width: 7),
                  Text('EXCEL',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
      ),
    );
  }

  Widget _rangeBar() {
    return InkWell(
      onTap: _pickRange,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tab == _ReportTab.recovery
                    ? DateFormat('MMMM yyyy').format(_from)
                    : '${_pretty.format(_from)} — ${_pretty.format(_to)}'
                        '${_from.year != _to.year ? " ${_to.year}" : ""}',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            Text('Change',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- collection ----

  List<Widget> _collectionView() {
    final c = _collection;
    if (c == null) return [_empty('No collection data for this range.')];

    return [
      AnimatedEntry(
        index: 0,
        child: _heroAmount('NET COLLECTION', c.netCollection, [
          _heroPair('Gross', money(c.grossCollection)),
          _heroPair('Tax', money(c.taxAmount)),
          _heroPair('Txns', '${c.transactionCount ?? 0}'),
        ]),
      ),
      const SizedBox(height: 14),
      AnimatedEntry(
        index: 1,
        child: ParkingCard(
          title: 'Summary',
          child: Column(
            children: [
              KeyValueRow(
                  label: 'Average ticket', value: money(c.averageTicketValue)),
              KeyValueRow(label: 'Free exits', value: '${c.freeExits ?? 0}'),
              KeyValueRow(
                  label: 'Merchant discount',
                  value: money(c.validationDiscountGiven)),
              if ((c.reversalCount ?? 0) > 0) ...[
                Divider(color: AppColors.divider, height: 18),
                KeyValueRow(
                    label: 'Reversals',
                    value: '${c.reversalCount}',
                    valueColor: AppColors.danger),
                KeyValueRow(
                    label: 'Reversed amount',
                    value: money(c.reversedAmount),
                    valueColor: AppColors.danger),
              ],
            ],
          ),
        ),
      ),
      ..._breakdown('By payment mode', c.byPaymentMode, 2),
      ..._breakdown('By vehicle type', c.byVehicleType, 3),
      ..._breakdown('By lane', c.byLane, 4),
      ..._breakdown('By operator', c.byOperator, 5),
      if (c.dailyBreakdown.isNotEmpty) ...[
        const SizedBox(height: 14),
        AnimatedEntry(index: 6, child: _dailyCard(c.dailyBreakdown)),
      ],
    ];
  }

  /// A share-of-total list. Bars beat bare numbers for "where did it come
  /// from" — the eye ranks lengths faster than it ranks figures.
  List<Widget> _breakdown(String title, Map<String, double> data, int index) {
    if (data.isEmpty) return const [];
    final total = data.values.fold<double>(0, (a, b) => a + b);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      const SizedBox(height: 14),
      AnimatedEntry(
        index: index,
        child: ParkingCard(
          title: title,
          child: Column(
            children: entries.map((e) {
              final double share = total > 0 ? e.value / total : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(ParkingConstants.label(e.key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        Text(money(e.value),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amount)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text('${(share * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ];
  }

  Widget _dailyCard(List<DailyCollectionLine> days) {
    final double peak = days.fold<double>(
        0, (a, d) => (d.collection ?? 0) > a ? d.collection! : a);
    final df = DateFormat('EEE dd MMM');
    return ParkingCard(
      title: 'Day by day',
      child: Column(
        children: days.map((d) {
          final double share = peak > 0 ? (d.collection ?? 0) / peak : 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.date == null ? '—' : df.format(d.date!),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text('${d.vehicles ?? 0} veh',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    Text(money(d.collection),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amount)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.amount),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------ recovery ----

  List<Widget> _recoveryView() {
    final lines = _recovery;
    if (lines == null || lines.isEmpty) {
      return [_empty('No shop validations to bill back this month.')];
    }

    double totalDiscount = 0;
    double totalRecoverable = 0;
    int totalCounter = 0;
    for (final l in lines) {
      totalDiscount += l.discountGiven ?? 0;
      totalRecoverable += l.recoverableAmount ?? 0;
      totalCounter += l.counterApplied ?? 0;
    }

    return [
      AnimatedEntry(
        index: 0,
        child: _heroAmount('RECOVERABLE THIS MONTH', totalRecoverable, [
          _heroPair('Given away', money(totalDiscount)),
          _heroPair('Shops', '${lines.length}'),
          _heroPair('Counter-applied', '$totalCounter'),
        ]),
      ),
      const SizedBox(height: 14),
      ...lines.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                AnimatedEntry(index: e.key + 1, child: _recoveryCard(e.value)),
          )),
    ];
  }

  Widget _recoveryCard(MerchantRecoveryLine l) {
    final int shop = l.shopApplied ?? 0;
    final int counter = l.counterApplied ?? 0;
    final int total = shop + counter;
    final double shopShare = total > 0 ? shop / total : 0;

    return ParkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.shopName ?? 'Shop ${l.merchantId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    if ((l.shopCode ?? '').isNotEmpty)
                      Text(l.shopCode!,
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (!l.recoverable)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('NOT BILLABLE',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary)),
                ),
            ],
          ),
          Divider(color: AppColors.divider, height: 18),
          KeyValueRow(label: 'Validations', value: '${l.validationCount ?? 0}'),
          KeyValueRow(label: 'Given away', value: money(l.discountGiven)),
          KeyValueRow(
            label: 'Recoverable',
            value: money(l.recoverableAmount),
            emphasise: true,
            valueColor: AppColors.amount,
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            // Who actually applied these. A line resting mostly on our staff's
            // word is a conversation to have BEFORE the invoice goes out.
            Row(
              children: [
                Text('Shop $shop',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
                const Spacer(),
                Text('Counter $counter',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: l.mostlyCounterApplied
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: l.mostlyCounterApplied
                            ? AppColors.warning
                            : AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: shopShare.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.warning.withOpacity(0.45),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            if (l.mostlyCounterApplied) ...[
              const SizedBox(height: 10),
              ParkingBanner(
                text: 'Mostly applied by our counter '
                    '(${money(l.counterAppliedAmount)}). Confirm with the shop '
                    'before billing.',
                color: AppColors.warning,
                icon: Icons.help_outline,
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- operations ----

  List<Widget> _operationsView() {
    final o = _operations;
    if (o == null) return [_empty('No operations data for this range.')];

    return [
      AnimatedEntry(
        index: 0,
        child: _heroCount('VEHICLES IN', o.totalEntries, [
          _heroPair('Out', '${o.totalExits ?? 0}'),
          _heroPair('Daily avg', '${o.averageDailyEntries ?? 0}'),
          _heroPair('Peak day', '${o.peakDayEntries ?? 0}'),
        ]),
      ),
      const SizedBox(height: 14),
      AnimatedEntry(
        index: 1,
        child: ParkingCard(
          title: 'Dwell',
          child: Column(
            children: [
              KeyValueRow(
                  label: 'Average stay',
                  value: durationLabel(o.averageDwellMinutes),
                  emphasise: true),
              KeyValueRow(
                  label: 'Median stay',
                  value: durationLabel(o.medianDwellMinutes)),
              if (o.busiestHour != null)
                KeyValueRow(
                    label: 'Busiest hour',
                    value: '${o.busiestHour!.toString().padLeft(2, '0')}:00'),
              if (o.peakDate != null)
                KeyValueRow(
                    label: 'Peak day',
                    value: DateFormat('EEE dd MMM').format(o.peakDate!)),
            ],
          ),
        ),
      ),
      if (o.dwellDistribution.isNotEmpty) ...[
        const SizedBox(height: 14),
        AnimatedEntry(
          index: 2,
          child: ParkingCard(
            title: 'How long they stayed',
            child: Column(
              children: _countBars(o.dwellDistribution, AppColors.accent),
            ),
          ),
        ),
      ],
      if (o.entriesByHour.isNotEmpty) ...[
        const SizedBox(height: 14),
        AnimatedEntry(index: 3, child: _hourChart(o)),
      ],
      const SizedBox(height: 14),
      AnimatedEntry(
        index: 4,
        child: ParkingCard(
          title: 'Utilisation',
          child: Column(
            children: [
              KeyValueRow(
                  label: 'Capacity', value: '${o.totalCapacity ?? 0} bays'),
              KeyValueRow(
                  label: 'Peak occupancy',
                  value: '${o.peakOccupancyPercent ?? 0}%'),
              KeyValueRow(
                  label: 'Revenue per bay / day',
                  value: money(o.revenuePerBayPerDay),
                  emphasise: true,
                  valueColor: AppColors.amount),
            ],
          ),
        ),
      ),
      if (o.zoneUtilisation.isNotEmpty) ...[
        const SizedBox(height: 14),
        AnimatedEntry(index: 5, child: _zoneUtilisation(o.zoneUtilisation)),
      ],
    ];
  }

  List<Widget> _countBars(Map<String, int> data, Color color) {
    final int peak = data.values.fold<int>(0, (a, b) => b > a ? b : a);
    return data.entries.map((e) {
      final double share = peak > 0 ? e.value / peak : 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.key,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Text('${e.value}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Entries by hour as columns — the shape of the day is the point, so a
  /// sparkline-style chart says more than 24 rows of numbers.
  Widget _hourChart(OperationsReport o) {
    final int peak =
        o.entriesByHour.values.fold<int>(0, (a, b) => b > a ? b : a);
    return ParkingCard(
      title: 'Arrivals by hour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final int v = o.entriesByHour[h] ?? 0;
                final double share = peak > 0 ? v / peak : 0;
                final bool busiest = o.busiestHour == h;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (busiest && v > 0)
                          Text('$v',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: share),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, v2, _) => Container(
                            height: (v2 * 80).clamp(2.0, 80.0),
                            decoration: BoxDecoration(
                              color: busiest
                                  ? AppColors.primary
                                  : AppColors.tint(AppColors.primary, 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['00', '06', '12', '18', '23']
                .map((h) => Text(h,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _zoneUtilisation(List<ZoneUtilisationLine> zones) {
    return ParkingCard(
      title: 'By zone',
      child: Column(
        children: zones.map((z) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(z.zoneName ?? '—',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                    ),
                    Text('${z.totalBays ?? 0} bays',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                KeyValueRow(label: 'Stays', value: '${z.totalStays ?? 0}'),
                KeyValueRow(
                    label: 'Peak occupancy', value: '${z.peakOccupancy ?? 0}%'),
                KeyValueRow(
                    label: 'Average occupancy',
                    value: '${z.averageOccupancy ?? 0}%'),
                KeyValueRow(
                    label: 'Turnover per bay',
                    value: (z.turnoverPerBay ?? 0).toStringAsFixed(1)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------- shared ----

  Widget _heroAmount(String label, double? value, List<Widget> pairs) => _hero(
      label,
      AnimatedCount(
        value: value ?? 0,
        format: (v) => money(v),
        style: const TextStyle(
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: AppColors.onPrimary),
      ),
      pairs);

  Widget _heroCount(String label, int? value, List<Widget> pairs) => _hero(
      label,
      AnimatedCount(
        value: (value ?? 0).toDouble(),
        style: const TextStyle(
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: AppColors.onPrimary),
      ),
      pairs);

  Widget _hero(String label, Widget value, List<Widget> pairs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
          stops: AppColors.heroStops,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroShadow.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary.withOpacity(0.8))),
          const SizedBox(height: 4),
          value,
          const SizedBox(height: 14),
          Row(children: pairs),
        ],
      ),
    );
  }

  Widget _heroPair(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.onPrimary.withOpacity(0.8))),
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 44, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}
