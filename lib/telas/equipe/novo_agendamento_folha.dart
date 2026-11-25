import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../logica/agenda_logica.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/paciente.dart';
import '../../modelos/usuario.dart';
import '../../widgets/comuns.dart';

/// Abre a folha de "Novo agendamento".
Future<void> abrirNovoAgendamento(
  BuildContext context, {
  required List<Usuario> profissionais,
  required DateTime dia,
  String? profissionalId,
}) {
  final repo = context.read<ClinicaRepositorio>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Cores.superficie,
    builder: (_) => _NovoAgendamento(
      repo: repo,
      profissionais: profissionais,
      diaInicial: dia,
      profissionalId: profissionalId,
    ),
  );
}

class _NovoAgendamento extends StatefulWidget {
  const _NovoAgendamento({
    required this.repo,
    required this.profissionais,
    required this.diaInicial,
    this.profissionalId,
  });
  final ClinicaRepositorio repo;
  final List<Usuario> profissionais;
  final DateTime diaInicial;
  final String? profissionalId;

  @override
  State<_NovoAgendamento> createState() => _NovoAgendamentoState();
}

class _NovoAgendamentoState extends State<_NovoAgendamento> {
  static const _tipos = [
    'Terapia',
    'Avaliação',
    'Avaliação Audiológica',
    'Retorno',
    'Reavaliação',
  ];

  Paciente? _paciente;
  String? _profissionalId;
  late DateTime _dia;
  DateTime? _horario;
  String _tipo = _tipos.first;
  String _sala = Salas.todas.first;
  bool _salvando = false;

  /// Agendamentos do dia escolhido: é tudo o que a checagem de conflitos e os
  /// horários livres precisam, então a folha consulta só esse dia.
  List<Agendamento> _doDia = const [];
  StreamSubscription<List<Agendamento>>? _sub;

  @override
  void initState() {
    super.initState();
    _profissionalId =
        widget.profissionalId ?? widget.profissionais.firstOrNull?.id;
    _dia = widget.diaInicial.inicioDoDia;
    final h = widget.diaInicial;
    if (h.hour != 0) _horario = h;
    _ouvirDia();
  }

  void _ouvirDia() {
    _sub?.cancel();
    _sub = widget.repo
        .agendamentosEntre(_dia, DateTime(_dia.year, _dia.month, _dia.day + 1))
        .listen((l) => setState(() => _doDia = l));
  }

  @override
  void dispose() {
    _sub?.cancel(); // evita vazamento: a folha fecha, a escuta para.
    super.dispose();
  }

  Usuario? get _profissional =>
      widget.profissionais.where((p) => p.id == _profissionalId).firstOrNull;

  Disponibilidade? get _checagem {
    if (_horario == null || _profissionalId == null) return null;
    return AgendaLogica.verificar(
      _doDia,
      profissionalId: _profissionalId!,
      sala: _sala,
      inicio: _horario!,
      fim: _horario!.add(const Duration(minutes: Salas.duracaoPadraoMin)),
    );
  }

  Future<void> _escolherDia() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d != null) {
      setState(() {
        _dia = d;
        _horario = null;
        _doDia = const [];
      });
      _ouvirDia();
    }
  }

  Future<void> _salvar() async {
    final p = _paciente;
    final prof = _profissional;
    if (p == null || prof == null || _horario == null) return;
    setState(() => _salvando = true);
    final sessoesAnteriores = await widget.repo.contarSessoesDoPaciente(p.id);
    await widget.repo.criarAgendamento(
      Agendamento(
        id: '',
        pacienteId: p.id,
        pacienteNome: p.nome,
        pacienteNascimento: p.dataNascimento,
        profissionalId: prof.id,
        profissionalNome: prof.nome,
        sala: _sala,
        inicio: _horario!,
        fim: _horario!.add(const Duration(minutes: Salas.duracaoPadraoMin)),
        tipo: _tipo,
        sessaoNumero: sessoesAnteriores + 1,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    avisar(
      context,
      '${p.primeiroNome} agendado(a) para ${Formatos.diaHoraCurto(_horario!)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final livres = _profissionalId == null
        ? <DateTime>[]
        : AgendaLogica.horariosLivres(
            _doDia,
            _dia,
            profissionalId: _profissionalId!,
          );
    final checagem = _checagem;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo agendamento', style: TemaApp.titulo(size: 20)),
            const SizedBox(height: 16),
            Observar<List<Paciente>>(
              stream: widget.repo.pacientes,
              builder: (context, pacientes) => DropdownButtonFormField<String>(
                initialValue: _paciente?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Paciente',
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: [
                  for (final p in pacientes)
                    DropdownMenuItem(value: p.id, child: Text(p.nome)),
                ],
                onChanged: (id) => setState(() {
                  _paciente = pacientes.firstWhere((p) => p.id == id);
                  if (_paciente!.profissionalId.isNotEmpty &&
                      widget.profissionalId == null &&
                      widget.profissionais.any(
                        (u) => u.id == _paciente!.profissionalId,
                      )) {
                    _profissionalId = _paciente!.profissionalId;
                  }
                }),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _profissionalId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Profissional',
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              items: [
                for (final p in widget.profissionais)
                  DropdownMenuItem(value: p.id, child: Text(p.nome)),
              ],
              onChanged: (v) => setState(() {
                _profissionalId = v;
                _horario = null;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _escolherDia,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${Formatos.diaSemanaCurto(_dia)}, ${Formatos.data(_dia)}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tipo,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      for (final t in _tipos)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged: (v) => setState(() => _tipo = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Sobrelinha('Horários livres do profissional'),
            const SizedBox(height: 8),
            if (livres.isEmpty)
              Text(
                'Sem horários livres neste dia.',
                style: TemaApp.corpo(color: Cores.textoSuave),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in livres)
                  ChoiceChip(
                    label: Text(Formatos.hora(h)),
                    selected: _horario == h,
                    onSelected: (_) => setState(() => _horario = h),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _sala,
              decoration: const InputDecoration(
                labelText: 'Sala',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              items: [
                for (final s in Salas.todas)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _sala = v!),
            ),
            if (checagem != null && !checagem.salaLivre) ...[
              const SizedBox(height: 8),
              Bloco(
                cor: Cores.alertaFundo,
                child: Text(
                  'Esta sala já está ocupada nesse horário. Escolha outra.',
                  style: TemaApp.corpo(color: Cores.alertaTexto),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  _salvando ||
                      _paciente == null ||
                      _horario == null ||
                      checagem?.livre != true
                  ? null
                  : _salvar,
              icon: const Icon(Icons.event_available),
              label: const Text('Confirmar agendamento'),
            ),
          ],
        ),
      ),
    );
  }
}
