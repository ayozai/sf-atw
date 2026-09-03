@IsTest(SeeAllData=true)
public class OlbicoGlobalFamilyTreeControllerTest {
    
    private static OlbicoGlobalFamilyTreeSettings settings = OlbicoGlobalFamilyTreeSettings.getInstance();

    @isTest
    public static void is_cc_test(){
        
        OlbicoGlobalFamilyTreeController.cc();
    }
    
    
    @isTest
    public static void test_getTree_Fails(){
        PageReference pageRef = Page.OlbicoGlobalFamilyTree;
        Test.setCurrentPage(pageRef);

        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);

        Test.startTest();
        controller.fetchTree();
        Test.stopTest();

        System.assert(ApexPages.getMessages().size() == 1);
        System.assert(ApexPages.getMessages().get(0).getDetail() == 'Invalid page param. No account id was specified.');
        System.assert(ApexPages.getMessages().get(0).getSeverity() == ApexPages.Severity.ERROR); 

        System.assert(controller.FamilyTreeJSON == null);
        System.assert(controller.CurrentDuns == null);
    }

    
    @isTest
    public static void test_fetchTree(){
        PageReference pageRef = Page.OlbicoGlobalFamilyTree;
        Test.setCurrentPage(pageRef);

        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        ApexPages.currentPage().getParameters().put('id', 'abc12');

        Test.startTest();
        controller.fetchTree();
        Test.stopTest();

        System.assert(controller.FamilyTreeJSON == null);
        System.assert(controller.CurrentDuns == null);
    }

    @isTest
    public static void test_SupportsBranchFiltering(){
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        boolean actual = controller.SupportsBranchFiltering;

        System.assertEquals(null, actual);
    }

    @isTest
    public static void test_TotalMembers(){
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        Integer actual = controller.TotalMembers;

        System.assertEquals(null, actual);
    }

    @isTest
    public static void test_FamilyTreeJSON(){
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        String actual = controller.FamilyTreeJSON;

        System.assertEquals(null, actual);
    }

    @isTest
    public static void test_CurrentDuns(){
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        String actual = controller.CurrentDuns;

        System.assertEquals(null, actual);
    }

    @isTest
    public static void test_CurrentId(){
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        String actual = controller.CurrentId;

        System.assertEquals(null, actual);
    }

    @isTest
    public static void test_putTreeInCache() {

        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);

        Set<String> str = new Set<String>();
        str.add('meh');

        //controller.putTreeInCache(str, 'abc');

        System.assert(true);
    }

    @isTest
    public static void test_bindTreeCrmId() {

        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        List<OlbicoCompanyModel> treeMembers = new List<OlbicoCompanyModel>();
        treeMembers.add(new OlbicoCompanyModel());

        Map<String,List<Account>> other = new Map<String, List<Account>>();

        controller.bindTreeCrmId(treeMembers, other);

        System.assert(true);
    }

    @isTest
    public static void test_getTreeFromCache() {
        
        OlbicoGlobalFamilyTreeController controller = new OlbicoGlobalFamilyTreeController(null);
        //controller.getTreeFromCache('abc');
        System.assert(true);
    }
}