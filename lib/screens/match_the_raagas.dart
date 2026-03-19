import 'package:flutter/material.dart';
import 'package:pitchscope/screens/raaga_practice_screen.dart';

class MatchTheRaagas extends StatelessWidget {
  const MatchTheRaagas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0015),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0015),
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFFD6C6FF),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Match the raagas",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD6C6FF),
          ),
        ),
      ),

      /// ✅ FIXED BODY (SCROLLABLE)
      body: SafeArea(
        child: ListView(
          children: [

            /// ================= CARNATIC =================
            _sectionHeader("Carnatic raaga"),

            _raagaTile(
              context,
              "Mayamalavagowla",
              "Deva Deva",
              "Sa Ri Ga Ma",
            ),

            _raagaTile(
              context,
              "Shankarabharanam",
              "Endaro Mahanubhavulu",
              "Sa Ri Ga Ma Pa",
            ),

            _raagaTile(
              context,
              "Kalyani",
              "Vasudevayani",
              "Sa Ri Ga Ma Pa Da",
            ),

            _raagaTile(
              context,
              "Todi",
              "Kaddanu Variki",
              "Sa Ri Ga Ma",
            ),

            _raagaTile(
              context,
              "Mohanam",
              "Nannu Palimpa",
              "Sa Ri Ga Pa Da",
            ),

            _raagaTile(
              context,
              "Bhairavi",
              "Upacharamu",
              "Sa Ri Ga Ma",
            ),

            _raagaTile(
              context,
              "Kamboji",
              "O Rangasayee",
              "Sa Ri Ga Ma Pa",
            ),

            const SizedBox(height: 12),

            /// ================= HINDUSTHANI =================
            _sectionHeader("Hindusthani raaga"),

            _raagaTile(
              context,
              "Yaman",
              "Eri Aali Piya",
              "Sa Re Ga Ma",
            ),

            _raagaTile(
              context,
              "Bhairav",
              "Jaago Mohan",
              "Sa Re Ga Ma",
            ),

            _raagaTile(
              context,
              "Darbari Kanada",
              "Ab Mori Baat",
              "Sa Re Ga",
            ),

            _raagaTile(
              context,
              "Bageshri",
              "Kaun Gali",
              "Sa Re Ga Ma",
            ),

            _raagaTile(
              context,
              "Malkauns",
              "Pag Ghunghroo",
              "Sa Ga Ma Dha",
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ================= SECTION HEADER =================
  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2A0048),
            Color(0xFF6A1B9A),
          ],
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFD6C6FF),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// ================= RAAGA TILE =================
  Widget _raagaTile(
    BuildContext context,
    String raagaName,
    String songName,
    String lyric,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RaagaPracticeScreen(
              raagaName: raagaName,
              songName: songName,
              lyric: lyric,
            ),
          ),
        );
      },

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF5A2A8F),
              width: 0.6,
            ),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Text(
              raagaName,
              style: const TextStyle(
                color: Color(0xFFD6C6FF),
                fontSize: 16,
              ),
            ),

            Container(
              height: 26,
              width: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD6C6FF),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFD6C6FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}