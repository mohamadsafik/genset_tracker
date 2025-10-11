import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:genset_tracker/screens/home_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart'; // path sesuai projectmu

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        backgroundColor: kDarkBackground,
        title: const Text('Profile', style: TextStyle(color: Colors.white),),
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userProvider.user;

          if (user == null) {
            return const Center(child: Text('Tidak ada user login'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Foto profile
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 16),

                // Nama user
                Text(
                  user.displayName ?? 'No Name',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Email
                Text(
                  user.email ?? 'No Email',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 24),

                // Info lainnya (optional)
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Colors.white,),
                  title: const Text('User ID', style: TextStyle(color: Colors.white)),
                  subtitle: Text(user.uid,style: TextStyle(color: Colors.white)),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.white,),
                  title: const Text('Email Verified',style: TextStyle(color: Colors.white)),
                  subtitle: Text(user.emailVerified ? 'Yes' : 'No',style: TextStyle(color: Colors.white)),
                ),

                // Logout button
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                   await userProvider.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.white,),
                  label: const Text('Logout', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
