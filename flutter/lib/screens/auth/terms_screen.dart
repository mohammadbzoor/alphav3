import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFB), // لون خلفية فاتح جداً
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Terms & Conditions",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                    ),
                    const SizedBox(height: 8),
                    const Text("Last updated: July 2026", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    
                    // بطاقة الالتزام
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Color(0xFF004D40), size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text("Our commitment to you", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                SizedBox(height: 5),
                                Text("Your financial data is fully encrypted and never sold or shared with any third party, under any circumstance", 
                                  style: TextStyle(fontSize: 13, color: Colors.black87)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // فقرات الشروط
                    _buildSection("1. Using the App", "By using Basira, you agree to use the app for personal purposes only, to manage your own finances in accordance with applicable local regulations."),
                    _buildSection("2. Data Collection", "We collect the income, expense, and goal data you enter yourself, plus scanned receipt data, to provide analysis and advice tailored to you alone."),
                    _buildSection("3. AI & Recommendations", "Advice from Basira consists of guiding information and should not replace a licensed financial advisor for major decisions."),
                  ],
                ),
              ),
            ),
            
            // زر الرجوع
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it, go back", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5)),
        ],
      ),
    );
  }
}