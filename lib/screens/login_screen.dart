import 'package:flutter/material.dart';
import 'package:genset_tracker/screens/home_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Definisi Palet Warna Konsisten
// Diambil dari warna umum yang muncul di kode/screenshot Genset Anda.
const Color kBackgroundColor = Color(0xFF071025); // Latar Belakang Gelap
const Color kCardColor = Color(0xFF0E1720); // Warna Card/Container
const Color kPrimaryColor = Color(0xFF3BD07E); // Warna Hijau (Primary/Success)
const Color kAccentColor = Color(0xFF5CC9FF); // Warna Biru (Accent/Info)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Set Loading = TRUE
    if (mounted) setState(() => isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await auth.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      // 2. Jika auth.signIn() berhasil (tidak melempar exception)
      if (auth.user != null) {
        if (!mounted) return;

        // Sukses: Navigasi dan HENTIKAN proses.
        // Catatan: finally tetap akan dieksekusi setelah navigasi, tapi ini lebih jelas.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return; // Sangat Penting: Keluar dari fungsi jika berhasil navigasi.

      } else {
        // Gagal (Soft Failure): Jika signIn selesai tanpa exception, tapi user null.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login gagal: masukan email/passord dengan benar'),
            backgroundColor: Colors.orange,
          ),
        );
      }

    } catch (e) {
      // 3. Gagal (Hard Failure): Exception tertangkap.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login gagal: masukan email/passord dengan benar'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 4. RESET LOADING: Selalu jalankan di akhir!
      // Ini adalah jaminan bahwa loading akan mati.
      // Kita gunakan Future.microtask untuk memastikan ini terjadi di event loop berikutnya.
      if (mounted) {
        await Future.microtask(() {
          if (mounted) setState(() => isLoading = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold menggunakan warna background aplikasi Genset
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Gambar Genset
              Image.asset(
                'assets/images/genset.png',
                height: 120,
              ),
              const SizedBox(height: 24),

              // 2. Branding Aplikasi (GENMON)
              const Text(
                'GENMON',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor, // Warna Hijau
                ),
              ),
              const SizedBox(height: 8),

              // 3. Deskripsi
              const Text(
                'GENMON membantu Anda menjaga kinerja genset tetap optimal dengan pemantauan secara real time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),

              // 4. Form Login
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardColor, // Warna Card/Container
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(emailController, 'Email', Icons.email, isEmail: true),
                      const SizedBox(height: 16),
                      _buildTextField(passwordController, 'Password', Icons.lock, isPassword: true),
                      const SizedBox(height: 30),

                      // Tombol Login
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: isLoading
                            ? Center(child: CircularProgressIndicator(color: kPrimaryColor))
                            : ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor, // Warna Hijau
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kBackgroundColor, // Teks Kontras
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget pembantu untuk TextFormField dengan desain dark-mode
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isPassword = false,
        bool isEmail = false,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: kAccentColor), // Warna Biru
        fillColor: kBackgroundColor.withOpacity(0.5),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2), // Fokus Hijau
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Masukkan $label';
        }
        if (isEmail && !val.contains('@')) {
          return 'Format email tidak valid';
        }
        return null;
      },
    );
  }
}