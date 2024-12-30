import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _promemoria = [];
  List<Map<String, dynamic>> _avvisi = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _fetchPromemoriaAndGenerateAvvisi();
    _fetchAvvisiFromFirestore();
  }

  void _initializeNotifications() {
    tz.initializeTimeZones();
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInitSettings);
    _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _fetchPromemoriaAndGenerateAvvisi() async {
    await _fetchPromemoriaFromFirestore();
    await _checkAndGenerateAvvisi();
  }

  Future<void> _checkAndGenerateAvvisi() async {
    final now = DateTime.now();
    for (var promemoria in _promemoria) {
      final scadenza = promemoria['scadenza'] as DateTime;
      if (_isSameDay(scadenza, now)) {
        await _addAvvisoIfNotExists(
          'Promemoria scaduto',
          'Il promemoria "${promemoria['title']}" è scaduto oggi.',
        );
      } else if (_isSameDay(scadenza.subtract(const Duration(days: 2)), now)) {
        await _addAvvisoIfNotExists(
          'Promemoria in scadenza',
          'Il promemoria "${promemoria['title']}" scadrà il ${DateFormat('dd/MM/yyyy').format(scadenza)}.',
        );
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Future<void> _scheduleNotification(String title, String body, DateTime scheduledTime) async {
    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) return;

    final androidDetails = AndroidNotificationDetails(
      'promemoria_channel',
      'Promemoria',
      channelDescription: 'Notifiche per i promemoria',
      importance: Importance.high,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    final twoDaysBefore = scheduledTime.subtract(const Duration(days: 2));

    if (twoDaysBefore.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        twoDaysBefore.hashCode,
        'Promemoria in scadenza',
        'Il promemoria "$title" scadrà il ${DateFormat('dd/MM/yyyy').format(scheduledTime)}.',
        tz.TZDateTime.from(twoDaysBefore, tz.local),
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    await _notificationsPlugin.zonedSchedule(
      scheduledTime.hashCode,
      'Promemoria scaduto',
      'Il promemoria "$title" è scaduto oggi.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _addPromemoria(String title, DateTime scadenza) async {
    try {
      final now = DateTime.now();
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('promemoria')
          .add({
        'title': title,
        'scadenza': scadenza,
        'createdAt': DateTime.now(),
      });

      if (_isSameDay(scadenza, now)) {
        await _addAvvisoIfNotExists(
          'Promemoria scaduto',
          'Il promemoria "$title" è scaduto oggi.',
        );
      } else if (_isSameDay(scadenza.subtract(const Duration(days: 2)), now)) {
        await _addAvvisoIfNotExists(
          'Promemoria in scadenza',
          'Il promemoria "$title" scadrà il ${DateFormat('dd/MM/yyyy').format(scadenza)}.',
        );
      }

      await _scheduleNotification(title, 'Il promemoria "$title" è scaduto.', scadenza);

      setState(() {
        _promemoria.insert(
          0,
          {'id': docRef.id, 'title': title, 'scadenza': scadenza},
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'aggiunta del promemoria: $e")),
      );
    }
  }

  Future<void> _fetchPromemoriaFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('promemoria')
          .orderBy('scadenza', descending: true)
          .get();

      setState(() {
        _promemoria = snapshot.docs
            .map((doc) => {
          'id': doc.id,
          'title': doc['title'],
          'scadenza': (doc['scadenza'] as Timestamp).toDate(),
        })
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il recupero dei promemoria: $e")),
      );
    }
  }

  Future<void> _fetchAvvisiFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('avvisi')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _avvisi = snapshot.docs
            .map((doc) => {
          'id': doc.id,
          'title': doc['title'],
          'body': doc['body'],
        })
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il recupero degli avvisi: $e")),
      );
    }
  }

  Future<void> _addAvvisoIfNotExists(String title, String body) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('avvisi')
        .where('title', isEqualTo: title)
        .where('body', isEqualTo: body)
        .get();

    if (snapshot.docs.isEmpty) {
      await _addAvviso(title, body);
    }
  }

  Future<void> _addAvviso(String title, String body) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('avvisi')
          .add({
        'title': title,
        'body': body,
        'createdAt': DateTime.now(),
      });

      setState(() {
        _avvisi.insert(
          0,
          {'id': docRef.id, 'title': title, 'body': body},
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'aggiunta dell'avviso: $e")),
      );
    }
  }

  Future<bool?> _deletePromemoria(String promemoriaId, int index) async {
    final bool? confirmed = await _showDeleteConfirmationDialog(
      "Conferma Eliminazione",
      "Vuoi davvero eliminare questo promemoria?",
    );

    if (confirmed == true) {
      try {
        // Elimina il promemoria da Firestore
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('promemoria')
            .doc(promemoriaId)
            .delete();

        // Aggiorna la lista locale
        setState(() {
          _promemoria.removeAt(index);
        });

        // Ricarica i dati da Firestore per garantire sincronizzazione
        await _fetchPromemoriaFromFirestore();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Promemoria eliminato con successo.")),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'eliminazione: $e")),
        );
      }
    }
    return false;
  }


  Future<bool?> _deleteAvviso(String avvisoId, int index) async {
    final bool? confirmed = await _showDeleteConfirmationDialog(
      "Conferma Eliminazione",
      "Vuoi davvero eliminare questo avviso?",
    );

    if (confirmed == true) {
      try {
        // Elimina l'avviso da Firestore
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('avvisi')
            .doc(avvisoId)
            .delete();

        // Aggiorna la lista locale
        setState(() {
          _avvisi.removeAt(index);
        });

        // Ricarica i dati da Firestore per garantire sincronizzazione
        await _fetchAvvisiFromFirestore();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Avviso eliminato con successo.")),
        );
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante l'eliminazione: $e")),
        );
      }
    }
    return false;
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

  Future<void> _showAddPromemoriaDialog() async {
    String? titolo;
    DateTime? dataScadenza;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Aggiungi Promemoria"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: "Titolo Promemoria"),
                    onChanged: (value) {
                      titolo = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          dataScadenza = selectedDate;
                        });
                      }
                    },
                    child: Text(
                      dataScadenza == null
                          ? "Seleziona Data di Scadenza"
                          : "Data: ${DateFormat('dd/MM/yyyy').format(dataScadenza!)}",
                      style: const TextStyle(color: Colors.blue),
                    ),
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
                    if (titolo != null && dataScadenza != null) {
                      _addPromemoria(titolo!, dataScadenza!);
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Completa tutti i campi")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPromemoriaDialog,
        backgroundColor: const Color(0xFFEDE7F6),
        child: const Icon(
          Icons.add,
          color: Colors.deepPurple,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Center(
              child: Text(
                "Gestione Promemoria",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _promemoria.isEmpty
                  ? const Center(
                child: Text("Non è presente nessun promemoria."),
              )
                  : ListView.builder(
                itemCount: _promemoria.length,
                itemBuilder: (context, index) {
                  final promemoria = _promemoria[index];
                  return Dismissible(
                    key: Key(promemoria['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => _deletePromemoria(promemoria['id'], index),
                    child: ListTile(
                      title: Text(promemoria['title']),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(promemoria['scadenza']),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Avvisi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _avvisi.isEmpty
                  ? const Center(
                child: Text("Non è presente nessun avviso."),
              )
                  : ListView.builder(
                itemCount: _avvisi.length,
                itemBuilder: (context, index) {
                  final avviso = _avvisi[index];
                  final isScaduto = avviso['title'] == 'Promemoria scaduto';
                  final isInScadenza = avviso['title'] == 'Promemoria in scadenza';
                  return Dismissible(
                    key: Key(avviso['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => _deleteAvviso(avviso['id'], index),
                    child: ListTile(
                      title: Text(
                        avviso['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isScaduto
                              ? Colors.red
                              : isInScadenza
                              ? Colors.orange
                              : Colors.black,
                        ),
                      ),
                      subtitle: Text(avviso['body']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
