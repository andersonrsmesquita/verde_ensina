// FILE: lib/modules/configuracoes/tela_perfil.dart
import 'package:flutter/material.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/models/app_user_model.dart'; // Importe o modelo se necessário

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _salvando = false;
  bool _dadosCarregados = false; // Trava para não carregar toda hora

  @override
  void initState() {
    super.initState();
    // ❌ Removemos a lógica daqui para evitar o erro de dependOnInheritedWidget
  }

  // ✅ CORREÇÃO: Este método roda assim que o contexto está disponível
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Só carrega na primeira vez (para não apagar o que você estiver digitando se a tela atualizar)
    if (!_dadosCarregados) {
      final session = SessionScope.of(context).session;

      if (session != null && session.user != null) {
        // Usa o displayName ou cai para o nome se houver
        _nomeController.text = session.user!.displayName;
        _emailController.text = session.user!.email;
      }
      _dadosCarregados = true;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Pega o controller da sessão
    final sessionController = SessionScope.of(context);
    final user = sessionController.session?.user;

    if (user == null) return;

    setState(() => _salvando = true);

    try {
      final repo = UserRepository();

      // 1. Salva no Banco de Dados
      await repo.updateProfile(
          uid: user.uid, nome: _nomeController.text.trim());

      // 2. Atualiza a Sessão Local (para refletir na hora na Home)
      // Cria uma cópia do usuário com o novo nome
      final novoUser = user.copyWith(displayName: _nomeController.text.trim());

      // Chama o método que criamos no session_scope.dart
      sessionController.updateUser(novoUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context); // Volta para a Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao atualizar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar (Placeholder)
              CircleAvatar(
                radius: 50,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  _nomeController.text.isNotEmpty
                      ? _nomeController.text[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                      fontSize: 40,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // Campo Email (Leitura apenas)
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // Campo Nome (Editável)
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe seu nome' : null,
              ),

              const SizedBox(height: 32),

              // Botão Salvar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: AppButtons.elevatedIcon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_salvando ? "SALVANDO..." : "SALVAR ALTERAÇÕES"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
