import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import 'admin_register_screen.dart';
import '../../features/admin/admin_main_wrapper.dart';
import '../../main.dart';
import '../../features/auth/password_reset_dialog.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _loginAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Please enter email and password")),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signInAdmin(
        email: email,
        password: password,
      );

      if (mounted) {
        // Navigate to admin dashboard immediately
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminMainWrapper()),
        );
      }
    } catch (e) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isMobile ? _mobileLayout() : _desktopLayout(),
    );
  }

  // ================= MOBILE =================
  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20), // Deep Forest Green
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.spa_rounded, color: Colors.white, size: 60),
                const SizedBox(height: 15),
                const Text(
                  "Admin Portal",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "Shivam Resorts Management",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: _loginForm(),
          ),
        ],
      ),
    );
  }

  // ================= DESKTOP =================
  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.spa_rounded, size: 100, color: Colors.white),
                  const SizedBox(height: 25),
                  const Text(
                    "Shivam Resorts",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "ADMINISTRATOR ACCESS",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _loginForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= FORM CONTENT =================
  Widget _loginForm() {
    const Color brandPurple = Color(0xFF673AB7);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Admin Sign In",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Authorized personnel only. Please enter your credentials.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 40),
        
        _customField(
          controller: _emailController,
          label: "Admin Email",
          icon: Icons.admin_panel_settings_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _customField(
          controller: _passwordController,
          label: "Password",
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 35),
        
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginAdmin,
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: brandPurple.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "LOGIN",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => PasswordResetDialog(
                  initialEmail: _emailController.text,
                ),
              );
            },
            child: const Text(
              "Forgot Password?",
              style: TextStyle(
                color: brandPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
              );
            },
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                children: [
                  const TextSpan(text: "New Administrator? "),
                  TextSpan(
                    text: "Create Account",
                    style: TextStyle(
                      color: brandPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _customField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black45, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF673AB7), size: 20),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF673AB7),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF673AB7), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
