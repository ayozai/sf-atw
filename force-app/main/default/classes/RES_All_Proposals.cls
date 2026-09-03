public class RES_All_Proposals
{
	public Proposal[] proposals;

	public class Proposal 
    {
		public String proposalId;	    //0003a11f-4ec7-4729-8712-6501f0e90e66
		public String folderId;     	//8662e82f-dd36-47cc-a2d1-94ad3748e7c3
		public String name;	            //Mémoire technique
		public String description;
		public boolean draft;
		public ProposalMergeField[] mergeFields;
		public String masterName;	    //Master Propreté - Réseaux - Offre technique
		public String owner;	        //DEHAENE Cyril
		public Datetime createdAt;	    //2021-12-02T15:36:59.754Z
		public Datetime updatedAt;	    //2021-12-13T10:15:01.100Z
	}

	private class ProposalMergeField 
    {
		public String name;	            //{{proposal}{scope}}
		public String type;	            //text
		public String value;	        //AO nettoyage des locaux du SDIS du 59
	}

	/* Parses the expected json returned and then  attempts to avoid bad Json error. 
	 * as we expect to get these in the form of an array without start/end json tags
	 */ 
	public static RES_All_Proposals Parse(String json)
    {
		return (RES_All_Proposals) System.JSON.deserialize('{ "proposals": ' + json + '}', RES_All_Proposals.class);
	}
}