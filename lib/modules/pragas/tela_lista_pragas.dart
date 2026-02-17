// FILE: lib/modules/pragas/tela_lista_pragas.dart
import 'package:flutter/material.dart';
import '../../core/models/praga_model.dart';
import '../../core/repositories/pragas_repository.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart'; // ✅ Importante para o Design System
import 'tela_cadastro_praga.dart';

class TelaListaPragas extends StatefulWidget {
  const TelaListaPragas({super.key});

  @override
  State<TelaListaPragas> createState() => _TelaListaPragasState();
}

class _TelaListaPragasState extends State<TelaListaPragas>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = PragasRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Função para dar baixa na praga (marcar como resolvida)
  void _resolverPraga(PragaModel praga, String tenantId) {
    final solucaoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Resolver Problema"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Qual solução foi aplicada?"),
            const SizedBox(height: 10),
            TextField(
              controller: solucaoCtrl,
              decoration: const InputDecoration(
                hintText: "Ex: Óleo de Neem, Capina manual...",
                border: OutlineInputBorder(), // Mantém o padrão do App
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          // ✅ USO DO PADRÃO APP_UI (AppButtons)
          SizedBox(
            width: 140, // Largura fixa para o botão não estourar
            child: AppButtons.elevatedIcon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Concluir"),
              onPressed: () async {
                if (solucaoCtrl.text.isNotEmpty) {
                  await _repo.resolverPraga(
                      tenantId, praga.id!, solucaoCtrl.text);
                  if (mounted) Navigator.pop(ctx);
                }
              },
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; // Cores do tema
    final session = SessionScope.of(context).session;
    final tenantId = session?.tenantId;

    if (tenantId == null) {
      return const Scaffold(body: Center(child: Text("Erro: Sessão inválida")));
    }

    return Scaffold(
      backgroundColor: cs.surface, // Fundo padrão
      appBar: AppBar(
        title: const Text("Controle de Pragas"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: "🚨 ATIVAS", icon: Icon(Icons.warning_amber)),
            Tab(text: "✅ HISTÓRICO", icon: Icon(Icons.history)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TelaCadastroPraga()),
        ),
        label: const Text("Nova Ocorrência"),
        icon: const Icon(Icons.add_a_photo),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLista(tenantId, ativa: true, cs: cs),
          _buildLista(tenantId, ativa: false, cs: cs),
        ],
      ),
    );
  }

  Widget _buildLista(String tenantId,
      {required bool ativa, required ColorScheme cs}) {
    final stream =
        ativa ? _repo.getPragasAtivas(tenantId) : _repo.getHistorico(tenantId);

    return StreamBuilder<List<PragaModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erro ao carregar: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final listaTotal = snapshot.data!;
        final pragas = listaTotal
            .where((p) => ativa ? p.status == 'ativa' : p.status != 'ativa')
            .toList();

        if (pragas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ativa ? Icons.check_circle_outline : Icons.history,
                    size: 64, color: cs.outline.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                    ativa
                        ? "Tudo limpo! Nenhuma praga ativa."
                        : "Histórico vazio.",
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pragas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final p = pragas[i];

            // Card visualmente limpo seguindo o estilo do Home
            return Container(
              decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor:
                      _getCorIntensidade(p.intensidade).withOpacity(0.2),
                  child: Icon(Icons.bug_report,
                      color: _getCorIntensidade(p.intensidade)),
                ),
                title: Text(p.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: cs.secondary),
                        const SizedBox(width: 4),
                        Text(p.canteiroNome,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                    if (!ativa && p.observacoes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Solução: ${p.observacoes}",
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: cs.primary),
                        ),
                      ),
                  ],
                ),
                trailing: ativa
                    ? IconButton(
                        icon: Icon(Icons.check_box_outlined,
                            color: cs.primary, size: 28),
                        tooltip: "Marcar como Resolvido",
                        onPressed: () => _resolverPraga(p, tenantId),
                      )
                    : Icon(Icons.check_circle, color: cs.tertiary),
              ),
            );
          },
        );
      },
    );
  }

  Color _getCorIntensidade(String intensidade) {
    switch (intensidade) {
      case 'Alta':
        return Colors.red;
      case 'Média':
        return Colors.orange;
      default:
        return Colors.green; // Leve
    }
  }
}
