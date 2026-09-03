public class SetPassword {
    
    @InvocableMethod(label='Set Password' iconName='slds:custom:custom77')
    public static void SetUserPassword(List<PasswordInput> passwordInputs) {
        List<Id> userIds = new List<Id>();
        for (PasswordInput input : passwordInputs) {
            userIds.addAll(input.userIds);
        }
        
        List<User> users = [SELECT Id, Name, IsActive FROM User WHERE IsActive = true AND Id IN :userIds];
        
        for (User u : users) {
            for (PasswordInput input : passwordInputs) {
                if (input.userIds.contains(u.Id)) {
                    String password = input.password;
                    System.setPassword(u.Id, password);
                    break;
                }
            }
        }
    }
    
    public class PasswordInput {
        @InvocableVariable(required=true)
        public List<Id> userIds;
        
        @InvocableVariable(required=true)
        public String password;
    }
}