import 'package:flutter/material.dart';

import '../../../data/services/drive_service.dart';

const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kRed     = Color(0xFFF44336);

class DrivePickerScreen extends StatefulWidget {
  const DrivePickerScreen({super.key});

  @override
  State<DrivePickerScreen> createState() => _DrivePickerScreenState();
}

class _DrivePickerScreenState extends State<DrivePickerScreen> {
  final _drive          = DriveService();
  final _searchCtrl     = TextEditingController();

  bool             _signing  = false;
  bool             _loading  = false;
  bool             _downloading = false;
  bool             _signedIn = false;
  String?          _userName;
  List<DriveFile>  _files    = [];
  String?          _error;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (await _drive.isSignedIn) {
      setState(() => _signedIn = true);
      _loadFiles();
    }
  }

  Future<void> _signIn() async {
    setState(() { _signing = true; _error = null; });
    try {
      final account = await _drive.signIn();
      if (account == null) {
        setState(() { _signing = false; _error = 'Login cancelado.'; });
        return;
      }
      setState(() {
        _signedIn = true;
        _signing  = false;
        _userName = account.displayName ?? account.email;
      });
      await _loadFiles();
    } catch (e) {
      setState(() { _signing = false; _error = 'Erro ao conectar: $e'; });
    }
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    setState(() { _signedIn = false; _files = []; _userName = null; });
  }

  Future<void> _loadFiles({String search = ''}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final files = await _drive.listFiles(search: search);
      setState(() { _files = files; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Erro ao carregar: $e'; });
    }
  }

  Future<void> _pick(DriveFile file) async {
    setState(() => _downloading = true);
    try {
      final content = await _drive.downloadContent(file);
      if (mounted) {
        Navigator.of(context)
            .pop({'name': file.name, 'content': content});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar: $e'),
            backgroundColor: _kRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: _kBg,
            foregroundColor: Colors.white,
            title: const Text(
              'Importar do Google Drive',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_signedIn)
                TextButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white54),
                  label: const Text('Sair', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ),
          body: _signedIn ? _fileList() : _loginView(),
        ),
        if (_downloading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                color: Color(0xFF1A1A2E),
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _kPrimary),
                      SizedBox(height: 16),
                      Text('Baixando arquivo…',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _loginView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPrimary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_to_drive_rounded,
                      color: _kPrimary, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Conectar Google Drive',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Importe PDFs, Google Docs e documentos de texto diretamente para o Cofre de Conhecimento.',
                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: _kRed, fontSize: 12)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signing ? null : _signIn,
                      icon: _signing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_signing ? 'Conectando…' : 'Entrar com Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileList() {
    return Column(
      children: [
        // User info + search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              if (_userName != null)
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Conectado como $_userName',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar arquivo no Drive…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white38),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadFiles();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _kCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (v) => _loadFiles(search: v.trim()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // File list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: _kRed, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(color: Colors.white54),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadFiles,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : _files.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum arquivo encontrado.\nSão suportados: Google Docs, PDF, DOCX e TXT.',
                            style: TextStyle(color: Colors.white38, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _FileTile(
                            file: _files[i],
                            onTap: () => _pick(_files[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onTap});
  final DriveFile  file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Icon(file.icon, color: _kPrimary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file.typeLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
