@IsTest
public class RES_All_Proposals_Test 
{
  @IsTest
  static void TestParse() 
  {
    String json = TestData.getProposalsResponseMockJson();
    RES_All_Proposals allProposals = RES_All_Proposals.Parse(json);
    System.assertNotEquals(null, allProposals, 'Failed to parse JSON!');
    System.assertEquals(3, allProposals.proposals.size(), 'Should have 2 proposals');
    System.assertEquals('FOLDER1', allProposals.proposals[0].folderId, 'PS111 folder Id is incorrect');
    System.assertEquals('FOLDER1', allProposals.proposals[1].folderId, 'PS111 folder Id is incorrect');
    System.assertEquals('FOLDER2', allProposals.proposals[2].folderId, 'PS111 folder Id is incorrect');
  }
}