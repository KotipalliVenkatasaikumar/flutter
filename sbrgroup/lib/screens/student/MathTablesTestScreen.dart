import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MathTablesTestScreen extends StatefulWidget {
  @override
  _MathTablesTestScreenState createState() => _MathTablesTestScreenState();
}

class _MathTablesTestScreenState extends State<MathTablesTestScreen> {
  final TextEditingController _answerController = TextEditingController();
  ConfettiController _confettiController = ConfettiController(
      duration: const Duration(seconds: 4)); // Initialize confetti controller
  late FlutterTts _flutterTts;
  int tableNumber = 1;
  int multiplier = 1;
  int correctAnswer = 0;
  int attemptCount = 0;
  String message = '';
  bool _isValidAnswer = false;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    setVoice();
    _confettiController = ConfettiController(
        duration: const Duration(seconds: 4)); // Initialize confetti controller
    _generateQuestion();

    // Listen to changes in the text field to update button state
    _answerController.addListener(() {
      setState(() {
        _isValidAnswer = _isNumber(_answerController.text);
      });
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _flutterTts.stop();
    _confettiController.dispose();
    super.dispose();
  }

  void _generateQuestion() {
    setState(() {
      tableNumber = Random().nextInt(9) + 1;
      multiplier = Random().nextInt(10) + 1;
      correctAnswer = tableNumber * multiplier;
      attemptCount = 0;
      message = '';
      _answerController.clear();
    });
  }

  Future<void> setVoice() async {
    // Set the language to Hindi (India)
    await _flutterTts.setLanguage("hi-IN");

    // Adjust pitch and speech rate for clarity
    await _flutterTts.setPitch(0.8); // Slightly lower pitch for a natural tone
    await _flutterTts.setSpeechRate(0.5); // A bit slower for better clarity

    // Set the voice to Google Hindi, with fallback in case it’s unavailable
    try {
      await _flutterTts.setVoice({'name': 'Google हिन्दी', 'locale': 'hi-IN'});
    } catch (e) {
      // Fallback to the default voice if Google Hindi is not available
      print("Google Hindi voice not available: $e");
    }
  }

  Future<void> _answerMsg() async {
    await _flutterTts.setSpeechRate(0.5); // Slower rate for better clarity
    String answerText = 'Very Good';
    String instructionText = 'Now, answer the next question';

    // Speak "Very Good" first
    await _flutterTts.speak(answerText);

    // Set up the completion handler for the second message
    _flutterTts.setCompletionHandler(() async {
      // Speak "Now, answer the next question" after "Very Good"
      await _flutterTts.speak(instructionText);

      // Reset the completion handler to avoid unwanted behavior in future calls
      _flutterTts.setCompletionHandler(() {});
    });
  }

  Future<void> _speakCorrectAnswer() async {
    await _flutterTts.setSpeechRate(0.5); // Slower rate for better clarity
    String answerText = '$tableNumber times $multiplier equals $correctAnswer.';
    _isValidAnswer = false;

    for (int i = 0; i < 3; i++) {
      // Speak the answer
      await _flutterTts.speak(answerText);

      // Wait for the speech to finish
      bool isSpeaking = true;
      _flutterTts.setCompletionHandler(() {
        isSpeaking = false;
      });

      // Ensure the loop waits until the current speech is complete
      while (isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Add a delay before repeating the message
      await Future.delayed(const Duration(seconds: 1));
    }

    // Reset the completion handler after finishing the loop
    _flutterTts.setCompletionHandler(() {});
  }

  Future<void> _checkAnswer() async {
    int? userAnswer = int.tryParse(_answerController.text);
    if (userAnswer == correctAnswer) {
      setState(() {
        message = '🎉 Hooray! You got it right!';
        _answerMsg();
      });
      // Start the confetti animation
      _confettiController.play();
      await Future.delayed(const Duration(seconds: 2));
      _generateQuestion();
    } else {
      setState(() {
        attemptCount++;
        if (attemptCount == 1) {
          message = '❌ Oops! That\'s incorrect. Listen to the correct answer.';
        } else {
          message = '❌ Keep trying: What is $tableNumber × $multiplier?';
        }
      });
      if (attemptCount == 1) {
        await _speakCorrectAnswer();
      }
    }
  }

  bool _isNumber(String value) {
    // Check if the value is a number (allows decimal points if needed)
    return RegExp(r'^\d+(\.\d+)?$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 231, 245, 254),
      appBar: AppBar(
        title: const Text(
          'Math Quiz',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color.fromRGBO(6, 73, 105, 1),
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'What is $tableNumber × $multiplier?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(251, 86, 90, 1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _answerController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Enter your answer',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      prefixIcon: const Icon(
                        Icons.question_mark,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isValidAnswer
                        ? () async {
                            await _checkAnswer();
                          }
                        : null, // Button is only enabled when _isValidAnswer is true
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Submit Answer',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (message.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: message.contains('Hooray!')
                              ? Colors.green
                              : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Spacer(),
                  Image.asset(
                    'lib/assets/images/child_playing.png', // Fun image of a child playing
                    height: 250, // Increased size for a better view
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow
              ],
            ),
          ),
        ],
      ),
    );
  }
}
