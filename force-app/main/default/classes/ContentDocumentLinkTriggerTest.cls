@IsTest
public class ContentDocumentLinkTriggerTest {

    @IsTest
    public static void testUpdateAfterInsert()
 	{
        Account a = new Account(Name = 'TestAccount');
        insert a;
        
        ContentVersion contentVersion = new ContentVersion(
          Title = 'Penguins',
          PathOnClient = 'Penguins.jpg',
          VersionData = Blob.valueOf('Test Content'),
          IsMajorVersion = true
        );
        insert contentVersion;  
        
        List<ContentDocument> documents = [
            SELECT Id, Title, LatestPublishedVersionId 
            FROM ContentDocument LIMIT 1
        ];

        Inspection__c i = new Inspection__c(
        	Account__c = a.id,
        	Audit_Date_Time__c = System.now(),
        	Type__c = '0');
        insert i;
        
        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=i.id;
        contentlink.ShareType= 'V';
        contentlink.Visibility = 'InternalUsers'; 
        contentlink.ContentDocumentId = documents[0].id;
        insert contentlink;
        
        List<ContentDocumentLink> documentLinks = [
            SELECT Id, Visibility
            FROM ContentDocumentLink WHERE Id = :contentlink.Id LIMIT 1
        ];
        
        System.assertEquals('AllUsers', documentLinks[0].Visibility);
        
        ContentDocumentLink contentlink2=new ContentDocumentLink();
        contentlink2.LinkedEntityId=a.id;
        contentlink2.ShareType= 'V';
        contentlink2.Visibility = 'InternalUsers'; 
        contentlink2.ContentDocumentId = documents[0].id;
        insert contentlink2;
        
        List<ContentDocumentLink> documentLinks2 = [
            SELECT Id, Visibility
            FROM ContentDocumentLink WHERE Id = :contentlink2.Id LIMIT 1
        ];
        
        System.assertEquals('InternalUsers', documentLinks2[0].Visibility);
 	}
}