import 'package:flutter/material.dart';
import 'package:ajna/screens/home_screen.dart';

class SuccessScreen extends StatefulWidget {
  @override
  _SuccessScreenState createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
    return false; // Prevents the default back button behavior
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsiveness
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove the back arrow
          backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
          title: const Text(
            'Success',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.06), // Dynamic padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: screenSize.width * 0.3, // Dynamic icon size
                  ),
                ),
                SizedBox(height: screenSize.height * 0.04), // Dynamic spacing
                Text(
                  'Data submitted successfully!',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.06, // Dynamic text size
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenSize.height * 0.04), // Dynamic spacing
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color.fromRGBO(6, 73, 105, 1), // Button color
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.12, // Dynamic padding
                      vertical: screenSize.height * 0.02, // Dynamic padding
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: Text(
                    'Go to Home Screen',
                    style: TextStyle(
                      fontSize: screenSize.width * 0.045, // Dynamic text size
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
