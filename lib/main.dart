import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const accent = Color(0xFFFF6B35);
const darkBg = Color(0xFF0B0B0F);
const darkCard = Color(0xFF1B1B23);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GainStore();
  await store.load();
  runApp(GainTrackApp(store: store));
}

class GainStore extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool onboarded = false;
  bool dark = true;
  String unit = 'kg';
  String name = '';
  String goal = 'Build Muscle';
  double height = 170;
  double goalWeight = 70;
  List<WeightEntry> weights = [];
  List<WorkoutLog> history = [];
  List<WorkoutPlan> customPlans = [];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('gaintrack_data');
    if (raw == null) return;
    final d = jsonDecode(raw);
    onboarded = d['onboarded'] ?? false;
    dark = d['dark'] ?? true;
    unit = d['unit'] ?? 'kg';
    name = d['name'] ?? '';
    goal = d['goal'] ?? 'Build Muscle';
    height = (d['height'] ?? 170).toDouble();
    goalWeight = (d['goalWeight'] ?? 70).toDouble();
    weights = ((d['weights'] ?? []) as List).map((e) => WeightEntry.fromJson(e)).toList();
    history = ((d['history'] ?? []) as List).map((e) => WorkoutLog.fromJson(e)).toList();
    customPlans = ((d['customPlans'] ?? []) as List).map((e) => WorkoutPlan.fromJson(e)).toList();
  }

  Future<void> save() async {
    await _prefs?.setString('gaintrack_data', jsonEncode({
      'onboarded': onboarded, 'dark': dark, 'unit': unit, 'name': name,
      'goal': goal, 'height': height, 'goalWeight': goalWeight,
      'weights': weights.map((e) => e.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
      'customPlans': customPlans.map((e) => e.toJson()).toList(),
    }));
    notifyListeners();
  }

  double get currentWeight => weights.isEmpty ? 0 : weights.last.weight;
  int get totalWorkouts => history.length;
  int get totalSets => history.fold(0, (a, b) => a + b.completedSets);
  int get streak {
    if (history.isEmpty) return 0;
    final days = history.map((e) => DateUtils.dateOnly(e.date)).toSet().toList()..sort((a,b)=>b.compareTo(a));
    int count = 0;
    var cursor = DateUtils.dateOnly(DateTime.now());
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  void finishOnboarding({required String n, required double h, required double w, required double g, required String fitnessGoal}) {
    name = n; height = h; goalWeight = g; goal = fitnessGoal; onboarded = true;
    weights = [WeightEntry(DateTime.now(), w)];
    save();
  }

  void addWeight(double weight) {
    weights.add(WeightEntry(DateTime.now(), weight));
    save();
  }

  void addWorkout(WorkoutLog log) {
    history.add(log);
    save();
  }

  void addCustomPlan(WorkoutPlan plan) {
    customPlans.add(plan);
    save();
  }

  void updateSettings({bool? isDark, String? newUnit, String? newName, String? newGoal, double? newHeight, double? newGoalWeight}) {
    dark = isDark ?? dark;
    unit = newUnit ?? unit;
    name = newName ?? name;
    goal = newGoal ?? goal;
    height = newHeight ?? height;
    goalWeight = newGoalWeight ?? goalWeight;
    save();
  }
}

class WeightEntry {
  final DateTime date;
  final double weight;
  WeightEntry(this.date, this.weight);
  Map<String,dynamic> toJson()=>{'date':date.toIso8601String(),'weight':weight};
  factory WeightEntry.fromJson(Map<String,dynamic> j)=>WeightEntry(DateTime.parse(j['date']), (j['weight']).toDouble());
}

class Exercise {
  final String name;
  final String muscle;
  final int sets;
  final int reps;
  Exercise(this.name, this.muscle, this.sets, this.reps);
  Map<String,dynamic> toJson()=>{'name':name,'muscle':muscle,'sets':sets,'reps':reps};
  factory Exercise.fromJson(Map<String,dynamic> j)=>Exercise(j['name'],j['muscle'],j['sets'],j['reps']);
}

class WorkoutPlan {
  final String id, name, description;
  final List<Exercise> exercises;
  WorkoutPlan(this.id, this.name, this.description, this.exercises);
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'description':description,'exercises':exercises.map((e)=>e.toJson()).toList()};
  factory WorkoutPlan.fromJson(Map<String,dynamic> j)=>WorkoutPlan(j['id'],j['name'],j['description'],(j['exercises'] as List).map((e)=>Exercise.fromJson(e)).toList());
}

