import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider())
      ],
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class Task {
  final String id;
  final String task;
  final bool completed;

  Task({required this.id, required this.task, required this.completed});

  factory Task.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id, 
      task: data['task'] ?? '', 
      completed: data['completed'] ?? false,
    );
  }
}

class TaskProvider extends ChangeNotifier {
  final _tasksRef = FirebaseFirestore.instance.collection('tasks');

  Stream<List<Task>> getTasks() {
    return _tasksRef
        .orderBy('createAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Task.fromDoc(doc)).toList());
  }

  Future<void> addTask(String task) async {
    await _tasksRef.add({
      'task': task,
      'completed': false,
      'createAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTask(Task task) async {
    await _tasksRef.doc(task.id).update({'completed': !task.completed});
  }

  Future<void> deleteTask(String id) async {
    await _tasksRef.doc(id).delete();
  }
  
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key,});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final TextEditingController taskcontroller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(20),
        color: Colors.white,
        child: Column(
          children: [
            Text(
              'To Do List',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(102, 103, 170, 1)
              ),
            ),
            SizedBox(height: 20,),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskcontroller,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Enter Task',
                    ),
                  ),
                ),
                SizedBox(width: 15,),
                Container(
                  alignment: Alignment.center,
                  height: 40,
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Color.fromRGBO(102, 103, 170, 1)
                  ),
                  child: TextButton(
                    onPressed: () async {
                      if (taskcontroller.text.trim().isNotEmpty) {
                        await taskProvider.addTask(taskcontroller.text.trim());
                        taskcontroller.clear();
                      }
                    },
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                      ),
                    )
                  ),
                )
              ],
            ),
            SizedBox(height: 20,),
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: taskProvider.getTasks(), 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(),);
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No tasks yet'),);
                  }

                  final tasks = snapshot.data!;

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return ListTile(
                        leading: Checkbox(
                          value: task.completed,
                          onChanged: (_) => taskProvider.toggleTask(task),
                        ),
                        title: Text(
                          task.task,
                          style: TextStyle(
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red,),
                          onPressed: () => taskProvider.deleteTask(task.id),
                        ),
                      );
                    },
                  );
                }
              ),
            )
          ],
        ),
      ),
    );
  }
}
