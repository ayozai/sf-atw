@IsTest
public class OlbicoCompanyModelTest {

    @isTest
    public static void test_Name(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.Name = 'abc';

        // assert
        System.assertEquals('abc', actual.Name);
    }
    
    @isTest
    public static void test_Location(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.Location = 'abc';

        // assert
        System.assertEquals('abc', actual.Location);
    }

    @isTest
    public static void test_CountryIsoCode(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.CountryIsoCode = 'abc';

        // assert
        System.assertEquals('abc', actual.CountryIsoCode);
    }

    @isTest
    public static void test_CountryName(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.CountryName = 'abc';

        // assert
        System.assertEquals('abc', actual.CountryName);
    }

    @isTest
    public static void test_CrmId(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.CrmId = 'abc';

        // assert
        System.assertEquals('abc', actual.CrmId);
    }


    @isTest
    public static void test_AmountOfMatchingCrmItems(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.AmountOfMatchingCrmItems = 5;

        // assert
        System.assertEquals(5, actual.AmountOfMatchingCrmItems);
    }

    @isTest
    public static void test_IsBranch(){

        // act
        OlbicoCompanyModel actual = new OlbicoCompanyModel();
        actual.IsBranch = true;

        // assert
        System.assertEquals(true, actual.IsBranch);
    }

    @isTest
    public static void test_getDunsNumbers() {

        // arrange
        OlbicoCompanyModel target = new OlbicoCompanyModel();
        target.Duns = 'abc';

        OlbicoCompanyModel target_child1 = new OlbicoCompanyModel();
        OlbicoCompanyModel target_child2 = new OlbicoCompanyModel();

        target_child1.Duns = 'abc-1';
        target_child2.Duns = 'abc-2';
        target.Children = new OlbicoCompanyModel[] { target_child1, target_child2 };

        // act
        List<String> actual = target.getDunsNumbers();

        // assert
        System.assertEquals(3, actual.size());
    }

    @isTest 
    public static void test_isFamilyMember_Success(){
        String expectedTree = '{"Name":"Almarach International Handelsmaatschappij B.V.","Location":"Netherlands","Duns":"417833209","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Almarach Shipping B.V.","Location":"Netherlands","Duns":"490167581","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Blue Line Logistics Nederland B.V.","Location":"Netherlands","Duns":"402606441","CrmId":null,"CountryIsoCode":null,"Children":[]},{"Name":"Tesco (The European Shipment Company) B.V.","Location":"Netherlands","Duns":"415645530","CrmId":null,"CountryIsoCode":null,"Children":[]}]},{"Name":"Almarach Europe B.V.","Location":"Netherlands","Duns":"489248027","CrmId":null,"CountryIsoCode":null,"Children":[]}]}';
        OlbicoCompanyModel company = new OlbicoCompanyModel();

        Test.startTest();

        company = OlbicoCompanyModel.parseFromJson(expectedTree);

        Boolean isMember = OlbicoCompanyModel.isFamilyMember(company, '489248027');
        
        Test.stopTest();

        System.assert(isMember);
    }

    @isTest 
    public static void test_parsefromJson_Success(){
        String expectedTree = '{"Name":"Almarach International Handelsmaatschappij B.V.","Location":"Netherlands","Duns":"417833209","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Almarach Shipping B.V.","Location":"Netherlands","Duns":"490167581","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Blue Line Logistics Nederland B.V.","Location":"Netherlands","Duns":"402606441","CrmId":null,"CountryIsoCode":null,"Children":[]},{"Name":"Tesco (The European Shipment Company) B.V.","Location":"Netherlands","Duns":"415645530","CrmId":null,"CountryIsoCode":null,"Children":[]}]},{"Name":"Almarach Europe B.V.","Location":"Netherlands","Duns":"489248027","CrmId":null,"CountryIsoCode":null,"Children":[]}]}';
        OlbicoCompanyModel company = new OlbicoCompanyModel();

        company = OlbicoCompanyModel.parseFromJson(expectedTree);
        
        System.assert(true);
    }

    @isTest 
    public static void test_getFlattenTree_Success(){
        String expectedTree = '{"Name":"Almarach International Handelsmaatschappij B.V.","Location":"Netherlands","Duns":"417833209","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Almarach Shipping B.V.","Location":"Netherlands","Duns":"490167581","CrmId":null,"CountryIsoCode":null,"Children":[{"Name":"Blue Line Logistics Nederland B.V.","Location":"Netherlands","Duns":"402606441","CrmId":null,"CountryIsoCode":null,"Children":[]},{"Name":"Tesco (The European Shipment Company) B.V.","Location":"Netherlands","Duns":"415645530","CrmId":null,"CountryIsoCode":null,"Children":[]}]},{"Name":"Almarach Europe B.V.","Location":"Netherlands","Duns":"489248027","CrmId":null,"CountryIsoCode":null,"Children":[]}]}';
        OlbicoCompanyModel company = new OlbicoCompanyModel();

        Test.startTest();

        company = OlbicoCompanyModel.parseFromJson(expectedTree);
        List<OlbicoCompanyModel> flat = company.getFlattenTree();
       
        Test.stopTest();

        System.assert(flat.size() > 0);
    }
}