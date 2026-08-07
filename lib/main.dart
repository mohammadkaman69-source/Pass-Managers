import 'package:flutter/material.dart';
import 'screens/login_page.dart';


void main(){

runApp(
const PassManagers()
);

}



class PassManagers extends StatelessWidget{

const PassManagers({super.key});


@override
Widget build(BuildContext context){


return MaterialApp(

debugShowCheckedModeBanner:false,

title:"Pass Managers",

theme:ThemeData(

colorSchemeSeed:Colors.blue,

useMaterial3:true,

),


home:const LoginPage(),


);

}


}
