@isTest
private class AutomatedApexSharingTest{
    @testSetup static void setup(){
        //set up test data
        Profile pf= [Select Id from profile where Name='Standard User']; 
        List<user> newUsers = new List<User>();
        String orgId = UserInfo.getOrganizationId(); 
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-',''); 
        Integer RandomId = Integer.valueOf(Math.rint(Math.random()*1000000)); 
        String uniqueName = orgId+dateString+RandomId;
        User hrUser = new User(firstname = 'Alan', 
                            lastName = 'McCarthy', 
                            email = uniqueName + '@test1' + orgId + '.org', 
                            Username = uniqueName + '@test1' + orgId + '.org', 
                            EmailEncodingKey = 'ISO-8859-1', 
                            Alias = uniqueName.substring(18, 23), 
                            TimeZoneSidKey = 'America/Los_Angeles', 
                            LocaleSidKey = 'en_US', 
                            LanguageLocaleKey = 'en_US', 
                            ProfileId = pf.Id);
        newUsers.add(hrUser);
        User recruiterUser = new User(firstname = 'John', 
                            lastName = 'Smith', 
                            email = uniqueName + '@test2' + orgId + '.org', 
                            Username = uniqueName + '@test2' + orgId + '.org', 
                            EmailEncodingKey = 'ISO-8859-1', 
                            Alias = uniqueName.substring(18, 23), 
                            TimeZoneSidKey = 'America/Los_Angeles', 
                            LocaleSidKey = 'en_US', 
                            LanguageLocaleKey = 'en_US', 
                            ProfileId = pf.Id);
        newUsers.add(recruiterUser);
        insert newUsers;
    
        Id uRTId = Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with User').getRecordTypeId();
        Id gRTId = Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with Public Group').getRecordTypeId();
        List<ApexShare_Config__c> shareConfigs = new List<ApexShare_Config__c>();
        ApexShare_Config__c ascTest1 = new ApexShare_Config__c();
        ascTest1.Name = 'Test User Sharing with Criteria';
        ascTest1.Object_API_Name__c = 'ApexShare_Test__c';
        ascTest1.RecordTypeId = uRTId;
        ascTest1.Access__c = 'Edit';
        ascTest1.Lookup_API_Name__c = 'Recruiter__c';
        ascTest1.Apex_Sharing_Reason__c = 'Recruiter__c';
        ascTest1.Criteria_Field_Name__c = 'Name';
        ascTest1.Criteria_Field_Value__c = 'Michelle Lambert';
        ascTest1.Active__c = TRUE;
        shareConfigs.add(ascTest1);

        ApexShare_Config__c ascTest2 = new ApexShare_Config__c();
        ascTest2.Name = 'Test User Sharing without Criteria';
        ascTest2.Object_API_Name__c = 'ApexShare_Test__c';
        ascTest2.RecordTypeId = uRTId;
        ascTest2.Access__c = 'Read';
        ascTest2.Lookup_API_Name__c = 'Hiring_Manager__c';
        ascTest2.Apex_Sharing_Reason__c = 'Hiring_Manager__c';
        ascTest2.Criteria_Field_Name__c = NULL;
        ascTest2.Criteria_Field_Value__c = NULL;
        ascTest2.Active__c = TRUE;
        shareConfigs.add(ascTest2);

        List<Group> allGroups = new List<Group>();
        Group grp1 = new Group();
        grp1.name = 'California';
        grp1.Type = 'Regular'; 
        allGroups.add(grp1);
        Group grp2 = new Group();
        grp2.name = 'New York';
        grp2.Type = 'Regular'; 
        allGroups.add(grp2);
        insert allGroups;
        
        ApexShare_Config__c ascTest3 = new ApexShare_Config__c();
        ascTest3.Name = 'Test California Group Sharing';
        ascTest3.Object_API_Name__c = 'ApexShare_Test__c';
        ascTest3.RecordTypeId = gRTId;
        ascTest3.Access__c = 'Edit';
        ascTest3.Group_Role_Name__c = 'California';
        ascTest3.Apex_Sharing_Reason__c = 'California_Group__c';
        ascTest3.Criteria_Field_Name__c = 'Name';
        ascTest3.Criteria_Field_Value__c = 'Michelle Lambert';
        ascTest3.Active__c = TRUE;
        shareConfigs.add(ascTest3);

        ApexShare_Config__c ascTest4 = new ApexShare_Config__c();
        ascTest4.Name = 'Test New York Group Sharing Without Criteria';
        ascTest4.Object_API_Name__c = 'ApexShare_Test__c';
        ascTest4.RecordTypeId = gRTId;
        ascTest4.Access__c = 'Edit';
        ascTest4.Group_Role_Name__c = 'New_York';
        ascTest4.Apex_Sharing_Reason__c = 'New_York_Group__c';
        ascTest4.Criteria_Field_Name__c = NULL;
        ascTest4.Criteria_Field_Value__c = NULL;
        ascTest4.Active__c = TRUE;
        shareConfigs.add(ascTest4);
        insert shareConfigs;

        List<ApexShare_Test__c> testRecords = new List<ApexShare_Test__c>();
        ApexShare_Test__c astTest1 = new ApexShare_Test__c();
        astTest1.Name = 'Michelle Lambert';
        astTest1.Recruiter__c = recruiterUser.Id;
        astTest1.Hiring_Manager__c = hrUser.Id;
        testRecords.add(astTest1);

        ApexShare_Test__c astTest2 = new ApexShare_Test__c();
        astTest2.Name = 'Michael Jones';
        astTest2.Recruiter__c = NULL;
        astTest2.Hiring_Manager__c = NULL;
        testRecords.add(astTest2);
        insert testRecords;

    }
    
