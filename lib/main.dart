import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    //final bool isDesktop = screenWidth >= 900;

    return MaterialApp(
      home: Scaffold(backgroundColor: Colors.white, body: 
      Center(child: 
      IntrinsicWidth(child: 
      Column(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.stretch, children: 
      [
        SvgPicture.asset(
          'assets/svg/main.svg',
          height: screenHeight/2,
        ),
        SizedBox(
          width: 0,
          child: Text('Добро пожаловать в Scoot!', style: TextStyle(fontSize: screenHeight/25, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 6, 43, 35))),
        ),
        SizedBox(
          width: (screenHeight/2*589/530)*0.8,
          child: Text('Безопасные поездки начинаются с проверки', style: TextStyle(fontSize: screenHeight/40, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 6, 43, 35))),
        ),
        Container(
          width: (screenHeight/2*589/530)*0.8,
        )
        ],
        ),
        )
      )),
    );
  }
}
