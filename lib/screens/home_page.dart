import 'package:flutter/material.dart';


class HomePage extends StatelessWidget {


const HomePage({super.key});


@override
Widget build(BuildContext context){

return Scaffold(

appBar:AppBar(
title:const Text("Pass Managers"),
),


body:const Center(

child:Text(
"Home Page - Ready",
style:TextStyle(
fontSize:25
),
),

),

);

}

}