class WorkoutLog {
  final String id, planName;
  final DateTime date;
  final int completedSets;
  final int durationMinutes;
  final Map<String, List<SetLog>> sets;
  WorkoutLog(this.id,this.planName,this.date,this.completedSets,this.durationMinutes,this.sets);
  Map<String,dynamic> toJson()=>{'id':id,'planName':planName,'date':date.toIso8601String(),'completedSets':completedSets,'durationMinutes':durationMinutes,'sets':sets.map((k,v)=>MapEntry(k,v.map((x)=>x.toJson()).toList()))};
  factory WorkoutLog.fromJson(Map<String,dynamic> j)=>WorkoutLog(j['id'],j['planName'],DateTime.parse(j['date']),j['completedSets'],j['durationMinutes'],(j['sets'] as Map).map((k,v)=>MapEntry(k,(v as List).map((x)=>SetLog.fromJson(x)).toList())));
}

class SetLog {
  final int reps;
  final double weight;
  final bool done;
  SetLog(this.reps,this.weight,this.done);
  Map<String,dynamic> toJson()=>{'reps':reps,'weight':weight,'done':done};
  factory SetLog.fromJson(Map<String,dynamic> j)=>SetLog(j['reps'],(j['weight']).toDouble(),j['done']);
}

List<WorkoutPlan> builtInPlans() => [
  WorkoutPlan('push','Push Day','Chest • Shoulders • Triceps',[
    Exercise('Bench Press','Chest',4,8), Exercise('Incline Dumbbell Press','Chest',3,10),
    Exercise('Shoulder Press','Shoulders',3,10), Exercise('Lateral Raise','Shoulders',3,12),
    Exercise('Tricep Pushdown','Triceps',3,12)]),
  WorkoutPlan('pull','Pull Day','Back • Biceps',[
    Exercise('Lat Pulldown','Back',4,10),Exercise('Seated Row','Back',3,10),
    Exercise('Face Pull','Back',3,15),Exercise('Bicep Curl','Biceps',3,12),
    Exercise('Hammer Curl','Biceps',3,12)]),
  WorkoutPlan('legs','Leg Day','Quads • Hamstrings • Calves',[
    Exercise('Squat','Legs',4,8),Exercise('Leg Press','Legs',3,10),
    Exercise('Romanian Deadlift','Hamstrings',3,10),Exercise('Leg Curl','Hamstrings',3,12),
    Exercise('Calf Raise','Calves',4,15)]),
  WorkoutPlan('upper','Upper Body','Chest • Back • Shoulders • Arms',[
    Exercise('Bench Press','Chest',3,8),Exercise('Lat Pulldown','Back',3,10),
    Exercise('Shoulder Press','Shoulders',3,10),Exercise('Bicep Curl','Biceps',3,12)]),
  WorkoutPlan('lower','Lower Body','Legs • Glutes • Calves',[
    Exercise('Squat','Legs',4,8),Exercise('Leg Press','Legs',3,12),
    Exercise('Leg Curl','Hamstrings',3,12),Exercise('Calf Raise','Calves',4,15)]),
  WorkoutPlan('full','Full Body','Whole body workout',[
    Exercise('Squat','Legs',3,10),Exercise('Bench Press','Chest',3,10),
    Exercise('Seated Row','Back',3,10),Exercise('Shoulder Press','Shoulders',3,10)])
];

