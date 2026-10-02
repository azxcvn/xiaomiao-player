import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/network/network_client_factory.dart';
import 'package:moumou/services/network/network_connection_settings.dart';

/// 网络存储账户编辑页：新增 / 编辑 WebDAV、SMB、FTP 账户。
///
/// 布局对齐小喵：端口 + 路径同排、账号 + 密码同排（匿名时隐藏）、
/// 预构建链接实时预览、测试连接及结果反馈。
///
/// [connection] 为 null 时视为新增，否则为编辑（保留原 id）。
class AccountEditPage extends StatefulWidget {
  final NetworkConnection? connection;

  const AccountEditPage({super.key, this.connection});

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _path;

  late NetworkProtocol _protocol;
  late bool _isAnonymous;
  late bool _useHttps;

  bool _portTouched = false;
  bool _saving = false;

  bool _passwordVisible = false;
  bool _testing = false;
  bool _testSuccess = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _protocol = c?.protocol ?? NetworkProtocol.webdav;
    _name = TextEditingController(text: c?.name ?? '');
    _host = TextEditingController(text: c?.host ?? '');
    _useHttps = c?.useHttps ?? false;
    _port = TextEditingController(
      text: (c?.port ?? _protocol.defaultPortFor(useHttps: _useHttps)).toString(),
    );
    _username = TextEditingController(text: c?.username ?? '');
    _password = TextEditingController(text: c?.password ?? '');
    _path = TextEditingController(text: c?.path ?? '/');
    _isAnonymous = c?.isAnonymous ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _path.dispose();
    super.dispose();
  }

  void _onProtocolChanged(NetworkProtocol? p) {
    if (p == null) return;
    setState(() {
      // 端口跟随协议：用户没手改过端口时，从旧协议的默认端口换成新协议的
      // （手改过的端口（如群晖 5005/5006）一律保留）。
      _port.text = resolvePortOnChange(
        currentText: _port.text,
        previousProtocol: _protocol,
        previousHttps: _useHttps,
        nextProtocol: p,
        nextHttps: _useHttps,
        touched: _portTouched,
      );
      _protocol = p;
      // 协议切换即失效上一次测试结果，避免误导
      _testResult = null;
    });
  }

  void _onHttpsChanged(bool value) {
    setState(() {
      // 与协议切换同一条规矩：http 的默认 80 ↔ https 的默认 443 自动跟随，
      // 手改过的端口不动（否则勾了 HTTPS 还停在 80，是本次要修的 bug）。
      _port.text = resolvePortOnChange(
        currentText: _port.text,
        previousProtocol: _protocol,
        previousHttps: _useHttps,
        nextProtocol: _protocol,
        nextHttps: value,
        touched: _portTouched,
      );
      _useHttps = value;
      _testResult = null;
    });
  }

  /// 预构建链接预览（对齐小喵 buildServerUrl）：按协议拼出服务器地址。
  String _buildServerUrl() {
    final host = _host.text.trim();
    if (host.isEmpty) return '';
    final scheme = switch (_protocol) {
      NetworkProtocol.webdav => _useHttps ? 'https' : 'http',
      NetworkProtocol.ftp => 'ftp',
      NetworkProtocol.smb => 'smb',
    };
    // IPv6 字面量需加方括号；IPv4/域名直接拼
    final hostPart = host.contains(':') && !host.startsWith('[')
        ? '[$host]'
        : host;
    final port = _port.text.trim();
    return '$scheme://$hostPart'
        '${port.isNotEmpty ? ':$port' : ''}'
        '${_normalizePath(_path.text)}';
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testResult = l10n.networkHostInputRequired;
      });
      return;
    }
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() {
        _testSuccess = false;
        _testResult = l10n.networkPortInvalid;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = false;
    });

    final client = createNetworkClient(NetworkConnection(
      name: 'test',
      protocol: _protocol,
      host: host,
      port: port,
      username: _isAnonymous ? '' : _username.text,
      password: _isAnonymous ? '' : _password.text,
      path: _normalizePath(_path.text),
      isAnonymous: _isAnonymous,
      useHttps: _useHttps,
    ));

    try {
      await client.connect();
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _testResult = l10n.commonConnectOk;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testResult = e is NetworkClientException
            ? e.message
            : l10n.commonConnectFailed('$e');
      });
    } finally {
      try {
        await client.disconnect();
      } catch (_) {
        // 忽略断开异常。
      }
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final connection = NetworkConnection(
      id: widget.connection?.id ?? 0,
      name: _name.text.trim(),
      protocol: _protocol,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? _protocol.defaultPort,
      username: _username.text,
      password: _password.text,
      path: _normalizePath(_path.text),
      isAnonymous: _isAnonymous,
      useHttps: _useHttps,
    );

    final settings = NetworkConnectionSettings.instance;
    if (widget.connection == null) {
      await settings.add(connection);
    } else {
      await settings.update(connection);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  static String _normalizePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '/';
    if (!trimmed.startsWith('/')) return '/$trimmed';
    return trimmed;
  }

  /// 端口输入框的占位提示：给「默认端口 + NAS 常用端口」，减少瞎试。
  String _defaultPortHint() {
    final l10n = AppLocalizations.of(context);
    final def = _protocol.defaultPortFor(useHttps: _useHttps);
    if (_protocol == NetworkProtocol.webdav) {
      return l10n.networkDefaultPortWithSynology('$def');
    }
    return l10n.networkDefaultPort('$def');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.connection != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? l10n.networkEditAccount : l10n.networkAddAccount,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.networkDisplayName,
                hintText: l10n.networkDisplayNameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.networkNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NetworkProtocol>(
              initialValue: _protocol,
              decoration: InputDecoration(
                labelText: l10n.networkProtocolLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final p in NetworkProtocol.values)
                  DropdownMenuItem(
                    value: p,
                    child: Row(
                      children: [
                        Icon(
                          _protocolIcon(p),
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(p.displayName),
                      ],
                    ),
                  ),
              ],
              onChanged: _onProtocolChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _host,
              decoration: InputDecoration(
                labelText: l10n.networkHostLabel,
                hintText: l10n.networkHostHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.networkHostRequiredInput
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _port,
                    decoration: InputDecoration(
                      labelText: l10n.networkPortLabel,
                      hintText: _defaultPortHint(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      _portTouched = true;
                      setState(() {});
                    },
                    validator: (v) {
                      final port = int.tryParse(v ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return '1-65535';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _path,
                    decoration: InputDecoration(
                      labelText: l10n.commonPath,
                      hintText: l10n.networkPathDefaultHint,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            // 预构建链接实时预览（对齐小喵：主机非空即显示）
            if (_host.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _buildServerUrl(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.networkAnonymous),
              subtitle: Text(l10n.networkAnonymousDesc),
              value: _isAnonymous,
              onChanged: (v) {
                setState(() => _isAnonymous = v);
              },
            ),
            if (_protocol == NetworkProtocol.webdav)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.networkUseHttps),
                subtitle: Text(l10n.networkUseHttpsDesc),
                value: _useHttps,
                onChanged: _onHttpsChanged,
              ),
            // 账号密码（匿名时隐藏，对齐小喵）
            if (!_isAnonymous) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _username,
                      decoration: InputDecoration(
                        labelText: l10n.networkUsername,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: l10n.networkPassword,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? l10n.networkHidePassword
                              : l10n.networkShowPassword,
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      obscureText: !_passwordVisible,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            // 测试连接 + 结果反馈
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi),
              label: Text(
                _testing ? l10n.commonTesting : l10n.commonTestConnection,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: _testSuccess ? const Color(0xFF4CAF50) : scheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _testSuccess
                              ? const Color(0xFF4CAF50)
                              : scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? l10n.commonSaving : l10n.commonSave),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _protocolIcon(NetworkProtocol p) => switch (p) {
        NetworkProtocol.webdav => Icons.cloud_outlined,
        NetworkProtocol.smb => Icons.folder_shared_outlined,
        NetworkProtocol.ftp => Icons.file_upload_outlined,
      };
}