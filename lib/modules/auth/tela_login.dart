import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _ehCadastro = false;
  bool _loading = false;
  bool _verSenha = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _autenticar() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text.trim();

      if (_ehCadastro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
      }
      // Se deu certo: o AuthGate (main.dart) troca pra Home automaticamente.
    } on FirebaseAuthException catch (e) {
      String mensagem = "Erro desconhecido";

      if (e.code == 'user-not-found') mensagem = "E-mail não cadastrado.";
      if (e.code == 'wrong-password') mensagem = "Senha incorreta.";
      if (e.code == 'invalid-email') mensagem = "E-mail inválido.";
      if (e.code == 'email-already-in-use') mensagem = "Este e-mail já existe.";
      if (e.code == 'weak-password')
        mensagem = "Senha fraca (mínimo 6 caracteres).";
      if (e.code == 'network-request-failed')
        mensagem = "Sem internet / falha de rede.";

      _snack(mensagem);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 20),
                  Text(
                    _ehCadastro ? 'Criar Conta' : 'Bem-vindo de volta',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // EMAIL
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Informe o e-mail.';
                      if (!t.contains('@')) return 'E-mail parece inválido.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // SENHA
                  TextFormField(
                    controller: _senhaController,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _verSenha = !_verSenha),
                        icon: Icon(_verSenha
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                    ),
                    obscureText: !_verSenha,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Informe a senha.';
                      if (_ehCadastro && t.length < 6)
                        return 'Mínimo 6 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // BOTÃO
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _autenticar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_ehCadastro ? 'CADASTRAR' : 'ENTRAR'),
                    ),
                  ),

                  // TROCAR MODO
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _ehCadastro = !_ehCadastro),
                    child: Text(
                      _ehCadastro
                          ? 'Já tem conta? Fazer Login'
                          : 'Não tem conta? Criar Cadastro',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