class GainTrackApp extends StatelessWidget {
  final GainStore store;
  const GainTrackApp({super.key, required this.store});
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_,__) => MaterialApp(
      debugShowCheckedModeBanner:false,
      title:'GainTrack',
      theme: ThemeData(
        useMaterial3:true,
        brightness: store.dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor:accent, brightness:store.dark?Brightness.dark:Brightness.light),
        scaffoldBackgroundColor: store.dark ? darkBg : const Color(0xFFF7F7F8),
        cardTheme: CardThemeData(color:store.dark?darkCard:Colors.white, elevation:0, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
      ),
      home: store.onboarded ? Shell(store:store) : Onboarding(store:store),
    ),
  );
}

class Onboarding extends StatefulWidget {
  final GainStore store;
  const Onboarding({super.key,required this.store});
  @override State<Onboarding> createState()=>_OnboardingState();
}
class _OnboardingState extends State<Onboarding>{
  int page=0;
  final name=TextEditingController(), height=TextEditingController(text:'170'), weight=TextEditingController(), target=TextEditingController();
  String goal='Build Muscle';
  @override Widget build(BuildContext context){
    final titles=['Welcome to GainTrack','Your body','Your goal'];
    return Scaffold(body:SafeArea(child:Padding(
      padding:const EdgeInsets.all(28),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Spacer(), Text('GAINTRACK',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:3)),
        const SizedBox(height:18), Text(titles[page],style:Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        if(page==0)...[
          const Text('A complete workout and progress tracker built to help you stay consistent.'),
          const SizedBox(height:24), field(name,'Your name',TextInputType.name)],
        if(page==1)...[
          field(height,'Height (cm)',TextInputType.number),const SizedBox(height:12),
          field(weight,'Current weight (kg)',TextInputType.number)],
        if(page==2)...[
          field(target,'Goal weight (kg)',TextInputType.number),const SizedBox(height:18),
          Wrap(spacing:8,runSpacing:8,children:['Build Muscle','Lose Fat','Stay Fit','Get Stronger'].map((x)=>ChoiceChip(label:Text(x),selected:goal==x,onSelected:(_)=>setState(()=>goal=x))).toList())],
        const Spacer(),
        FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,minimumSize:const Size.fromHeight(56)),
          onPressed:(){
            if(page<2){setState(()=>page++);return;}
            final w=double.tryParse(weight.text)??0, g=double.tryParse(target.text)??0, h=double.tryParse(height.text)??170;
            if(name.text.trim().isEmpty||w<=0||g<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please complete all required fields')));return;}
            widget.store.finishOnboarding(n:name.text.trim(),h:h,w:w,g:g,fitnessGoal:goal);
          },child:Text(page==2?'START MY JOURNEY':'CONTINUE'))
      ]))));
  }
}

Widget field(TextEditingController c,String label,TextInputType type)=>TextField(controller:c,keyboardType:type,decoration:InputDecoration(labelText:label,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16))));

class Shell extends StatefulWidget {
  final GainStore store;
  const Shell({super.key,required this.store});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell>{
  int tab=0;
  @override Widget build(BuildContext context){
    final pages=[HomePage(store:widget.store,onWorkout:()=>setState(()=>tab=1)),WorkoutPage(store:widget.store),ProgressPage(store:widget.store),ProfilePage(store:widget.store)];
    return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(
      selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
      destinations:const[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.fitness_center_outlined),selectedIcon:Icon(Icons.fitness_center),label:'Workout'),
        NavigationDestination(icon:Icon(Icons.insights_outlined),selectedIcon:Icon(Icons.insights),label:'Progress'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
      ]));
  }
}

