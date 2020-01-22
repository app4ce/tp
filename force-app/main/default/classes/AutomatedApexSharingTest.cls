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
        ascTest2.Access__c = 'Edit';
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
        ascTest4.Name = 'Test New York Group Sharing';
        ascTest4.Object_API_Name__c = 'ApexShare_Test__c';
        ascTest4.RecordTypeId = gRTId;
        ascTest4.Access__c = 'Edit';
        ascTest4.Group_Role_Name__c = 'New_York';
        ascTest4.Apex_Sharing_Reason__c = 'New_York_Group__c';
        ascTest4.Criteria_Field_Name__c = NULL;
        ascTest4.Criteria_Field_Value__c = NULL;
        ascTest4.Active__c = TRUE;
        shareConfigs.add(ascTest4);

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

    static testMethod void testUserSharing(){
        Map<Id, ApexShare_Test__c> testRecords = new Map<Id, ApexShare_Test__c>([SELECT Id, Recruiter__c, Hiring_Manager__c FROM ApexShare_Test__c]);
        List<Id> recordIds = new List<Id>();
        for(ApexShare_Test__c rec: testRecords.values()){
            if(rec.Recruiter__c != NULL && rec.Hiring_Manager__c != NULL) recordIds.add(rec.Id);
        }
        AutomatedUserSharing.createUserShareRecords(recordIds);
    }

    //test user sharing features

    //test group sharing features

    //test sharing recalculation for users

    //test sharing recalculation for groups


}