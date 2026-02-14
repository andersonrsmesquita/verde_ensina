import 'package:flutter/material.dart';
import '../app_ui.dart'; // Ajuste o caminho se necessário para importar seus AppTokens e AppButtons

class ClinicaDaPlantaSheet extends StatefulWidget {
  const ClinicaDaPlantaSheet({super.key});

  @override
  State<ClinicaDaPlantaSheet> createState() => _ClinicaDaPlantaSheetState();
}

class _ClinicaDaPlantaSheetState extends State<ClinicaDaPlantaSheet> {
  int _step = 0; // 0: Local do problema, 1: Sintoma, 2: Resultado

  String _localSelecionado = '';
  String _sintomaSelecionado = '';

  String _resultadoDiagnostico = '';
  String _acaoSugerida = '';

  // Regras de negócio baseadas no E-book Organo 15
  void _processarDiagnostico() {
    if (_localSelecionado == 'Folhas Velhas') {
      if (_sintomaSelecionado.contains('uniforme')) {
        _resultadoDiagnostico = 'Deficiência de Nitrogênio (N)';
        _acaoSugerida =
            'Aplique adubos orgânicos ricos em N (Esterco/Bokashi) e verifique a umidade do solo.';
      } else if (_sintomaSelecionado.contains('entre nervuras')) {
        _resultadoDiagnostico = 'Deficiência de Magnésio (Mg)';
        _acaoSugerida =
            'Recomenda-se calagem com Calcário Dolomítico ou uso de Termofosfato.';
      } else if (_sintomaSelecionado.contains('necrose em V')) {
        _resultadoDiagnostico = 'Deficiência de Potássio (K)';
        _acaoSugerida =
            'Aplique Cinza de Madeira ou adubação orgânica rica em K.';
      } else if (_sintomaSelecionado.contains('Arroxeadas')) {
        _resultadoDiagnostico = 'Deficiência de Fósforo (P)';
        _acaoSugerida = 'Aplique Termofosfato ou Farinha de Osso na adubação.';
      }
    } else if (_localSelecionado == 'Folhas Novas') {
      if (_sintomaSelecionado.contains('uniforme')) {
        _resultadoDiagnostico = 'Deficiência de Enxofre (S)';
        _acaoSugerida = 'Aplique matéria orgânica curtida.';
      } else if (_sintomaSelecionado.contains('entre nervuras')) {
        _resultadoDiagnostico = 'Falta de Ferro ou Manganês (Fe/Mn)';
        _acaoSugerida = 'Pulverize Biofertilizante Supermagro nas folhas.';
      }
    } else if (_localSelecionado == 'Frutos') {
      if (_sintomaSelecionado.contains('Fundo preto')) {
        _resultadoDiagnostico = 'Deficiência de Cálcio (Ca)';
        _acaoSugerida =
            'Faça calagem ou pulverize calda rica em cálcio. Evite falta de água no solo.';
      } else if (_sintomaSelecionado.contains('Rachaduras')) {
        _resultadoDiagnostico = 'Deficiência de Boro (B)';
        _acaoSugerida =
            'Aplique Biofertilizante Supermagro (contém Ácido Bórico).';
      }
    } else if (_localSelecionado == 'Pragas ou Doenças') {
      if (_sintomaSelecionado.contains('Pulgão') ||
          _sintomaSelecionado.contains('Ácaro') ||
          _sintomaSelecionado.contains('Pinta Preta')) {
        _resultadoDiagnostico = 'Excesso de Nitrogênio (N)';
        _acaoSugerida =
            'A planta está fraca por excesso de N. Reduza a adubação nitrogenada imediatamente e melhore a ventilação.';
      } else if (_sintomaSelecionado.contains('Cochonilha') ||
          _sintomaSelecionado.contains('Requeima')) {
        _resultadoDiagnostico = 'Deficiência de Cálcio (Ca)';
        _acaoSugerida = 'Corrija o solo com Calcário e evite encharcamento.';
      } else if (_sintomaSelecionado.contains('Vaquinha') ||
          _sintomaSelecionado.contains('Percevejo')) {
        _resultadoDiagnostico = 'Falta de Potássio e Solo Compactado';
        _acaoSugerida =
            'Descompacte o solo (afofe a terra) e aplique Cinza de Madeira.';
      }
    }

    setState(() => _step = 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text('Clínica da Planta',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // PASSO 0: Onde está o problema?
          if (_step == 0) ...[
            Text('Onde você notou o problema?',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildOptionCard('Folhas Velhas', Icons.energy_savings_leaf, cs),
            _buildOptionCard('Folhas Novas', Icons.eco, cs),
            _buildOptionCard('Frutos', Icons.apple, cs),
            _buildOptionCard('Pragas ou Doenças', Icons.bug_report, cs),
          ],

          // PASSO 1: Qual o sintoma?
          if (_step == 1) ...[
            Text('Qual o sintoma exato nas $_localSelecionado?',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_localSelecionado == 'Folhas Velhas') ...[
              _buildOptionCard('Amarelecimento uniforme', Icons.palette, cs),
              _buildOptionCard(
                  'Amarelecimento entre nervuras', Icons.format_color_fill, cs),
              _buildOptionCard('Amarelecimento nas bordas (necrose em V)',
                  Icons.warning_amber, cs),
              _buildOptionCard('Arroxeadas', Icons.grass, cs),
            ],
            if (_localSelecionado == 'Folhas Novas') ...[
              _buildOptionCard('Amarelecimento uniforme', Icons.palette, cs),
              _buildOptionCard(
                  'Amarelecimento entre nervuras', Icons.format_color_fill, cs),
            ],
            if (_localSelecionado == 'Frutos') ...[
              _buildOptionCard(
                  'Fundo preto (Podridão apical)', Icons.coronavirus, cs),
              _buildOptionCard('Rachaduras', Icons.broken_image, cs),
            ],
            if (_localSelecionado == 'Pragas ou Doenças') ...[
              _buildOptionCard(
                  'Pulgão, Ácaros ou Pinta Preta', Icons.pest_control, cs),
              _buildOptionCard('Cochonilha ou Requeima', Icons.coronavirus, cs),
              _buildOptionCard('Vaquinha ou Percevejo', Icons.emoji_nature, cs),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Voltar'),
            )
          ],

          // PASSO 2: Resultado
          if (_step == 2) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  Text('Diagnóstico do Sistema',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: Colors.red.shade900)),
                  const SizedBox(height: 8),
                  Text(_resultadoDiagnostico,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900)),
                  const Divider(),
                  Text('Recomendação de Manejo',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: Colors.red.shade700)),
                  const SizedBox(height: 4),
                  Text(_acaoSugerida,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('ENTENDIDO, VOLTAR PARA ADUBAÇÃO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Fazer nova consulta médica'),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard(String label, IconData icon, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_step == 0) {
            setState(() {
              _localSelecionado = label;
              _step = 1;
            });
          } else if (_step == 1) {
            setState(() {
              _sintomaSelecionado = label;
              _processarDiagnostico();
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
