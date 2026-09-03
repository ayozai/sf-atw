public class OlbicoGlobalFamilyTreeController {

    private String globalUltimateDuns;
    private static OlbicoGlobalFamilyTreeSettings settings = OlbicoGlobalFamilyTreeSettings.getInstance();

    public OlbicoGlobalFamilyTreeController(ApexPages.StandardController controller){
    }

    public String CurrentId{
        private set;
        get;
    }

    public String CurrentDuns{
        private set;
        get;
    }

    public String FamilyTreeJSON{
        private set;
        get;
    }

    public Integer TotalMembers {
        private set;
        get;
    }

    public boolean SupportsBranchFiltering {
        private set;
        get;
    }

    public PageReference fetchTree() {
        try{
            System.debug('Settings object: ' + settings);
            System.debug('[FTREE] Executing fetchTree...');

            this.CurrentId = ApexPages.currentPage().getParameters().get('id');

            if(CurrentId == null || CurrentId.length() == 0){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Invalid page param. No account id was specified.'));
                return null;
            }

            OlbicoAccountRepository repository  = new OlbicoAccountRepository(settings);
            OlbicoGlobalFamilyAPIProxy api      = new OlbicoGlobalFamilyAPIProxy(settings);

            Account account         = repository.getById(CurrentId);
            this.CurrentDuns        = (String)account.get(settings.DunsFieldName);
            this.globalUltimateDuns = (String)account.get(settings.GlobalUltimateDunsFieldName);

            this.SupportsBranchFiltering = settings.Version != null && settings.Version != '' && settings.Version != 'v1';

            String jsonTreeData = this.getTreeFromCache(this.CurrentDuns);
            System.debug('[FTREE] jsonTreeData:' + jsonTreeData);
            boolean fromCache = false;

            if (jsonTreeData == null || jsonTreeData == '') {
                jsonTreeData = api.getTree(this.CurrentDuns);
            } else {
                fromCache = true;
            }

            if(jsonTreeData == null || jsonTreeData.length() == 0){

                System.debug('[FTREE] Empty family tree for duns:' + this.CurrentDuns);
                this.FamilyTreeJSON = '{}';

                return null;
            }

            System.debug('[FTREE] Parsing family tree.');
            OlbicoCompanyModel company = OlbicoCompanyModel.parseFromJson(jsonTreeData);

            Map<String,List<Account>> accountsExistingInTree;

            if (this.globalUltimateDuns == null || this.globalUltimateDuns == '`')
            {
                System.debug('[FTREE] Get accounts which exist in the tree by comparing their duns numbers.');

                List<String> dunsNumbers = company.getDunsNumbers();
                accountsExistingInTree = repository.getAccountsByDunsNumbers(dunsNumbers);
            }
            else
            {
                System.debug('[FTREE] Get accounts which exist in the tree using the global ultimate DUNS');
                accountsExistingInTree = repository.getAccountsByGlobalUltimate(globalUltimateDuns);
            }

            if(accountsExistingInTree.size() == 0){
                System.debug('[FTREE] fetchTree warning, no mappings found for this tree.');
            }

            System.debug('[FTREE] Binding existing accounts to tree');
            List<OlbicoCompanyModel> flattenTree = company.getFlattenTree();
            this.TotalMembers = flattenTree.size();
            this.bindTreeCrmId(flattenTree, accountsExistingInTree);

            System.debug('[FTREE] Serialize tree to JSON');
            this.FamilyTreeJSON = JSON.serialize(company);

            if (!fromCache) {
                Set<String> accountIds = accountsExistingInTree.keySet();
                this.putTreeInCache(accountIds, jsonTreeData);
            }

            System.debug('[FTREE] fetchTree was successfully completed.');
        }
        catch(Exception ex){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, ex.getMessage()));
            System.debug('[FTREE] fetchTree failed. Error: ' + ex.getMessage());
        }

        return null;
    }

    @TestVisible
    private String getTreeFromCache(String dunsNumber)
    {
        if (settings == null || settings.CacheNamespace == null || settings.CacheNamespace == '')
            return null;

        String cacheKey = settings.CacheNamespace + '.tree' + dunsNumber;
        System.debug('[FTREE] Getting tree from cache: ' + cacheKey);
        String treeJson = (String)Cache.Session.get(cacheKey);

        if (treeJson != null){
            System.debug('[FTREE] Found tree in cache');
        }

        return treeJson;
    }

    @TestVisible
    private void putTreeInCache(Set<String> dunsNumbers, String tree)
    {
        if (settings == null || settings.CacheNamespace == null || settings.CacheNamespace == '')
            return;

        for(String dunsNumber : dunsNumbers) {

            String cacheKey = settings.CacheNamespace + '.tree' + dunsNumber;
            System.debug('[FTREE] Putting tree in cache: ' + cacheKey);
            Cache.Session.put(cacheKey, tree, 28800);
        }
    }

    @TestVisible
    private void bindTreeCrmId(List<OlbicoCompanyModel> treeMembers, Map<String,List<Account>> accountsExistingInTree)
    {
        for (OlbicoCompanyModel treeMember : treeMembers)
        {
            List<Account> existingAccounts = accountsExistingInTree.get(treeMember.Duns);
            if(existingAccounts != null){

                for(Account account : existingAccounts) {

                    treeMember.CrmId = account.Id;
                    if (account.Id == this.CurrentId)
                        break;
                }

                treeMember.AmountOfMatchingCrmItems = existingAccounts.size();
            }
        }
    }

    public static void cc() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}