import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _limit = 10; // 🔹 Jumlah notifikasi per halaman
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<DocumentSnapshot> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  // 🔹 Load halaman pertama
  Future<void> _loadInitial() async {
    final query = await _firestore
        .collection('notifications')
        .orderBy('CreatedAt', descending: true)
        .limit(_limit)
        .get();

    setState(() {
      _notifications = query.docs;
      if (query.docs.isNotEmpty) _lastDocument = query.docs.last;
      _hasMore = query.docs.length == _limit;
    });
  }

  // 🔹 Load halaman berikutnya
  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final query = await _firestore
        .collection('notifications')
        .orderBy('CreatedAt', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(_limit)
        .get();

    setState(() {
      _notifications.addAll(query.docs);
      _isLoadingMore = false;
      if (query.docs.isNotEmpty) _lastDocument = query.docs.last;
      _hasMore = query.docs.length == _limit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071025),
      appBar: AppBar(
        title: Text("Notifikasi", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF071025),
      ),
      body: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
        child: SafeArea(
          child: _notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (!_isLoadingMore &&
                        _hasMore &&
                        scrollInfo.metrics.pixels ==
                            scrollInfo.metrics.maxScrollExtent) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: _loadInitial,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _notifications.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
        
                        final notif =
                            _notifications[index].data() as Map<String, dynamic>;
                        final title = notif['Title'] ?? 'Tanpa Judul';
                        final body = notif['Body'] ?? '';
                        final time = notif['CreatedAt'] != null
                            ? (notif['CreatedAt'] as Timestamp).toDate()
                            : DateTime.now();
                        final isRead = notif['is_read'] ?? false;
        
                        return Card(
                          color: isRead
                              ? Colors.white
                              : Colors.blue.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.notifications,
                              color: Colors.yellow,
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              body,
                              style: TextStyle(color: Colors.grey),
                            ),
                            trailing: Text(
                              DateFormat('dd MMM yy HH:mm').format(time),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