    //test trigger validations
    static testMethod void testTrigger(){
        List<ApexShare_Config__c> apexSCList = [SELECT Id FROM ApexShare_Config__c];
        update apexSCList;
    }

    //test user sharing features
    static testMethod void testSharing(){
        Map<Id, ApexShare_Test__c> testRecords = new Map<Id, ApexShare_Test__c>([SELECT Id, Recruiter__c, Hiring_Manager__c FROM ApexShare_Test__c]);
        List<Id> recordIds = new List<Id>();
        for(ApexShare_Test__c rec: testRecords.values()){
            recordIds.add(rec.Id);
        }
        AutomatedUserSharing.createUserShareRecords(recordIds);
        AutomatedGroupSharing.creategroupShareRecords(recordIds);

        // This query returns jobs and related sharing records that were inserted       
        // by the batch job's execute method.     
        List<ApexShare_Test__c> jobs = [SELECT Id, Name, Hiring_Manager__c, Recruiter__c, 
            (SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause FROM Shares 
            WHERE (RowCause = :Schema.ApexShare_Test__Share.rowCause.Recruiter__c OR 
            RowCause = :Schema.ApexShare_Test__Share.rowCause.Hiring_Manager__c OR 
            RowCause = :Schema.ApexShare_Test__Share.rowCause.California_Group__c OR 
            RowCause = :Schema.ApexShare_Test__Share.rowCause.New_York_Group__c))
            FROM ApexShare_Test__c];
        
        List<Id> newShareIds = new List<Id>();
        for(ApexShare_Test__c job : jobs){
            for(ApexShare_Test__Share jobShr : job.Shares){
               // Test the sharing record for hiring manager on job.             
                if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.Hiring_Manager__c){
                    System.assertEquals(jobShr.UserOrGroupId,job.Hiring_Manager__c);
                    System.assertEquals(jobShr.AccessLevel,'Read');
                    if(job.Name == 'Michelle Lambert') newShareIds.add(jobShr.Id);
                }
                // Test the sharing record for recruiter on job.
                else if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.Recruiter__c){
                    System.assertEquals(jobShr.UserOrGroupId,job.Recruiter__c);
                    System.assertEquals(jobShr.AccessLevel,'Edit');
                    if(job.Name == 'Michelle Lambert') newShareIds.add(jobShr.Id);
                }
                else if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.California_Group__c){
                    System.assertEquals(jobShr.AccessLevel,'Edit');
                    if(job.Name == 'Michelle Lambert') newShareIds.add(jobShr.Id);
                }
                else if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.New_York_Group__c){
                    System.assertEquals(jobShr.AccessLevel,'Edit');
                    if(job.Name == 'Michelle Lambert') newShareIds.add(jobShr.Id);
                }
            }
        }
        //check total number of share records
        System.assert(newShareIds.size() == 4);
    }

    //test sharing recalculation
    static testMethod void testRecalculation(){
        List<ApexShare_Config__c> ascList = [SELECT Id, Name FROM ApexShare_Config__c];
        Id recordId = NULL;
        for(ApexShare_Config__c apexsc: ascList){
            if(apexsc.Name == 'Test User Sharing with Criteria') recordId = apexsc.Id;
        }
        ApexSharingRecalculation asr = new ApexSharingRecalculation(recordId, true);
        String jobId = Database.executeBatch(asr);

        // Get the Apex job and verify there are no errors.
        AsyncApexJob aaj = [Select JobType, TotalJobItems, JobItemsProcessed, Status, 
                            CompletedDate, CreatedDate, NumberOfErrors 
                            from AsyncApexJob where Id = :jobId];
        System.assertEquals(0, aaj.NumberOfErrors);
      
        // This query returns jobs and related sharing records that were inserted       
        // by the batch job's execute method.     
        List<ApexShare_Test__c> jobs = [SELECT Id, Name, Hiring_Manager__c, Recruiter__c, 
            (SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause FROM Shares 
            WHERE (RowCause = :Schema.ApexShare_Test__Share.rowCause.Recruiter__c OR 
            RowCause = :Schema.ApexShare_Test__Share.rowCause.Hiring_Manager__c ))
            FROM ApexShare_Test__c WHERE Name = 'Michelle Lambert'];       
        
        // Validate that Apex managed sharing exists on jobs.     
        for(ApexShare_Test__c job : jobs){
            for(ApexShare_Test__Share jobShr : job.Shares){
               // Test the sharing record for hiring manager on job.             
                if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.Hiring_Manager__c){
                    System.assertEquals(jobShr.UserOrGroupId,job.Hiring_Manager__c);
                    System.assertEquals(jobShr.AccessLevel,'Read');
                }
                // Test the sharing record for recruiter on job.
                else if(jobShr.RowCause == Schema.ApexShare_Test__Share.RowCause.Recruiter__c){
                    System.assertEquals(jobShr.UserOrGroupId,job.Recruiter__c);
                    System.assertEquals(jobShr.AccessLevel,'Edit');
                }
            }
        }

        for(ApexShare_Config__c apexsc: ascList){
            if(apexsc.Name == 'Test User Sharing without Criteria') recordId = apexsc.Id;
        }
        ApexSharingRecalculation asr2 = new ApexSharingRecalculation(recordId, true);
        String jobId2 = Database.executeBatch(asr2);

        for(ApexShare_Config__c apexsc: ascList){
            if(apexsc.Name == 'Test California Group Sharing') recordId = apexsc.Id;
        }
        ApexSharingRecalculation asr3 = new ApexSharingRecalculation(recordId, true);
        String jobId3 = Database.executeBatch(asr3);

        List<Id> ids = new List<Id>();
        for(ApexShare_Config__c apexsc: ascList){
            if(apexsc.Name == 'Test New York Group Sharing Without Criteria') ids.add(apexsc.Id);
        }
        SharingRecalculationBatch.runBatchJob(ids);
    }

}