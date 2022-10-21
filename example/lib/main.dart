import 'package:flutter/material.dart';
import 'package:slide_view/slide_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  var slideView = GlobalKey<SlideViewState>();

  void _incrementCounter() {
    slideView.currentState?.change(true).then((value) {
      print("ok");
    });
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    var home = Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
    return SlideView(
      key: slideView,
      //curve: Curves.fastLinearToSlowEaseIn,
      //duration: Duration(milliseconds: 2000),
      background: home,
      // ignore: sort_child_properties_last
      child: Container(
        color: Colors.amber,
        child: const Center(child: Text("Hello")),
      ),
      collapsedChild: Container(
        color: Colors.yellow,
        child: Center(
          child: TextButton(
              onPressed: () => slideView.currentState?.change(true),
              child: const Text("Slide up")),
        ),
      ),
      onChange: ((isOpen) {
        print("changed to: $isOpen");
      }),
    );
  }
}
