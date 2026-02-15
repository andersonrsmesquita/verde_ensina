import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/repositories/user_profile_repository.dart';
import '../../core/ui/app_ui.dart';

/// ✅ Mantém compatibilidade com o GoRouter (antes apontava pra LoginPage)
/// Agora o wrapper mora no MESMO arquivo do TelaLogin.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const TelaLogin();
}

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _ehCadastro = false;
  bool _loading = false;
  bool _verSenha = false;

  final _profileRepo = UserProfileRepository();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    if (_loading) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final senha = _senhaCtrl.text.trim();

      UserCredential cred;

      if (_ehCadastro) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
      }

      final user = cred.user;
      if (user != null) {
        await _profileRepo.ensureFromAuthUser(user);
      }

      // ✅ NÃO navega aqui.
      // O GoRouter redirect decide:
      // - sem tenant => /tenant
      // - com tenant => /home
    } on FirebaseAuthException catch (e) {
      var msg = 'Erro ao autenticar';

      switch (e.code) {
        case 'user-not-found':
          msg = 'E-mail não cadastrado.';
          break;
        case 'wrong-password':
          msg = 'Senha incorreta.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        case 'email-already-in-use':
          msg = 'Este e-mail já está em uso.';
          break;
        case 'weak-password':
          msg = 'Senha fraca (mínimo 6 caracteres).';
          break;
        case 'network-request-failed':
          msg = 'Sem internet / falha de rede.';
          break;
      }

      AppMessenger.error(msg);
    } catch (e) {
      AppMessenger.error('Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      title: _ehCadastro ? 'Criar conta' : 'Entrar',
      centered: true,
      maxWidth: 520,
      body: SectionCard(
        title: _ehCadastro ? 'Cadastro' : 'Login',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.eco, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _ehCadastro
                          ? 'Crie sua conta pra começar.'
                          : 'Acesse sua conta pra continuar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'seuemail@dominio.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                enabled: !_loading,
                validator: AppValidators.compose([
                  AppValidators.required('Informe o e-mail.'),
                  AppValidators.email('E-mail inválido.'),
                ]),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _senhaCtrl,
                label: 'Senha',
                hint: _ehCadastro ? 'mínimo 6 caracteres' : 'sua senha',
                obscureText: !_verSenha,
                prefixIcon: Icons.lock_outline,
                enabled: !_loading,
                suffix: IconButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _verSenha = !_verSenha),
                  icon:
                      Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Informe a senha.';
                  if (_ehCadastro && t.length < 6)
                    return 'Mínimo 6 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AppButtons.primary(
                onPressed: _loading ? null : _autenticar,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(_ehCadastro ? 'CADASTRAR' : 'ENTRAR'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppButtons.text(
                onPressed: _loading
                    ? null
                    : () => setState(() => _ehCadastro = !_ehCadastro),
                child: Text(
                  _ehCadastro
                      ? 'Já tem conta? Fazer login'
                      : 'Não tem conta? Criar cadastro',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
