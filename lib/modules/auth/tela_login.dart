import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/tela_home.dart'; // Vamos criar essa em breve, vai dar erro por 1 minuto

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  // Controladores para ler o que o usuário digita
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  
  bool _ehCadastro = false; // Alterna entre "Entrar" e "Criar Conta"
  bool _loading = false;

  // FUNÇÃO: Falar com o Firebase Auth
  Future<void> _autenticar() async {
    setState(() => _loading = true);
    
    try {
      if (_ehCadastro) {
        // CRIAR CONTA NOVA
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      } else {
        // FAZER LOGIN
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );
      }
      
      // Se deu certo, o main.dart vai perceber e mudar de tela sozinho
    } on FirebaseAuthException catch (e) {
      String mensagem = "Erro desconhecido";
      if (e.code == 'user-not-found') mensagem = "E-mail não cadastrado.";
      if (e.code == 'wrong-password') mensagem = "Senha incorreta.";
      if (e.code == 'email-already-in-use') mensagem = "Este e-mail já existe.";
      if (e.code == 'weak-password') mensagem = "A senha é muito fraca (mínimo 6 dígitos).";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
              const SizedBox(height: 20),
              Text(
                _ehCadastro ? 'Criar Conta' : 'Bem-vindo de volta',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              
              // CAMPO DE EMAIL
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // CAMPO DE SENHA
              TextField(
                controller: _senhaController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              // BOTÃO PRINCIPAL
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _autenticar,
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_ehCadastro ? 'CADASTRAR' : 'ENTRAR'),
                ),
              ),
              
              // BOTÃO DE TROCAR MODO
              TextButton(
                onPressed: () {
                  setState(() => _ehCadastro = !_ehCadastro);
                },
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
    );
  }
}