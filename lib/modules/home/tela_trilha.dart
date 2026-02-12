import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports das telas
import '../canteiros/tela_canteiros.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart';
import '../adubacao/tela_adubacao_organo15.dart';

class TelaTrilha extends StatefulWidget {
  const TelaTrilha({super.key});

  @override
  State<TelaTrilha> createState() => _TelaTrilhaState();
}

class _TelaTrilhaState extends State<TelaTrilha> {
  User? get _user => FirebaseAuth.instance.currentUser;

  String _formatarArea(dynamic valor) {
    if (valor == null) return '-';
    if (valor is int) return valor.toString();
    if (valor is double) {
      final isInteiro = valor == valor.roundToDouble();
      return isInteiro ? valor.toInt().toString() : valor.toStringAsFixed(2);
    }
    if (valor is num) return valor.toString();
    return valor.toString();
  }

  void _navegarParaAcao(
    BuildContext pageContext,
    String acao,
    String canteiroId,
  ) {
    if (acao == 'diagnostico') {
      Navigator.of(pageContext).push(
        MaterialPageRoute(
          builder: (_) => TelaDiagnostico(canteiroIdOrigem: canteiroId),
        ),
      );
      return;
    }

    if (acao == 'calagem') {
      Navigator.of(pageContext).push(
        MaterialPageRoute(
          builder: (_) => TelaCalagem(canteiroIdOrigem: canteiroId),
        ),
      );
      return;
    }
  }

  void _iniciarAcaoComCanteiro(BuildContext pageContext, String acao) {
    final user = _user;

    if (user == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para continuar.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.60,
          minChildSize: 0.35,
          maxChildSize: 0.90,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.place, color: Colors.green),
                        SizedBox(width: 10),
                        Text(
                          'Selecionar Local',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Onde você vai realizar esta ação?',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('canteiros')
                            .where('uid_usuario', isEqualTo: user.uid)
                            .where('ativo', isEqualTo: true)
                            .snapshots(),
                        builder: (sbContext, snapshot) {
                          if (snapshot.hasError) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: const Text(
                                'Deu erro ao carregar seus locais. Tenta de novo em instantes.',
                                style: TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          if (docs.isEmpty) {
                            return ListView(
                              controller: controller,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber,
                                        color: Colors.orange,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Nenhum local ativo encontrado.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Cadastre um canteiro/vaso pra continuar.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(sheetContext);
                                            Navigator.of(pageContext).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TelaCanteiros(),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text(
                                            'Cadastrar Novo Local',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            );
                          }

                          final ordenados = [...docs]
                            ..sort((a, b) {
                              final ma =
                                  (a.data() as Map<String, dynamic>?) ?? {};
                              final mb =
                                  (b.data() as Map<String, dynamic>?) ?? {};
                              final na = (ma['nome'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final nb = (mb['nome'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return na.compareTo(nb);
                            });

                          return ListView.separated(
                            controller: controller,
                            itemCount: ordenados.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx2, index) {
                              final doc = ordenados[index];
                              final dados =
                                  (doc.data() as Map<String, dynamic>?) ?? {};
                              final nome = (dados['nome'] ?? 'Sem nome')
                                  .toString();
                              final area = _formatarArea(dados['area_m2']);

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.grid_on,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  area == '-'
                                      ? 'Área não informada'
                                      : '$area m²',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                onTap: () {
                                  // fecha o bottomsheet com o sheetContext
                                  Navigator.pop(sheetContext);

                                  // navega com o context da página (pageContext)
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    _navegarParaAcao(pageContext, acao, doc.id);
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Jornada do Produtor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.95), primary.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vamos começar!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Siga os passos abaixo para ter uma colheita de sucesso.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          _TimelineItem(
            step: '1',
            title: 'Planejamento',
            desc: 'Defina o que plantar e calcule o consumo.',
            icon: Icons.edit_note,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TelaPlanejamentoConsumo(),
              ),
            ),
          ),
          _TimelineItem(
            step: '2',
            title: 'Meus Locais',
            desc: 'Cadastre vasos e canteiros.',
            icon: Icons.grid_view,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCanteiros()),
            ),
          ),
          _TimelineItem(
            step: '3',
            title: 'Diagnóstico',
            desc: 'Analise a saúde do seu solo.',
            icon: Icons.science,
            color: Colors.amber,
            onTap: () => _iniciarAcaoComCanteiro(context, 'diagnostico'),
          ),
          _TimelineItem(
            step: '4',
            title: 'Correção (Calagem)',
            desc: 'Calcule o calcário necessário.',
            icon: Icons.landscape,
            color: Colors.brown,
            onTap: () => _iniciarAcaoComCanteiro(context, 'calagem'),
          ),
          _TimelineItem(
            step: '5',
            title: 'Adubação Organo15',
            desc: 'Calculadora de misturas para vasos e canteiros.',
            icon: Icons.eco,
            color: Colors.orange,
            isLocked: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaAdubacaoOrgano15()),
            ),
          ),
          const _TimelineItem(
            step: '6',
            title: 'Colheita & Venda',
            desc: 'Em breve: Gestão de produção e lucro.',
            icon: Icons.storefront,
            color: Colors.purple,
            isLast: true,
            isLocked: true,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String step;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isLocked;

  const _TimelineItem({
    required this.step,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLast = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLocked ? Colors.grey.shade300 : Colors.white,
                  border: Border.all(
                    color: isLocked ? Colors.transparent : color,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: isLocked
                      ? []
                      : [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    step,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLocked ? null : onTap,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLocked
                                ? Colors.grey.shade100
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: isLocked ? Colors.grey : color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isLocked
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isLocked ? Icons.lock : Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
