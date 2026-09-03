public class OlbicoCdpController {

    private String token;
    private String language;
    private String accountId;
    private String recordType;
    private String profile;
    private String availableRecordTypes;
    
    private String companyName;
    private String companyAddress;
    private String companyCity;
    private String companyPostcode;
    private String companyCountry;
    private String companyDuns;
    private String companyRegistrationNumber;


    private Boolean showMDPPage = true;
    //private String userCountry;
    
    
    public OlbicoCdpController (ApexPages.StandardController controller) {

        List<string> availableRecordTypesList = GetAvailableRecordTypeNamesForSObject(Account.SObjectType);
        availableRecordTypes = String.join( availableRecordTypesList , ' ');
        
        List<string> contactRecordTypes = GetAvailableRecordTypeNamesForSObject(Contact.SObjectType);        
        
        //String recordTypeID = Schema.SObjectType.Account.getRecordTypeInfosByName().get('TEST1').getRecordTypeId();
        //System.debug('testretrive recordType' + recordTypeID);
        
              
        FillAccountId();
        FillCompanyName();
        FillCompanyAddress();
        FillCompanyCity();
        FillCompanyPostcode();
        FillCompanyCountry();
        FillCompanyDuns();
        FillCompanyRegistrationNumber();
        FillProfile();
        FillLanguage();
        FillRecordType();  
        LogIn();
    }
    
    private void FillProfile()
    {
       List<Profile> listProfiles = [SELECT Id, Name FROM Profile WHERE Id=:userinfo.getProfileId() LIMIT 1];
       profile = listProfiles [0].Name;
       profile = profile.replace('&', 'and');
    }
    
    private void FillRecordType()
    {
        recordType = ApexPages.currentPage().getParameters().get('RecordType');

      


        
        //}
        
        
        //if(u.Country == 'France')
        //{
            if(recordType != null) 
            {
                String recordtypename = Schema.SObjectType.Account.getRecordTypeInfosById().get(recordType).getname();           
                showMDPPage = (recordtypename != 'UK_record_type');
            }
        //}
        //else
        //{
        //    showMDPPage = false;
        //}
        
    }
    
    private void FillAccountId()
    {
        Id accountIdShort = ApexPages.currentPage().getParameters().get('accid');

        if (accountIdShort == null)
        {
            //This means we are coming from an account so just get id from id param
            accountIdShort = ApexPages.currentPage().getParameters().get('id');
        }
        
        if (accountIdShort != null)
        {
            Account account = [SELECT Id, Name FROM Account WHERE Id = :accountIdShort ];
            accountId= account.Id;
        }
        else
        {
            accountId = ApexPages.currentPage().getParameters().get('selectedAccount');
        }        
        System.debug('Account id: ' + accountId);
    }    

    private void FillCompanyName()
    {

        if (accountId != null)
        {
            Account account = [SELECT Id, Name FROM Account WHERE Id = :accountId ];
            companyName= account.Name;
        }
        else
        {
            companyName= '';
        }        
        System.debug('Company name: ' + companyName);
    }

    private void FillCompanyAddress()
    {
    
        if (accountId != null)
        {
            Account account = [SELECT Id, BillingStreet FROM Account WHERE Id = :accountId ];
            companyAddress= account.BillingStreet;
        }
        else
        {
            companyAddress= '';
        }        
        System.debug('Company address: ' + companyAddress);
    }
    
    private void FillCompanyCity()
    {
    
        if (accountId != null)
        {
            Account account = [SELECT Id, BillingCity FROM Account WHERE Id = :accountId ];
            companyCity= account.BillingCity;
        }
        else
        {
            companyCity= '';
        }        
        System.debug('Company city: ' + companyCity);
    }
    
    private void FillCompanyPostcode()
    {
    
        if (accountId != null)
        {
            Account account = [SELECT Id, BillingPostalCode FROM Account WHERE Id = :accountId ];
            companyPostcode= account.BillingPostalCode;
        }
        else
        {
            companyPostcode= '';
        }        
        System.debug('Company city: ' + companyCity);
    }
    
    private void FillCompanyCountry()
    {
        if (accountId != null)
        {
            Account account = [SELECT Id, BillingCountry FROM Account WHERE Id = :accountId ];
            companyCountry = account.BillingCountry;
        }
        else
        {
            User u = [select Country from user where id=:userinfo.getuserid()];
 
            if(ApexPages.currentPage().getParameters().get('companyCountry') != null)
            {
                companyCountry = ApexPages.currentPage().getParameters().get('companyCountry');
            
            }
            else
            {
                companyCountry = u.Country;        
                if(companyCountry == null)
                {
                    companyCountry = 'France';
                }
            }    
       //companyCountry= '';
       }
                
       System.debug('Company country: ' + companyCountry);
    }
    
    private void FillCompanyDuns()
    {
    
        if (accountId != null)
        {
            Account account = [SELECT Id, DUNS__c FROM Account WHERE Id = :accountId ];
            companyDuns= account.DUNS__c;
        }
        else
        {
            companyDuns= '';
        }        
        System.debug('Company Duns: ' + companyDuns);
    }
 
    private void FillCompanyRegistrationNumber()
    {
    
        //if (accountId != null)
        //{
            //Account account = [SELECT Id, Registration_number__c FROM Account WHERE Id = :accountId ];
            //companyRegistrationNumber= account.Registration_number__c;
        //}
        //else
       // {
         //   companyRegistrationNumber= '';
        //}        
        //System.debug('Company RegistrationNumber: ' + companyRegistrationNumber);
    }   
    
    private void FillLanguage()

    {
        String locale = UserInfo.getLanguage();
        String[] localeParts = locale.split('_');
        language = localeParts[0];
    }
    
    private void LogIn() {
        token = '';
        try {
            
            OlbicoCdpClientServiceProxy.BasicHttpBinding_ICrmClientService1 loginService = new OlbicoCdpClientServiceProxy.BasicHttpBinding_ICrmClientService1();

            String username = OlbicoSettings__c.getOrgDefaults().CdpUserName__c;
            String password = OlbicoSettings__c.getOrgDefaults().CdpPassword__c;
            
            System.debug('userName: ' + username );
            System.debug('password: ' + password );
            
            token = loginService.CrmClientLogIn(username,password);
            if (token != '') {
                System.debug('Login finished, user is logged in ' + token);
            }
            else {
                System.debug('Login finished, user is NOT logged in');
            }
        }
        catch(Exception e) {
            System.debug('Login ended in an exception:');
            System.debug(e.getMessage());
        }
    }
    
    public string getAccountId() {
        return accountId;
    }
    
    public string getCompanyName() {
        
        return EncodingUtil.urlEncode(companyName, 'UTF-8');
        //return companyName;
    }
    
    public string getCompanyAddress() {
        return companyAddress;
    }
    
    public string getCompanyCity() {
        return companyCity;
    }
    
    public string getCompanyPostcode() {
        return companyPostcode;
    }
    
    public string getCompanyCountry() {
        return companyCountry;
    }
    
    public string getCompanyDuns() {
        return companyDuns;
    }
    
    public string getCompanyRegistrationNumber() {
        return companyRegistrationNumber;
    }
    
    public string getRecordType() {
        return recordType;
    }
    
    public string getLanguage() {
        return language;
    }
    
    public string getToken() {
        return token;
    }
    
    public string getProfile() {
        return profile;
    }
    
    //public string getUserCountry() {
    //    return userCountry;
    //}
    
    
    public string getAvailableRecordTypes() {
        
        return EncodingUtil.urlEncode(availableRecordTypes, 'UTF-8');
    }
    
    public string getParams() {
        //return the current querystring as a string
        String queryString = '';
        for (String key: ApexPages.currentPage().getParameters().keyset() ) {
            String value = ApexPages.currentPage().getParameters().get(key);
            
            value = value.replace('&amp;', 'AND');
            queryString += '&' + key + '=' + EncodingUtil.urlEncode(value, 'UTF-8');
        }
        
        
      
        return queryString;

    }
    
    
      // Returns a List of the Names of all RecordTypes
    // available to the running user for a given SOBject type
    public static List<String> GetAvailableRecordTypeNamesForSObject(Schema.SObjectType objType) {
        
        List<String> names = new List<String>();
        List<RecordTypeInfo> infos = objType.getDescribe().getRecordTypeInfos();
        // If there are 2 or more RecordTypes...
        if (infos.size() > 1) {
            for (RecordTypeInfo i : infos) {
               if (i.isAvailable() 
               // Ignore the Master Record Type, whose Id always ends with 'AAA'.
               // We check the Id because Name can change depending on the user's language.
                && !String.valueOf(i.getRecordTypeId()).endsWith('AAA'))
                    names.add(i.getRecordTypeId());
            }
        } 
        // Otherwise there's just the Master record type,
        // so add it in, since it MUST always be available
        else names.add(infos[0].getName());
        return names;
    }


     public PageReference redirect() {
         if (showMDPPage) {
             return null;
         } else {
             PageReference pr = new PageReference('/001/e?nooverride=1&&RecordType=' + recordType);
             pr.setRedirect(true);
           
             return pr;
         }
     }
    
}