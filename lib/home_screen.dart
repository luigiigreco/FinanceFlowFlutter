import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  double _saldoTotale = 0.0;
  final List<Map<String, dynamic>> _transazioni = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _caricaTransazioni();
  }

  Future<void> _caricaTransazioni() async {
    final transazioniSnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('transazioni')
        .orderBy('data', descending: true)
        .get();

    setState(() {
      _transazioni.clear();
      _saldoTotale = 0.0;
      for (var doc in transazioniSnapshot.docs) {
        final data = doc.data();
        final importo = data['importo'] as double;
        _transazioni.add({
          "id": doc.id,
          "tipo": data['tipo'],
          "categoria": data['categoria'],
          "data": (data['data'] as Timestamp).toDate(),
          "importo": importo,
        });
        _saldoTotale += importo;
      }
    });
  }

  Future<void> _aggiungiTransazione(
      String tipo, double importo, bool isEntrata) async {
    final nuovaTransazione = {
      "tipo": isEntrata ? "entrata" : "uscita",
      "categoria": tipo,
      "data": DateTime.now(),
      "importo": isEntrata ? importo : -importo,
    };

    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('transazioni')
        .add(nuovaTransazione);

    setState(() {
      _transazioni.insert(0, {
        "id": docRef.id,
        "tipo": isEntrata ? "entrata" : "uscita",
        "categoria": tipo,
        "data": DateTime.now(),
        "importo": isEntrata ? importo : -importo,
      });
      _saldoTotale += isEntrata ? importo : -importo;
    });
  }

  Future<void> _showDeleteConfirmationDialog(String id, double importo) async {
    final bool? conferma = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Conferma Eliminazione"),
          content:
          const Text("Sei sicuro di voler eliminare questa transazione?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annulla"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Conferma"),
            ),
          ],
        );
      },
    );

    if (conferma == true) {
      await _eliminaTransazione(id, importo);
    }
  }

  Future<void> _eliminaTransazione(String id, double importo) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('transazioni')
        .doc(id)
        .delete();

    setState(() {
      _transazioni.removeWhere((transazione) => transazione["id"] == id);
      _saldoTotale -= importo;
    });
  }

  void _showAddTransactionDialog() {
    String tipo = "Stipendio";
    double importo = 0.0;
    bool isEntrata = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Aggiungi Transazione"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Importo"),
                    onChanged: (value) {
                      importo = double.tryParse(value) ?? 0.0;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          title: Transform.translate(
                            offset: const Offset(-12, 0),
                            child: const Text("Entrata",
                                style: TextStyle(fontSize: 16)),
                          ),
                          value: true,
                          groupValue: isEntrata,
                          onChanged: (value) {
                            setState(() {
                              isEntrata = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          title: Transform.translate(
                            offset: const Offset(-12, 0),
                            child: const Text("Uscita",
                                style: TextStyle(fontSize: 16)),
                          ),
                          value: false,
                          groupValue: isEntrata,
                          onChanged: (value) {
                            setState(() {
                              isEntrata = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    decoration:
                    const InputDecoration(labelText: "Tipo di Transazione"),
                    value: tipo,
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
                      tipo = newValue!;
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
                  onPressed: () {
                    _aggiungiTransazione(tipo, importo, isEntrata);
                    Navigator.of(context).pop();
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/');
  }

  Widget buildHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Saldo Totale: €${_saldoTotale.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 10), // Aggiunge spazio tra saldo e lista
        const Center(
          child: Text(
            "Transazioni",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10), // Distanza aggiuntiva tra il titolo e la lista
        Expanded(
          child: _transazioni.isEmpty
              ? const Center(
            child: Text(
              "Non è presente nessuna transazione",
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          )
              : ListView.builder(
            itemCount: _transazioni.length,
            itemBuilder: (context, index) {
              final transazione = _transazioni[index];
              final importoColor =
              transazione["importo"] >= 0 ? Colors.green : Colors.red;
              final importoPrefix =
              transazione["importo"] >= 0 ? "+" : "-";
              final dataFormat = DateFormat('dd/MM/yyyy HH:mm');
              final data = dataFormat.format(transazione["data"]);

              return Dismissible(
                key: Key(transazione["id"]),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  await _showDeleteConfirmationDialog(
                      transazione["id"], transazione["importo"]);
                  return false;
                },
                child: ListTile(
                  title: Text(transazione["categoria"]),
                  subtitle: Text(data),
                  trailing: Text(
                    "$importoPrefix€${transazione["importo"].abs().toStringAsFixed(2)}",
                    style: TextStyle(color: importoColor),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finance Flow"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? buildHomeContent()
          : _selectedIndex == 1
          ? const DashboardScreen()
          : const NotificationsScreen(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: const Icon(Icons.add),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
      ),
    );
  }
}
