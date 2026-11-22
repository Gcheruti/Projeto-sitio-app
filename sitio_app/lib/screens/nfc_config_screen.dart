import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../services/dispositivo_service.dart';
import '../services/nfc_service.dart';

class NfcConfigScreen extends StatefulWidget {
  const NfcConfigScreen({super.key});

  @override
  State<NfcConfigScreen> createState() => _NfcConfigScreenState();
}

class _NfcConfigScreenState extends State<NfcConfigScreen>
    with WidgetsBindingObserver {
  final _codigoCtrl = TextEditingController();
  String? _status;
  EstadoNfc? _estado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
  }

  Future<void> _verificar() async {
    final e = await DispositivoService.estadoNfc();
    if (mounted) setState(() => _estado = e);
  }

  /// Ao voltar das configurações do Android, confere de novo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<bool> _pedirSenha() async {
    final senhaCtrl = TextEditingController();
    var erro = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Senha'),
              content: TextField(
                controller: senhaCtrl,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Sua senha (do login atual)',
                  border: const OutlineInputBorder(),
                  errorText: erro ? 'Senha incorreta' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!await authState.senhaConfere(senhaCtrl.text)) {
                      setLocal(() => erro = true);
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
    return ok == true;
  }

  void _msg(String t) {
    setState(() => _status = t);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _ler() async {
    if (kIsWeb || !NfcService.isAndroid) {
      _msg('NFC só no app Android');
      return;
    }
    setState(() => _status = 'Aproxime a tag para ler…');
    await NfcService.lerUmaVez(
      onTexto: (t) {
        _codigoCtrl.text = t;
        _msg('Lido: $t');
      },
      onErro: _msg,
    );
  }

  Future<void> _gravar() async {
    if (kIsWeb || !NfcService.isAndroid) {
      _msg('NFC só no app Android');
      return;
    }
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      _msg('Digite o código a gravar');
      return;
    }
    if (!await _pedirSenha()) return;
    setState(() => _status = 'Aproxime a tag para gravar…');
    await NfcService.gravarTexto(
      texto: codigo,
      onOk: () => _msg('Tag gravada: $codigo'),
      onErro: _msg,
    );
  }

  Future<void> _limpar() async {
    if (kIsWeb || !NfcService.isAndroid) {
      _msg('NFC só no app Android');
      return;
    }
    if (!await _pedirSenha()) return;
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar tag?'),
        content: const Text('O conteúdo NDEF será sobrescrito.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (conf != true) return;
    setState(() => _status = 'Aproxime a tag para limpar…');
    await NfcService.limparTag(
      onOk: () => _msg('Tag limpa'),
      onErro: _msg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_estado != null)
            Card(
              child: ListTile(
                leading: Icon(_estado == EstadoNfc.ligado
                    ? Icons.check_circle_outline
                    : (_estado == EstadoNfc.desligado
                        ? Icons.nfc
                        : Icons.info_outline)),
                title: Text(DispositivoService.mensagemNfc(_estado!)),
                trailing: _estado == EstadoNfc.desligado
                    ? TextButton(
                        onPressed: DispositivoService.abrirConfigNfc,
                        child: const Text('Ligar NFC'),
                      )
                    : null,
              ),
            ),
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código / payload',
              hintText: 'Ex: SITIO:001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _ler,
            icon: const Icon(Icons.nfc),
            label: const Text('Ler tag'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _gravar,
            icon: const Icon(Icons.edit),
            label: const Text('Gravar código na tag'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _limpar,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Limpar tag'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 24),
            Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}