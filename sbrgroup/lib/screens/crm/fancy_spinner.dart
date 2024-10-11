import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class FancySpinner extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const FancySpinner({required this.child, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/assets/images/ajna.png', // Adjust the path according to your project structure
                  width: 40, // Adjust the width of the logo as needed
                ),
                const SizedBox(height: 10),
                const SpinKitFadingCube(
                  color: Color.fromRGBO(6, 73, 105, 1),
                  size: 15.0,
                ),
                const SizedBox(height: 20),
                AnimatedText(),
              ],
            ),
          ),
      ],
    );
  }
}

class AnimatedText extends StatefulWidget {
  @override
  _AnimatedTextState createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Text(
            'AJNA: Loading...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        );
      },
    );
  }
}
