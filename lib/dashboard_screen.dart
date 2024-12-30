import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;
  Map<String, double> _entrateData = {};
  Map<String, double> _usciteData = {};
  List<Map<String, dynamic>> _budgets = [];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _fetchTransactionData();
    _fetchBudgetData();
  }

  Future<void> _fetchTransactionData() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('transazioni')
        .orderBy('data', descending: false)
        .get();

    final Map<String, double> entrate = {};
    final Map<String, double> uscite = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final tipo = data['tipo'];
      final categoria = data['categoria'];
      final importo = (data['importo'] as num).toDouble();

      if (tipo == "entrata") {
        entrate[categoria] = (entrate[categoria] ?? 0) + importo;
      } else if (tipo == "uscita") {
        uscite[categoria] = (uscite[categoria] ?? 0) + importo;
      }
    }

    setState(() {
      _entrateData = entrate;
      _usciteData = uscite;
      _updateBudgetUsage(snapshot.docs);
    });
  }

  Future<void> _fetchBudgetData() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('budget')
        .orderBy('data_inizio', descending: true)
        .get();

    setState(() {
      _budgets = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "nome": data['nome'],
          "importo": data['importo'],
          "usato": data['usato'] ?? 0,
          "data_inizio": (data['data_inizio'] as Timestamp).toDate(),
          "data_fine": (data['data_fine'] as Timestamp).toDate(),
          "tag": data['tag'],
        };
      }).toList();
    });
  }

  void _updateBudgetUsage(List<QueryDocumentSnapshot<Map<String, dynamic>>> transazioniDocs) {
    final now = DateTime.now();

    for (var budget in _budgets) {
      final tag = budget['tag'];
      final dataInizio = budget['data_inizio'];
      double usato = 0.0;

      if (now.isAfter(dataInizio) || now.isAtSameMomentAs(dataInizio)) {
        for (var transazione in transazioniDocs) {
          final dataTransazione = (transazione['data'] as Timestamp).toDate();
          final importo = (transazione['importo'] as num).toDouble();

          if ((dataTransazione.isAfter(dataInizio) || dataTransazione.isAtSameMomentAs(dataInizio)) &&
              transazione['categoria'] == tag &&
              transazione['tipo'] == "uscita") {
            usato += importo.abs();
          }
        }

        budget['usato'] = usato;

        _firestore
            .collection('users')
            .doc(_userId)
            .collection('budget')
            .doc(budget['id'])
            .update({"usato": usato});
      }
    }

    setState(() {});
  }

  Future<void> _deleteBudget(String budgetId) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('budget')
          .doc(budgetId)
          .delete();

      setState(() {
        _budgets.removeWhere((budget) => budget['id'] == budgetId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Budget eliminato con successo.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante l'eliminazione del budget.")),
      );
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Elimina"),
            ),
          ],
        );
      },
    );
  }

  List<BarChartGroupData> _buildBarChartData() {
    final categories = _entrateData.keys.toSet()
        .union(_usciteData.keys.toSet());
    final List<BarChartGroupData> barGroups = [];
    int index = 0;

    for (var category in categories) {
      final entrata = _entrateData[category] ?? 0;
      final uscita = _usciteData[category] ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: index++,
          barRods: [
            BarChartRodData(
              toY: entrata,
              color: Colors.green,
              width: 15,
            ),
            BarChartRodData(
              toY: uscita,
              color: Colors.red,
              width: 15,
            ),
          ],
          showingTooltipIndicators: [0, 1],
        ),
      );
    }
    return barGroups;
  }

  BarTouchTooltipData _buildTooltipStyle() {
    return BarTouchTooltipData(
      tooltipPadding: const EdgeInsets.all(8),
      tooltipRoundedRadius: 8,
      getTooltipColor: (group) {
        return Colors.white.withOpacity(0.6); // Transparent tooltip background
      },
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        return BarTooltipItem(
          rod.toY.toString(),
          const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  void _showAddBudgetDialog() {
    String nomeBudget = '';
    double importo = 0.0;
    DateTime? dataInizio;
    DateTime? dataFine;
    String tag = "Stipendio";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Aggiungi Budget"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: "Nome Budget"),
                    onChanged: (value) {
                      nomeBudget = value;
                    },
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "Importo"),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      importo = double.tryParse(value) ?? 0.0;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          dataInizio = selectedDate;
                        });
                      }
                    },
                    child: Text(
                      dataInizio == null
                          ? "Seleziona Data Inizio"
                          : "Data Inizio: ${DateFormat('dd/MM/yyyy').format(dataInizio!)}",
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          dataFine = selectedDate;
                        });
                      }
                    },
                    child: Text(
                      dataFine == null
                          ? "Seleziona Data Fine"
                          : "Data Fine: ${DateFormat('dd/MM/yyyy').format(dataFine!)}",
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Tag"),
                    value: tag,
                    items: [
                      "Stipendio",
                      "Alimentari",
                      "Shopping",
                      "Spese Mediche",
                      "Regali",
                      "Bollette",
                      "Tutte le Spese"
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        tag = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Annulla"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nomeBudget.isNotEmpty &&
                        importo > 0 &&
                        dataInizio != null &&
                        dataFine != null) {
                      await _aggiungiBudget(nomeBudget, importo, dataInizio!, dataFine!, tag);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Completa tutti i campi.")),
                      );
                    }
                  },
                  child: const Text("Aggiungi"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _aggiungiBudget(
      String nome, double importo, DateTime dataInizio, DateTime dataFine, String tag) async {
    try {
      final docRef = await _firestore.collection('users').doc(_userId).collection('budget').add({
        "nome": nome,
        "importo": importo,
        "usato": 0.0,
        "data_inizio": dataInizio,
        "data_fine": dataFine,
        "tag": tag,
        "data_creazione": DateTime.now(),
      });
      setState(() {
        _budgets.insert(0, {
          "id": docRef.id,
          "nome": nome,
          "importo": importo,
          "usato": 0.0,
          "data_inizio": dataInizio,
          "data_fine": dataFine,
          "tag": tag,
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante l'aggiunta del budget.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Panoramica Transazioni",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: _buildBarChartData(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final category = _entrateData.keys.toList() + _usciteData.keys.toList();
                          return Text(category[value.toInt()]);
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: _buildTooltipStyle(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Gestione Budget",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Expanded(
              child: _budgets.isEmpty
                  ? const Center(
                child: Text(
                  "Non è presente nessun Budget",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              )
                  : ListView.builder(
                itemCount: _budgets.length,
                itemBuilder: (context, index) {
                  final budget = _budgets[index];
                  final progress =
                      (budget['usato'] as double) / (budget['importo'] as double);
                  final isOverBudget = budget['usato'] >= budget['importo'];
                  final isExpired = DateTime.now().isAfter(budget['data_fine']);

                  return Dismissible(
                    key: Key(budget['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final bool? confirmed =
                      await _showDeleteConfirmationDialog(
                          "Conferma Eliminazione Budget",
                          "Sei sicuro di voler eliminare questo budget?");
                      if (confirmed == true) {
                        await _deleteBudget(budget['id']);
                      }
                      return confirmed;
                    },
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(budget["nome"]),
                          subtitle: Text(
                            "Importo: ${budget["importo"]} - Usato: ${budget["usato"]}\n"
                                "Da: ${DateFormat('dd/MM/yyyy').format(budget["data_inizio"])} "
                                "a: ${DateFormat('dd/MM/yyyy').format(budget["data_fine"])}",
                            style: TextStyle(
                              color: isOverBudget || isExpired
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                          trailing: Text("Tag: ${budget["tag"]}"),
                        ),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[300],
                          color: Colors.yellow,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showAddBudgetDialog,
              child: const Text("Aggiungi Budget"),
            ),
          ],
        ),
      ),
    );
  }
}
