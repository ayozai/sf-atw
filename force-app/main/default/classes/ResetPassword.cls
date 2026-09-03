public class ResetPassword {
       
@InvocableMethod(label='Reset Password' iconName='slds:custom:custom77')
public static void ResetUserPassword(List<List<string>> userIds){
            
List<Id> idList = userIds[0];
List<User> users = [SELECT Id, Name, isActive FROM User WHERE isActive = true AND Id IN :idList];

if(!users.isEmpty()){
for(User u : users){

System.resetPassword(u.Id, true);
  
}
}
}
}