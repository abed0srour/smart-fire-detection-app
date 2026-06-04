import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/models/room_overview.dart';
import 'package:smart_fire_detection_app/src/data/models/sensor_data.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_service.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  BackendService? _backend;
  Stream<List<RoomOverview>>? _roomsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backend = context.read<BackendService>();
    if (_backend == backend) {
      return;
    }

    _backend = backend;
    _roomsStream = backend.watchRoomOverviews();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<BackendService>();
    final stream = _roomsStream ?? backend.watchRoomOverviews();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('Rooms'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add room',
            icon: const Icon(Icons.add_home_work_outlined),
            onPressed: () => _showCreateRoomDialog(backend),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ROOM'),
        onPressed: () => _showCreateRoomDialog(backend),
      ),
      body: StreamBuilder<List<RoomOverview>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _buildStateMessage(
              icon: Icons.cloud_off,
              title: 'Rooms unavailable',
              subtitle: 'Check backend connection and API status.',
            );
          }

          final rooms = snapshot.data ?? const <RoomOverview>[];
          if (rooms.isEmpty) {
            return _buildStateMessage(
              icon: Icons.meeting_room_outlined,
              title: 'No rooms yet',
              subtitle: 'Create the first monitoring room.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async => _reloadRooms(backend),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              itemCount: rooms.length,
              itemBuilder: (context, index) =>
                  _buildRoomCard(backend, rooms[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reloadRooms(BackendService backend) async {
    setState(() {
      _roomsStream = backend.watchRoomOverviews();
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 76, color: AppColors.textMuted),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(BackendService backend, RoomOverview room) {
    final reading = room.currentReading;
    final color = _riskColor(room.riskLevel);
    final onlineDevices = room.devices
        .where((device) => device.isOnline)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.meeting_room, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.location.isEmpty ? 'No location' : room.location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildRiskBadge(room.riskLevel),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Manage room',
                icon: const Icon(Icons.tune, color: AppColors.textMuted),
                onPressed: () => _showManageRoomDialog(backend, room),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRoomSummary(room, onlineDevices),
          const SizedBox(height: 12),
          _buildManageRoomButton(backend, room),
          const SizedBox(height: 16),
          if (reading == null)
            _buildNoReadingPanel(room)
          else ...[
            _buildMetricsGrid(reading),
            const SizedBox(height: 14),
            _buildReadingFooter(reading),
          ],
        ],
      ),
    );
  }

  Widget _buildManageRoomButton(BackendService backend, RoomOverview room) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showManageRoomDialog(backend, room),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.tune, size: 18),
        label: const Text(
          'MANAGE ROOM',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildRoomSummary(RoomOverview room, int onlineDevices) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryChip(
            icon: Icons.sensors,
            color: AppColors.info,
            value: '${room.devices.length}',
            label: room.devices.length == 1 ? 'Device' : 'Devices',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryChip(
            icon: Icons.wifi,
            color: onlineDevices == 0 ? AppColors.danger : AppColors.success,
            value: '$onlineDevices',
            label: 'Online',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReadingPanel(RoomOverview room) {
    final deviceCodes = room.devices
        .map((device) => device.deviceCode)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Waiting for sensor data',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (deviceCodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: deviceCodes.map(_buildDeviceCodeChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceCodeChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(SensorData reading) {
    final metrics = [
      _RoomMetric(
        icon: Icons.thermostat,
        label: 'Temp',
        value: reading.temperature.toStringAsFixed(1),
        unit: '\u00B0C',
        color: AppColors.info,
      ),
      _RoomMetric(
        icon: Icons.cloud,
        label: 'Smoke',
        value: reading.smokeLevel.toStringAsFixed(1),
        unit: 'ppm',
        color: AppColors.textSecondary,
      ),
      _RoomMetric(
        icon: Icons.opacity,
        label: 'Humidity',
        value: reading.humidity.toStringAsFixed(1),
        unit: '%',
        color: Colors.cyanAccent,
      ),
      _RoomMetric(
        icon: Icons.science,
        label: 'CO2',
        value: reading.coLevel.toStringAsFixed(1),
        unit: 'ppm',
        color: const Color(0xFFA78BFA),
      ),
      _RoomMetric(
        icon: Icons.light_mode,
        label: 'Light',
        value: reading.lightLevel.toStringAsFixed(0),
        unit: 'lux',
        color: AppColors.warning,
      ),
      _RoomMetric(
        icon: Icons.local_fire_department,
        label: 'Flame',
        value: reading.flameDetected ? 'YES' : 'NO',
        unit: ' ${reading.flameLevel.toStringAsFixed(0)}',
        color: reading.flameDetected ? AppColors.danger : AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 540 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.35 : 1.55,
          ),
          itemBuilder: (context, index) => _buildMetricTile(metrics[index]),
        );
      },
    );
  }

  Widget _buildMetricTile(_RoomMetric metric) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: metric.color.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, color: metric.color, size: 20),
          const SizedBox(height: 8),
          Text(
            metric.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: metric.value,
                children: [
                  TextSpan(
                    text: metric.unit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                color: metric.color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingFooter(SensorData reading) {
    return Row(
      children: [
        Expanded(
          child: _buildFooterItem(
            icon: reading.isConnected ? Icons.wifi : Icons.wifi_off,
            label: reading.isConnected ? 'Online' : 'Offline',
            color: reading.isConnected ? AppColors.success : AppColors.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFooterItem(
            icon: Icons.battery_full,
            label: '${reading.batteryLevel.toStringAsFixed(0)}%',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFooterItem(
            icon: Icons.update,
            label: _formatLastUpdated(reading.lastUpdated),
            color: AppColors.info,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(RiskLevel riskLevel) {
    final color = _riskColor(riskLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        riskLevel.displayLabel,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _riskColor(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return Colors.deepOrange;
      case RiskLevel.fire:
        return AppColors.danger;
    }
  }

  String _formatLastUpdated(DateTime lastUpdated) {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 60) {
      return 'Now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    return '${diff.inDays}d';
  }

  Future<void> _showCreateRoomDialog(BackendService backend) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final deviceCodeController = TextEditingController();
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: const Text(
                'Create Room',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorMessage != null) ...[
                        _buildDialogError(errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: nameController,
                        enabled: !isSaving,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Room name',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        enabled: !isSaving,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deviceCodeController,
                        enabled: !isSaving,
                        style: const TextStyle(color: AppColors.textPrimary),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Device code',
                          prefixIcon: Icon(Icons.sensors_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final form = formKey.currentState;
                          if (form == null || !form.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            await backend.createRoom(
                              name: nameController.text,
                              location: locationController.text,
                              deviceCode: deviceCodeController.text,
                            );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext);
                            await _reloadRooms(backend);
                            if (!mounted) {
                              return;
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: const Text('Room created'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (error) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = error.toString();
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(isSaving ? 'CREATING' : 'CREATE'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
    deviceCodeController.dispose();
  }

  Future<void> _showManageRoomDialog(
    BackendService backend,
    RoomOverview room,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: room.name);
    final locationController = TextEditingController(text: room.location);
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Manage Room',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete room',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final shouldDelete = await _confirmDeleteRoom(
                              dialogContext,
                              room.name,
                            );
                            if (!shouldDelete) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                              errorMessage = null;
                            });

                            try {
                              await backend.deleteRoom(room.id);
                              if (!dialogContext.mounted) {
                                return;
                              }
                              Navigator.pop(dialogContext);
                              await _reloadRooms(backend);
                              if (!mounted) {
                                return;
                              }
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Room deleted'),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            } catch (error) {
                              setDialogState(() {
                                isSaving = false;
                                errorMessage = error.toString();
                              });
                            }
                          },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        _buildDialogError(errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: nameController,
                        enabled: !isSaving,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Room name',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        enabled: !isSaving,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Devices',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (room.devices.isEmpty)
                        _buildDeviceEmptyState()
                      else
                        ...room.devices.map(_buildManageDeviceRow),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final form = formKey.currentState;
                          if (form == null || !form.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            await backend.updateRoom(
                              roomId: room.id,
                              name: nameController.text,
                              location: locationController.text,
                            );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.pop(dialogContext);
                            await _reloadRooms(backend);
                            if (!mounted) {
                              return;
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: const Text('Room updated'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (error) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = error.toString();
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'SAVING' : 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
  }

  Future<bool> _confirmDeleteRoom(BuildContext context, String roomName) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: const Text(
              'Delete Room',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Delete "$roomName" and its device readings?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildDeviceEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No devices attached',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }

  Widget _buildManageDeviceRow(RoomDevice device) {
    final statusColor = device.isOnline ? AppColors.success : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.sensors, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            device.isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _RoomMetric {
  const _RoomMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
}
