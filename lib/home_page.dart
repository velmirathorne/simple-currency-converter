import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _bgDark = Color(0xFF181a20);
const _bgCard = Color(0xFF252930);
const _borderIdle = Color(0xFF434c5a);
const _gold = Color(0xFFfcd535);
const _goldDark = Color(0xFFb79525);

// Currencies that should be displayed without decimal places.
const _noDecimalCurrencies = {'VND', 'JPY', 'KRW', 'IDR', 'CLP', 'HUF'};

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

// GET https://api.frankfurter.dev/v2/rates?base=USD
// Returns a JSON array: [{"base":"USD","quote":"EUR","rate":0.91}, ...]
Future<Map<String, double>> fetchAllRates() async {
  final response = await http.get(
    Uri.parse('https://api.frankfurter.dev/v2/rates?base=USD'),
  );
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }
  final List<dynamic> data = jsonDecode(response.body);
  final rates = <String, double>{'USD': 1.0};
  for (final entry in data) {
    rates[entry['quote'] as String] = (entry['rate'] as num).toDouble();
  }
  return rates;
}

// ---------------------------------------------------------------------------
// Searchable currency picker — pure Flutter, no third-party packages
// ---------------------------------------------------------------------------

Future<String?> showCurrencyPicker({
  required BuildContext context,
  required List<String> currencies,
  required String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // lets it expand to 90 % of screen height
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CurrencyPickerSheet(currencies: currencies, selected: selected),
  );
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selected,
  });

  final List<String> currencies;
  final String? selected;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  late List<String> _filtered;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.currencies;
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.currencies
          : widget.currencies
                .where((c) => c.toLowerCase().contains(q))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 90 % of screen height so the search box + list have plenty of room.
    final sheetHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _borderIdle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search field — autofocused so the keyboard opens immediately
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: _goldDark,
              decoration: const InputDecoration(
                hintText: 'Search currency…',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: _bgDark,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _goldDark, width: 1.5),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _borderIdle, width: 1.5),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ),

          const Divider(color: _borderIdle, height: 1),

          // Currency list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No currency found',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemExtent: 52, // fixed height = faster layout
                    itemBuilder: (context, index) {
                      final code = _filtered[index];
                      final isSelected = code == widget.selected;
                      return ListTile(
                        dense: true,
                        title: Text(
                          code,
                          style: TextStyle(
                            color: isSelected ? _gold : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: _gold, size: 18)
                            : null,
                        selectedTileColor: _bgDark,
                        selected: isSelected,
                        onTap: () => Navigator.pop(context, code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _CCMaterialPageState();
}

class _CCMaterialPageState extends State<HomePage> {
  // --- Data ---
  Map<String, double> _rates = {};
  List<String> _sortedCurrencies = [];
  bool _isLoading = true;
  String? _error;

  // --- Converter ---
  String? _fromCurrency;
  String? _toCurrency;
  double _result = 0.0;

  // --- Controllers & keys ---
  final TextEditingController _amountController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _amountFocus = FocusNode();
  final GlobalKey _amountKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadRates();
    // Scroll the amount field into view when the keyboard appears.
    // Scrollable.ensureVisible is timing-independent — it uses the widget's
    // actual render position rather than a hardcoded delay.
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _amountKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _scrollController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _loadRates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rates = await fetchAllRates();
      final sorted = rates.keys.toList()..sort();
      setState(() {
        _rates = rates;
        _sortedCurrencies = sorted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'Could not load exchange rates.\nPlease check your connection.';
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Conversion logic
  // ---------------------------------------------------------------------------

  // Cross-rate: amount × (toRate / fromRate), both relative to USD base.
  double _convert(double amount) {
    return amount * (_rates[_toCurrency!]! / _rates[_fromCurrency!]!);
  }

  void _onConvert() {
    if (_fromCurrency == null || _toCurrency == null) return;
    final sanitized = _amountController.text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(sanitized);
    if (value == null || value < 0) return;
    setState(() => _result = _convert(value));
  }

  void _swapCurrencies() {
    if (_fromCurrency == null || _toCurrency == null) return;
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
      final sanitized = _amountController.text
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^0-9.]'), '');
      final value = double.tryParse(sanitized);
      if (value != null && value >= 0) _result = _convert(value);
    });
  }

  Future<void> _pickCurrency({required bool isFrom}) async {
    final picked = await showCurrencyPicker(
      context: context,
      currencies: _sortedCurrencies,
      selected: isFrom ? _fromCurrency : _toCurrency,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromCurrency = picked;
      } else {
        _toCurrency = picked;
      }
      // Re-convert immediately if both sides are set and there's a value.
      if (_fromCurrency != null && _toCurrency != null) {
        final sanitized = _amountController.text
            .replaceAll(RegExp(r'\s+'), '')
            .replaceAll(RegExp(r'[^0-9.]'), '');
        final value = double.tryParse(sanitized);
        if (value != null && value >= 0) _result = _convert(value);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  String _formatResult(double value) {
    if (value == 0.0) return '0';
    // Scientific notation for very large or very small values.
    if (value >= 1e9 || (value > 0 && value < 0.0001)) {
      return value
          .toStringAsExponential(4)
          .replaceFirst('e+', '×10^')
          .replaceFirst('e-', '×10^-')
          .replaceFirst('e', '×10^');
    }
    if (_noDecimalCurrencies.contains(_toCurrency)) {
      return NumberFormat('#,##0', 'en_US').format(value);
    }
    return NumberFormat('#,##0.####', 'en_US').format(value);
  }

  String _rateHint() {
    if (_fromCurrency == null || _toCurrency == null) return '';
    return '1 $_fromCurrency ≈ ${_formatResult(_convert(1.0))} $_toCurrency';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF181a20),
        elevation: 0.0,
        systemOverlayStyle:
            SystemUiOverlayStyle.light, // White status bar icons
      ),
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgDark,
      body: SafeArea(
        child: _isLoading
            ? Center(child: _buildLoading())
            : _error != null
            ? Center(child: _buildError())
            : _buildConverter(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: _gold),
        SizedBox(height: 16),
        Text(
          'Loading exchange rates…',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _loadRates,
            style: TextButton.styleFrom(foregroundColor: _gold),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildConverter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Result display
                  Text(
                    (_fromCurrency != null && _toCurrency != null)
                        ? '${_formatResult(_result)} $_toCurrency'
                        : '—',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Currency selectors + swap
                  Row(
                    children: [
                      Expanded(
                        child: _buildCurrencyButton(
                          label: _fromCurrency ?? 'Select',
                          isPlaceholder: _fromCurrency == null,
                          onTap: () => _pickCurrency(isFrom: true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IconButton(
                          onPressed: _swapCurrencies,
                          icon: const Icon(Icons.swap_horiz),
                          color: _gold,
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: _bgCard,
                            shape: const CircleBorder(
                              side: BorderSide(color: _borderIdle, width: 1.5),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildCurrencyButton(
                          label: _toCurrency ?? 'Select',
                          isPlaceholder: _toCurrency == null,
                          onTap: () => _pickCurrency(isFrom: false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Amount input
                  TextField(
                    key: _amountKey,
                    focusNode: _amountFocus,
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: _fromCurrency != null
                          ? 'Amount in $_fromCurrency'
                          : 'Amount',
                      labelStyle: const TextStyle(color: Colors.white54),
                      floatingLabelStyle: const TextStyle(color: _goldDark),
                      hintText: 'e.g. 1.99',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.monetization_on_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                      filled: true,
                      fillColor: _bgCard,
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _goldDark, width: 1.5),
                        borderRadius: BorderRadius.all(Radius.circular(60)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: _borderIdle, width: 1.5),
                        borderRadius: BorderRadius.all(Radius.circular(60)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    cursorColor: _goldDark,
                    textAlignVertical: const TextAlignVertical(y: 0.5),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSubmitted: (_) => _onConvert(),
                  ),

                  const SizedBox(height: 16),

                  // Convert button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _onConvert,
                      style: TextButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black87,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(60),
                        ),
                      ),
                      child: const Text('Convert'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Live rate hint
                  Text(
                    _rateHint(),
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Pill-shaped tappable button that opens the currency picker sheet.
  Widget _buildCurrencyButton({
    required String label,
    required bool isPlaceholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: _borderIdle, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPlaceholder ? Colors.white38 : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