class HomePage extends StatelessWidget {
  final GainStore store; final VoidCallback onWorkout;
  const HomePage({super.key,required this.store,required this.onWorkout});
  @override Widget build(BuildContext context){
    final plan=builtInPlans().first;
    final progress=store.goalWeight==0?0:(store.currentWeight/store.goalWeight).clamp(0.0,1.0);
    return ListView(padding:const EdgeInsets.all(20),children:[
      Text('GAINTRACK',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:3)),
      const SizedBox(height:8),Text('Hi, ${store.name} 👋',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:20),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('🔥 ${store.streak} DAY STREAK',style:const TextStyle(color:accent,fontWeight:FontWeight.bold)),
        const SizedBox(height:20),Text('CURRENT WEIGHT',style:Theme.of(context).textTheme.labelLarge),
        Text(store.currentWeight==0?'Add weight':'${store.currentWeight.toStringAsFixed(1)} ${store.unit.toUpperCase()}',style:Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:8),Text('Goal: ${store.goalWeight.toStringAsFixed(1)} ${store.unit.toUpperCase()}'),
        const SizedBox(height:12),LinearProgressIndicator(value:progress,color:accent,minHeight:10,borderRadius:BorderRadius.circular(20))
      ])),
      sectionTitle(context,'TODAY’S WORKOUT'),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('💪 ${plan.name.toUpperCase()}',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),Text(plan.description),
        const SizedBox(height:16),FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,minimumSize:const Size.fromHeight(52)),onPressed:onWorkout,child:const Text('START WORKOUT'))
      ])),
      sectionTitle(context,'YOUR STATS'),
      Row(children:[Expanded(child:miniStat(context,'WORKOUTS','${store.totalWorkouts}')),const SizedBox(width:12),Expanded(child:miniStat(context,'TOTAL SETS','${store.totalSets}'))])
    ]);
  }
}
Widget sectionTitle(BuildContext c,String t)=>Padding(padding:const EdgeInsets.only(top:20,bottom:10),child:Text(t,style:Theme.of(c).textTheme.labelLarge?.copyWith(letterSpacing:2)));
Widget miniStat(BuildContext c,String a,String b)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:Theme.of(c).textTheme.labelSmall),const SizedBox(height:8),Text(b,style:Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold))])));

class WorkoutPage extends StatelessWidget {
  final GainStore store;
  const WorkoutPage({super.key,required this.store});
  @override Widget build(BuildContext context){
    final plans=[...builtInPlans(),...store.customPlans];
    return ListView(padding:const EdgeInsets.all(20),children:[
      Text('WORKOUTS',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:6),const Text('Choose a plan or create your own.'),
      ...plans.map((p)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(16),leading:CircleAvatar(backgroundColor:accent.withOpacity(.18),child:const Icon(Icons.fitness_center,color:accent)),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${p.description}\n${p.exercises.length} exercises'),isThreeLine:true,trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>WorkoutSession(store:store,plan:p)))))),
      const SizedBox(height:10),
      OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CustomWorkoutPage(store:store))),icon:const Icon(Icons.add),label:const Text('CREATE CUSTOM WORKOUT'))
    ]);
  }
}

class WorkoutSession extends StatefulWidget {
  final GainStore store; final WorkoutPlan plan;
  const WorkoutSession({super.key,required this.store,required this.plan});
  @override State<WorkoutSession> createState()=>_WorkoutSessionState();
}
class _WorkoutSessionState extends State<WorkoutSession>{
  late Map<String,List<SetLog>> data;
  late DateTime started;
  int rest=0;
  @override void initState(){super.initState();started=DateTime.now();data={for(final e in widget.plan.exercises)e.name:List.generate(e.sets,(_)=>SetLog(e.reps,0,false))};}
  int get done=>data.values.expand((x)=>x).where((x)=>x.done).length;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.plan.name)),body:ListView(padding:const EdgeInsets.all(16),children:[
    Text(widget.plan.description),
    ...widget.plan.exercises.map((e)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(e.name,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),Text('${e.muscle} • ${e.sets} sets × ${e.reps} reps'),
      const SizedBox(height:10),
      ...List.generate(e.sets,(i){final s=data[e.name]![i];return Row(children:[
        SizedBox(width:54,child:Text('Set ${i+1}')),
        Expanded(child:TextField(keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Reps',hintText:'${s.reps}'),onChanged:(v)=>data[e.name]![i]=SetLog(int.tryParse(v)??s.reps,s.weight,s.done))),
        const SizedBox(width:8),Expanded(child:TextField(keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Weight'),onChanged:(v)=>data[e.name]![i]=SetLog(s.reps,double.tryParse(v)??0,s.done))),
        Checkbox(value:s.done,onChanged:(v)=>setState(()=>data[e.name]![i]=SetLog(s.reps,s.weight,v??false)))
      ]);})
    ])))),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
      Text('REST TIMER',style:Theme.of(context).textTheme.labelLarge),Text('${rest ~/ 60}:${(rest%60).toString().padLeft(2,'0')}',style:Theme.of(context).textTheme.displaySmall),
      Wrap(spacing:8,children:[30,60,90,120].map((s)=>OutlinedButton(onPressed:()=>setState(()=>rest=s),child:Text('${s}s'))).toList())
    ])),
    FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,minimumSize:const Size.fromHeight(56)),onPressed:done==0?null:(){
      final mins=DateTime.now().difference(started).inMinutes.clamp(1,999);
      widget.store.addWorkout(WorkoutLog(DateTime.now().microsecondsSinceEpoch.toString(),widget.plan.name,DateTime.now(),done,mins,data));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Workout saved! Great job 🔥')));
      Navigator.pop(context);
    },child:Text('FINISH WORKOUT ($done SETS)'))
  ]));
}

