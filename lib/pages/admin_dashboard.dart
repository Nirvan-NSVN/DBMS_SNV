import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _svc = SupabaseService();

  static const _tables = [
    _TableDef('hotel', 'Hotels', 'Hotel ID', false, [
      _Col('Hotel ID', 'Hotel ID', isInt: true, isPk: true),
      _Col('Name', 'Name'),
      _Col('Address', 'Address'),
      _Col('Phone Number', 'Phone Number', isInt: true),
      _Col('Email', 'Email'),
    ]),
    _TableDef('rooms type', 'Room Types', 'type id', false, [
      _Col('type id', 'Type ID', isInt: true, isPk: true),
      _Col('Hotel id', 'Hotel ID', isInt: true),
      _Col('room category', 'Category'),
      _Col('price', 'Price', isDouble: true),
    ]),
    _TableDef('rooms', 'Rooms', 'Room ID', false, [
      _Col('Room ID', 'Room ID', isInt: true, isPk: true),
      _Col('Hotel ID', 'Hotel ID', isInt: true),
      _Col('Room Number', 'Room Number', isInt: true),
      _Col('room type', 'Room Type ID', isInt: true),
    ]),
    _TableDef('booking', 'Bookings', 'Booking ID', false, [
      _Col('Booking ID', 'Booking ID', isInt: true, isPk: true),
      _Col('Booking Date', 'Booking Date'),
      _Col('CHECK IN', 'Check In'),
      _Col('CHECK OUT', 'Check Out'),
      _Col('Booking Status', 'Status'),
      _Col('Customer ID', 'Customer ID', isInt: true),
      _Col('Payment ID', 'Payment ID'),
    ]),
    _TableDef('reservation', 'Reservations', 'Booking ID', false, [
      _Col('Booking ID', 'Booking ID', isInt: true, isPk: true),
      _Col('Room ID', 'Room ID', isInt: true),
    ]),
    _TableDef('payment', 'Payments', 'Transaction ID', false, [
      _Col('Transaction ID', 'Transaction ID', isPk: true),
      _Col('Received', 'Received'),
      _Col('Amount', 'Amount', isDouble: true),
      _Col('Mode', 'Mode'),
    ]),
    _TableDef('customer', 'Customers', 'Customer ID', true, [
      _Col('Customer ID', 'Customer ID', isInt: true, isPk: true),
      _Col('Name', 'Name'),
      _Col('Phone Number', 'Phone Number', isInt: true),
      _Col('Address', 'Address'),
      _Col('Email', 'Email'),
    ]),
    _TableDef('staff', 'Staff', 'Staff ID', true, [
      _Col('Staff ID', 'Staff ID', isInt: true, isPk: true),
      _Col('Name', 'Name'),
      _Col('Email', 'Email'),
      _Col('Phone Number', 'Phone Number', isInt: true),
      _Col('Role', 'Role'),
      _Col('Salary', 'Salary', isDouble: true),
      _Col('Hotel ID', 'Hotel ID', isInt: true),
      _Col('Joining Date', 'Joining Date'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tables.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black54),
          label: const Text('Back', style: TextStyle(color: Colors.black54)),
        ),
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.black87)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const _AddUserDialog(),
              ),
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.indigo[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo[700],
          tabs: _tables
              .map((t) => Tab(
                    child: Row(
                      children: [
                        Text(t.label),
                        if (t.readOnly) ...[
                          const SizedBox(width: 6),
                          Icon(LucideIcons.eye, size: 14, color: Colors.grey[500]),
                        ],
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tables
            .map((t) => _TableTab(table: t, svc: _svc))
            .toList(),
      ),
    );
  }
}

// ── Table tab ─────────────────────────────────────────────────────────────────

class _TableTab extends StatefulWidget {
  final _TableDef table;
  final SupabaseService svc;

  const _TableTab({required this.table, required this.svc});

  @override
  State<_TableTab> createState() => _TableTabState();
}

class _TableTabState extends State<_TableTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client
          .from(widget.table.name)
          .select();
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showForm({Map<String, dynamic>? existing}) {
    showDialog(
      context: context,
      builder: (_) => _RowFormDialog(
        table: widget.table,
        existing: existing,
        onSave: (data) async {
          if (existing == null) {
            await widget.svc.adminInsert(widget.table.name, data);
          } else {
            await widget.svc.adminUpdate(
                widget.table.name,
                widget.table.pkCol,
                existing[widget.table.pkCol],
                data);
          }
          await _load();
        },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.svc.adminDelete(
          widget.table.name, widget.table.pkCol, row[widget.table.pkCol]);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_rows.length} records',
                  style: TextStyle(color: Colors.grey[600])),
              if (widget.table.readOnly) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    border: Border.all(color: Colors.amber[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.eye, size: 12, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text('View only',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber[700])),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (!widget.table.readOnly)
                ElevatedButton.icon(
                  onPressed: () => _showForm(),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(Colors.grey[100]),
                border: TableBorder.all(
                    color: Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(8)),
                columns: [
                  ...widget.table.cols.map((c) => DataColumn(
                      label: Text(c.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)))),
                  if (!widget.table.readOnly)
                    const DataColumn(
                        label: Text('Actions',
                            style:
                                TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: _rows.map((row) {
                  return DataRow(cells: [
                    ...widget.table.cols.map((c) {
                      final val = row[c.key];
                      String display = val?.toString() ?? '';
                      if (val is String &&
                          val.length > 10 &&
                          val.contains('T')) {
                        try {
                          display = DateFormat.yMMMd()
                              .format(DateTime.parse(val));
                        } catch (_) {}
                      }
                      return DataCell(Text(display,
                          overflow: TextOverflow.ellipsis));
                    }),
                    if (!widget.table.readOnly)
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(LucideIcons.pencil,
                                size: 16, color: Colors.indigo[600]),
                            onPressed: () => _showForm(existing: row),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                size: 16, color: Colors.red),
                            onPressed: () => _delete(row),
                            tooltip: 'Delete',
                          ),
                        ],
                      )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Row form dialog ───────────────────────────────────────────────────────────

class _RowFormDialog extends StatefulWidget {
  final _TableDef table;
  final Map<String, dynamic>? existing;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _RowFormDialog(
      {required this.table, this.existing, required this.onSave});

  @override
  State<_RowFormDialog> createState() => _RowFormDialogState();
}

class _RowFormDialogState extends State<_RowFormDialog> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final c in widget.table.cols)
        c.key: TextEditingController(
            text: widget.existing?[c.key]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{};
    for (final col in widget.table.cols) {
      final raw = _controllers[col.key]!.text.trim();
      if (raw.isEmpty) continue;
      if (col.isInt) {
        data[col.key] = int.tryParse(raw) ?? raw;
      } else if (col.isDouble) {
        data[col.key] = double.tryParse(raw) ?? raw;
      } else {
        data[col.key] = raw;
      }
    }
    try {
      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Record' : 'Add Record'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              ...widget.table.cols.map((col) {
                final isPkEdit = isEdit && col.isPk;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[col.key],
                    enabled: !isPkEdit,
                    keyboardType: col.isInt || col.isDouble
                        ? const TextInputType.numberWithOptions(
                            decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: col.label,
                      border: const OutlineInputBorder(),
                      filled: isPkEdit,
                      fillColor: isPkEdit ? Colors.grey[100] : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[600],
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Data definitions ──────────────────────────────────────────────────────────

class _TableDef {
  final String name;
  final String label;
  final String pkCol;
  final bool readOnly;
  final List<_Col> cols;

  const _TableDef(
      this.name, this.label, this.pkCol, this.readOnly, this.cols);
}

class _Col {
  final String key;
  final String label;
  final bool isInt;
  final bool isDouble;
  final bool isPk;

  const _Col(this.key, this.label,
      {this.isInt = false, this.isDouble = false, this.isPk = false});
}

// ── Add User Dialog ───────────────────────────────────────────────────────────

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  String _targetRole = 'customer';
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _salary = TextEditingController();
  final _hotelId = TextEditingController();
  String _staffRoleValue = 'Receptionist';
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone, _address, _salary, _hotelId]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _error = null; _success = null; });
    try {
     final body = <String, dynamic>{
        'email': _email.text.trim(),
        'password': _password.text,
        'targetRole': _targetRole,
      };

      // 1. Create a separate map specifically for the trigger data
      final metadata = <String, dynamic>{};

      if (_targetRole == 'customer') {
        metadata['name'] = _name.text.trim();
        metadata['phone'] = int.tryParse(_phone.text.trim()) ?? 0;
        metadata['address'] = _address.text.trim();
      } else {
        // staff or admin
        metadata['name'] = _name.text.trim();
        metadata['phone'] = int.tryParse(_phone.text.trim()) ?? 0;
        metadata['salary'] = double.tryParse(_salary.text.trim()) ?? 0;
        metadata['hotel_id'] = int.tryParse(_hotelId.text.trim()) ?? 0;
        metadata['staff_role'] = _targetRole == 'admin' ? 'Admin' : _staffRoleValue;
      }

      // 2. Attach the metadata object to the main body payload
      body['metadata'] = metadata;

      final token = await AuthService().getAccessToken();
      final client = AuthService().client;
      
      await client.functions.invoke(
        'create-user-admin',
        body: body,
        headers: {'Authorization': 'Bearer $token'},
      );

      setState(() { 
        _success = 'User created successfully!'; 
        _saving = false; 
      });
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaffLike = _targetRole == 'staff' || _targetRole == 'admin';
    return AlertDialog(
      title: const Text('Add User'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_success!, style: const TextStyle(color: Colors.green)),
                ),
              DropdownButtonFormField<String>(
                value: _targetRole,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _targetRole = v!),
              ),
              const SizedBox(height: 12),
              _field(_email, 'Email'),
              _field(_password, 'Password', obscure: true),
              _field(_name, 'Name'),
              _field(_phone, 'Phone'),
              if (_targetRole == 'customer') _field(_address, 'Address'),
              if (isStaffLike) ...[
                _field(_salary, 'Salary', numeric: true),
                _field(_hotelId, 'Hotel ID', numeric: true),
                if (_targetRole == 'staff')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _staffRoleValue,
                      decoration: const InputDecoration(labelText: 'Staff Role', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'Receptionist', child: Text('Receptionist')),
                        DropdownMenuItem(value: 'Auxiliary', child: Text('Auxiliary')),
                      ],
                      onChanged: (v) => setState(() => _staffRoleValue = v!),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _saving || _success != null ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[600],
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool obscure = false, bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
