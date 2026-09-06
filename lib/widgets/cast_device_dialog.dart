import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/models/cast_device.dart';
import 'package:moumou/services/cast/cast_service.dart';
import 'package:moumou/services/cast/lan_media_server.dart';
import 'package:moumou/utils/app_dialog.dart';

/// 投屏设备选择弹窗：进入即开始 SSDP 发现，列出局域网内的渲染器
/// （电视/盒子），点选即暴露本地文件并推流（仅推流，不做遥控）。
///
/// 关闭弹窗只停止发现；投屏成功后 LAN 服务器保持运行供电视拉流，
/// 由播放页退出时统一释放（见 player_page.dispose）。
Future<void> showCastDeviceDialog(
  BuildContext context, {
  required String path,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => CastDeviceDialog(path: path),
  );
}

class CastDeviceDialog extends StatefulWidget {
  final String path;

  const CastDeviceDialog({super.key, required this.path});

  @override
  State<CastDeviceDialog> createState() => _CastDeviceDialogState();
}

class _CastDeviceDialogState extends State<CastDeviceDialog> {
  List<CastDevice> _devices = const [];
  bool _searching = true;
  String? _error;
  StreamSubscription<List<CastDevice>>? _sub;
  CastDevice? _casting;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    CastService.instance.stopDiscovery();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final stream = await CastService.instance.startDiscovery();
      _sub = stream.listen(_onDevices);
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _error = '投屏搜索启动失败：$e';
        });
      }
    }
  }

  void _onDevices(List<CastDevice> list) {
    if (!mounted) return;
    setState(() {
      _devices = list;
      _searching = false;
    });
  }

  Future<void> _cast(CastDevice device) async {
    if (_casting != null) return;
    setState(() => _casting = device);
    try {
      final url = await CastService.instance.resolveUrl(widget.path);
      if (url == null) {
        _toast('暂不支持投屏该来源');
        return;
      }
      await CastService.instance.pushToDevice(device, url);
      if (!mounted) return;
      _toast('已投屏到 ${device.friendlyName}');
      Navigator.of(context).pop();
    } catch (e) {
      // 投屏失败：释放刚启动的服务器端口（无人拉流）
      await LanMediaServer.instance.stop();
      if (mounted) _toast('投屏失败：$e');
    } finally {
      if (mounted) setState(() => _casting = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cast, size: 22),
          SizedBox(width: 8),
          Text('投屏'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_searching && _devices.isEmpty && _error == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在搜索投屏设备…',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      );
    }

    if (_devices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          '未发现可投屏设备，请确认手机与电视连接同一 WiFi 后重试。',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _devices.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final device = _devices[index];
          final busy = _casting?.id == device.id;
          return ListTile(
            leading: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cast_connected),
            title: Text(device.friendlyName),
            subtitle: Text(device.kind),
            onTap: busy ? null : () => _cast(device),
          );
        },
      ),
    );
  }
}
