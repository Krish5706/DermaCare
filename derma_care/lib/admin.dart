// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class AdminPage extends StatefulWidget {
//   const AdminPage({super.key});

//   @override
//   State<AdminPage> createState() => _AdminPageState();
// }

// class _AdminPageState extends State<AdminPage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   Future<List<Map<String, dynamic>>> fetchAllUsers() async {
//     final snapshot = await _firestore.collection('users').get();
//     return snapshot.docs.map((doc) {
//       return {
//         'id': doc.id,
//         ...doc.data(),
//       };
//     }).toList();
//   }

//   Future<void> deleteUser(String docId) async {
//     await _firestore.collection('users').doc(docId).delete();
//     setState(() {}); // Refresh UI
//   }

//   void openEditDialog(Map<String, dynamic> user) {
//     final nameController = TextEditingController(text: user['name']);
//     final emailController = TextEditingController(text: user['email']);

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Edit User'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
//             TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               await _firestore.collection('users').doc(user['id']).update({
//                 'name': nameController.text.trim(),
//                 'email': emailController.text.trim(),
//               });
//               Navigator.pop(context);
//               setState(() {});
//             },
//             child: const Text('Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> exportUsersToCSV() async {
//     final users = await fetchAllUsers();

//     if (users.isEmpty) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users to export')));
//       return;
//     }

//     List<List<String>> csvData = [
//       ['ID', 'Name', 'Email', 'Phone', 'Created At', 'Updated At']
//     ];

//     for (var user in users) {
//       csvData.add([
//         user['id'] ?? '',
//         user['name'] ?? '',
//         user['email'] ?? '',
//         user['phone'] ?? '',
//         user['created_at'] ?? '',
//         user['updated_at'] ?? '',
//       ]);
//     }

//     String csv = const ListToCsvConverter().convert(csvData);

//     final directory = await getApplicationDocumentsDirectory();
//     final path = '${directory.path}/users_export.csv';
//     final file = File(path);
//     await file.writeAsString(csv);

//     await Share.shareXFiles([XFile(path)], text: 'User List Export');
//   }

//   Future<void> logout() async {
//     await _auth.signOut();
//     if (!mounted) return;
//     Navigator.of(context).pushReplacementNamed('/login');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Admin Dashboard'),
//         backgroundColor: Colors.blueAccent,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             tooltip: 'Logout',
//             onPressed: logout,
//           ),
//           IconButton(
//             icon: const Icon(Icons.download),
//             tooltip: 'Export Users as CSV',
//             onPressed: exportUsersToCSV,
//           ),
//         ],
//       ),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: fetchAllUsers(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }

//           final users = snapshot.data ?? [];

//           if (users.isEmpty) {
//             return const Center(child: Text('No users found.'));
//           }

//           return ListView.separated(
//             itemCount: users.length,
//             separatorBuilder: (_, __) => const Divider(),
//             itemBuilder: (context, index) {
//               final user = users[index];
//               return ListTile(
//                 title: Text(user['name'] ?? 'No Name'),
//                 subtitle: Text(user['email'] ?? 'No Email'),
//                 trailing: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.edit, color: Colors.orange),
//                       onPressed: () => openEditDialog(user),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.delete, color: Colors.red),
//                       onPressed: () async {
//                         final confirmed = await showDialog<bool>(
//                           context: context,
//                           builder: (_) => AlertDialog(
//                             title: const Text('Confirm Delete'),
//                             content: Text('Are you sure you want to delete user "${user['name']}"?'),
//                             actions: [
//                               TextButton(
//                                 onPressed: () => Navigator.pop(context, false),
//                                 child: const Text('Cancel'),
//                               ),
//                               ElevatedButton(
//                                 onPressed: () => Navigator.pop(context, true),
//                                 child: const Text('Delete'),
//                               ),
//                             ],
//                           ),
//                         );
//                         if (confirmed ?? false) {
//                           await deleteUser(user['id']);
//                         }
//                       },
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// /// Helper to convert List<List<String>> to CSV string
// class ListToCsvConverter {
//   const ListToCsvConverter();

//   String convert(List<List<String>> rows) {
//     return rows.map((row) {
//       return row.map(_escapeField).join(',');
//     }).join('\n');
//   }

//   String _escapeField(String field) {
//     if (field.contains(',') || field.contains('\n') || field.contains('"')) {
//       final escaped = field.replaceAll('"', '""');
//       return '"$escaped"';
//     }
//     return field;
//   }
// }
