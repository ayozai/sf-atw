public class OlbicoCompanyModel {
    public string Duns { get; set; }
    public string Name { get; set; }
    public string Location { get; set; }
    public string CountryIsoCode { get; set; }
    public string CountryName { get; set; }
    public string CrmId { get; set; }
    public integer AmountOfMatchingCrmItems { get;set; }
    public boolean IsBranch { get;set; }
    public OlbicoCompanyModel[] Children { get; set; }

    public List<String> getDunsNumbers() {

        List<String> dunsNumbers = new List<String>();
        if (Children != null) {

            for(OlbicoCompanyModel child : Children){
                List<String> childNumbers = child.getDunsNumbers();
                dunsNumbers.addAll(childNumbers);
            }
        }

        dunsNumbers.Add(this.Duns);
        return dunsNumbers;
    }

    public List<OlbicoCompanyModel> getFlattenTree() {
         
        List<OlbicoCompanyModel> treeMembers = new List<OlbicoCompanyModel>();
        if (Children != null) {

            for(OlbicoCompanyModel child : Children){
                List<OlbicoCompanyModel> subTree = child.getFlattenTree();
                treeMembers.addAll(subTree);
            }
        }

        treeMembers.Add(this);
        return treeMembers;
    }

    public static OlbicoCompanyModel parseFromJson(String jsonData){
        OlbicoCompanyModel globalFamilyTree = (OlbicoCompanyModel)JSON.deserialize(jsonData, OlbicoCompanyModel.class);

        return globalFamilyTree;
    }

    public static Boolean isFamilyMember(OlbicoCompanyModel root, String duns)
    {
        if (root.Duns == duns)
            return true;

        for (OlbicoCompanyModel company : root.Children)
        {
            if (isFamilyMember(company, duns))
            {
                return true;
            }
        }

        return false;
    }
}