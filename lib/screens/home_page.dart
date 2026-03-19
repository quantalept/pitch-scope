import 'package:flutter/material.dart';
import 'pitch_screen.dart';
import 'match_the_raagas.dart'; // 👈 ADDED

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0026),
      body: SafeArea(
        child: Column(
          children: [

            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Voctave Studio",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.settings, color: Colors.white),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ================= WAVE CARD =================
            Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF2B003D),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Icon(
                  Icons.graphic_eq,
                  size: 90,
                  color: Colors.purpleAccent,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ================= MONITOR OWN VOICE =================
            _buildMainButton(
              context,
              title: "🎤 Monitor own voice",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PitchScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ================= MATCH THE RAAGAS =================
            _buildMainButton(
              context,
              title: "🎵 Match The Raagas",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MatchTheRaagas(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ================= USE YOUR OWN SONG =================
            _buildMainButton(
              context,
              title: "🎶 Use your own song",
              onPressed: () {},
            ),

            const Spacer(),

            // ================= FOOTER =================
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF2B003D),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _FooterItem(icon: Icons.history, label: "History"),
                  _FooterItem(icon: Icons.menu_book, label: "Learn"),
                  _FooterItem(icon: Icons.info_outline, label: "About"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= BUTTON BUILDER =================
  Widget _buildMainButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B00B3),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// ================= FOOTER ITEM WIDGET =================
class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}