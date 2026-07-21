import 'package:flutter/material.dart';


class PersonalProvider extends ChangeNotifier {


  String? gender;


  String? maritalStatus;


  bool? isHeadOfHousehold;


  bool? contributesToExpenses;


  bool? isStudent;


  int familyMembers = 1;



  void setGender(String value){

    gender=value;

    notifyListeners();

  }



  void setMaritalStatus(String value){

    maritalStatus=value;

    notifyListeners();

  }




  void setHeadOfHousehold(bool value){

    isHeadOfHousehold=value;


    if(value){

      contributesToExpenses=null;

    }


    notifyListeners();

  }






  void setContributes(bool value){

    contributesToExpenses=value;

    notifyListeners();

  }




  void setStudent(bool value){

    isStudent=value;

    notifyListeners();

  }




  void increaseFamily(){

    familyMembers++;

    notifyListeners();

  }




  void decreaseFamily(){

    if(familyMembers>1){

      familyMembers--;

    }

    notifyListeners();

  }






  Map<String,dynamic> get data => {


    "gender":gender,

    "marital_status":maritalStatus,

    "is_head_of_household":
    isHeadOfHousehold,

    "contributes_to_expenses":
    contributesToExpenses,

    "is_student":
    isStudent,

    "family_members":
    familyMembers,


  };

// في PersonalProvider
double get pageProgress {
  int totalQuestions = (isHeadOfHousehold == false) ? 5 : 4;
  int completedQuestions = 0;

  if (gender != null) completedQuestions++;
  if (maritalStatus != null) completedQuestions++;
  if (isHeadOfHousehold != null) completedQuestions++;
  if (isStudent != null) completedQuestions++;
  if (isHeadOfHousehold == false && contributesToExpenses != null) completedQuestions++;

  
  double weight =  (1 / 3); 
  return (completedQuestions / totalQuestions) * weight;
}

bool get isValid {


  if(gender == null) return false;


  if(maritalStatus == null) return false;


  if(isHeadOfHousehold == null) return false;



  if(isHeadOfHousehold == false &&
      contributesToExpenses == null){

    return false;

  }


  if(isStudent == null) return false;


  return true;

}
}