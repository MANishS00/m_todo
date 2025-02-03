import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(
    create: (context) => TodoProvider()..loadTasks(),
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TodoScreen(),
    );
  }
}

class TodoScreen extends StatefulWidget {
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  bool isThumbsUp = true;

  void toggleIcon() {
    setState(() {
      isThumbsUp = !isThumbsUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      appBar: AppBar(
        toolbarHeight: 150,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Manage Your",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                "Task",
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadiusDirectional.circular(20),
                  color: Colors.grey,
                ),
                child: IconButton(
                  icon: Icon(
                    isThumbsUp ? Icons.thumb_up : Icons.thumb_down,
                    size: 50,
                  ),
                  onPressed: toggleIcon,
                ),
              ),
            ),
          )
        ],
        backgroundColor: Colors.black,
      ),
      body: Consumer<TodoProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.tasks.length,
            itemBuilder: (context, index) {
              final task = provider.tasks[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        provider.toggleTaskCompletion(index);
                      },
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: Colors.white,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (task.dateTime != null)
                          Text(
                            "Due:        ${DateFormat('dd- MMM- yy ||  hh:mm a').format(task.dateTime!)}",
                            style: TextStyle(color: Colors.white70, fontSize: 12,fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _showTaskDialog(context, task, index);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            provider.deleteTask(index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.today_outlined),
        onPressed: () {
          _showTaskDialog(context, null, null);
        },
      ),
    );
  }
}

void _showTaskDialog(BuildContext context, Task? task, int? index) {
  final TextEditingController controller = TextEditingController(text: task?.title);
  DateTime? selectedDateTime = task?.dateTime;

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: selectedDateTime != null
            ? TimeOfDay.fromDateTime(selectedDateTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(task == null ? "Add Task" : "Edit Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller),
            SizedBox(height: 10),
            TextButton(
              onPressed: _pickDateTime,
              child: Text(selectedDateTime == null
                  ? "Pick Date & Time"
                  : DateFormat('dd-MM-yy hh:mm a').format(selectedDateTime!)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (task == null) {
                  Provider.of<TodoProvider>(context, listen: false)
                      .addTask(controller.text, selectedDateTime);
                } else {
                  Provider.of<TodoProvider>(context, listen: false)
                      .editTask(index!, controller.text, selectedDateTime);
                }
                Navigator.pop(context);
              }
            },
            child: Text("Save"),
          ),
        ],
      );
    },
  );
}

class Task {
  String title;
  bool isCompleted;
  DateTime? dateTime;

  Task(this.title, {this.isCompleted = false, this.dateTime});

  Map<String, dynamic> toJson() => {
    'title': title,
    'isCompleted': isCompleted,
    'dateTime': dateTime?.toIso8601String(),
  };

  static Task fromJson(Map<String, dynamic> json) => Task(
    json['title'],
    isCompleted: json['isCompleted'] ?? false,
    dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : null,
  );
}

class TodoProvider extends ChangeNotifier {
  List<Task> tasks = [];

  void addTask(String title, DateTime? dateTime) {
    tasks.add(Task(title, dateTime: dateTime));
    saveTasks();
    notifyListeners();
  }

  void editTask(int index, String title, DateTime? dateTime) {
    tasks[index] = Task(title, isCompleted: tasks[index].isCompleted, dateTime: dateTime);
    saveTasks();
    notifyListeners();
  }

  void deleteTask(int index) {
    tasks.removeAt(index);
    saveTasks();
    notifyListeners();
  }

  void toggleTaskCompletion(int index) {
    tasks[index].isCompleted = !tasks[index].isCompleted;
    saveTasks();
    notifyListeners();
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    prefs.setString('tasks', jsonEncode(tasksJson));
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;  // Check if the user is new

    if (isFirstTime) {
      tasks = [];  // Start with an empty list
      prefs.setBool('isFirstTime', false);  // Mark as not a first-time user
    } else {
      final tasksString = prefs.getString('tasks');
      if (tasksString != null) {
        final List<dynamic> tasksJson = jsonDecode(tasksString);
        tasks = tasksJson.map((json) => Task.fromJson(json)).toList();
      }
    }
    notifyListeners();
  }
}