class ProgressPage extends StatelessWidget {
  final GainStore store;
  const ProgressPage({super.key,required this.store});
  @override Widget build(BuildContext context){
    return ListView(padding:const EdgeInsets.all(20),children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('PROGRESS',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),IconButton(icon:const Icon(Icons.add_circle_outline),onPressed:()=>_weightDialog(context,store))]),
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('WEIGHT HISTORY',style:Theme.of(context).textTheme.labelLarge),const SizedBox(height:12),
        SizedBox(height:210,child:store.weights.length<2?const Center(child:Text('Add at least 2 weight entries to see your chart.')):LineChart(LineChartData(gridData:const FlGridData(show:true),titlesData:const FlTitlesData(show:true,rightTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),topTitles:AxisTitles(sideTitles:SideTitles(showTitles:false))),lineBarsData:[LineChartBarData(spots:List.generate(store.weights.length,(i)=>FlSpot(i.toDouble(),store.weights[i].weight)),isCurved:true,color:accent,barWidth:4,dotData:const FlDotData(show:true))]))),
      ])),
      sectionTitle(context,'WORKOUT HISTORY'),
      if(store.history.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('No workouts yet. Start your first workout!'))),
      ...store.history.reversed.map((h)=>Card(child:ListTile(leading:const Icon(Icons.check_circle,color:accent),title:Text(h.planName),subtitle:Text('${h.date.day}/${h.date.month}/${h.date.year} • ${h.durationMinutes} min'),trailing:Text('${h.completedSets} sets')))),
      sectionTitle(context,'PERSONAL BESTS'),
      ..._pbs(store).entries.map((e)=>Card(child:ListTile(title:Text(e.key),trailing:Text('${e.value.toStringAsFixed(1)} kg',style:const TextStyle(fontWeight:FontWeight.bold,color:accent)))))
    ]);
  }
}
Map<String,double> _pbs(GainStore s){final r=<String,double>{};for(final h in s.history){h.sets.forEach((k,v){for(final x in v){if(x.done&&x.weight>(r[k]??0))r[k]=x.weight;}});}return r;}
void _weightDialog(BuildContext c,GainStore s){final t=TextEditingController();showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Add weight'),content:TextField(controller:t,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Weight (${s.unit})')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('CANCEL')),FilledButton(onPressed:(){final w=double.tryParse(t.text);if(w!=null&&w>0){s.addWeight(w);Navigator.pop(c);}},child:const Text('SAVE'))]));}

class ProfilePage extends StatelessWidget {
  final GainStore store;
  const ProfilePage({super.key,required this.store});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
    Text('PROFILE',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
    Card(child:ListTile(leading:const CircleAvatar(radius:28,child:Icon(Icons.person,size:30)),title:Text(store.name,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20)),subtitle:Text(store.goal))),
    sectionTitle(context,'SETTINGS'),
    Card(child:Column(children:[
      SwitchListTile(title:const Text('Dark mode'),secondary:const Icon(Icons.dark_mode),value:store.dark,onChanged:(v)=>store.updateSettings(isDark:v)),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.straighten),title:const Text('Units'),trailing:DropdownButton<String>(value:store.unit,items:['kg','lb'].map((u)=>DropdownMenuItem(value:u,child:Text(u.toUpperCase()))).toList(),onChanged:(v){if(v!=null)store.updateSettings(newUnit:v);})),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.edit),title:const Text('Edit profile'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EditProfile(store:store)))),
    ])),
    sectionTitle(context,'APP'),
    const Card(child:Column(children:[ListTile(leading:Icon(Icons.privacy_tip_outlined),title:Text('Privacy'),subtitle:Text('Your fitness data stays on this device in the current version.')),ListTile(leading:Icon(Icons.info_outline),title:Text('GainTrack'),subtitle:Text('Version 1.0.0'))]))
  ]);
}

class EditProfile extends StatefulWidget{final GainStore store;const EditProfile({super.key,required this.store});@override State<EditProfile> createState()=>_EditProfileState();}
class _EditProfileState extends State<EditProfile>{late TextEditingController n,h,g;late String goal;@override void initState(){super.initState();n=TextEditingController(text:widget.store.name);h=TextEditingController(text:widget.store.height.toString());g=TextEditingController(text:widget.store.goalWeight.toString());goal=widget.store.goal;}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Edit profile')),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[field(n,'Name',TextInputType.name),const SizedBox(height:12),field(h,'Height (cm)',TextInputType.number),const SizedBox(height:12),field(g,'Goal weight',TextInputType.number),const SizedBox(height:12),DropdownButtonFormField(value:goal,items:['Build Muscle','Lose Fat','Stay Fit','Get Stronger'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>goal=v??goal),const Spacer(),FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,minimumSize:const Size.fromHeight(54)),onPressed:(){widget.store.updateSettings(newName:n.text,newHeight:double.tryParse(h.text),newGoalWeight:double.tryParse(g.text),newGoal:goal);Navigator.pop(c);},child:const Text('SAVE CHANGES'))])));}
class CustomWorkoutPage extends StatefulWidget{final GainStore store;const CustomWorkoutPage({super.key,required this.store});@override State<CustomWorkoutPage> createState()=>_CustomWorkoutPageState();}
class _CustomWorkoutPageState extends State<CustomWorkoutPage>{final name=TextEditingController(),desc=TextEditingController();final exName=TextEditingController(),sets=TextEditingController(text:'3'),reps=TextEditingController(text:'10');List<Exercise> ex=[];@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Custom workout')),body:ListView(padding:const EdgeInsets.all(20),children:[field(name,'Workout name',TextInputType.name),const SizedBox(height:10),field(desc,'Description',TextInputType.name),const SizedBox(height:20),Text('EXERCISES',style:Theme.of(c).textTheme.labelLarge),...ex.map((e)=>Card(child:ListTile(title:Text(e.name),subtitle:Text('${e.sets} × ${e.reps}')))),field(exName,'Exercise name',TextInputType.name),const SizedBox(height:8),Row(children:[Expanded(child:field(sets,'Sets',TextInputType.number)),const SizedBox(width:8),Expanded(child:field(reps,'Reps',TextInputType.number))]),OutlinedButton.icon(onPressed:(){if(exName.text.trim().isNotEmpty)setState(()=>ex.add(Exercise(exName.text.trim(),'Custom',int.tryParse(sets.text)??3,int.tryParse(reps.text)??10)));exName.clear();},icon:const Icon(Icons.add),label:const Text('ADD EXERCISE')),const SizedBox(height:18),FilledButton(style:FilledButton.styleFrom(backgroundColor:accent,minimumSize:const Size.fromHeight(54)),onPressed:(){if(name.text.trim().isNotEmpty&&ex.isNotEmpty){widget.store.addCustomPlan(WorkoutPlan(DateTime.now().microsecondsSinceEpoch.toString(),name.text.trim(),desc.text.trim(),ex));Navigator.pop(c);}},child:const Text('SAVE WORKOUT'))]));}
